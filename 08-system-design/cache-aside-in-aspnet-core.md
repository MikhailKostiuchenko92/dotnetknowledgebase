# Cache-Aside in ASP.NET Core

**Category:** System Design / Caching
**Difficulty:** 🔴 Senior
**Tags:** `cache-aside`, `IDistributedCache`, `Redis`, `IMemoryCache`, `HybridCache`, `stampede`, `serialization`, `ASP.NET Core`

## Question

> How do you implement a production-ready cache-aside pattern in ASP.NET Core? What are the concerns around serialisation, cache stampede prevention, error handling, and testability, and how does the new `HybridCache` (.NET 9) change the picture?

## Short Answer

The cache-aside pattern in ASP.NET Core is implemented via `IMemoryCache` (single-instance) or `IDistributedCache` + Redis (multi-instance). A production-grade implementation must handle: key namespacing, consistent serialisation (System.Text.Json or MessagePack), TTL with jitter, stampede prevention via a distributed lock or `HybridCache`'s built-in deduplication, graceful degradation when Redis is unavailable, and an `IDistributedCache`-based abstraction that is mockable in tests. `HybridCache` in .NET 9 encapsulates all of this behind a single `GetOrCreateAsync` call.

## Detailed Explanation

### Production Concerns Beyond Basic Cache-Aside

The naïve pattern — "check cache, miss → fetch DB, store in cache" — breaks in production in several ways:

| Concern | Naïve Implementation | Production Requirement |
|---------|---------------------|----------------------|
| Key collision | Flat key `"product:42"` | Namespaced: `"v1:tenant:abc:product:42"` |
| Stampede | No protection | Distributed lock or `HybridCache` |
| Redis down | Exception propagates | Fall through to DB; log warning |
| Key version changes | Old cached shape returned | Version prefix on all keys |
| Serialization errors | Unhandled exception | Treat as cache miss; log; re-fetch |
| Test isolation | Real Redis required | Mock `IDistributedCache` |
| TTL management | Single value | Jitter to prevent mass expiry |

### Key Namespacing and Versioning

When you change the shape of a cached type (add/remove properties), cached bytes from the old schema fail to deserialise. Version the key prefix:

```csharp
private static string Key(int id) => $"v2:product:{id}";
// v2 → bump when cached DTO shape changes; old keys expire naturally
```

### Serialisation Choice

`IDistributedCache` stores `byte[]`. You must serialise/deserialise yourself:

| Format | Library | Speed | Size | Schema evolution |
|--------|---------|-------|------|-----------------|
| JSON | `System.Text.Json` | Medium | Large | Easy (optional fields) |
| MessagePack | `MessagePack-CSharp` | Fast | Small | Good with versioned schemas |
| Protobuf | `protobuf-net` | Fast | Smallest | Requires schema files |

For most applications, `System.Text.Json` is the right default. Opt for MessagePack when cache payload size is a bottleneck.

### Stampede Prevention: Distributed Lock

When a key expires under high concurrency, hundreds of requests may all miss simultaneously and flood the DB. Use a Redis `SET NX` lock — only one caller refreshes; others wait and retry:

[See: cache-invalidation-problem.md](./cache-invalidation-problem.md)

### Resilience: Redis Down

Redis being unavailable should degrade gracefully — not cause a 500 cascade. Wrap cache operations in try/catch and fall through to the DB:

```csharp
try   { return await cache.GetAsync(key); }
catch { logger.LogWarning("Redis unavailable, bypassing cache"); return null; }
```

### HybridCache (.NET 9) — The Better Default

`HybridCache` (introduced in .NET 9 as a first-party Microsoft library) combines:
- **L1** in-process `IMemoryCache` (sub-µs reads)
- **L2** `IDistributedCache` / Redis (shared across replicas)
- **Stampede protection**: concurrent calls for the same key are deduplicated — only one factory invocation runs
- **Tag-based invalidation**: `RemoveByTagAsync("category:electronics")`
- **Serialiser pluggability**: JSON by default, MessagePack via extension

This eliminates the need for hand-rolled distributed lock logic in most scenarios.

### Testability

Replace `IDistributedCache` with `MemoryDistributedCache` (in-memory, no Redis required) for unit tests:

```csharp
services.AddDistributedMemoryCache();  // test setup
```

Or mock with `Substitute.For<IDistributedCache>()` (NSubstitute) to control exact cache hit/miss scenarios.

## Code Example

```csharp
// ASP.NET Core 8/9 — Production-grade cache-aside service
// Covers: key versioning, JSON serialisation, TTL jitter,
//         stampede lock, graceful degradation, and HybridCache (.NET 9)

using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.Hybrid;
using StackExchange.Redis;
using System.Text.Json;

// ── Registration ──────────────────────────────────────────────────────
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddStackExchangeRedisCache(o =>
    o.Configuration = builder.Configuration["Redis:ConnectionString"]);

// .NET 9: HybridCache replaces the manual cache-aside service below
builder.Services.AddHybridCache(o =>
{
    o.DefaultEntryOptions = new HybridCacheEntryOptions
    {
        Expiration           = TimeSpan.FromMinutes(10),  // L2 Redis TTL
        LocalCacheExpiration = TimeSpan.FromSeconds(30),  // L1 in-proc TTL
    };
});

builder.Services.AddSingleton<IConnectionMultiplexer>(_ =>
    ConnectionMultiplexer.Connect(
        builder.Configuration["Redis:ConnectionString"] ?? "localhost:6379"));

builder.Services.AddScoped<ProductCacheService>();
builder.Services.AddScoped<ProductRepository>();

var app = builder.Build();

// ── Endpoint using manual cache-aside (.NET 8 compatible) ─────────────
app.MapGet("/products/{id}/v1", async (int id, ProductCacheService svc, CancellationToken ct) =>
{
    var product = await svc.GetProductAsync(id, ct);
    return product is null ? Results.NotFound() : Results.Ok(product);
});

// ── Endpoint using HybridCache (.NET 9) ──────────────────────────────
app.MapGet("/products/{id}/v2", async (int id, HybridCache cache, ProductRepository repo, CancellationToken ct) =>
{
    var product = await cache.GetOrCreateAsync(
        $"v1:product:{id}",
        async token => await repo.GetByIdAsync(id, token),
        tags: [$"product:{id}"],       // enables tag-based invalidation
        cancellationToken: ct);

    return product is null ? Results.NotFound() : Results.Ok(product);
});

// ── Cache invalidation with HybridCache tags ──────────────────────────
app.MapPut("/products/{id}", async (int id, ProductDto dto, HybridCache cache, ProductRepository repo, CancellationToken ct) =>
{
    var updated = await repo.UpdateAsync(id, dto, ct);
    await cache.RemoveByTagAsync($"product:{id}", ct);   // invalidates L1 + L2
    return Results.Ok(updated);
});

app.Run();

// ── Manual cache-aside service (NET 8, Redis, with resilience) ────────
public sealed class ProductCacheService(
    IDistributedCache cache,
    IConnectionMultiplexer redis,
    ProductRepository repo,
    ILogger<ProductCacheService> logger)
{
    // Version prefix: bump when ProductDto shape changes
    private static string CacheKey(int id) => $"v2:product:{id}";
    private static string LockKey(int id)  => $"lock:product:{id}";

    private static readonly DistributedCacheEntryOptions CacheOptions = new()
    {
        // Jitter ±30s to prevent mass expiry of keys set at the same time
        AbsoluteExpirationRelativeToNow =
            TimeSpan.FromMinutes(10) + TimeSpan.FromSeconds(Random.Shared.Next(-30, 30))
    };

    public async Task<ProductDto?> GetProductAsync(int id, CancellationToken ct)
    {
        // 1. Try cache
        byte[]? cached = null;
        try   { cached = await cache.GetAsync(CacheKey(id), ct); }
        catch (Exception ex)
        {
            // Redis down: degrade gracefully — don't fail the request
            logger.LogWarning(ex, "Redis unavailable for key {Key}; bypassing cache", CacheKey(id));
        }

        if (cached is not null)
        {
            try   { return JsonSerializer.Deserialize<ProductDto>(cached); }
            catch (JsonException ex)
            {
                // Stale serialization schema: treat as miss, let it refresh
                logger.LogWarning(ex, "Deserialisation failed for {Key}; treating as miss", CacheKey(id));
            }
        }

        // 2. Acquire distributed lock to prevent stampede
        var db          = redis.GetDatabase();
        var lockValue   = Guid.NewGuid().ToString();
        bool lockAcquired = false;

        try
        {
            lockAcquired = await db.StringSetAsync(LockKey(id), lockValue,
                TimeSpan.FromSeconds(15), When.NotExists);

            if (!lockAcquired)
            {
                // Another worker is populating: wait briefly and retry from cache
                await Task.Delay(150, ct);
                cached = await cache.GetAsync(CacheKey(id), ct);
                if (cached is not null)
                    return JsonSerializer.Deserialize<ProductDto>(cached);
            }

            // 3. Fetch from DB
            var product = await repo.GetByIdAsync(id, ct);
            if (product is null) return null;

            // 4. Populate cache
            try
            {
                await cache.SetAsync(CacheKey(id),
                    JsonSerializer.SerializeToUtf8Bytes(product),
                    CacheOptions, ct);
            }
            catch (Exception ex)
            {
                // Cache write failure is non-fatal — still return the DB result
                logger.LogWarning(ex, "Failed to write {Key} to cache", CacheKey(id));
            }

            return product;
        }
        finally
        {
            if (lockAcquired)
            {
                // Release lock via Lua script (only if we still hold it)
                const string script = """
                    if redis.call("get", KEYS[1]) == ARGV[1] then
                        return redis.call("del", KEYS[1]) else return 0 end
                    """;
                await db.ScriptEvaluateAsync(script,
                    [(RedisKey)LockKey(id)], [(RedisValue)lockValue]);
            }
        }
    }
}

// ── Supporting types ───────────────────────────────────────────────────
record ProductDto(int Id, string Name, decimal Price);
record ProductUpdateRequest(string Name, decimal Price);
record ProductDtoAlias(string N, decimal P);  // hypothetical v1 schema (to illustrate version bump)

class ProductRepository
{
    public Task<ProductDto?> GetByIdAsync(int id, CancellationToken _ = default) =>
        Task.FromResult<ProductDto?>(new ProductDto(id, "Widget", 9.99m));

    public Task<ProductDto?> UpdateAsync(int id, ProductDto dto, CancellationToken _ = default) =>
        Task.FromResult<ProductDto?>(dto with { Id = id });
}

record ProductDto2(int Id, string Name, decimal Price);  // alias for code clarity
```

## Common Follow-up Questions

- How does `HybridCache.GetOrCreateAsync` guarantee only one factory call fires when 50 concurrent requests arrive for the same missing key?
- How would you implement cache warming (pre-populating the cache on startup) with `IHostedService`?
- When you version the cache key prefix (v1 → v2), old v1 keys remain in Redis until their TTL expires. How do you force-evict them during a deployment?
- How do you test a service that uses `IDistributedCache` in isolation without a running Redis?
- What serialization format would you choose for a cache that stores 10 million entries of 5 KB each?
- How does `HybridCache`'s tag-based invalidation work internally across multiple application instances?

## Common Mistakes / Pitfalls

- **No key versioning**: when a cached DTO gains a required property, deserialization of old cached bytes throws `JsonException` and crashes the request. Always prefix keys with a version token and increment it on schema changes.
- **Blocking on cache failure**: if Redis is down and the app throws on every cache read, origin services are still healthy but the app is 100% unavailable. Wrap cache reads in try/catch and fall through to the DB.
- **Lock TTL shorter than DB query time**: if the distributed lock expires before the DB query returns, multiple workers enter the lock-protected section simultaneously — exactly the stampede you wanted to prevent.
- **`GetOrCreate` with `IMemoryCache` is not thread-safe under high load**: `IMemoryCache.GetOrCreate` can invoke the factory multiple times under contention in .NET versions before 7. Use `HybridCache` or a `SemaphoreSlim` per key.
- **Storing serialised `null` in cache**: `JsonSerializer.Serialize(null)` produces `"null"`. On deserialisation you get `null` back — technically correct, but some serialisers throw. Explicitly handle null DB results by caching a sentinel value with a short TTL.
- **Ignoring `CancellationToken` in cache operations**: `IDistributedCache` methods accept a `CancellationToken`. Pass the request's token; otherwise a cancelled HTTP request keeps the Redis connection open unnecessarily.

## References

- [HybridCache in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/caching/hybrid)
- [IDistributedCache — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/caching/distributed)
- [StackExchange.Redis — GitHub](https://github.com/StackExchange/StackExchange.Redis)
- [See: cache-invalidation-problem.md](./cache-invalidation-problem.md) — stampede prevention in detail
- [See: distributed-cache-vs-local-cache.md](./distributed-cache-vs-local-cache.md) — IMemoryCache vs IDistributedCache trade-offs
