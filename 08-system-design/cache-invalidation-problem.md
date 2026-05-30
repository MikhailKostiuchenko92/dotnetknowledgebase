# Cache Invalidation Problem

**Category:** System Design / Caching
**Difficulty:** 🟡 Middle
**Tags:** `cache-invalidation`, `TTL`, `stampede`, `thundering-herd`, `event-driven-invalidation`, `stale-data`

## Question

> Why is cache invalidation considered one of the hardest problems in computer science? What strategies exist for invalidating cached data, and how do you handle cache stampede?

## Short Answer

Cache invalidation is hard because any strategy involves trade-offs between consistency (does the cache always reflect the current DB state?), complexity (how much logic does invalidation require?), and availability (what happens when many clients hit an expired cache simultaneously?). The main strategies are TTL-based expiry, event-driven invalidation (invalidate on write), and write-through (always update cache with DB). Cache stampede occurs when a popular cache key expires and many requests all miss simultaneously — mitigated by probabilistic early expiration, locking/semaphore ("cache lock"), or background refresh.

## Detailed Explanation

### Why Invalidation Is Hard

Phil Karlton's famous quote: *"There are only two hard things in Computer Science: cache invalidation and naming things."*

The difficulty stems from the **consistency-availability tension**:

- **Short TTL**: data is fresh, but cache hit rate is low — DB is hammered after every expiry.
- **Long TTL**: high hit rate, but stale data for extended periods.
- **Event-driven invalidation**: data is fresh, but requires coordination between writer and cache — complex, additional failure point.
- **No cache**: perfectly consistent, but no performance benefit.

### Strategy 1: TTL-Based Expiry

The simplest approach: every cache entry expires after a fixed duration.

```csharp
cache.Set("user:42", user, TimeSpan.FromMinutes(5));
```

**Problems**:
- Stale data between write and TTL expiry (up to 5 minutes).
- Mass expiry: if many keys were cached simultaneously (application startup), they all expire together → thundering herd.

**Mitigation**: add jitter to TTL to spread expiry times:
```csharp
var jitter = TimeSpan.FromSeconds(Random.Shared.Next(0, 60));
cache.Set(key, value, baseExpiry + jitter);
```

### Strategy 2: Event-Driven Invalidation

When a record is updated, an invalidation event is published. Cache consumers listen and delete/update the key.

```
DB write → publish "user:42:updated" event → cache listener → cache.Remove("user:42")
```

**Pros**: fresh data immediately after writes; no unnecessary expiry of unchanged data.
**Cons**: requires reliable event delivery (at-least-once); consumer failures can leave stale entries; distributed coordination complexity.

**In .NET**: Redis pub/sub (`ISubscriber`), Azure Service Bus, or using a background service that listens to DB change events (CDC).

### Strategy 3: Write-Through Invalidation

On every write, update (or delete) the cache entry in the same operation:

```csharp
await repo.UpdateUserAsync(user);
await cache.RemoveAsync($"user:{user.Id}");   // simple: delete and let next read repopulate
// OR
await cache.SetAsync($"user:{user.Id}", serialize(user), options);  // write-through
```

**Pros**: cache always has fresh data (or is empty, prompting a fresh read).
**Cons**: write latency increases; if cache and DB writes are not atomic, partial failures cause inconsistency.

> **Warning:** If the DB write succeeds but the cache invalidation fails (network error, Redis down), the cache serves stale data indefinitely until TTL. Always treat cache invalidation as best-effort and set a safety TTL even on write-through caches.

### Strategy 4: Version-Based / ETags

Store the DB version/etag alongside the cached data. On read, compare version; if mismatched, refresh:

```csharp
var cached = await cache.GetAsync(key);  // includes version token
var dbVersion = await db.GetVersionAsync(id);
if (cached.Version != dbVersion) { /* refresh */ }
```

This is the HTTP ETag pattern applied to cache. Rarely used in application caches but common in HTTP layer caching.

### Cache Stampede (Thundering Herd)

When a popular key expires, many simultaneous requests all miss and all try to fetch from the DB and populate the cache. With 10,000 req/s, expiry of a hot key triggers 10,000 concurrent DB queries.

#### Mitigation 1: Cache Lock (Mutex)

Only one request fetches from the DB; others wait on a lock:

```csharp
// Redis SET NX — only one process holds the "cache refresh lock"
var lockKey = $"lock:{cacheKey}";
if (await redis.StringSetAsync(lockKey, "1", TimeSpan.FromSeconds(5), When.NotExists))
{
    // winner: fetch from DB, populate cache, release lock
    var value = await db.GetAsync(id);
    await cache.SetAsync(cacheKey, value, ttl);
    await redis.KeyDeleteAsync(lockKey);
}
else
{
    // loser: wait briefly, retry
    await Task.Delay(50);
    return await cache.GetAsync(cacheKey); // may now be populated
}
```

**Downside**: if the winner crashes before populating, all waiters time out.

#### Mitigation 2: Probabilistic Early Expiration (PER)

Randomly refresh the cache entry **before** it actually expires, based on proximity to TTL and compute cost:

```
probability_to_refresh = exp(-delta / (beta * cost))
```

where `delta` = time remaining, `beta` = tunable parameter, `cost` = time to fetch from DB.

As TTL approaches zero, each request independently has an increasing probability of triggering a refresh — spreading the refresh load.

#### Mitigation 3: Background Refresh

Never let the cache miss. A background job refreshes keys before they expire:

```csharp
// Refresh "user:42" every 4 minutes when TTL is 5 minutes
// IHostedService polls near-expiry keys and proactively refreshes them
```

**Downside**: requires tracking which keys to refresh; stale data until next refresh cycle.

### Redis-Specific: Key Space Notifications

Redis can emit events when keys expire or are deleted. Subscribe to receive invalidation signals:

```csharp
var sub = redis.GetSubscriber();
await sub.SubscribeAsync("__keyevent@0__:expired", (channel, key) =>
{
    Console.WriteLine($"Key expired: {key} — repopulate if needed");
});
```

Useful for triggering background refresh on expiry.

## Code Example

```csharp
// Cache stampede prevention: cache lock + jitter + probabilistic early expiration
// .NET 8 + StackExchange.Redis

using StackExchange.Redis;
using System.Text.Json;

public class StampedeResistentCache(IConnectionMultiplexer redis)
{
    private readonly IDatabase _db = redis.GetDatabase();
    private readonly TimeSpan _defaultTtl = TimeSpan.FromMinutes(5);
    private readonly TimeSpan _lockTtl = TimeSpan.FromSeconds(10);

    public async Task<T?> GetOrCreateAsync<T>(
        string key,
        Func<Task<T>> factory,
        TimeSpan? ttl = null,
        CancellationToken ct = default) where T : class
    {
        ttl ??= _defaultTtl;

        // Add TTL jitter to avoid mass-expiry of keys set at the same time
        var jitter = TimeSpan.FromSeconds(Random.Shared.Next(0, 30));
        var effectiveTtl = ttl.Value + jitter;

        // 1. Try cache first
        var cached = await _db.StringGetWithExpiryAsync(key);
        if (cached.Value.HasValue)
        {
            // 2. Probabilistic early expiration: random refresh before actual expiry
            var remaining = cached.Expiry ?? TimeSpan.Zero;
            if (remaining > TimeSpan.FromSeconds(30) && ShouldEarlyRefresh(remaining, effectiveTtl))
            {
                // Trigger background refresh without waiting
                _ = RefreshInBackgroundAsync(key, factory, effectiveTtl);
            }
            return JsonSerializer.Deserialize<T>(cached.Value.ToString());
        }

        // 3. Cache miss — use distributed lock to prevent stampede
        var lockKey = $"lock:{key}";
        var lockValue = Guid.NewGuid().ToString();
        bool acquired = await _db.StringSetAsync(lockKey, lockValue, _lockTtl, When.NotExists);

        if (acquired)
        {
            try
            {
                var value = await factory();
                var json  = JsonSerializer.Serialize(value);
                await _db.StringSetAsync(key, json, effectiveTtl);
                return value;
            }
            finally
            {
                // Release lock only if we still hold it
                var script = """
                    if redis.call("get", KEYS[1]) == ARGV[1] then
                        return redis.call("del", KEYS[1])
                    else return 0 end
                    """;
                await _db.ScriptEvaluateAsync(script, [(RedisKey)lockKey], [(RedisValue)lockValue]);
            }
        }
        else
        {
            // Another process is populating — wait briefly and retry
            await Task.Delay(100, ct);
            var retryVal = await _db.StringGetAsync(key);
            return retryVal.HasValue ? JsonSerializer.Deserialize<T>(retryVal.ToString()) : null;
        }
    }

    private static bool ShouldEarlyRefresh(TimeSpan remaining, TimeSpan ttl)
    {
        // Probability increases as TTL approaches 0 (XFetch / PER algorithm)
        double ratio = remaining.TotalSeconds / ttl.TotalSeconds;
        return Random.Shared.NextDouble() > ratio;
    }

    private async Task RefreshInBackgroundAsync<T>(string key, Func<Task<T>> factory, TimeSpan ttl) where T : class
    {
        var value = await factory();
        await _db.StringSetAsync(key, JsonSerializer.Serialize(value), ttl);
    }
}
```

## Common Follow-up Questions

- How do you invalidate a group of related cache keys (e.g., all product listings for category X) without enumerating every key?
- How does Redis pub/sub compare to Redis Streams for cache invalidation notifications?
- What is the "dog-piling" problem in caching systems, and how does a cache lock solve it vs creating a new bottleneck?
- How does cache invalidation work in a multi-region deployment where the cache is geographically distributed?
- How do you implement cache-tag-based invalidation (invalidate all entries tagged "category:electronics")?
- What is the "write-and-invalidate" race condition, and how do you prevent it?

## Common Mistakes / Pitfalls

- **No safety TTL even on event-driven invalidation**: events can be lost; without a TTL safety net, stale data persists indefinitely if the invalidation event is dropped.
- **Invalidating by prefix without atomic scan-and-delete**: `KEYS product:*` followed by individual DELETEs is not atomic in Redis — new keys may appear between the scan and deletes. Use Lua scripts or Redis tags for atomic group invalidation.
- **Write-and-invalidate race**: Thread A reads DB (v1), Thread B updates DB (v2) and deletes cache, Thread A writes v1 to cache → cache now has stale v1. Fix with short TTL, version tokens, or the "read DB → check version → write to cache" pattern.
- **No jitter on TTL**: setting all keys with `TimeSpan.FromMinutes(5)` at 9:00 AM causes all keys to expire at 9:05 AM simultaneously → thundering herd.
- **Cache lock timeout too short**: if the DB call takes longer than the lock TTL, the lock expires before the winner finishes → multiple processes fetch from DB simultaneously — exactly the stampede you wanted to prevent.
- **Not caching empty/null results**: every request for a non-existent key (e.g., product deleted) hits the DB. Cache a null sentinel with a short TTL.

## References

- [ASP.NET Core response caching and cache stampede prevention](https://learn.microsoft.com/aspnet/core/performance/caching/overview)
- [Redis keyspace notifications](https://redis.io/docs/manual/keyspace-notifications/)
- [XFetch — optimal probabilistic cache stampede prevention algorithm](https://cseweb.ucsd.edu/~avattani/papers/cache_stampede.pdf) (verify URL)
- [StackExchange.Redis — Lua scripting](https://stackexchange.github.io/StackExchange.Redis/Scripting)
- [See: redis-fundamentals.md](./redis-fundamentals.md) — Redis data structures and persistence
