# Design: Rate Limiter

**Category:** System Design / Classic Design Problems
**Difficulty:** 🟡 Middle
**Tags:** `system-design`, `rate-limiter`, `Redis`, `sliding-window`, `token-bucket`, `distributed`, `API-gateway`

## Question

> Design a rate limiter service that can be used as middleware or a standalone service. Support per-user limits, multiple limit tiers (free/pro/enterprise), burst allowance, and real-time limit status in response headers. Scale: 500K active users, 1M req/s peak.

## Short Answer

A distributed rate limiter uses Redis as the shared counter store (token bucket or sliding window counter per user) with Lua scripts for atomic operations. The limiter runs as ASP.NET Core middleware (in-process) or as a dedicated sidecar/API gateway plugin. Key design decisions: algorithm choice (token bucket for burst-friendly APIs, sliding window for strict limits), partition key granularity (per-user + per-endpoint), tier configuration storage (Redis hash or DB), and response headers (`X-RateLimit-*`, `Retry-After`). At 1M req/s, run Redis Cluster with per-shard partitioning; at lower scale, a single Redis with pipeline batching suffices.

## Detailed Explanation

### Requirements Clarification

**Functional**:
- Limit requests per user per time window.
- Support multiple tiers with different limits (free: 100/min, pro: 1000/min, enterprise: 10000/min).
- Allow configurable burst capacity.
- Return limit status in every response header.
- Hard reject (429) or soft throttle (queue)?

**Non-functional**:
- < 5 ms added latency per request.
- Highly available — if the rate limiter is down, fail open (allow) not fail closed.
- Consistent across all application replicas.

### Component Design

```
Request
  │
  ▼
[Rate Limiter Middleware]
  1. Identify user (JWT sub / API key / IP)
  2. Load tier limits (Redis hash, cached locally)
  3. Execute rate limit check (Redis Lua script)
  4. If allowed: set X-RateLimit-* headers, pass through
  5. If denied:  return 429 with Retry-After
  │
  ▼
[Application]
```

### Tier Configuration Storage

Store tier limits in Redis (fast read, rarely changed) with a background sync from DB:

```
HSET limits:free   rpm 100   burst 20   rph 2000
HSET limits:pro    rpm 1000  burst 100  rph 20000
HSET limits:enterprise  rpm 10000  burst 1000  rph 200000

HSET user:tier user:123 pro
HSET user:tier user:456 free
```

Cache tier config in-process (invalidated by Redis pub/sub on admin update): 0 ms lookup.

### Algorithm: Token Bucket per Tier

- **Capacity** = burst allowance (configurable per tier).
- **Refill rate** = sustained requests per second.

Token bucket is ideal here: allows clients to accumulate unused capacity and use it as a burst — essential for mobile clients that batch requests.

### Data Storage: Redis Key Design

```
rl:tb:{userId}   → Hash: {tokens: float, ts: epoch_ms}
rl:quota:{userId}:{date}   → Int: daily request count
limits:{tier}    → Hash: {rpm, burst, daily_quota}
```

TTL on `rl:tb:{userId}`: `capacity / refill_rate + 5s` buffer.

### Scale Analysis

At 1M req/s:
- 1 Redis command per request → 1M ops/s (single Redis: max ~500K–1M ops/s for simple ops).
- Solution: Redis Cluster (3+ shards) + pipeline batching for non-latency-sensitive counters.
- Use local in-process token buckets with periodic Redis sync for extreme scale (accuracy trade-off).

### Failover: Fail Open

If Redis is unavailable:
1. Log a warning metric.
2. Allow the request (fail open) — service stays available.
3. Apply a local in-process rate limit as a fallback guard.

The local fallback prevents complete abuse during Redis outages while not blocking legitimate traffic.

## Code Example

```csharp
// ASP.NET Core 8 — Full rate limiter system with tier support

using StackExchange.Redis;
using Microsoft.Extensions.Caching.Memory;

// ── Tier configuration ────────────────────────────────────────────────
public record RateLimitTier(int RequestsPerMinute, int BurstCapacity, int DailyQuota);

public sealed class TierConfig
{
    public static readonly Dictionary<string, RateLimitTier> Tiers = new()
    {
        ["free"]       = new(100,   20,    2_000),
        ["pro"]        = new(1000,  100,   20_000),
        ["enterprise"] = new(10000, 1000,  200_000)
    };
}

// ── Rate limit result ─────────────────────────────────────────────────
public record RateLimitDecision(
    bool   Allowed,
    int    Limit,
    int    Remaining,
    long   ResetEpochSeconds,
    int    RetryAfterSeconds);

// ── Redis-backed token bucket rate limiter ────────────────────────────
public sealed class DistributedRateLimiter(
    IConnectionMultiplexer redis,
    IMemoryCache tierCache,
    ILogger<DistributedRateLimiter> log)
{
    private const string TokenBucketLua = """
        local key         = KEYS[1]
        local capacity    = tonumber(ARGV[1])
        local refill_ms   = tonumber(ARGV[2])   -- tokens per ms
        local now         = tonumber(ARGV[3])
        local expire_ms   = tonumber(ARGV[4])

        local data   = redis.call('HMGET', key, 'tokens', 'ts')
        local tokens = tonumber(data[1]) or capacity
        local ts     = tonumber(data[2]) or now
        local elapsed = now - ts

        -- Refill
        tokens = math.min(capacity, tokens + elapsed * refill_ms)

        if tokens < 1 then
            local wait_ms = (1 - tokens) / refill_ms
            return {0, tokens, math.ceil(wait_ms)}
        end

        tokens = tokens - 1
        redis.call('HSET', key, 'tokens', tokens, 'ts', now)
        redis.call('PEXPIRE', key, expire_ms)
        return {1, tokens, 0}
        """;

    public async Task<RateLimitDecision> CheckAsync(
        string userId, string tier, CancellationToken ct = default)
    {
        if (!TierConfig.Tiers.TryGetValue(tier, out var limits))
            limits = TierConfig.Tiers["free"];

        var key         = $"rl:tb:{userId}";
        var capacity    = limits.BurstCapacity;
        var refillPerMs = (double)limits.RequestsPerMinute / 60_000.0;
        var now         = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        var expireMs    = (long)(capacity / refillPerMs + 5000);
        var resetEpoch  = DateTimeOffset.UtcNow.AddMinutes(1).ToUnixTimeSeconds();

        try
        {
            var db     = redis.GetDatabase();
            var result = (RedisResult[])await db.ScriptEvaluateAsync(TokenBucketLua,
                keys: [(RedisKey)key],
                values: [(RedisValue)capacity, refillPerMs, now, expireMs]);

            var allowed    = (int)result[0] == 1;
            var remaining  = (int)(double)result[1];
            var waitMs     = (long)result[2];

            return new RateLimitDecision(
                Allowed:           allowed,
                Limit:             limits.RequestsPerMinute,
                Remaining:         Math.Max(0, remaining),
                ResetEpochSeconds: resetEpoch,
                RetryAfterSeconds: allowed ? 0 : (int)Math.Ceiling(waitMs / 1000.0));
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Redis unavailable; failing open for user {UserId}", userId);
            // Fail open: allow the request, apply in-process fallback guard
            return new RateLimitDecision(true, limits.RequestsPerMinute, -1, resetEpoch, 0);
        }
    }
}

// ── ASP.NET Core middleware ───────────────────────────────────────────
public sealed class RateLimiterMiddleware(RequestDelegate next, DistributedRateLimiter limiter)
{
    public async Task InvokeAsync(HttpContext ctx)
    {
        var userId = ctx.User.FindFirst("sub")?.Value
                  ?? ctx.Connection.RemoteIpAddress?.ToString()
                  ?? "anon";
        var tier   = ctx.User.FindFirst("tier")?.Value ?? "free";

        var decision = await limiter.CheckAsync(userId, tier, ctx.RequestAborted);

        // Always add informational headers
        ctx.Response.Headers["X-RateLimit-Limit"]     = decision.Limit.ToString();
        ctx.Response.Headers["X-RateLimit-Remaining"] = decision.Remaining.ToString();
        ctx.Response.Headers["X-RateLimit-Reset"]     = decision.ResetEpochSeconds.ToString();
        ctx.Response.Headers["X-RateLimit-Tier"]      = tier;

        if (!decision.Allowed)
        {
            ctx.Response.StatusCode  = StatusCodes.Status429TooManyRequests;
            ctx.Response.Headers.RetryAfter = decision.RetryAfterSeconds.ToString();
            await ctx.Response.WriteAsJsonAsync(new
            {
                error       = "Rate limit exceeded",
                retryAfter  = decision.RetryAfterSeconds,
                tier,
                upgradeUrl  = tier == "free" ? "https://example.com/upgrade" : null
            });
            return;
        }

        await next(ctx);
    }
}

// ── Registration ──────────────────────────────────────────────────────
// builder.Services.AddSingleton<DistributedRateLimiter>();
// app.UseAuthentication();
// app.UseMiddleware<RateLimiterMiddleware>();
```

## Common Follow-up Questions

- How would you implement a "credits" system where users buy API call credits and the rate limiter deducts from their balance?
- How do you communicate remaining quota to SDK clients so they can pre-emptively throttle themselves?
- How would you add per-endpoint limits on top of per-user limits?
- At what scale would you move the rate limiter from in-process middleware to a standalone service, and what API would it expose?
- How do you handle the case where a user upgrades from free to pro tier mid-window — should their existing counter reset?
- How do you test that your rate limiter correctly allows exactly N requests and blocks N+1?

## Common Mistakes / Pitfalls

- **No fallback when Redis is unavailable**: if the rate limiter throws on Redis downtime and you don't catch it, every API request returns 500. Decide: fail open (allow) or fail closed (block). Fail open is typical for rate limiting.
- **Non-atomic multi-command Redis operations**: reading tokens + writing updated tokens as separate commands races with concurrent requests from the same user. Always use Lua scripts.
- **Rate limiting by IP behind a NAT/proxy**: an entire office (100 people) shares one public IP. A per-IP limit of 100/min blocks legitimate users. Use authenticated user IDs for limits; fall back to IP only for unauthenticated endpoints.
- **Sending tier info in headers that clients can spoof**: if you read `X-User-Tier: enterprise` from the request to apply limits, clients can forge the header. Always derive the tier from the validated JWT claims or DB lookup.
- **Counting failed requests against quota**: a request that returns a 400 (client error) or 404 shouldn't deplete the user's rate limit. Some implementations count the request before validating it. Apply rate limiting only to requests that pass authentication/validation.
- **Tiny burst capacity relative to sustained rate**: burst = 5, sustained = 1000/min. A single page load that fires 10 parallel requests will hit the burst limit even if the user is well within their sustained quota. Set burst = 5–10% of the per-minute limit minimum.

## References

- [See: distributed-rate-limiting.md](./distributed-rate-limiting.md) — Redis Lua implementation detail
- [See: rate-limiting-algorithms.md](./rate-limiting-algorithms.md) — token bucket internals
- [See: rate-limiting-in-aspnet-core.md](./rate-limiting-in-aspnet-core.md) — built-in middleware
- [System design interview — rate limiter (ByteByteGo)](https://bytebytego.com/courses/system-design-interview/design-a-rate-limiter) (verify URL)
- [IETF RateLimit header fields draft](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/)
