# Output Caching in ASP.NET Core (.NET 7+)

**Category:** ASP.NET Core / Web API Design
**Difficulty:** 🔴 Senior
**Tags:** `IOutputCacheStore`, `output-caching`, `OutputCache`, `cache-policies`, `vary-by`, `tag-eviction`

## Question

> How does `OutputCacheMiddleware` (.NET 7+) differ from `ResponseCachingMiddleware`? How do you configure vary-by rules and invalidate cached entries by tag?

## Short Answer

`OutputCachingMiddleware` is a server-side response cache that stores full response bytes in memory (or a custom `IOutputCacheStore`). Unlike `ResponseCachingMiddleware` — which only caches `public` responses respecting HTTP cache headers — output caching operates independently of `Cache-Control` headers, works for authenticated responses, and supports tag-based eviction. Use `.CacheOutput()` on minimal APIs, `[OutputCache]` on controllers, and call `IOutputCacheStore.EvictByTagAsync` to invalidate on mutation.

## Detailed Explanation

### Key differences from response caching

| Aspect | `ResponseCachingMiddleware` | `OutputCacheMiddleware` |
|---|---|---|
| Cache location | Server (must follow HTTP rules) | Server (any response) |
| Respects `Cache-Control` | ✅ Required | ❌ Independent |
| Caches authenticated responses | ❌ | ✅ (if configured) |
| Tag-based eviction | ❌ | ✅ |
| Custom storage | ❌ | ✅ `IOutputCacheStore` |
| Vary-by query/header | Limited | ✅ Rich |
| Added in | .NET Core 1.1 | .NET 7 |

### Setup

```csharp
builder.Services.AddOutputCache(opts =>
{
    // Named base policy
    opts.AddBasePolicy(policy => policy
        .Expire(TimeSpan.FromSeconds(60))
        .SetVaryByHeader("Accept-Language"));

    // Named policy — reuse across endpoints
    opts.AddPolicy("products-list", policy => policy
        .Expire(TimeSpan.FromMinutes(5))
        .SetVaryByQuery("category", "page", "pageSize")
        .Tag("products"));
});

var app = builder.Build();
app.UseOutputCache(); // must be BEFORE UseRouting / MapControllers
```

### Applying to minimal APIs

```csharp
app.MapGet("/api/products", GetProductsHandler)
   .CacheOutput("products-list");

// Inline policy (no named policy required)
app.MapGet("/api/categories", GetCategoriesHandler)
   .CacheOutput(policy => policy
       .Expire(TimeSpan.FromHours(1))
       .Tag("categories"));
```

### Applying to controllers

```csharp
[OutputCache(PolicyName = "products-list")]
[HttpGet]
public async Task<IActionResult> GetProducts(
    string? category, int page = 1, CancellationToken ct = default)
    => Ok(await _svc.GetPageAsync(category, page, ct));

// Inline
[OutputCache(Duration = 30)]
[HttpGet("{id}")]
public async Task<IActionResult> GetById(int id) => Ok(await _svc.GetByIdAsync(id));

// Disable caching on base policy
[OutputCache(NoStore = true)]
[HttpGet("live-feed")]
public IActionResult GetLiveFeed() => Ok(_feed.GetLatest());
```

### Tag-based eviction

Tag entries at cache time, then evict by tag when data changes:

```csharp
// Cache with a product-specific tag
app.MapGet("/api/products/{id:int}", async (int id, IProductService svc) =>
    TypedResults.Ok(await svc.GetByIdAsync(id)))
    .CacheOutput(policy => policy
        .Expire(TimeSpan.FromMinutes(10))
        .Tag($"product-{id}") // per-entry tag
        .Tag("products"));     // group tag

// Evict by tag after update
app.MapPut("/api/products/{id:int}", async (
    int id,
    UpdateProductRequest req,
    IProductService svc,
    IOutputCacheStore cache,
    CancellationToken ct) =>
{
    await svc.UpdateAsync(id, req, ct);
    await cache.EvictByTagAsync($"product-{id}", ct); // evict specific entry
    return TypedResults.NoContent();
});
```

### Vary-by options

```csharp
policy
    .SetVaryByQuery("page", "sort")          // vary by query params
    .SetVaryByHeader("Accept-Language")      // vary by header
    .SetVaryByRouteValue("version")          // vary by route segment
    .SetVaryByValue(ctx => ctx.User.Identity?.Name ?? "anon")  // custom key
```

### Custom `IOutputCacheStore` (Redis)

The default store is in-memory. For multi-instance deployments:

```bash
dotnet add package Microsoft.AspNetCore.OutputCaching.StackExchangeRedis  # preview / community
```

Or implement `IOutputCacheStore` with `IDistributedCache`:

```csharp
public sealed class RedisOutputCacheStore(IDistributedCache redis) : IOutputCacheStore
{
    public ValueTask EvictByTagAsync(string tag, CancellationToken ct) { ... }
    public ValueTask<byte[]?> GetAsync(string key, CancellationToken ct) { ... }
    public ValueTask SetAsync(string key, byte[] value, string[]? tags,
        TimeSpan validFor, CancellationToken ct) { ... }
}
```

## Code Example

```csharp
// Full output cache setup with eviction
builder.Services.AddOutputCache(opts =>
{
    opts.AddPolicy("catalog", policy => policy
        .Expire(TimeSpan.FromMinutes(10))
        .SetVaryByQuery("category", "page")
        .Tag("catalog"));
});

var app = builder.Build();
app.UseOutputCache();

// GET — cached
app.MapGet("/api/catalog", async (IProductService svc, string? category, int page = 1) =>
    TypedResults.Ok(await svc.GetPageAsync(category, page)))
    .CacheOutput("catalog");

// POST — invalidates cache
app.MapPost("/api/catalog", async (
    CreateProductRequest req,
    IProductService svc,
    IOutputCacheStore cache,
    CancellationToken ct) =>
{
    var product = await svc.CreateAsync(req, ct);
    await cache.EvictByTagAsync("catalog", ct); // bust all catalog pages
    return TypedResults.Created($"/api/catalog/{product.Id}", product);
});
```

## Common Follow-up Questions

- How does output caching interact with `[Authorize]` — can you cache per-user responses?
- What happens when `IOutputCacheStore.EvictByTagAsync` is called in a multi-node deployment using the default in-memory store?
- How do you implement a custom lock mechanism to prevent cache stampede?
- Can output caching and response caching be used simultaneously in the same pipeline?
- How does `.SetVaryByValue(ctx => ...)` differ from `.SetVaryByHeader` or `.SetVaryByQuery`?

## Common Mistakes / Pitfalls

- **Using the default in-memory store in a multi-node cluster** — each node has its own cache; a tag eviction on one node won't propagate. Use a distributed cache backend for accurate cross-node eviction.
- **Caching responses that include user-specific data with a shared key** — without `.SetVaryByValue(ctx => ctx.User.Identity?.Name)`, authenticated responses are served from a shared cache entry, leaking user data.
- **Placing `UseOutputCache()` after `UseAuthorization()`** — output caching middleware needs to intercept the response before it's written; placing it after auth means the cached response won't include correct auth behavior.
- **Using `[ResponseCache]` and `CacheOutput()` on the same endpoint** — they operate independently; having both can send conflicting HTTP cache headers to clients.
- **Not calling `EvictByTagAsync` after write operations** — stale cached responses are served until natural expiry. Always evict relevant tags after any mutation that changes the cached data.

## References

- [Microsoft Learn — Output caching middleware (.NET 7+)](https://learn.microsoft.com/aspnet/core/performance/caching/output?view=aspnetcore-8.0)
- [Microsoft Blog — Output caching in .NET 7](https://devblogs.microsoft.com/dotnet/output-caching-middleware/) (verify URL)
- [Microsoft — IOutputCacheStore source](https://github.com/dotnet/aspnetcore/blob/main/src/Middleware/OutputCaching/src/IOutputCacheStore.cs)
- [Andrew Lock — Output caching in .NET 7](https://andrewlock.net/tag/output-cache/) (verify URL)
