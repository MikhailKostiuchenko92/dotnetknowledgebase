# Rate Limiting in ASP.NET Core (.NET 7+)

**Category:** ASP.NET Core / Web API Design
**Difficulty:** 🔴 Senior
**Tags:** `RateLimiter`, `rate-limiting`, `fixed-window`, `sliding-window`, `token-bucket`, `concurrency`, `partitioned`

## Question

> How do you implement rate limiting in ASP.NET Core (.NET 7+)? What algorithms are available and when would you use each?

## Short Answer

.NET 7 introduced built-in rate limiting middleware via `System.Threading.RateLimiting` and `Microsoft.AspNetCore.RateLimiting`. Four algorithms are available: **fixed window** (simple counter per time window), **sliding window** (smoothed fixed window with sub-segments), **token bucket** (allows burst up to capacity, refills at a rate), and **concurrency** (limits simultaneous requests). Use partitioned limiters to enforce per-user/per-IP limits; combine with `[EnableRateLimiting]` attribute on controllers/minimal API routes.

## Detailed Explanation

### The four algorithms

| Algorithm | Best for | Burst allowed | Memory |
|---|---|---|---|
| Fixed window | Simple counters (N req/min) | ✅ At window reset | Low |
| Sliding window | Smooth traffic, avoid reset bursts | ⚠️ Dampened | Medium |
| Token bucket | APIs allowing short bursts | ✅ Up to capacity | Low |
| Concurrency | Limiting concurrent heavy operations | N/A (parallel, not rate) | Low |

### Fixed window

```
Window: 0s──────60s──────120s
Limit:  100 req  100 req  100 req
Problem: 100 req at 59s + 100 at 61s = 200 in 2 seconds
```

### Sliding window

Divides the window into segments; each segment tracks a fraction of the limit. Smooths out the burst at window boundaries.

### Token bucket

Tokens are added at a constant rate (refill rate); each request consumes one token. If the bucket is empty, the request is rejected/queued. Allows burst up to `tokenLimit` when the bucket is full.

### Setup

```csharp
builder.Services.AddRateLimiter(opts =>
{
    opts.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    // Named policy — fixed window
    opts.AddFixedWindowLimiter("fixed", config =>
    {
        config.PermitLimit = 100;
        config.Window = TimeSpan.FromMinutes(1);
        config.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        config.QueueLimit = 10; // allow 10 to queue; rest get 429
    });

    // Named policy — sliding window
    opts.AddSlidingWindowLimiter("sliding", config =>
    {
        config.PermitLimit = 100;
        config.Window = TimeSpan.FromMinutes(1);
        config.SegmentsPerWindow = 4; // 15-second segments
        config.QueueLimit = 5;
    });

    // Named policy — token bucket
    opts.AddTokenBucketLimiter("token-bucket", config =>
    {
        config.TokenLimit = 20;           // max burst
        config.ReplenishmentPeriod = TimeSpan.FromSeconds(1);
        config.TokensPerPeriod = 10;      // refill rate: 10/sec
        config.AutoReplenishment = true;
    });

    // Named policy — concurrency
    opts.AddConcurrencyLimiter("concurrency", config =>
    {
        config.PermitLimit = 5;   // max 5 simultaneous requests
        config.QueueLimit = 10;
    });
});
```

```csharp
var app = builder.Build();
app.UseRateLimiter(); // must be added to pipeline
```

### Per-user partitioned limiting

```csharp
opts.AddPolicy("per-user", context =>
    RateLimitPartition.GetFixedWindowLimiter(
        partitionKey: context.User.Identity?.Name ?? context.Connection.RemoteIpAddress?.ToString() ?? "anonymous",
        factory: _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 50,
            Window = TimeSpan.FromMinutes(1)
        }));
```

### Applying to endpoints

```csharp
// Controller
[EnableRateLimiting("per-user")]
[ApiController]
[Route("[controller]")]
public class OrdersController : ControllerBase { ... }

// Individual action — overrides controller-level policy
[HttpPost]
[EnableRateLimiting("concurrency")]
public Task<IActionResult> PlaceOrder() { ... }

// Opt out of a globally applied policy
[DisableRateLimiting]
[HttpGet("status")]
public IActionResult Status() => Ok("alive");
```

```csharp
// Minimal API
app.MapPost("/api/orders", PlaceOrderHandler)
   .RequireRateLimiting("per-user");
```

### Global policy (all endpoints)

```csharp
opts.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
    RateLimitPartition.GetFixedWindowLimiter(
        partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        factory: _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 500,
            Window = TimeSpan.FromMinutes(1)
        }));
```

## Code Example

```csharp
// Complete setup: global IP-based limiter + per-endpoint policies
builder.Services.AddRateLimiter(opts =>
{
    opts.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    // Burst-friendly token bucket for authenticated users
    opts.AddPolicy("authenticated", ctx =>
    {
        var userId = ctx.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return string.IsNullOrEmpty(userId)
            ? RateLimitPartition.GetNoLimiter("anonymous") // auth required — let auth middleware handle
            : RateLimitPartition.GetTokenBucketLimiter(userId, _ => new TokenBucketRateLimiterOptions
            {
                TokenLimit = 30,
                ReplenishmentPeriod = TimeSpan.FromSeconds(10),
                TokensPerPeriod = 10,
                AutoReplenishment = true,
                QueueLimit = 5
            });
    });

    // Stricter limit for expensive operations
    opts.AddConcurrencyLimiter("report-generation", cfg =>
    {
        cfg.PermitLimit = 2;
        cfg.QueueLimit = 3;
        cfg.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
    });

    opts.OnRejected = async (ctx, ct) =>
    {
        ctx.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        if (ctx.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
            ctx.HttpContext.Response.Headers.RetryAfter = retryAfter.TotalSeconds.ToString("0");
        await ctx.HttpContext.Response.WriteAsJsonAsync(new { error = "Rate limit exceeded" }, ct);
    };
});
```

## Common Follow-up Questions

- How does rate limiting interact with a load-balanced multi-instance deployment?
- What is the difference between `QueueLimit` and `PermitLimit`?
- How do you expose `Retry-After` headers to clients when rejecting requests?
- How do you test rate limiting behavior in integration tests?
- How does `RateLimitPartition.GetNoLimiter` differ from simply not applying any policy?

## Common Mistakes / Pitfalls

- **Using in-memory rate limiting in a horizontally scaled deployment** — each instance has its own counters; use a distributed rate limiter (Redis-backed) for accurate limits across nodes.
- **Setting `RejectionStatusCode` globally but returning a different status in `OnRejected`** — `OnRejected` runs after `RejectionStatusCode` is already set; write the status code inside `OnRejected` if you want to override it.
- **Placing `UseRateLimiter()` after `UseAuthentication()`** — this is correct for user-partitioned limits (identity is available). But if you place it before, `context.User` is not populated and user-based partitioning won't work.
- **Not setting `QueueLimit`** — the default queue limit is 0; every rejected request returns 429 immediately. Set a small queue to absorb brief spikes.
- **Using `AddFixedWindowLimiter` for APIs with bursty traffic** — fixed window allows doubling at window boundaries. Use `AddSlidingWindowLimiter` or `AddTokenBucketLimiter` for smoother control.

## References

- [Microsoft Learn — Rate limiting in ASP.NET Core](https://learn.microsoft.com/aspnet/core/performance/rate-limit?view=aspnetcore-8.0)
- [Microsoft Blog — Rate limiting in .NET 7](https://devblogs.microsoft.com/dotnet/announcing-rate-limiting-for-dotnet/)
- [Microsoft — System.Threading.RateLimiting source](https://github.com/dotnet/runtime/tree/main/src/libraries/System.Threading.RateLimiting)
- [Maarten Balliauw — Rate limiting in ASP.NET Core](https://blog.maartenballiauw.be/post/2022/09/26/aspnet-core-rate-limiting-middleware.html)
