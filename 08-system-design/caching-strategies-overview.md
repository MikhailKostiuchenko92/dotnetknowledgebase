# Caching Strategies Overview

**Category:** System Design / Caching
**Difficulty:** 🟢 Junior
**Tags:** `caching`, `cache-aside`, `read-through`, `write-through`, `write-behind`, `TTL`, `IMemoryCache`, `IDistributedCache`

## Question

> What are the main caching strategies (cache-aside, read-through, write-through, write-behind)? When do you use each, and how do you implement cache-aside in ASP.NET Core?

## Short Answer

**Cache-aside** (lazy loading) is the most common: the application checks the cache first, fetches from the DB on miss, then populates the cache. **Read-through** keeps the cache layer in front of the DB — the cache itself fetches missing data. **Write-through** writes to both cache and DB synchronously on every update — no stale data but double write latency. **Write-behind** (write-back) writes to the cache immediately and asynchronously flushes to the DB — lowest write latency but risk of data loss. Cache-aside is the default for most ASP.NET Core applications.

## Detailed Explanation

### Cache-Aside (Lazy Loading)

The application is responsible for all cache interactions:

```
Read:
  1. Check cache (IMemoryCache / IDistributedCache)
  2. Cache HIT  → return cached value
  3. Cache MISS → query DB → store in cache → return value

Write:
  4. Update DB
  5. Invalidate (delete) or update cache entry
```

**Pros**: Simple; cache only contains data that's been requested; DB is always the source of truth.
**Cons**: First read after expiry always hits the DB (cache miss penalty); risk of stale data between DB write and cache invalidation.

**Use when**: most reads; the cache can be rebuilt on miss; stale data for a few seconds is acceptable.

### Read-Through

The cache sits in front of the DB. The application talks only to the cache. On a miss, the **cache** fetches from the DB and stores the result.

**Pros**: Application code is simpler — no cache-miss handling logic.
**Cons**: First read is slow (miss + DB fetch + store); requires a cache layer that supports this (e.g., Redis with a read-through plugin, or frameworks like NCache).

**Use when**: you want to keep cache logic out of the application; the cache product supports it natively.

### Write-Through

Every write goes to both cache and DB simultaneously (synchronously):

```
Write:
  1. Write to DB
  2. Write to cache
  3. Return to client
```

**Pros**: Cache is always fresh; no stale reads immediately after writes.
**Cons**: Every write is slower (two synchronous writes); cache may store data that's never read again (wasted memory if not combined with TTL).

**Use when**: high read-to-write ratio; data freshness is critical; combined with read-through.

### Write-Behind (Write-Back)

Write to the cache first; flush to the DB asynchronously in the background:

```
Write:
  1. Write to cache → return immediately to client (fast)
  Background:
  2. Flush dirty cache entries to DB (buffered, batched)
```

**Pros**: Very low write latency — write returns after cache update.
**Cons**: Risk of data loss if cache crashes before flush; complexity of managing the flush pipeline; inconsistency window between cache and DB.

**Use when**: write throughput is very high and some data loss is acceptable (gaming leaderboards, view counters); batched DB writes reduce DB load.

### Strategy Comparison

| Strategy | Read performance | Write performance | Consistency | Complexity |
|----------|-----------------|-------------------|-------------|-----------|
| Cache-aside | High (after warm-up) | Normal (DB write + invalidate) | Eventual (TTL or invalidation) | Low |
| Read-through | High (after warm-up) | Normal | Eventual | Medium |
| Write-through | High | Lower (double write) | Strong | Medium |
| Write-behind | High | Very high | Eventually (flush delay) | High |

### TTL (Time-to-Live)

Every cache entry should have a TTL — a maximum age after which it's evicted automatically:

- Short TTL (seconds to minutes): ensures freshness but increases DB load on expiry storms.
- Long TTL (hours/days): reduces DB load but serves stale data longer.
- Sliding TTL: refreshes the TTL on every access — risk of never evicting hot data that never changes.

> **Cache stampede / thundering herd**: if many requests miss a popular key simultaneously (after TTL expiry), all hit the DB at once. Mitigate with: mutex (one fills the cache, others wait), probabilistic early expiration, or background refresh. [See: cache-invalidation-problem.md](./cache-invalidation-problem.md)

### ASP.NET Core Options

| Interface | Backend | Scope |
|-----------|---------|-------|
| `IMemoryCache` | In-process memory | Single instance |
| `IDistributedCache` | Redis, SQL Server, etc. | Shared across instances |

[See: distributed-cache-vs-local-cache.md](./distributed-cache-vs-local-cache.md)

## Code Example

```csharp
// ASP.NET Core 8 — Cache-aside pattern with both IMemoryCache and IDistributedCache

using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Caching.Distributed;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddMemoryCache();
builder.Services.AddStackExchangeRedisCache(options =>
    options.Configuration = "localhost:6379");

var app = builder.Build();

// ── Cache-aside with IMemoryCache (single instance) ───────────────────
app.MapGet("/products/{id}/local", async (
    int id,
    IMemoryCache cache,
    ProductRepository repo) =>
{
    if (cache.TryGetValue($"product:{id}", out Product? product))
        return Results.Ok(product);   // HIT: sub-millisecond

    product = await repo.GetByIdAsync(id);
    if (product is null) return Results.NotFound();

    cache.Set($"product:{id}", product, new MemoryCacheEntryOptions
    {
        AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5),
        SlidingExpiration = TimeSpan.FromMinutes(1),   // extend if accessed
        Size = 1                                        // needed if SizeLimit is set
    });

    return Results.Ok(product);
});

// ── Cache-aside with IDistributedCache (Redis — shared across replicas) ──
app.MapGet("/products/{id}/distributed", async (
    int id,
    IDistributedCache cache,
    ProductRepository repo,
    CancellationToken ct) =>
{
    var key = $"product:{id}";
    var cached = await cache.GetStringAsync(key, ct);

    if (cached is not null)
        return Results.Ok(JsonSerializer.Deserialize<Product>(cached));

    var product = await repo.GetByIdAsync(id);
    if (product is null) return Results.NotFound();

    await cache.SetStringAsync(key, JsonSerializer.Serialize(product),
        new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10)
        }, ct);

    return Results.Ok(product);
});

// ── Write-through: update DB + cache atomically ───────────────────────
app.MapPut("/products/{id}", async (
    int id,
    ProductUpdateRequest req,
    IDistributedCache cache,
    ProductRepository repo,
    CancellationToken ct) =>
{
    var product = await repo.UpdateAsync(id, req.Name, req.Price);   // DB write
    if (product is null) return Results.NotFound();

    // Write-through: immediately update cache with new value
    await cache.SetStringAsync($"product:{id}", JsonSerializer.Serialize(product),
        new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10) },
        ct);

    return Results.Ok(product);
});

// ── Cache invalidation: delete on write (simplest cache-aside variant) ─
app.MapDelete("/products/{id}", async (
    int id,
    IDistributedCache cache,
    ProductRepository repo,
    CancellationToken ct) =>
{
    await repo.DeleteAsync(id);
    await cache.RemoveAsync($"product:{id}", ct);   // invalidate
    return Results.NoContent();
});

app.Run();

record Product(int Id, string Name, decimal Price);
record ProductUpdateRequest(string Name, decimal Price);
class ProductRepository
{
    public Task<Product?> GetByIdAsync(int id) => Task.FromResult<Product?>(new Product(id, "Widget", 9.99m));
    public Task<Product?> UpdateAsync(int id, string name, decimal price) => Task.FromResult<Product?>(new Product(id, name, price));
    public Task DeleteAsync(int id) => Task.CompletedTask;
}
```

## Common Follow-up Questions

- What is the cache stampede problem and how do you prevent it?
- When should you use `IMemoryCache` vs `IDistributedCache`? [See: distributed-cache-vs-local-cache.md](./distributed-cache-vs-local-cache.md)
- How do you choose a TTL value for a given type of data?
- How does write-behind interact with ACID transactions if the DB write fails?
- How do you implement cache warming on application startup?
- How does the output cache in ASP.NET Core 7+ differ from response caching?

## Common Mistakes / Pitfalls

- **No TTL on cache entries**: entries never expire → stale data forever. Always set `AbsoluteExpirationRelativeToNow`.
- **Caching mutable reference objects in IMemoryCache**: `IMemoryCache` stores object references. If code modifies the cached object, all callers see the modification. Cache immutable objects or clones.
- **Forgetting to invalidate cache on write**: a write-through or invalidation step that's missing after a DB update means the cache serves stale data until TTL expires.
- **Using the same cache key for different tenants / users**: a cache key like `"product:42"` without tenant or user context serves data from one tenant to another. Always include scope in keys: `"tenant:abc:product:42"`.
- **Caching `null` / "not found" results**: if you don't cache a not-found result, every request for a non-existent key hits the DB. Cache negative results with a short TTL (e.g., 30s) to prevent DB hammering.
- **Large objects in distributed cache**: serialising a 1MB object to Redis on every cache miss is slower than querying the DB for a small result set. Measure before caching large objects.

## References

- [IMemoryCache in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/caching/memory)
- [IDistributedCache in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/caching/distributed)
- [StackExchange.Redis .NET client](https://stackexchange.github.io/StackExchange.Redis/)
- [Azure Cache for Redis — .NET quickstart](https://learn.microsoft.com/azure/azure-cache-for-redis/cache-dotnet-core-quickstart)
- [See: cache-invalidation-problem.md](./cache-invalidation-problem.md) — the hardest caching problem
