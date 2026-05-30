# Distributed Cache vs Local Cache

**Category:** System Design / Caching
**Difficulty:** 🟡 Middle
**Tags:** `IMemoryCache`, `IDistributedCache`, `Redis`, `distributed-cache`, `local-cache`, `consistency`, `horizontal-scaling`

## Question

> When should you use a local in-process cache (`IMemoryCache`) vs a distributed cache (`IDistributedCache` backed by Redis)? What are the consistency risks of local caches in a multi-instance deployment, and how do you mitigate them?

## Short Answer

`IMemoryCache` is fast (nanosecond reads, no serialisation) and ideal for a single-instance app or data that's safe to be slightly inconsistent across instances. `IDistributedCache` (e.g., Redis) is shared across all instances — writes are visible to every replica instantly, but reads involve a network round-trip and serialisation. In Kubernetes or Azure App Service deployments with multiple replicas, local caches diverge: instance A caches a stale value that instance B already invalidated. Use a distributed cache when cross-instance consistency matters; use a hybrid (local L1 + Redis L2) when you need both speed and consistency.

## Detailed Explanation

### Local Cache (IMemoryCache)

Data lives in the process's heap memory. There is zero serialization, no network I/O, and sub-microsecond access via a `ConcurrentDictionary` under the hood.

**When it's appropriate:**
- Single-instance deployments (no replicas).
- Data that's immutable or changes rarely (configuration, feature flags, reference lookups).
- Acceptable if replicas serve slightly different cached values (e.g., product catalogue with 5-minute TTL).
- Data too complex or large to serialise efficiently (in-memory object graphs).

**When it's dangerous:**
- Horizontally scaled deployments: each pod has its own local cache. A write to the DB + invalidation of instance A's cache leaves B, C, D still serving stale data until their TTL expires.
- Sticky sessions partially mitigate this (one user always goes to the same instance), but sticky sessions break rolling deploys.

### Distributed Cache (IDistributedCache + Redis)

Data lives in a shared Redis instance (or cluster). All application replicas read from and write to the same store.

**When it's required:**
- Multiple replicas must see the same data (session tokens, feature flags, user permissions).
- Cache invalidation must be immediate across all instances.
- Data is user-specific and the user may hit different instances on different requests.

**Costs:**
- Every cache read = Redis network round-trip + deserialisation (~1–3 ms on local network).
- Serialisation/deserialisation overhead (JSON or protobuf).
- Redis is a separate infrastructure component with its own HA requirements.

### IMemoryCache vs IDistributedCache — Feature Comparison

| Feature | `IMemoryCache` | `IDistributedCache` (Redis) |
|---------|---------------|----------------------------|
| Storage location | In-process heap | External Redis server |
| Read latency | < 1 µs | 1–5 ms (network) |
| Serialisation | Not required | Required (bytes/string) |
| Shared across instances | ❌ No | ✅ Yes |
| Eviction control | Size, TTL, priority | TTL, eviction policy |
| Object type support | Any .NET object | `byte[]` / `string` only |
| Expiry after access | ✅ Sliding expiry | ✅ Sliding expiry |
| Memory limit | Process memory | Redis `maxmemory` config |
| Testability | `MemoryCache` concrete or `IMemoryCache` mock | `IDistributedCache` mock or in-memory impl |

### Hybrid (L1 + L2) Pattern

For the best of both worlds: check local cache first (L1), then Redis (L2), then DB:

```
Read: L1 hit → return (sub-µs)
      L1 miss → L2 hit → populate L1 → return (1–3 ms)
      L2 miss → DB → populate L2 → populate L1 → return (10–50 ms)
```

Used by GitHub, Stack Overflow, and similar high-traffic .NET apps. The Microsoft `HybridCache` service (introduced in .NET 9 preview, stable in ASP.NET Core 9) provides this out of the box.

> **Warning (L1 consistency):** In a hybrid setup, L1 can still serve stale data after Redis is updated. The window of staleness equals the L1 TTL (typically seconds). For security-sensitive data (auth tokens, permissions), use Redis-only — never L1.

### ASP.NET Core: HybridCache (.NET 9)

```csharp
builder.Services.AddHybridCache(options =>
{
    options.DefaultEntryOptions = new HybridCacheEntryOptions
    {
        Expiration = TimeSpan.FromMinutes(5),      // L2 (Redis) TTL
        LocalCacheExpiration = TimeSpan.FromSeconds(30) // L1 TTL
    };
});
```

`HybridCache` also handles **stampede protection** natively: concurrent callers for the same key are deduplicated — only one DB fetch happens.

### Session State in ASP.NET Core

| Session provider | Behaviour |
|-----------------|-----------|
| `AddSession()` default | Stores session in `IDistributedCache` — works with any `IDistributedCache` provider |
| `AddDistributedMemoryCache()` | In-process only — breaks in multi-instance |
| `AddStackExchangeRedisCache()` | Shared Redis — correct for multi-instance |

> **Common production bug:** `AddDistributedMemoryCache()` is the default in single-instance examples. Deploying to Kubernetes with 2 replicas and forgetting to switch to Redis causes users to lose session data whenever they hit a different pod.

## Code Example

```csharp
// .NET 9 — IMemoryCache, IDistributedCache, and HybridCache side-by-side

using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.Hybrid;   // .NET 9
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

// ── Option A: Local only (single instance or acceptable stale data) ───
builder.Services.AddMemoryCache(o => o.SizeLimit = 1000);

// ── Option B: Distributed (Redis — multi-instance) ────────────────────
builder.Services.AddStackExchangeRedisCache(o =>
    o.Configuration = builder.Configuration["Redis:ConnectionString"]);

// ── Option C: Hybrid L1+L2 (.NET 9) ──────────────────────────────────
builder.Services.AddHybridCache(o =>
{
    o.DefaultEntryOptions = new HybridCacheEntryOptions
    {
        Expiration            = TimeSpan.FromMinutes(10),    // Redis TTL
        LocalCacheExpiration  = TimeSpan.FromSeconds(60)     // in-proc TTL
    };
});

var app = builder.Build();

// ── IMemoryCache usage ────────────────────────────────────────────────
app.MapGet("/local/{id}", (int id, IMemoryCache memCache) =>
{
    var value = memCache.GetOrCreate($"item:{id}", entry =>
    {
        entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5);
        entry.Size = 1;
        return FetchFromDb(id);  // called only on miss
    });
    return Results.Ok(value);
});

// ── IDistributedCache usage ───────────────────────────────────────────
app.MapGet("/distributed/{id}", async (int id, IDistributedCache distCache, CancellationToken ct) =>
{
    var key    = $"item:{id}";
    var cached = await distCache.GetStringAsync(key, ct);

    if (cached is not null)
        return Results.Ok(JsonSerializer.Deserialize<MyItem>(cached));

    var item = FetchFromDb(id);
    await distCache.SetStringAsync(key, JsonSerializer.Serialize(item),
        new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5)
        }, ct);

    return Results.Ok(item);
});

// ── HybridCache usage (.NET 9) — stampede-safe, L1+L2 ────────────────
app.MapGet("/hybrid/{id}", async (int id, HybridCache hybridCache, CancellationToken ct) =>
{
    // One call handles: L1 check → L2 check → DB fetch → populate both
    // If two simultaneous requests miss, only ONE factory call is made
    var item = await hybridCache.GetOrCreateAsync(
        $"item:{id}",
        async token => await FetchFromDbAsync(id, token),
        cancellationToken: ct);

    return Results.Ok(item);
});

app.Run();

static MyItem FetchFromDb(int id) => new(id, $"Item {id}");
static Task<MyItem> FetchFromDbAsync(int id, CancellationToken _) =>
    Task.FromResult(new MyItem(id, $"Item {id}"));

record MyItem(int Id, string Name);
```

## Common Follow-up Questions

- How does `HybridCache` in .NET 9 handle cache stampedes compared to manually implementing a lock with `IDistributedCache`?
- What happens to local cache entries when a rolling deployment replaces pods one by one?
- How do you invalidate a local cache entry across all instances without a distributed event bus?
- Can you use `IDistributedCache` with SQL Server as the backend, and when would that make sense?
- How do you test code that depends on `IDistributedCache`?
- What serialisation format (JSON vs protobuf vs MessagePack) would you choose for Redis cache values and why?

## Common Mistakes / Pitfalls

- **`AddDistributedMemoryCache()` in multi-instance production**: this stores "distributed" cache in local memory — not shared. Sessions and shared state are lost when a request hits a different replica.
- **No expiry on `IDistributedCache` entries**: unlike `IMemoryCache`, Redis does not automatically evict entries without an expiry. Omitting `AbsoluteExpirationRelativeToNow` means the key lives forever, filling Redis memory.
- **Storing mutable objects in `IMemoryCache` without cloning**: `IMemoryCache` stores object references. Callers that modify the returned object mutate the cached value for all future readers. Return immutable types (`record`, frozen collections) or clone on read.
- **Serialising complex object graphs to Redis**: circular references, `Stream` objects, or types with no parameterless constructor fail silently or throw at runtime. Test serialisation round-trips in unit tests.
- **Ignoring L1 TTL in hybrid caches**: if L1 TTL is 60 seconds and an admin updates a permission in Redis, users on the same pod will see the old permission for up to 60 seconds. This is acceptable for product names, dangerous for security decisions.
- **Using a single Redis instance as both cache and primary data store**: if Redis goes down and you've set `noeviction`, writes fail entirely. Separate your cache Redis (eviction enabled) from your data Redis (persistence, no eviction).

## References

- [IMemoryCache in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/caching/memory)
- [IDistributedCache in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/caching/distributed)
- [HybridCache in ASP.NET Core (.NET 9) — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/caching/hybrid)
- [StackExchange.Redis — GitHub](https://github.com/StackExchange/StackExchange.Redis)
- [See: redis-fundamentals.md](./redis-fundamentals.md) — Redis internals, clustering, persistence
