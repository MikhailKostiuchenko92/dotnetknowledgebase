# Distributed Caching in ASP.NET Core

**Category:** ASP.NET Core / Performance & Diagnostics
**Difficulty:** 🔴 Senior
**Tags:** `IDistributedCache`, `Redis`, `cache-aside`, `sliding-expiry`, `absolute-expiry`, `StackExchangeRedis`

## Question

> How does `IDistributedCache` work in ASP.NET Core? What is the cache-aside pattern, and what are the differences between sliding and absolute expiration?

## Short Answer

`IDistributedCache` is an abstraction for key/value stores (Redis, SQL Server, NCache, in-memory for testing) that persists data **outside** the process — enabling sharing across multiple app instances. It serializes values as `byte[]`. The **cache-aside** pattern: check cache first; on miss, load from the source, store in cache, return. **Absolute expiration** removes the entry at a fixed time regardless of access; **sliding expiration** resets the timer on each access but must be combined with an absolute expiry to prevent indefinite retention.

## Detailed Explanation

### `IDistributedCache` interface

```csharp
public interface IDistributedCache
{
    byte[]? Get(string key);
    Task<byte[]?> GetAsync(string key, CancellationToken ct = default);
    void Set(string key, byte[] value, DistributedCacheEntryOptions options);
    Task SetAsync(string key, byte[] value, DistributedCacheEntryOptions options, CancellationToken ct = default);
    void Refresh(string key); // reset sliding expiry
    Task RefreshAsync(string key, CancellationToken ct = default);
    void Remove(string key);
    Task RemoveAsync(string key, CancellationToken ct = default);
}
```

### Redis setup

```bash
dotnet add package Microsoft.Extensions.Caching.StackExchangeRedis
```

```csharp
builder.Services.AddStackExchangeRedisCache(opts =>
{
    opts.Configuration = builder.Configuration.GetConnectionString("Redis");
    opts.InstanceName = "MyApp:"; // key prefix for namespace isolation
});
```

For testing / single node:

```csharp
builder.Services.AddDistributedMemoryCache(); // in-process; NOT distributed
```

### Cache-aside pattern

```csharp
public sealed class ProductCacheService(
    IDistributedCache cache,
    IProductRepository repo,
    ILogger<ProductCacheService> logger)
{
    public async Task<Product?> GetByIdAsync(int id, CancellationToken ct = default)
    {
        var cacheKey = $"product:{id}";

        // 1. Try cache
        var cached = await cache.GetAsync(cacheKey, ct);
        if (cached is not null)
        {
            logger.LogDebug("Cache hit for product {Id}", id);
            return JsonSerializer.Deserialize<Product>(cached);
        }

        // 2. Cache miss — load from source
        logger.LogDebug("Cache miss for product {Id}", id);
        var product = await repo.GetByIdAsync(id, ct);
        if (product is null) return null;

        // 3. Store in cache
        var bytes = JsonSerializer.SerializeToUtf8Bytes(product);
        await cache.SetAsync(cacheKey, bytes, new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1),
            SlidingExpiration = TimeSpan.FromMinutes(20) // reset on access, max 1h
        }, ct);

        return product;
    }

    public Task InvalidateAsync(int id, CancellationToken ct = default) =>
        cache.RemoveAsync($"product:{id}", ct);
}
```

### Expiration modes

| Mode | How it works | Use when |
|---|---|---|
| `AbsoluteExpiration` | Fixed `DateTimeOffset` — expires at that moment | Known TTL, e.g., "expire at midnight" |
| `AbsoluteExpirationRelativeToNow` | Fixed duration from now | Most common: `TimeSpan.FromHours(1)` |
| `SlidingExpiration` | Reset timer on each access | Frequently accessed data; combine with absolute |

> **Warning:** Using `SlidingExpiration` alone without an absolute expiry can result in hot items never expiring, causing stale data to persist indefinitely.

### Serialization helpers

`IDistributedCache` only handles `byte[]`. Common patterns:

```csharp
// JSON (System.Text.Json)
await cache.SetAsync(key, JsonSerializer.SerializeToUtf8Bytes(value), opts, ct);
var value = JsonSerializer.Deserialize<T>(await cache.GetAsync(key, ct));

// Extension methods (Microsoft.Extensions.Caching.Abstractions)
await cache.SetStringAsync(key, value, opts, ct); // UTF-8 string
var str = await cache.GetStringAsync(key, ct);

// MessagePack (faster, smaller)
await cache.SetAsync(key, MessagePackSerializer.Serialize(value), opts, ct);
```

### Handling cache stampede

When many requests miss the cache simultaneously (e.g., after a TTL expires), they all hit the database:

```csharp
// Use SemaphoreSlim per key to prevent stampede
private readonly ConcurrentDictionary<string, SemaphoreSlim> _locks = new();

public async Task<Product?> GetWithLockAsync(int id, CancellationToken ct)
{
    var key = $"product:{id}";
    var cached = await _cache.GetAsync(key, ct);
    if (cached is not null) return Deserialize<Product>(cached);

    var semaphore = _locks.GetOrAdd(key, _ => new SemaphoreSlim(1, 1));
    await semaphore.WaitAsync(ct);
    try
    {
        // Double-check after acquiring lock
        cached = await _cache.GetAsync(key, ct);
        if (cached is not null) return Deserialize<Product>(cached);

        var product = await _repo.GetByIdAsync(id, ct);
        if (product is not null)
            await _cache.SetAsync(key, Serialize(product), _options, ct);
        return product;
    }
    finally
    {
        semaphore.Release();
    }
}
```

## Code Example

```csharp
// Typed cache wrapper — hides serialization and key management
public sealed class ProductCache(IDistributedCache cache)
{
    private static readonly DistributedCacheEntryOptions DefaultOptions = new()
    {
        AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1),
        SlidingExpiration = TimeSpan.FromMinutes(15)
    };

    public async Task<Product?> GetAsync(int id, CancellationToken ct = default)
    {
        var data = await cache.GetAsync($"product:{id}", ct);
        return data is null ? null : JsonSerializer.Deserialize<Product>(data);
    }

    public Task SetAsync(Product product, CancellationToken ct = default) =>
        cache.SetAsync($"product:{product.Id}",
            JsonSerializer.SerializeToUtf8Bytes(product), DefaultOptions, ct);

    public Task RemoveAsync(int id, CancellationToken ct = default) =>
        cache.RemoveAsync($"product:{id}", ct);
}
```

## Common Follow-up Questions

- How does `IDistributedCache` differ from `IMemoryCache`?
- What is a cache stampede and how do you prevent it?
- How do you handle cache deserialization failures (e.g., schema changes between deployments)?
- What is `Refresh()` / `RefreshAsync()` and when would you call it?
- How do you implement a write-through cache pattern?

## Common Mistakes / Pitfalls

- **Using `AddDistributedMemoryCache()` in production** — this is an in-memory, single-node implementation; it doesn't distribute. Use Redis or SQL Server for real distributed caching.
- **Storing large objects in cache** — Redis handles large values poorly above ~100KB; serialize selectively and prefer caching IDs or small DTOs over full domain aggregates.
- **No absolute expiry with sliding expiry** — a hot item with only sliding expiry may never expire, serving stale data indefinitely after source updates.
- **Not handling `null` from `GetAsync`** — cache may be unavailable; always handle `null` gracefully and fall through to the source.
- **Key collisions in multi-tenant or multi-app deployments** — always prefix keys with app name and tenant ID: `"myapp:tenant123:product:456"`. Use `InstanceName` in `AddStackExchangeRedisCache` for automatic prefixing.

## References

- [Microsoft Learn — Distributed caching](https://learn.microsoft.com/aspnet/core/performance/caching/distributed?view=aspnetcore-8.0)
- [Microsoft Learn — StackExchange Redis cache](https://learn.microsoft.com/aspnet/core/performance/caching/distributed?view=aspnetcore-8.0#distributed-redis-cache)
- [StackExchange.Redis documentation](https://stackexchange.github.io/StackExchange.Redis/)
- [Martin Fowler — Cache-Aside pattern](https://martinfowler.com/bliki/CacheAsidePattern.html) (verify URL)
