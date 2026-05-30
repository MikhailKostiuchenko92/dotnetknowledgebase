# CDN Fundamentals

**Category:** System Design / Caching
**Difficulty:** 🟡 Middle
**Tags:** `CDN`, `edge-caching`, `cache-control`, `stale-while-revalidate`, `cache-purge`, `Azure CDN`, `CloudFront`

## Question

> What is a CDN and how does edge caching work? How do you control what gets cached at the edge vs at the origin, and how do you handle cache invalidation when content changes?

## Short Answer

A CDN (Content Delivery Network) is a globally distributed network of **edge servers** that cache static and dynamic content close to end users, reducing round-trip latency and origin load. HTTP `Cache-Control` headers tell edges how long to cache responses and when to revalidate. `stale-while-revalidate` lets edges serve stale content immediately while fetching a fresh copy in the background. Cache invalidation (purging) pushes explicit deletion commands to edges — necessary for instant updates outside the TTL window.

## Detailed Explanation

### How It Works

```
User (Frankfurt) → CDN Edge (Frankfurt) → [HIT: return cached] 
                                         → [MISS: fetch from Origin → cache → return]
                   CDN Edge (Sydney)
                   CDN Edge (São Paulo)
```

The edge server acts as a **reverse proxy with caching**. On a cache miss, it fetches from the origin (your servers), stores the response, and serves subsequent requests from its local copy.

**Benefits**:
- Reduced latency: edge is physically close to the user (10–50 ms vs 200+ ms cross-continent).
- Reduced origin load: popular assets served 100% from edge after warm-up.
- DDoS absorption: volumetric attacks hit the distributed CDN rather than your origin.
- Bandwidth cost reduction: egress from CDN edges is cheaper than from origin data centres.

### Cache-Control Headers

The `Cache-Control` response header tells both browsers and CDN edges how to cache responses:

| Directive | Meaning |
|-----------|---------|
| `max-age=3600` | Cache for 3600 seconds |
| `s-maxage=3600` | CDN-specific TTL (overrides `max-age` for shared caches) |
| `no-cache` | Must revalidate before serving (but may store locally) |
| `no-store` | Never cache (sensitive data) |
| `private` | Browser may cache; CDN must not |
| `public` | Both browser and CDN may cache |
| `immutable` | Content will never change (use with content-hashed filenames) |
| `stale-while-revalidate=60` | Serve stale for 60s while fetching fresh in background |
| `stale-if-error=86400` | Serve stale for 24h if origin returns 5xx |

**Example for a static JS bundle with content hash:**
```
Cache-Control: public, max-age=31536000, immutable
```

**Example for an API response:**
```
Cache-Control: public, s-maxage=60, stale-while-revalidate=30
```

### ETag and Conditional Requests

ETag is a version token for a resource. Clients send `If-None-Match: <etag>` on revalidation; if the content hasn't changed, the origin returns `304 Not Modified` (no body), saving bandwidth.

ASP.NET Core sets ETags automatically for static files; for API responses, use `ResponseCachingMiddleware` or set headers manually.

### stale-while-revalidate (SWR)

Serve the cached (possibly stale) response immediately, while the CDN fetches a fresh copy from origin in the background. The next request after the fresh copy arrives will get the updated content.

```
Request at T+61 (TTL expired by 1s):
  → Edge serves stale (T=0 content) immediately — no latency for the user
  → Edge fetches fresh from origin in background
  → Next request at T+62 gets fresh content
```

SWR is ideal for content that changes infrequently but must not block on origin latency.

### What Should (and Should Not) Be Cached at Edge

| Cache | Examples |
|-------|---------|
| ✅ Always | Static assets (JS, CSS, images, fonts) with content hashes |
| ✅ Usually | Public API responses with low personalisation (product catalogue, pricing) |
| ✅ With care | HTML pages (short TTL + SWR) |
| ❌ Never | Authenticated/personalised responses (`Cache-Control: private`) |
| ❌ Never | POST/PUT/DELETE mutation responses |
| ❌ Never | Session cookies, auth tokens |

> **Warning:** Never cache responses containing user-specific data at a shared CDN edge. If one user's data is cached, it can be served to another user. Use `Vary: Authorization` or `Cache-Control: private` to prevent this.

### Cache Invalidation (Purging)

When you deploy new content before the TTL expires, the CDN continues serving the old version. Options:

1. **Content-hashed filenames** (preferred for static assets): `app.js` → `app.abc123.js`. Deploy new file → update HTML to reference new hash → CDN caches both simultaneously; no purge needed.
2. **Explicit cache purge API**: CDN providers expose a purge API. Call it from your CI/CD pipeline after deploy.
3. **Short TTL + SWR**: accept stale content for 60 seconds; no purge needed for most use cases.
4. **Cache tags / surrogate keys**: tag cache entries with logical labels (`product:42`, `category:electronics`). Purge by tag to invalidate all affected entries atomically.

### CDN Options

| Provider | Notes |
|----------|-------|
| Azure CDN / Azure Front Door | Integrates with Azure App Service, Blob Storage; WAF included |
| AWS CloudFront | Tight AWS integration; Lambda@Edge for compute at edge |
| Cloudflare | Global anycast network; Workers for edge compute |
| Fastly | Fine-grained VCL configuration; cache tag purging |

### ASP.NET Core Response Caching

```csharp
// Origin-side: set Cache-Control headers via response caching middleware
builder.Services.AddResponseCaching();
app.UseResponseCaching();

app.MapGet("/products", () => Results.Ok(GetProducts()))
   .WithMetadata(new ResponseCacheAttribute
   {
       Duration   = 60,             // max-age=60
       Location   = ResponseCacheLocation.Any,  // public
       VaryByHeader = "Accept-Encoding"
   });
```

For more control, set headers directly:
```csharp
app.MapGet("/catalogue", (HttpContext ctx) =>
{
    ctx.Response.Headers.CacheControl = "public, s-maxage=300, stale-while-revalidate=60";
    return Results.Ok(GetCatalogue());
});
```

## Code Example

```csharp
// ASP.NET Core 8 — CDN-friendly caching headers for different content types

var app = WebApplication.Create(args);

// ── Static files: long TTL + immutable (content-hashed filenames) ─────
app.UseStaticFiles(new StaticFileOptions
{
    OnPrepareResponse = ctx =>
    {
        // Set 1 year TTL for hashed assets (e.g., app.abc123.js)
        if (ctx.File.Name.Contains('.') && IsContentHashed(ctx.File.Name))
        {
            ctx.Context.Response.Headers.CacheControl =
                "public, max-age=31536000, immutable";
        }
        else
        {
            // Non-hashed static files: 1 hour with must-revalidate
            ctx.Context.Response.Headers.CacheControl =
                "public, max-age=3600, must-revalidate";
        }
    }
});

// ── Public API: short edge TTL + stale-while-revalidate ───────────────
app.MapGet("/api/products", (HttpContext ctx) =>
{
    ctx.Response.Headers.CacheControl =
        "public, s-maxage=60, stale-while-revalidate=30, stale-if-error=86400";
    ctx.Response.Headers.Vary = "Accept-Encoding";
    return Results.Ok(new[] { new Product(1, "Widget", 9.99m) });
});

// ── Personalised: no CDN caching ─────────────────────────────────────
app.MapGet("/api/me/cart", (HttpContext ctx) =>
{
    ctx.Response.Headers.CacheControl = "private, no-store";
    return Results.Ok(GetUserCart(ctx.User));
});

// ── ETag support: conditional GET avoids sending unchanged bodies ─────
app.MapGet("/api/config", (HttpContext ctx) =>
{
    var config   = GetConfig();
    var etag     = $"\"{config.Version}\"";
    var ifNoneMatch = ctx.Request.Headers.IfNoneMatch.ToString();

    if (ifNoneMatch == etag)
        return Results.StatusCode(304);   // Not Modified — no body sent

    ctx.Response.Headers.ETag       = etag;
    ctx.Response.Headers.CacheControl = "public, s-maxage=300";
    return Results.Ok(config);
});

app.Run();

static bool IsContentHashed(string fileName) =>
    System.Text.RegularExpressions.Regex.IsMatch(fileName, @"\.[a-f0-9]{8,}\.");

record Product(int Id, string Name, decimal Price);
record Config(string Version, bool FeatureX);
static Config GetConfig() => new("v42", true);
static object GetUserCart(System.Security.Claims.ClaimsPrincipal user) => new { Items = 3 };
```

## Common Follow-up Questions

- How do you handle CDN caching for A/B testing where different users should see different variants?
- What is edge-side includes (ESI), and when would you use it to cache parts of a page?
- How does Azure Front Door's Rules Engine differ from simply setting `Cache-Control` headers?
- What is the difference between a CDN and a reverse proxy cache like Varnish or Nginx?
- How do you debug a CDN cache miss vs hit for a specific URL?
- How do CDN providers handle cache invalidation across hundreds of globally distributed PoPs?

## Common Mistakes / Pitfalls

- **Caching authenticated responses at the CDN**: forgetting `Cache-Control: private` on personalised endpoints allows one user's data to be served to another — a serious data privacy bug.
- **No `Vary` header with compression**: if the CDN caches a gzip response and serves it to a client that doesn't support gzip (no `Accept-Encoding`), the client receives garbled content. Always set `Vary: Accept-Encoding` on compressed responses.
- **Using `no-cache` when you mean `no-store`**: `no-cache` does NOT prevent caching — it requires revalidation before serving. Use `no-store` for truly sensitive content.
- **Deploying static files without content hashing**: `styles.css` cached with `max-age=31536000` can't be updated without a purge. Use build tools (webpack, Vite) to generate content-hashed filenames.
- **Purging only one CDN edge**: purge APIs are eventually consistent — some edges may take seconds to minutes to propagate the purge. Don't assume a purge is instant globally.
- **Caching error responses (5xx) without `stale-if-error`**: a CDN may cache a 500 response from a briefly failing origin and serve it for `max-age` seconds. Set a short TTL for error responses or use `stale-if-error` explicitly.

## References

- [Azure Front Door caching — Microsoft Learn](https://learn.microsoft.com/azure/frontdoor/front-door-caching)
- [Cache-Control — MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control)
- [stale-while-revalidate — web.dev](https://web.dev/stale-while-revalidate/)
- [ASP.NET Core response caching middleware — Microsoft Learn](https://learn.microsoft.com/aspnet/core/performance/caching/middleware)
- [RFC 7234 — HTTP/1.1 Caching](https://www.rfc-editor.org/rfc/rfc7234) (verify URL)
