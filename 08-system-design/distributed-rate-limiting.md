# Distributed Rate Limiting

**Category:** System Design / Rate Limiting
**Difficulty:** 🔴 Senior
**Tags:** `distributed-rate-limiting`, `Redis`, `Lua`, `atomic`, `sliding-window`, `token-bucket`, `multi-region`, `Redis-cluster`

## Question

> How do you implement rate limiting that works correctly across multiple application instances? Walk through a Redis-backed sliding window counter with atomic Lua script, and explain the challenges in multi-region deployments.

## Short Answer

In-process rate limiters don't work across replicas — each process has an independent counter. For distributed rate limiting, use **Redis as the shared counter store**: a single `INCR` + `EXPIRE` implements a fixed window atomically; a sorted set with `ZADD`/`ZCOUNT` implements a sliding window log; a Lua script makes multi-key operations atomic. The primary challenge in multi-region deployments is **counter synchronisation across data centres** — fully synchronous limits require cross-region round trips (20–200 ms added latency), while asynchronous/approximate limits accept some over-limit window.

## Detailed Explanation

### Why In-Process Fails at Scale

```
3 replicas, limit: 100 req/min per user

Pod A: counter = 50
Pod B: counter = 60
Pod C: counter = 70
Total: 180 requests sent — 80% over the limit

Each pod thinks it's within limits; no single pod sees the real total.
```

Solution: centralise the counter in Redis. All pods increment the same key.

### Pattern 1: Fixed Window in Redis

```csharp
// Atomic: INCR + EXPIRE (set expiry only if key is new)
var key   = $"rl:{userId}:{windowStart}";  // windowStart = UTC minute truncated
var count = await redis.StringIncrementAsync(key);
if (count == 1) await redis.KeyExpireAsync(key, TimeSpan.FromMinutes(2));  // 2m safety margin
if (count > 100) return Reject();
```

**Problem**: two commands (`INCR` + `EXPIRE`) are not atomic. If the process crashes between them, the key has no expiry and lives forever. Fix: use `SET` with `NX` + `EXAT`, or Lua script.

### Pattern 2: Sliding Window with Sorted Set

```
ZADD rl:{userId} <timestamp_ms> <unique_id>
ZREMRANGEBYSCORE rl:{userId} 0 <now - 60000>
ZCARD rl:{userId}
EXPIRE rl:{userId} 60
```

These four commands must run atomically → Lua script.

### Pattern 3: Token Bucket in Redis (Lazy Refill)

No background job needed. On each request, compute tokens based on time elapsed since last refill:

```
tokens = min(capacity, stored_tokens + elapsed_seconds × refill_rate)
```

Store `(tokens, last_refill_time)` atomically in a Lua script.

### Atomicity Requirement

Redis is single-threaded; individual commands are atomic. But **multi-command sequences are not** — another request from the same user can interleave between your commands. Use:

1. **Lua scripts** (`EVAL`): entire script executes atomically in Redis.
2. **Redis transactions** (`MULTI`/`EXEC`): optimistic; can fail if watched keys change.

Lua scripts are simpler and more reliable for rate limiting.

### Multi-Region Challenges

| Approach | Latency | Accuracy | Complexity |
|----------|---------|----------|-----------|
| **Single global Redis** | Cross-region round-trip (50–200 ms) added to every request | Exact | Low |
| **Regional Redis + async sync** | Local (< 1 ms added) | Approximate (may allow some over-limit during sync window) | Medium |
| **Local counter + periodic flush** | Local | Approximate (over-limit by sync period) | Medium |
| **CRDT-based counters** | Local | Approximate (eventual convergence) | High |

For most use cases: deploy Redis per region, accept small over-limit windows during sync. For financial/billing limits where accuracy is critical: use a single authoritative Redis with cross-region reads acknowledged.

### Rate Limit Partitioning Across Redis Cluster

In Redis Cluster, different keys land on different shards. This is fine for per-user keys (each user has their own key → their own shard). `EVAL` scripts on a single key work in cluster mode. Scripts touching multiple keys require all keys to be on the same shard (use hash tags).

## Code Example

```csharp
// .NET 8 — Distributed rate limiting with Redis + Lua

using StackExchange.Redis;
using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;

// ── Sliding window Lua script ─────────────────────────────────────────
// Atomically: remove old entries, count, add new, set expiry
// Returns: [current_count, allowed (1/0)]
const string SlidingWindowScript = """
    local key    = KEYS[1]
    local now    = tonumber(ARGV[1])
    local window = tonumber(ARGV[2])
    local limit  = tonumber(ARGV[3])
    local uid    = ARGV[4]

    -- Remove timestamps outside the window
    redis.call('ZREMRANGEBYSCORE', key, 0, now - window)

    -- Count current requests
    local count = redis.call('ZCARD', key)

    if count >= limit then
        -- Compute earliest slot that will free up
        local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
        local retry_after = (oldest[2] + window - now) / 1000
        return {count, 0, retry_after}
    end

    -- Add this request
    redis.call('ZADD', key, now, uid)
    redis.call('PEXPIRE', key, window + 1000)   -- 1s buffer

    return {count + 1, 1, 0}
    """;

// ── Token bucket Lua script ───────────────────────────────────────────
const string TokenBucketScript = """
    local key         = KEYS[1]
    local capacity    = tonumber(ARGV[1])
    local refill_rate = tonumber(ARGV[2])   -- tokens per millisecond
    local now         = tonumber(ARGV[3])
    local tokens_req  = tonumber(ARGV[4])

    local data        = redis.call('HMGET', key, 'tokens', 'ts')
    local tokens      = tonumber(data[1]) or capacity
    local last_ts     = tonumber(data[2]) or now

    -- Refill tokens based on elapsed time
    local elapsed     = now - last_ts
    tokens            = math.min(capacity, tokens + elapsed * refill_rate)

    if tokens < tokens_req then
        local wait_ms = (tokens_req - tokens) / refill_rate
        return {0, math.ceil(wait_ms / 1000)}  -- denied, retry_after_seconds
    end

    tokens = tokens - tokens_req
    redis.call('HSET', key, 'tokens', tokens, 'ts', now)
    redis.call('PEXPIRE', key, math.ceil(capacity / refill_rate * 1000) + 5000)

    return {1, 0}  -- allowed, retry_after = 0
    """;

// ── Redis Rate Limiter service ────────────────────────────────────────
public sealed class RedisRateLimiter(IConnectionMultiplexer redis, ILogger<RedisRateLimiter> log)
{
    private readonly IDatabase _db = redis.GetDatabase();

    public async Task<RateLimitResult> SlidingWindowAsync(
        string key, int limitPerMinute, CancellationToken ct = default)
    {
        var now       = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        var windowMs  = 60_000L;                         // 60 seconds in ms
        var uid       = $"{now}:{Random.Shared.Next()}"; // unique per request

        try
        {
            var result = (RedisResult[])await _db.ScriptEvaluateAsync(SlidingWindowScript,
                keys: [(RedisKey)key],
                values: [(RedisValue)now, windowMs, limitPerMinute, uid]);

            var count      = (int)result[0];
            var allowed    = (int)result[1] == 1;
            var retryAfter = (double)result[2];

            return new RateLimitResult(allowed, count, limitPerMinute,
                allowed ? 0 : (int)Math.Ceiling(retryAfter));
        }
        catch (Exception ex)
        {
            // Redis down: fail open (allow request) to avoid full outage
            log.LogWarning(ex, "Redis rate limiter unavailable for {Key}; failing open", key);
            return new RateLimitResult(true, 0, limitPerMinute, 0);
        }
    }

    public async Task<RateLimitResult> TokenBucketAsync(
        string key, int capacity, double refillPerSecond, CancellationToken ct = default)
    {
        var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        var refillPerMs = refillPerSecond / 1000.0;

        try
        {
            var result = (RedisResult[])await _db.ScriptEvaluateAsync(TokenBucketScript,
                keys: [(RedisKey)key],
                values: [(RedisValue)capacity, refillPerMs, now, 1]);

            var allowed    = (int)result[0] == 1;
            var retryAfter = (int)result[1];

            return new RateLimitResult(allowed, 0, capacity, retryAfter);
        }
        catch (Exception ex)
        {
            log.LogWarning(ex, "Redis token bucket unavailable for {Key}; failing open", key);
            return new RateLimitResult(true, 0, capacity, 0);
        }
    }
}

record RateLimitResult(bool Allowed, int Current, int Limit, int RetryAfterSeconds);

// ── ASP.NET Core integration: middleware using RedisRateLimiter ──────
public sealed class RedisRateLimitMiddleware(RequestDelegate next, RedisRateLimiter limiter)
{
    public async Task InvokeAsync(HttpContext ctx)
    {
        var userId = ctx.User.FindFirst("sub")?.Value
                  ?? ctx.Connection.RemoteIpAddress?.ToString()
                  ?? "anon";
        var key    = $"rl:api:{userId}";

        var result = await limiter.SlidingWindowAsync(key, limitPerMinute: 100);

        ctx.Response.Headers["X-RateLimit-Limit"]     = result.Limit.ToString();
        ctx.Response.Headers["X-RateLimit-Remaining"] =
            Math.Max(0, result.Limit - result.Current).ToString();

        if (!result.Allowed)
        {
            ctx.Response.StatusCode = StatusCodes.Status429TooManyRequests;
            if (result.RetryAfterSeconds > 0)
                ctx.Response.Headers.RetryAfter = result.RetryAfterSeconds.ToString();
            await ctx.Response.WriteAsJsonAsync(new { error = "Rate limit exceeded" });
            return;
        }

        await next(ctx);
    }
}
```

## Common Follow-up Questions

- What happens to rate limit accuracy if the Redis primary fails and traffic is routed to a replica with stale counters?
- How does the Redlock algorithm affect rate limiting correctness when multiple Redis instances are used?
- How do you implement "burst allowance" in a distributed token bucket — without the per-request Redis round-trip?
- What is the "fail open vs fail closed" decision for rate limiting when Redis is unavailable, and how do you decide?
- How would you design a multi-region rate limiting system that avoids cross-region latency but still prevents a user from exceeding their global quota?
- How do you pre-warm rate limit counters when deploying a new service that inherits existing users?

## Common Mistakes / Pitfalls

- **Multi-command non-atomic operations**: `INCR` then `EXPIRE` as separate commands races with concurrent requests from the same user. One request increments and crashes; the key has no expiry. Use Lua scripts for all compound operations.
- **Not handling Redis unavailability**: if Redis is down and you don't catch exceptions, every request fails with a 500. Decide your "fail open" vs "fail closed" policy explicitly — most public APIs fail open (allow requests) to avoid an outage during Redis downtime.
- **ZADD-based sliding window without ZREMRANGEBYSCORE**: if you only add entries and never remove old ones, the sorted set grows indefinitely. The `ZREMRANGEBYSCORE` cleanup is mandatory.
- **Unique member IDs in the sorted set**: using a constant member (e.g., the user ID) means ZADD updates the score instead of adding a new entry — you end up with only one entry per user regardless of request count. Use a unique value per request (timestamp + random suffix).
- **Using `KEYS *` to find rate limit keys for cleanup**: `KEYS *` blocks the Redis server for the full scan. Use `SCAN` with a cursor, or let TTL handle cleanup automatically.
- **Single Redis shard for all rate limit keys**: if all users' rate limit counters go to one shard, it becomes a hotspot in Redis Cluster. Use hash tags with randomised suffixes or ensure keys distribute evenly across shards.

## References

- [StackExchange.Redis — Lua scripting](https://stackexchange.github.io/StackExchange.Redis/Scripting)
- [Redis EVAL command](https://redis.io/commands/eval/)
- [Redis sorted set commands (ZADD, ZREMRANGEBYSCORE)](https://redis.io/docs/data-types/sorted-sets/)
- [See: rate-limiting-algorithms.md](./rate-limiting-algorithms.md) — algorithm internals
- [See: redis-fundamentals.md](./redis-fundamentals.md) — Redis clustering and data structures
