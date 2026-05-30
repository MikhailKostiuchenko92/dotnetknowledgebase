# Rate Limiting Concepts

**Category:** System Design / Rate Limiting
**Difficulty:** 🟢 Junior
**Tags:** `rate-limiting`, `throttling`, `429`, `Retry-After`, `per-user`, `global`, `ASP.NET-Core`

## Question

> What is rate limiting and why do APIs need it? What is the difference between per-user and global rate limits, and how should an API communicate that a client is being throttled?

## Short Answer

Rate limiting restricts how many requests a client can make within a time window to protect backend services from overload, prevent abuse, and ensure fair resource distribution. **Global limits** protect the entire service (e.g., max 10,000 req/s total). **Per-user/per-IP limits** ensure no single client starves others (e.g., 100 req/min per API key). When a client exceeds its limit, the API returns **HTTP 429 Too Many Requests** with a `Retry-After` header telling the client how long to wait before retrying. ASP.NET Core 7+ includes built-in rate limiting middleware with multiple algorithm implementations.

## Detailed Explanation

### Why Rate Limiting Is Necessary

Without rate limiting:
- A single misbehaving client (bug, abuse, DDoS) can exhaust server resources for all users.
- A single slow query from one tenant degrades all other tenants in a multi-tenant system.
- An API key leaked on a public repo can incur unbounded cost.
- Downstream dependencies (DB, third-party APIs) can be overwhelmed by a spike.

Rate limiting provides:
- **Availability protection**: cap total throughput to what the system can sustain.
- **Fairness**: distribute capacity across clients.
- **Cost control**: limit expensive operations per API key/subscription tier.
- **Security**: slow down brute-force, credential stuffing, scraping attacks.

### Rate Limit Scopes

| Scope | Key | Use Case |
|-------|-----|---------|
| **Global** | None | Protect the service as a whole |
| **Per IP** | Client IP | Unauthenticated endpoints, basic DDoS protection |
| **Per user/API key** | User ID, API key | Authenticated endpoints, fair usage |
| **Per endpoint** | Route + user | Expensive endpoints have stricter limits |
| **Per tenant** | Tenant ID | Multi-tenant SaaS billing/quota |
| **Per subscription tier** | Plan (free/pro/enterprise) | Different rate limits per pricing tier |

Rate limiters are typically applied in layers: an API gateway enforces global + per-IP limits; the application layer enforces per-user + per-endpoint limits.

### HTTP Response: 429 Too Many Requests

When a client is rate-limited:

```
HTTP/1.1 429 Too Many Requests
Retry-After: 30
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1717091234
Content-Type: application/problem+json

{
  "type": "https://example.com/errors/rate-limited",
  "title": "Too Many Requests",
  "status": 429,
  "detail": "You have exceeded the rate limit of 100 requests per minute.",
  "retryAfter": 30
}
```

| Header | Meaning |
|--------|---------|
| `Retry-After: 30` | Wait 30 seconds before retrying |
| `X-RateLimit-Limit: 100` | Your total allowance per window |
| `X-RateLimit-Remaining: 0` | Requests left in current window |
| `X-RateLimit-Reset: <timestamp>` | Unix timestamp when window resets |

These headers are not standardised (use [IETF draft RateLimit headers](https://datatracker.ietf.org/doc/html/draft-ietf-httpapi-ratelimit-headers) for forward compatibility).

> **Warning:** Return 429, not 503. HTTP 503 (Service Unavailable) means the server is overloaded — it does not tell the client they specifically are rate-limited. Clients handle 429 differently (respect Retry-After) vs 503 (generic retry with back-off).

### Graceful Client Behaviour

Well-behaved clients should:
1. Read `Retry-After` and wait the specified duration before retrying.
2. Implement **exponential back-off with jitter** if no `Retry-After` is provided.
3. Cache responses to reduce repeat requests for the same data.
4. Use bulk/batch APIs instead of N individual calls.

### Global vs Per-User: Which Takes Priority?

Apply limits in this order (most specific wins):
1. Endpoint-specific limit (if exists).
2. Per-user/API key limit.
3. Global limit.

If the global limit is hit, ALL requests are rejected (429), even users who haven't hit their personal limit yet. This is by design — the system is protecting itself.

## Code Example

```csharp
// ASP.NET Core 7+ — Built-in rate limiting middleware basics
// (algorithm details in rate-limiting-algorithms.md)

using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRateLimiter(options =>
{
    // ── Global fixed-window limit ─────────────────────────────────────
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: "global",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                Window             = TimeSpan.FromSeconds(1),
                PermitLimit        = 1000,   // 1000 req/s total
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit         = 0       // no queuing — reject immediately
            }));

    // ── Per-user sliding window limit ─────────────────────────────────
    options.AddPolicy("per-user", ctx =>
        RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: ctx.User?.Identity?.Name    // authenticated user
                       ?? ctx.Connection.RemoteIpAddress?.ToString()   // fall back to IP
                       ?? "anonymous",
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                Window          = TimeSpan.FromMinutes(1),
                PermitLimit     = 100,   // 100 req/min per user
                SegmentsPerWindow = 6    // 6 × 10s segments for sliding accuracy
            }));

    // ── Expensive endpoint: tighter limit ─────────────────────────────
    options.AddPolicy("reports", ctx =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: ctx.User?.Identity?.Name ?? "anon",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                Window      = TimeSpan.FromHours(1),
                PermitLimit = 10    // only 10 report exports per hour
            }));

    // ── Custom rejection response (429 with Retry-After) ─────────────
    options.OnRejected = async (ctx, ct) =>
    {
        ctx.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;

        if (ctx.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
        {
            ctx.HttpContext.Response.Headers.RetryAfter =
                ((int)retryAfter.TotalSeconds).ToString();
        }

        ctx.HttpContext.Response.ContentType = "application/problem+json";
        await ctx.HttpContext.Response.WriteAsJsonAsync(new
        {
            type    = "https://httpstatuses.io/429",
            title   = "Too Many Requests",
            status  = 429,
            detail  = "Rate limit exceeded. See Retry-After header."
        }, ct);
    };
});

var app = builder.Build();
app.UseRateLimiter();

// ── Standard endpoint: per-user limit ─────────────────────────────────
app.MapGet("/api/products", () => Results.Ok("products"))
   .RequireRateLimiting("per-user");

// ── Expensive endpoint: tight limit ───────────────────────────────────
app.MapPost("/api/reports/generate", () => Results.Ok("report"))
   .RequireRateLimiting("reports");

// ── Health check: exempt from rate limiting ──────────────────────────
app.MapGet("/health", () => Results.Ok("healthy"))
   .DisableRateLimiting();

app.Run();
```

## Common Follow-up Questions

- What is the difference between rate limiting and throttling in terms of how the server responds?
- How do you implement rate limiting at the API gateway layer vs the application layer?
- What HTTP status code should a server return when globally overloaded (vs when a specific client is rate-limited)?
- How do you rate limit WebSocket connections that maintain a persistent connection?
- Should rate limits be enforced before or after authentication middleware? Why?
- How do you communicate different rate limits for different subscription tiers (free vs paid)?

## Common Mistakes / Pitfalls

- **Using HTTP 503 instead of 429**: 503 means "server overloaded"; 429 means "you specifically are rate-limited." Clients handle these differently. Respect the distinction.
- **No `Retry-After` header**: clients that receive 429 without `Retry-After` will retry immediately, making the problem worse. Always include retry guidance.
- **Rate limiting only at the application layer**: a DDoS attack sending millions of requests will exhaust your app before it can even evaluate rate limits. First line of defence is the CDN/WAF/load balancer level.
- **Keying per-IP behind a load balancer**: if the load balancer doesn't preserve `X-Forwarded-For`, all traffic appears to come from the LB's IP → everyone shares one limit or no one is limited. Extract real client IP from `X-Forwarded-For` carefully.
- **Rate limiting health check endpoints**: `/health`, `/metrics`, `/readyz` should be exempt from rate limiting — infrastructure (Kubernetes, load balancers) polls these frequently and should never be blocked.
- **Not rate limiting internal APIs**: internal microservices that call each other without limits can produce cascading overloads when a bug causes tight loops. Apply rate limits to internal service-to-service calls too.

## References

- [Rate limiting middleware in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/rate-limit)
- [HTTP 429 Too Many Requests — MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/429)
- [IETF draft — RateLimit header fields for HTTP](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/)
- [See: rate-limiting-algorithms.md](./rate-limiting-algorithms.md) — token bucket, sliding window, fixed window
- [See: distributed-rate-limiting.md](./distributed-rate-limiting.md) — Redis-backed distributed counters
