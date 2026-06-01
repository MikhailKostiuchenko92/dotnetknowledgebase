# Response Caching in ASP.NET Core

**Category:** ASP.NET Core / Web API Design
**Difficulty:** 🟡 Middle
**Tags:** `ResponseCache`, `Cache-Control`, `Vary`, `IResponseCachePolicy`, `CDN`, `ETag`

## Question

> How does the `[ResponseCache]` attribute work in ASP.NET Core, and how does it differ from output caching? What are the Cache-Control and Vary header implications?

## Short Answer

`[ResponseCache]` is an **MVC result filter** that sets HTTP caching headers (`Cache-Control`, `Pragma`, `Vary`) on the response — it does NOT cache anything on the server side by default. It tells HTTP intermediaries (browsers, CDNs, reverse proxies) how to cache the response. `ResponseCachingMiddleware` adds server-side response caching on top of this. Output caching (`.NET 7+`, `IOutputCacheStore`) is a separate, more powerful server-side cache that doesn't depend on HTTP cache headers.

## Detailed Explanation

### `[ResponseCache]` only sets headers

```
[ResponseCache] → Cache-Control: public, max-age=60, Vary: Accept-Encoding
                  (tells the browser / CDN to cache for 60 seconds)
```

No bytes are cached on the server unless you add `ResponseCachingMiddleware`:

```csharp
app.UseResponseCaching(); // must be BEFORE app.UseRouting / app.MapControllers
```

### `[ResponseCache]` parameters

| Parameter | Maps to | Example |
|---|---|---|
| `Duration` | `max-age` / `s-maxage` | `Duration = 60` |
| `Location` | `public` / `private` / `no-store` | `Location = ResponseCacheLocation.Any` |
| `NoStore` | `no-store` | `NoStore = true` |
| `VaryByHeader` | `Vary` header | `VaryByHeader = "Accept-Language"` |
| `VaryByQueryKeys` | Used by ResponseCachingMiddleware only | `VaryByQueryKeys = new[] { "page" }` |
| `CacheProfileName` | Named profile | `CacheProfileName = "Default60"` |

### Cache-Control values per Location

| `ResponseCacheLocation` | Cache-Control |
|---|---|
| `Any` | `public, max-age=<n>` |
| `Client` | `private, max-age=<n>` |
| `None` | `no-cache` |
| `NoStore = true` | `no-store` |

### Cache profiles (DRY)

Define reusable profiles in `MvcOptions`:

```csharp
builder.Services.AddControllers(opts =>
{
    opts.CacheProfiles.Add("Default60", new CacheProfile
    {
        Duration = 60,
        Location = ResponseCacheLocation.Any,
        VaryByHeader = "Accept"
    });
});

[ResponseCache(CacheProfileName = "Default60")]
public IActionResult GetCatalog() => Ok(catalog);
```

### `VaryByQueryKeys` — server-side only

`VaryByQueryKeys` is used by `ResponseCachingMiddleware` to distinguish cached responses by query string:

```csharp
[ResponseCache(Duration = 120, VaryByQueryKeys = new[] { "category", "page" })]
public IActionResult GetProducts(string? category, int page = 1) => Ok(...)
```

Without `UseResponseCaching()`, this parameter is silently ignored.

### Response caching vs output caching

| | `ResponseCachingMiddleware` | `OutputCacheMiddleware` (.NET 7+) |
|---|---|---|
| Depends on Cache-Control headers | ✅ Yes | ❌ No |
| Configurable policies | Limited | ✅ Rich — vary-by, expiry, tags |
| Cache invalidation | ❌ None | ✅ Tag-based eviction |
| `private` responses cached | ❌ No | ✅ (if explicitly configured) |
| Works with CDN | ✅ (headers respected) | ✅ (separate header control) |
| API | `[ResponseCache]` | `.CacheOutput()` minimal API / `[OutputCache]` controller |

> **Recommendation:** For new projects on .NET 7+, prefer `OutputCacheMiddleware` + `[OutputCache]` over `ResponseCachingMiddleware` for server-side caching. Use `[ResponseCache]` only for CDN/browser-level HTTP cache headers.

## Code Example

```csharp
// Program.cs
builder.Services.AddResponseCaching();
builder.Services.AddControllers(opts =>
{
    opts.CacheProfiles.Add("PublicLong", new CacheProfile
    {
        Duration = 3600,   // 1 hour
        Location = ResponseCacheLocation.Any,
        VaryByHeader = "Accept-Encoding"
    });
    opts.CacheProfiles.Add("NoStore", new CacheProfile
    {
        NoStore = true,
        Location = ResponseCacheLocation.None
    });
});

var app = builder.Build();
app.UseResponseCaching(); // must come before routing/controllers
app.MapControllers();
```

```csharp
// Controller usage
[ApiController]
[Route("[controller]")]
public class CatalogController : ControllerBase
{
    // Cache for 1 hour at public caches (CDNs, shared proxies)
    [HttpGet("categories")]
    [ResponseCache(CacheProfileName = "PublicLong")]
    public IActionResult GetCategories() => Ok(_categories);

    // Vary by user locale + page number
    [HttpGet("products")]
    [ResponseCache(Duration = 120, VaryByQueryKeys = new[] { "page" }, VaryByHeader = "Accept-Language")]
    public IActionResult GetProducts(int page = 1) => Ok(GetPage(page));

    // Sensitive data: never cache
    [HttpGet("user/cart")]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public IActionResult GetCart() => Ok(_cart);
}
```

## Common Follow-up Questions

- How does `[ResponseCache]` interact with HTTPS responses and `Cache-Control: no-store`?
- What is the `Vary` header and why does the framework add `Vary: Accept-Encoding` by default?
- How do you clear a cached response in `ResponseCachingMiddleware`? (You can't — use `OutputCacheMiddleware` for eviction.)
- How does response caching interact with authentication / `[Authorize]` responses?
- What is the difference between `s-maxage` and `max-age` in Cache-Control?

## Common Mistakes / Pitfalls

- **Using `[ResponseCache]` and expecting server-side caching without `UseResponseCaching()`** — the attribute only sets headers; `UseResponseCaching()` must be added to actually cache on the server.
- **Caching authenticated responses with `Location = ResponseCacheLocation.Any`** — this tells shared caches (CDNs) they can cache and serve private user data to any user. Always use `Client` or `NoStore` for authenticated responses.
- **Registering `UseResponseCaching()` after `UseRouting()`** — the middleware must process the response before MVC sets headers; place it early in the pipeline.
- **Relying on `VaryByQueryKeys` without `UseResponseCaching()`** — silently ignored without the middleware; the response is cached without query key variation.
- **Confusing `Duration = 0` with `NoStore = true`** — `Duration = 0` sets `max-age=0` (revalidate on next request); `NoStore = true` prohibits caching entirely. They have different semantics.

## References

- [Microsoft Learn — Response caching in ASP.NET Core](https://learn.microsoft.com/aspnet/core/performance/caching/response?view=aspnetcore-8.0)
- [Microsoft Learn — Response caching middleware](https://learn.microsoft.com/aspnet/core/performance/caching/middleware?view=aspnetcore-8.0)
- [Microsoft Learn — Output caching middleware (.NET 7+)](https://learn.microsoft.com/aspnet/core/performance/caching/output?view=aspnetcore-8.0)
- [MDN — Cache-Control header](https://developer.mozilla.org/docs/Web/HTTP/Headers/Cache-Control)
