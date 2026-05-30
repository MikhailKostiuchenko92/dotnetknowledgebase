# API Versioning Strategies

**Category:** Architecture / API Design
**Difficulty:** 🟢 Junior
**Tags:** `API-versioning`, `URL-path`, `query-string`, `header-versioning`, `content-negotiation`, `trade-offs`

## Question

> What are the main strategies for API versioning — URL path, query string, header, and content negotiation? What are the trade-offs of each, and which is recommended for most ASP.NET Core APIs?

## Short Answer

API versioning has four main strategies: **URL path** (`/api/v2/orders`) — most visible, easy to cache and bookmark, but bloats URLs. **Query string** (`/api/orders?api-version=2.0`) — simple, doesn't change URL structure, harder to see in browser. **Header** (`Api-Version: 2.0`) — clean URLs, but invisible to logs and proxies by default. **Content negotiation** (`Accept: application/vnd.myapi.v2+json`) — RESTful purist approach, complex for clients. For most .NET APIs: URL path versioning for its visibility and caching properties. Use the `Asp.Versioning` NuGet package for consistent implementation.

## Detailed Explanation

### URL Path Versioning

```
/api/v1/orders
/api/v2/orders
/api/orders/v1/42    ← less common, version after resource name
```

```csharp
// ASP.NET Core Minimal API with URL path versioning
builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true; // ← adds api-supported-versions header to all responses
});

var v1 = app.NewApiVersionSet("Orders").HasApiVersion(1).HasApiVersion(2).Build();

app.MapGet("/api/v{version:apiVersion}/orders", async (ISender sender, CancellationToken ct)
    => await sender.Send(new GetOrdersQuery(), ct))
    .WithApiVersionSet(v1).MapToApiVersion(1).MapToApiVersion(2);

// Controller-based versioning
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
[ApiVersion("1.0")]
[ApiVersion("2.0")]
public class OrdersController : ControllerBase
{
    [HttpGet, MapToApiVersion("1.0")]
    public Task<List<OrderDtoV1>> GetV1() => ...;

    [HttpGet, MapToApiVersion("2.0")]
    public Task<List<OrderDtoV2>> GetV2() => ...;  // enriched response
}
```

### Query String Versioning

```
/api/orders?api-version=1.0
/api/orders?api-version=2.0
```

```csharp
builder.Services.AddApiVersioning(options =>
{
    options.ApiVersionReader = new QueryStringApiVersionReader("api-version");
    options.DefaultApiVersion = new ApiVersion(1);
    options.AssumeDefaultVersionWhenUnspecified = true;
});
```

### Header Versioning

```
GET /api/orders
Api-Version: 2.0
```

```csharp
builder.Services.AddApiVersioning(options =>
{
    options.ApiVersionReader = new HeaderApiVersionReader("Api-Version");
});
```

**Limitation**: not visible in browser address bar, may be stripped by some proxies, not bookmarkable.

### Content Negotiation (Media Type Versioning)

```
GET /api/orders
Accept: application/vnd.myapi.v2+json
```

```csharp
builder.Services.AddApiVersioning(options =>
{
    options.ApiVersionReader = new MediaTypeApiVersionReader("ver");
    // Reads version from: Accept: application/json;ver=2.0
});
```

### Multiple Readers (Combined)

Many teams support multiple strategies simultaneously for flexibility:

```csharp
builder.Services.AddApiVersioning(options =>
{
    options.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),
        new QueryStringApiVersionReader("api-version"),
        new HeaderApiVersionReader("Api-Version")
    );
    options.DefaultApiVersion = new ApiVersion(1);
    options.AssumeDefaultVersionWhenUnspecified = true;
});
```

### Trade-Off Comparison

| | URL Path | Query String | Header | Content Type |
|--|---------|-------------|--------|-------------|
| **Visibility** | ✅ Visible in URL | ✅ Visible in URL | ❌ Hidden | ❌ Hidden |
| **Cacheable** | ✅ Yes | ✅ Yes | ❌ Cache key doesn't include header | ❌ Complex |
| **Bookmarkable** | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| **URL cleanliness** | ❌ Adds `/v2/` prefix | ❌ Adds `?api-version=` | ✅ Clean | ✅ Clean |
| **HATEOAS compatible** | ✅ Works | ✅ Works | ⚠️ Links don't include version | ❌ Hard |
| **Recommended for** | Public APIs | Internal/tools | Private APIs | Pure REST fans |

## Code Example

```csharp
// Complete URL path versioning setup (recommended for most APIs)
builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true;
    options.ApiVersionReader = new UrlSegmentApiVersionReader();
})
.AddApiExplorer(options =>
{
    options.GroupNameFormat = "'v'VVV";           // ← v1, v2 in OpenAPI groups
    options.SubstituteApiVersionInUrl = true;     // ← fills in {version:apiVersion} in route templates
});
```

## Common Follow-up Questions

- How do you deprecate an API version and communicate the sunset date to clients?
- How do you generate separate Swagger/OpenAPI documentation per version?
- What is the `[ApiVersion("2.0", Deprecated = true)]` attribute used for?
- How do you handle versioning for ASP.NET Core Minimal APIs specifically?
- What is semantic versioning for APIs vs sequential integer versioning?

## Common Mistakes / Pitfalls

- **No versioning strategy from day one**: adding API versioning after clients are integrated requires breaking changes or complex migration. Define a versioning strategy before the first public release.
- **Breaking changes in the same version**: adding new required fields, removing existing fields, or changing field types in a deployed version without bumping the version breaks existing clients.
- **Never deprecating old versions**: maintaining v1, v2, v3, v4 indefinitely causes exponential maintenance cost. Set a deprecation policy (e.g., support for 12 months after a new major version is released).
- **Version in the controller name instead of routing**: `OrdersV2Controller` without proper version routing configuration doesn't actually route `/api/v2/orders` — it's just a naming convention.

## References

- [Asp.Versioning NuGet package](https://github.com/dotnet/aspnet-api-versioning)
- [API versioning — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/web-api/advanced/custom-formatters)
- [See: api-versioning-in-aspnet-core.md](./api-versioning-in-aspnet-core.md)
- [See: backward-compatible-api-changes.md](./backward-compatible-api-changes.md)
