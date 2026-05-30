# Rate Limiting in ASP.NET Core

**Category:** System Design / Rate Limiting
**Difficulty:** 🟡 Middle
**Tags:** `RateLimiter`, `ASP.NET-Core`, `.NET-7`, `FixedWindowLimiter`, `SlidingWindowLimiter`, `TokenBucketLimiter`, `middleware`

## Question

> How do you implement rate limiting in ASP.NET Core (.NET 7+)? Walk through configuring per-user and global limits, applying them per endpoint, and customising the rejection response.

## Short Answer

ASP.NET Core 7 introduced first-party rate limiting via `Microsoft.AspNetCore.RateLimiting`. You register named policies with `AddRateLimiter`, configure partition keys (per-user, per-IP, per-route), choose an algorithm (`FixedWindowLimiter`, `SlidingWindowLimiter`, `TokenBucketLimiter`, `ConcurrencyLimiter`), and apply policies to endpoints via `.RequireRateLimiting("policy-name")` or globally via `options.GlobalLimiter`. The `OnRejected` callback lets you return a properly formatted 429 response with `Retry-After`. For multi-instance deployments, the built-in limiters are **in-process only** — use a Redis-backed solution for distributed limiting.

## Detailed Explanation

### Architecture Overview

```
Request → UseRateLimiter middleware → [check limiter]
           ├─ HIT (permit available)  → next middleware
           └─ MISS (rate exceeded)    → OnRejected → 429
```

The middleware is inserted via `app.UseRateLimiter()` — must be placed **after** `UseRouting()` and **after** `UseAuthentication()` / `UseAuthorization()` if the partition key uses `ctx.User`.

### Partition Keys: Who Gets Counted?

A `PartitionedRateLimiter` groups requests into "partitions" by a key. Each partition has its own independent counter:

| Key | Effect |
|-----|-------|
| `"global"` (constant) | One shared counter for all requests |
| `ctx.User.Identity.Name` | One counter per authenticated user |
| `ctx.Connection.RemoteIpAddress` | One counter per IP address |
| `ctx.GetRouteValue("tenantId")` | One counter per tenant |
| `(user, route)` combined | One counter per user per endpoint |

> **Important:** If `UseAuthentication` hasn't run yet when the rate limiter evaluates, `ctx.User.Identity.Name` is null for all requests. Place `UseRateLimiter` AFTER `UseAuthentication`.

### Algorithm Selection Guide

| Scenario | Algorithm | Reason |
|---------|-----------|--------|
| Simple per-minute API limit | `FixedWindow` | Easiest; acceptable burst at window edge |
| Strict no-burst limit | `SlidingWindow` | Better accuracy than fixed window |
| Allow bursting for bursty clients | `TokenBucket` | Controlled burst; client-friendly |
| Limit concurrent DB connections | `ConcurrencyLimiter` | Limits in-flight requests, not rate |

### Queuing vs Rejecting

Limiters support a `QueueLimit`:
- `QueueLimit = 0`: reject immediately with 429 (recommended for public APIs).
- `QueueLimit > 0`: excess requests wait in a FIFO queue (adds backpressure; risk of memory growth under sustained overload).

Use queuing only for internal services where waiting is preferable to failing.

### Chaining Limiters (Global + Per-User)

Use `PartitionedRateLimiter.CreateChained` to stack multiple limiters. A request must pass ALL of them:

```csharp
options.GlobalLimiter = PartitionedRateLimiter.CreateChained(
    globalLimiter,    // 1000 req/s total
    perUserLimiter    // 100 req/min per user
);
```

The first limiter that rejects the request short-circuits the chain.

### Endpoint-Level vs Controller-Level Attributes

For minimal APIs: `.RequireRateLimiting("policy")`
For controllers: `[EnableRateLimiting("policy")]` / `[DisableRateLimiting]`

`[DisableRateLimiting]` bypasses the global limiter on that endpoint — useful for health checks.

## Code Example

```csharp
// ASP.NET Core 8 — Comprehensive rate limiting setup
// Covers: per-user, global, token bucket, per-endpoint, custom 429 response

using Microsoft.AspNetCore.RateLimiting;
using System.Net;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthentication().AddJwtBearer();
builder.Services.AddAuthorization();

builder.Services.AddRateLimiter(options =>
{
    // ── 1. Per-user sliding window: 100 req/min ───────────────────────
    options.AddPolicy("api", httpCtx =>
    {
        // Partition key: authenticated user ID > IP > "anonymous"
        var key = httpCtx.User.FindFirst("sub")?.Value
               ?? httpCtx.Connection.RemoteIpAddress?.ToString()
               ?? "anonymous";

        return RateLimitPartition.GetSlidingWindowLimiter(key,
            _ => new SlidingWindowRateLimiterOptions
            {
                Window            = TimeSpan.FromMinutes(1),
                PermitLimit       = 100,
                SegmentsPerWindow = 6,    // recalculate every 10s
                QueueLimit        = 0     // reject immediately
            });
    });

    // ── 2. Token bucket: allow bursting for mobile clients ────────────
    options.AddPolicy("mobile", httpCtx =>
        RateLimitPartition.GetTokenBucketLimiter(
            partitionKey: httpCtx.User.FindFirst("sub")?.Value ?? "anon",
            factory: _ => new TokenBucketRateLimiterOptions
            {
                TokenLimit          = 20,   // burst: up to 20 requests instantly
                TokensPerPeriod     = 5,    // refill 5 tokens per second
                ReplenishmentPeriod = TimeSpan.FromSeconds(1),
                AutoReplenishment   = true,
                QueueLimit          = 0
            }));

    // ── 3. Concurrency limiter: protect expensive report endpoint ─────
    options.AddPolicy("reports", httpCtx =>
        RateLimitPartition.GetConcurrencyLimiter(
            partitionKey: httpCtx.User.FindFirst("sub")?.Value ?? "anon",
            factory: _ => new ConcurrencyLimiterOptions
            {
                PermitLimit = 2,    // max 2 concurrent report requests per user
                QueueLimit  = 5     // queue up to 5 more (report takes minutes)
            }));

    // ── 4. Global limit: protect the server from DDoS ─────────────────
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(_ =>
        RateLimitPartition.GetFixedWindowLimiter("global", _ =>
            new FixedWindowRateLimiterOptions
            {
                Window      = TimeSpan.FromSeconds(1),
                PermitLimit = 5000,   // 5000 req/s total across all users
                QueueLimit  = 0
            }));

    // ── 5. Custom 429 response with Retry-After ───────────────────────
    options.OnRejected = async (rejCtx, ct) =>
    {
        var res = rejCtx.HttpContext.Response;
        res.StatusCode = StatusCodes.Status429TooManyRequests;

        // Extract Retry-After from the lease metadata
        if (rejCtx.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
            res.Headers.RetryAfter = ((int)retryAfter.TotalSeconds).ToString();

        // Standard rate-limit informational headers
        res.Headers["X-RateLimit-Limit"]     = "100";
        res.Headers["X-RateLimit-Remaining"] = "0";

        res.ContentType = "application/problem+json";
        await res.WriteAsJsonAsync(new ProblemDetails
        {
            Type   = "https://tools.ietf.org/html/rfc6585#section-4",
            Title  = "Too Many Requests",
            Status = StatusCodes.Status429TooManyRequests,
            Detail = "You have exceeded your rate limit. Please try again later."
        }, ct);
    };

    // Reject immediately (no queuing at global level)
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();   // AFTER auth so ctx.User is populated

// ── Endpoint policies ─────────────────────────────────────────────────
app.MapGet("/api/products", () => "products")
   .RequireRateLimiting("api");

app.MapGet("/api/mobile/sync", () => "sync")
   .RequireRateLimiting("mobile");

app.MapPost("/api/reports/generate", () => "report")
   .RequireRateLimiting("reports");

// Health checks: never rate-limited
app.MapGet("/health", () => Results.Ok())
   .DisableRateLimiting();

app.Run();

// ── ProblemDetails helper (already defined in .NET 7+) ───────────────
record ProblemDetails
{
    public string? Type   { get; init; }
    public string? Title  { get; init; }
    public int?    Status { get; init; }
    public string? Detail { get; init; }
}
```

## Common Follow-up Questions

- How does `UseRateLimiter` interact with `UseOutputCache` — which runs first and do they conflict?
- Can you apply different rate limits to the same endpoint for authenticated vs anonymous users?
- How do you test rate limiting in unit and integration tests without hitting the real limiter?
- What happens if the rate limiter's background replenishment thread throws — does it crash the app?
- How do you expose current rate limit status (remaining requests, reset time) in API responses for all endpoints without duplicating code?
- When would you use `PartitionedRateLimiter.CreateChained` vs separate `GlobalLimiter` + per-endpoint policy?

## Common Mistakes / Pitfalls

- **`UseRateLimiter` placed before `UseAuthentication`**: `ctx.User` is unauthenticated, so all requests fall into the same partition (e.g., "anonymous"). Every user shares one limit — or the per-user limit never applies. Ordering matters.
- **Using in-process limiters in multi-pod Kubernetes deployments**: the built-in ASP.NET Core limiters are per-process. With 5 replicas each allowing 100 req/min, the effective limit is 500 req/min per user. Use Redis-backed limiting for multi-instance accuracy.
- **`QueueLimit` too large on `ConcurrencyLimiter`**: if the endpoint is slow (report generation: 30s), a queue of 100 means 100 × 30s of work = 50 minutes of backlog that users are waiting for. Reject early rather than building an unbounded queue.
- **Not disabling rate limiting on internal probe endpoints**: Kubernetes liveness/readiness probes hit `/health` every 5–10 seconds. Under rate-limited conditions, if `/health` is throttled the pod appears unhealthy and is restarted — creating a death spiral.
- **Applying rate limiting to streaming responses**: rate limiting counts permits on request start. A single HTTP/2 streaming connection that holds the permit for 10 minutes blocks 1 of your `ConcurrencyLimiter` slots for that entire time. Design concurrency limits with streaming in mind.
- **Ignoring `MetadataName.RetryAfter` from the lease**: the built-in limiters provide the exact retry-after duration via lease metadata. Not forwarding it to the client means clients can't implement efficient back-off.

## References

- [Rate limiting middleware in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/rate-limit)
- [System.Threading.RateLimiting namespace — .NET API docs](https://learn.microsoft.com/dotnet/api/system.threading.ratelimiting)
- [Andrew Lock — Exploring the new rate limiting abstractions in .NET 7](https://andrewlock.net/exploring-the-dotnet-7-rate-limiting-abstractions/) (verify URL)
- [See: rate-limiting-algorithms.md](./rate-limiting-algorithms.md) — algorithm internals and trade-offs
- [See: distributed-rate-limiting.md](./distributed-rate-limiting.md) — Redis-backed multi-instance limiting
