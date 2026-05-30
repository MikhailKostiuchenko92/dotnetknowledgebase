# Rate Limiting Algorithms

**Category:** System Design / Rate Limiting
**Difficulty:** 🟡 Middle
**Tags:** `token-bucket`, `leaky-bucket`, `fixed-window`, `sliding-window`, `rate-limiting`, `algorithms`

## Question

> Describe the main rate limiting algorithms — fixed window, sliding window, token bucket, and leaky bucket. What are the trade-offs of each, and which is best for what use case?

## Short Answer

**Fixed window** is simplest: count requests in a fixed time slot; reset at the window boundary — but allows burst doubling at window edges. **Sliding window log** is most accurate: track exact request timestamps; expensive to store. **Sliding window counter** approximates the sliding window cheaply using two fixed windows. **Token bucket** allows controlled bursting: tokens accumulate up to a cap and are consumed per request — the most client-friendly. **Leaky bucket** (FIFO queue) enforces a smooth, constant output rate with no bursting — ideal when downstream systems can't handle any spikes. Token bucket is the de facto standard for API rate limiting; leaky bucket for traffic shaping at network edges.

## Detailed Explanation

### Fixed Window Counter

Divide time into fixed windows (e.g., 60-second buckets). Count requests per key per window. Reset on window boundary.

```
Window: [00:00 – 01:00]  Count: 95/100
Window: [01:00 – 02:00]  Count: 0/100  ← reset
```

**Pros**: O(1) storage per key; trivial to implement; trivial to distribute (single Redis INCR + EXPIRE).
**Cons**: "double burst" problem — 100 requests at 00:59 + 100 requests at 01:00 = 200 requests in 2 seconds, both within their respective windows.

```
00:59: 100 requests allowed ✅ (window A not exhausted)
01:00: 100 requests allowed ✅ (window B just reset)
→ 200 requests in 2 seconds — 2× the intended limit
```

**Use when**: coarse-grained limits are acceptable; simplicity is valued; the burst problem is tolerable (e.g., per-hour limits where a 2× burst for 1 second doesn't matter).

### Sliding Window Log

Store a sorted set of exact request timestamps per key. On each request, count how many timestamps are in `[now - window, now]`:

```
Request at T=61:
  Remove all timestamps < T=1 (outside window)
  Count remaining: if < limit → allow, add T=61
                   else → reject
```

**Pros**: perfectly accurate — no burst at window boundaries.
**Cons**: memory scales with request count (100 req/min limit → up to 100 timestamps stored per user); expensive for high-throughput scenarios.

**Use when**: strict accuracy is required; request rate is low; storage is not a concern.

### Sliding Window Counter (Approximate)

A practical compromise: use two adjacent fixed window counters and weight them by the fraction of the current window elapsed.

```
Approximate rate = (previous_window_count × (1 - elapsed_fraction)) + current_window_count

current window: 00:30 – 01:30
elapsed_fraction = 30s / 60s = 0.5

rate ≈ (prev_count × 0.5) + curr_count
```

**Pros**: O(1) storage (just two counters); much better accuracy than fixed window; no burst doubling.
**Cons**: slight approximation — actual rate can differ by a small percentage.

This is the algorithm used by **Cloudflare** and **Nginx** for high-throughput rate limiting.

### Token Bucket

A bucket holds tokens up to a maximum (`capacity`). Tokens are added at a fixed rate (`refill_rate`). Each request consumes tokens.

```
Initial: 100 tokens
Refill: +1 token/second (max 100)

Burst of 100 requests: 100 tokens consumed instantly ✅
Next request immediately: 0 tokens → rejected ❌
After 10 seconds: 10 tokens refilled → 10 requests allowed
```

**Pros**:
- Allows **controlled bursting** (burst up to `capacity` tokens instantly).
- Naturally handles variable request rates.
- Refill can be lazy (compute "tokens since last request" on demand — no background job).

**Cons**:
- Two parameters to tune: capacity (burst size) and refill rate (sustained throughput).
- Distributed implementation requires atomic CAS or Lua script.

**Use when**: API rate limiting where bursting is acceptable; mobile/web clients that may batch requests.

### Leaky Bucket

Requests enter a FIFO queue ("bucket"). A background drainer processes them at a constant rate. If the queue is full, requests are rejected.

```
Queue capacity: 100
Drain rate: 10 req/s

11 requests arrive simultaneously:
  10 enqueued, 1 rejected (overflow)
  Output: steady 10 req/s regardless of arrival pattern
```

**Pros**:
- Enforces a **perfectly smooth output rate** — no bursts downstream.
- Protects downstream systems that can't handle spikes (legacy systems, metered APIs).

**Cons**:
- Adds latency (requests wait in queue).
- Requests are processed out of order if earlier requests queue longer.
- Not client-friendly — a user sending a brief burst gets queued/rejected even if they haven't exceeded their daily quota.

**Use when**: traffic shaping at network egress; protecting a slow downstream dependency; network QoS.

### Algorithm Comparison

| Algorithm | Burst allowed? | Memory cost | Accuracy | Best for |
|-----------|---------------|-------------|---------|---------|
| Fixed window | 2× at edges | O(1) | Low | Coarse limits, simplicity |
| Sliding log | No | O(n) per key | Perfect | Strict accuracy, low traffic |
| Sliding counter | Slight | O(1) | High | High throughput, production |
| Token bucket | Yes (controlled) | O(1) | High | API limits, client-friendly |
| Leaky bucket | No | O(queue) | High | Traffic shaping, smooth output |

## Code Example

```csharp
// .NET 8 — Token bucket and sliding window implementations

using System.Collections.Concurrent;

// ── Token Bucket (in-process, for illustration) ───────────────────────
public sealed class TokenBucketLimiter(int capacity, double refillRatePerSecond)
{
    private double _tokens = capacity;
    private DateTime _lastRefill = DateTime.UtcNow;
    private readonly Lock _lock = new();

    public bool TryConsume(int tokens = 1)
    {
        lock (_lock)
        {
            Refill();
            if (_tokens < tokens) return false;
            _tokens -= tokens;
            return true;
        }
    }

    private void Refill()
    {
        var now     = DateTime.UtcNow;
        var elapsed = (now - _lastRefill).TotalSeconds;
        _tokens     = Math.Min(capacity, _tokens + elapsed * refillRatePerSecond);
        _lastRefill = now;
    }
}

// ── Fixed Window Counter (in-process) ────────────────────────────────
public sealed class FixedWindowCounter(int limit, TimeSpan window)
{
    private int _count;
    private DateTime _windowStart = DateTime.UtcNow;
    private readonly Lock _lock = new();

    public bool TryAllow()
    {
        lock (_lock)
        {
            var now = DateTime.UtcNow;
            if (now - _windowStart >= window)
            {
                _count = 0;
                _windowStart = now;
            }
            if (_count >= limit) return false;
            _count++;
            return true;
        }
    }
}

// ── ASP.NET Core 7+ built-in algorithms ──────────────────────────────
using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddRateLimiter(options =>
{
    // Token bucket: 10 tokens capacity, refill 2/second per user
    options.AddPolicy("token-bucket", ctx =>
        RateLimitPartition.GetTokenBucketLimiter(
            partitionKey: ctx.User?.Identity?.Name ?? ctx.Connection.RemoteIpAddress?.ToString() ?? "anon",
            factory: _ => new TokenBucketRateLimiterOptions
            {
                TokenLimit              = 10,    // burst capacity
                ReplenishmentPeriod     = TimeSpan.FromSeconds(1),
                TokensPerPeriod         = 2,     // +2 tokens/second
                AutoReplenishment       = true,
                QueueProcessingOrder    = QueueProcessingOrder.OldestFirst,
                QueueLimit              = 0      // reject immediately instead of queuing
            }));

    // Fixed window: 100 req/min per user
    options.AddPolicy("fixed-window", ctx =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: ctx.User?.Identity?.Name ?? "anon",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                Window      = TimeSpan.FromMinutes(1),
                PermitLimit = 100
            }));

    // Sliding window: 100 req/min, 6 segments → approximates sliding
    options.AddPolicy("sliding-window", ctx =>
        RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: ctx.User?.Identity?.Name ?? "anon",
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                Window            = TimeSpan.FromMinutes(1),
                PermitLimit       = 100,
                SegmentsPerWindow = 6    // recalculates every 10s
            }));

    // Concurrency limiter (leaky bucket equivalent for concurrent requests)
    options.AddPolicy("concurrent", ctx =>
        RateLimitPartition.GetConcurrencyLimiter(
            partitionKey: ctx.User?.Identity?.Name ?? "anon",
            factory: _ => new ConcurrencyLimiterOptions
            {
                PermitLimit = 5,   // max 5 concurrent requests per user
                QueueLimit  = 10   // queue up to 10 more; rest are rejected
            }));
});

var app = builder.Build();
app.UseRateLimiter();

app.MapGet("/api/burst-friendly",    () => "ok").RequireRateLimiting("token-bucket");
app.MapGet("/api/fixed",             () => "ok").RequireRateLimiting("fixed-window");
app.MapGet("/api/sliding",           () => "ok").RequireRateLimiting("sliding-window");
app.MapGet("/api/slow-downstream",   () => "ok").RequireRateLimiting("concurrent");
app.Run();
```

## Common Follow-up Questions

- How do you implement a token bucket in Redis with atomic operations (Lua script)?
- What is the "birthday problem" variant in sliding window counters — how does approximation error accumulate?
- How does Nginx's `limit_req` directive map to the leaky bucket algorithm?
- Can you combine multiple rate limiting algorithms? For example, token bucket per user + fixed window global?
- How does the `ConcurrencyLimiter` in ASP.NET Core differ from a token bucket or sliding window?
- What is the GCRA (Generic Cell Rate Algorithm) and how does it improve on token bucket for distributed systems?

## Common Mistakes / Pitfalls

- **Using a fixed window for strict SLA limits**: a 100 req/min fixed window allows 200 requests in a 2-second edge burst. If your downstream has a hard limit of 100/min, this will breach it. Use sliding window or token bucket instead.
- **Setting token bucket capacity = 1**: a capacity of 1 means no burst is allowed — effectively rate-limiting to exactly `refill_rate` with zero elasticity. Users with legitimate bursty patterns (page load triggers 10 parallel API calls) will be throttled immediately. Set capacity ≥ 5–10× typical burst size.
- **In-process rate limiters in a multi-instance app**: each server instance has its own counter. With 3 replicas and a per-user limit of 100/min, a user can actually make 300/min. For multi-instance deployments, use Redis-backed rate limiting. [See: distributed-rate-limiting.md](./distributed-rate-limiting.md)
- **Forgetting the `QueueLimit = 0` option**: ASP.NET Core's built-in limiters can queue requests (add backpressure). With `QueueLimit > 0` under heavy load, requests pile up in memory and the server may OOM. For public APIs, prefer immediate rejection (429) over queuing.
- **Leaky bucket with too-small queue**: if the queue fills instantly under load, the leaky bucket effectively becomes a very tight fixed window — all requests beyond queue capacity are dropped immediately.
- **Not tuning `SegmentsPerWindow` for sliding window**: with `SegmentsPerWindow = 1`, the sliding window degrades to a fixed window. Use at least 4–10 segments for meaningful smoothing.

## References

- [Rate limiting middleware in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/rate-limit)
- [System.Threading.RateLimiting API — .NET](https://learn.microsoft.com/dotnet/api/system.threading.ratelimiting)
- [Cloudflare — How we built rate limiting](https://blog.cloudflare.com/counting-things-a-lot-of-different-things/) (verify URL)
- [Token bucket algorithm — Wikipedia](https://en.wikipedia.org/wiki/Token_bucket)
- [See: distributed-rate-limiting.md](./distributed-rate-limiting.md) — Redis atomic implementation
