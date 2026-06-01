# API Versioning in ASP.NET Core

**Category:** ASP.NET Core / Web API Design
**Difficulty:** 🟡 Middle
**Tags:** `versioning`, `Asp.Versioning`, `URL-versioning`, `header-versioning`, `OpenAPI`, `deprecated`

## Question

> How do you implement API versioning in ASP.NET Core? What versioning strategies are available and what are their trade-offs?

## Short Answer

Use the `Asp.Versioning.Http` NuGet package (the successor to `Microsoft.AspNetCore.Mvc.Versioning`). It supports four strategies: **URL segment** (`/api/v1/products`), **query string** (`?api-version=1.0`), **HTTP header** (`api-version: 1.0`), and **media type** (`Accept: application/json;version=1`). URL versioning is the most visible and cacheable; header versioning keeps URLs clean but is harder to test in a browser. Use version sets to share versioning metadata across minimal API endpoints.

## Detailed Explanation

### Package setup

```bash
dotnet add package Asp.Versioning.Http          # for minimal APIs
dotnet add package Asp.Versioning.Mvc           # for controllers
dotnet add package Asp.Versioning.Mvc.ApiExplorer  # for Swagger/OpenAPI
```

### Configuration

```csharp
builder.Services.AddApiVersioning(opts =>
{
    opts.DefaultApiVersion = new ApiVersion(1, 0);  // fallback when no version specified
    opts.AssumeDefaultVersionWhenUnspecified = true;
    opts.ReportApiVersions = true; // adds api-supported-versions header to responses
    opts.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),
        new HeaderApiVersionReader("api-version"),
        new QueryStringApiVersionReader("api-version")
    );
});
```

### Strategies compared

| Strategy | Example | Pros | Cons |
|---|---|---|---|
| URL segment | `/api/v2/products` | Explicit, cacheable, browser-friendly | Changes URL; breaks bookmarks |
| Query string | `?api-version=2.0` | Easy to test | Leaks to logs/analytics |
| Header | `api-version: 2.0` | Clean URL | Harder to test in browser |
| Media type | `Accept: app/json;version=2` | REST-purist | Verbose; poor tooling support |

### Controller versioning

```csharp
[ApiController]
[ApiVersion("1.0")]
[ApiVersion("2.0")]
[Route("api/v{version:apiVersion}/[controller]")]
public class ProductsController : ControllerBase
{
    [HttpGet]
    [MapToApiVersion("1.0")]
    public IActionResult GetV1() => Ok(new { version = "1" });

    [HttpGet]
    [MapToApiVersion("2.0")]
    public IActionResult GetV2() => Ok(new { version = "2", extra = true });
}
```

### Minimal API version sets (.NET 7+)

```csharp
var versionSet = app.NewApiVersionSet()
    .HasApiVersion(new ApiVersion(1, 0))
    .HasApiVersion(new ApiVersion(2, 0))
    .ReportApiVersions()
    .Build();

var products = app.MapGroup("/api/v{version:apiVersion}/products")
    .WithApiVersionSet(versionSet);

products.MapGet("/", GetProductsV1)
    .MapToApiVersion(1, 0);

products.MapGet("/", GetProductsV2)
    .MapToApiVersion(2, 0);
```

### Deprecating a version

```csharp
builder.Services.AddApiVersioning(opts =>
{
    opts.ApiVersionSelector = new CurrentImplementationApiVersionSelector(opts);
});

[ApiVersion("1.0", Deprecated = true)]
[ApiVersion("2.0")]
public class ProductsController : ControllerBase { ... }
```

With `ReportApiVersions = true`, deprecated versions appear in the `api-deprecated-versions` response header.

### OpenAPI / Swagger integration

```csharp
builder.Services.AddApiVersioning()
    .AddApiExplorer(opts =>
    {
        opts.GroupNameFormat = "'v'VVV"; // "v1", "v2"
        opts.SubstituteApiVersionInUrl = true; // replaces {version} in route templates
    });

// Add one Swagger document per API version
foreach (var desc in app.DescribeApiVersions())
{
    builder.Services.AddSwaggerGen(c =>
        c.SwaggerDoc(desc.GroupName, new OpenApiInfo
        {
            Title = $"My API {desc.GroupName}",
            Version = desc.ApiVersion.ToString()
        }));
}
```

## Code Example

```csharp
// Program.cs — full setup with URL segment versioning + Swagger
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddApiVersioning(opts =>
{
    opts.DefaultApiVersion = new ApiVersion(1, 0);
    opts.AssumeDefaultVersionWhenUnspecified = true;
    opts.ReportApiVersions = true;
    opts.ApiVersionReader = new UrlSegmentApiVersionReader();
})
.AddMvc()
.AddApiExplorer(opts =>
{
    opts.GroupNameFormat = "'v'VVV";
    opts.SubstituteApiVersionInUrl = true;
});

builder.Services.AddSwaggerGen();

var app = builder.Build();
app.UseSwagger();
app.UseSwaggerUI(opts =>
{
    // Dynamically generate Swagger UI tab per version
    foreach (var desc in app.DescribeApiVersions())
        opts.SwaggerEndpoint($"/swagger/{desc.GroupName}/swagger.json", desc.GroupName);
});

app.MapControllers();
app.Run();
```

```csharp
// V1 and V2 controllers
[ApiController]
[ApiVersion(1)]
[Route("api/v{version:apiVersion}/[controller]")]
public class WeatherController : ControllerBase
{
    [HttpGet]
    public IActionResult Get() => Ok(new[] { "Sunny", "Rainy" });
}

[ApiController]
[ApiVersion(2)]
[Route("api/v{version:apiVersion}/[controller]")]
public class WeatherController2 : ControllerBase
{
    [HttpGet]
    public IActionResult Get() => Ok(new WeatherForecast[] { /* richer DTO */ });
}
```

## Common Follow-up Questions

- How do you sunset (fully remove) a deprecated API version?
- How do you handle versioning for minimal APIs that share a route group?
- What is the difference between `[MapToApiVersion]` and `[ApiVersion]` on a controller?
- How does `SubstituteApiVersionInUrl` work and when is it needed?
- What happens when a client calls an endpoint without specifying a version and `AssumeDefaultVersionWhenUnspecified = false`?

## Common Mistakes / Pitfalls

- **Applying `[ApiVersion]` without configuring the version reader** — if no `ApiVersionReader` is configured, the framework can't read the version from requests and defaults are always used.
- **Forgetting `SubstituteApiVersionInUrl = true` in `AddApiExplorer`** — without it, Swagger UI shows `{version}` as a literal string in URLs instead of the version number.
- **Creating separate controller classes for each version with the same route** — both respond to the same URL pattern; `[MapToApiVersion]` is the correct way to have multiple versions in one controller or different controllers serving different versions of the same route.
- **Using `Microsoft.AspNetCore.Mvc.Versioning`** — this package is deprecated in favor of `Asp.Versioning.*`. Don't start new projects with the old package.
- **Leaking internal versioning details** — avoid version strings like "2024-01-01" (date-based versioning) unless your API contract explicitly defines date versioning (e.g., Microsoft Graph API style).

## References

- [Microsoft Learn — ASP.NET Core API versioning](https://learn.microsoft.com/aspnet/core/web-api/advanced/conventions?view=aspnetcore-8.0) (verify URL)
- [Asp.Versioning GitHub](https://github.com/dotnet/aspnet-api-versioning)
- [Asp.Versioning Wiki — Getting Started](https://github.com/dotnet/aspnet-api-versioning/wiki/New-Services-Quick-Start)
- [Andrew Lock — API versioning in minimal APIs](https://andrewlock.net/tag/versioning/) (verify URL)
