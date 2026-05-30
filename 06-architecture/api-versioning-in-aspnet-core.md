# API Versioning in ASP.NET Core

**Category:** Architecture / API Design
**Difficulty:** 🟡 Middle
**Tags:** `Asp.Versioning`, `API-versioning`, `minimal-APIs`, `version-sets`, `MapToApiVersion`, `OpenAPI`, `ASP.NET-Core`

## Question

> How do you implement API versioning in ASP.NET Core using the `Asp.Versioning` package? Cover version sets for Minimal APIs, `[ApiVersion]` for controllers, `MapToApiVersion`, deprecated versions, and OpenAPI integration.

## Short Answer

Install `Asp.Versioning.Http` (Minimal APIs) or `Asp.Versioning.Mvc` (controllers), call `AddApiVersioning()` in `Program.cs`. For controllers, use `[ApiVersion("2.0")]` on the controller and `[MapToApiVersion("2.0")]` on individual action methods. For Minimal APIs, create version sets with `app.NewApiVersionSet()` and chain `.MapToApiVersion(2)` per endpoint. Integrate with Swagger/OpenAPI via `AddApiExplorer()` and Swashbuckle's `VersionedApiExplorer`.

## Detailed Explanation

### Package Installation

```bash
# Minimal APIs
dotnet add package Asp.Versioning.Http

# Controller-based APIs
dotnet add package Asp.Versioning.Mvc
dotnet add package Asp.Versioning.Mvc.ApiExplorer  # ← for Swagger support

# Both + OpenAPI
dotnet add package Asp.Versioning.Http
dotnet add package Swashbuckle.AspNetCore
```

### Service Registration

```csharp
builder.Services
    .AddApiVersioning(options =>
    {
        options.DefaultApiVersion = new ApiVersion(1);
        options.AssumeDefaultVersionWhenUnspecified = true;
        options.ReportApiVersions = true;  // ← api-supported-versions: 1.0, 2.0 in response headers
        options.ApiVersionReader = new UrlSegmentApiVersionReader();
    })
    .AddApiExplorer(options =>
    {
        options.GroupNameFormat = "'v'VVV";       // ← group name "v1", "v2", "v3"
        options.SubstituteApiVersionInUrl = true; // ← replaces {version:apiVersion} in Swagger UI
    });
```

### Minimal API Version Sets

```csharp
// Create a version set for a logical API group
var ordersApi = app.NewApiVersionSet("Orders")
    .HasApiVersion(1)
    .HasApiVersion(2)
    .HasDeprecatedApiVersion(1)   // ← marks v1 as deprecated (clients get warning header)
    .ReportApiVersions()
    .Build();

// Route definition — note {version:apiVersion} route parameter required for URL versioning
app.MapGet("/api/v{version:apiVersion}/orders",
    async (ISender sender, CancellationToken ct)
        => await sender.Send(new GetOrdersQueryV1(), ct))
    .WithApiVersionSet(ordersApi)
    .MapToApiVersion(1);

app.MapGet("/api/v{version:apiVersion}/orders",
    async (ISender sender, CancellationToken ct)
        => await sender.Send(new GetOrdersQueryV2(), ct))
    .WithApiVersionSet(ordersApi)
    .MapToApiVersion(2);

// POST: exists in both v1 and v2 — same handler
app.MapPost("/api/v{version:apiVersion}/orders",
    async ([FromBody] PlaceOrderCommand cmd, ISender sender, CancellationToken ct)
        => Results.Created($"/api/v1/orders/{await sender.Send(cmd, ct)}", null))
    .WithApiVersionSet(ordersApi)
    .MapToApiVersion(1)
    .MapToApiVersion(2);
```

### Controller-Based Versioning

```csharp
// Single controller handling multiple versions
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
[ApiVersion("1.0", Deprecated = true)]   // ← v1 deprecated
[ApiVersion("2.0")]
public class OrdersController(ISender sender) : ControllerBase
{
    // GET /api/v1/orders — deprecated
    [HttpGet, MapToApiVersion("1.0")]
    public async Task<List<OrderDtoV1>> GetV1(CancellationToken ct)
        => await sender.Send(new GetOrdersQueryV1(), ct);

    // GET /api/v2/orders — current
    [HttpGet, MapToApiVersion("2.0")]
    public async Task<List<OrderDtoV2>> GetV2([FromQuery] OrderFilterV2 filter, CancellationToken ct)
        => await sender.Send(new GetOrdersQueryV2(filter.Status, filter.Page), ct);

    // POST works identically for both versions — MapToApiVersion not needed when controller-level
    [HttpPost]
    public async Task<IActionResult> Place([FromBody] PlaceOrderCommand cmd, CancellationToken ct)
    {
        var id = await sender.Send(cmd, ct);
        return CreatedAtAction(nameof(GetV2), new { id, version = "2.0" }, id);
    }
}

// Alternative: separate controllers per version (cleaner for large diffs)
[ApiController, ApiVersion("3.0"), Route("api/v{version:apiVersion}/orders")]
public class OrdersV3Controller(ISender sender) : ControllerBase { ... }
```

### Deprecation and Sunset Headers

```csharp
// When a version is deprecated, response headers automatically include:
// api-deprecated-versions: 1.0
// Clients can also receive sunset dates via middleware

builder.Services.AddApiVersioning(options =>
{
    options.Policies.Sunset(1.0)     // ← add this after: mark v1 as sunset
        .Effective(new DateTimeOffset(2025, 12, 31, 0, 0, 0, TimeSpan.Zero))
        .Link("https://api.mycompany.com/changelog#v2-migration");
});
// Response header: Sunset: Tue, 31 Dec 2025 00:00:00 GMT
// Response header: Link: <https://...>; rel="successor-version"
```

### OpenAPI (Swagger) Integration

```csharp
// Multiple Swagger documents — one per API version
builder.Services.AddSwaggerGen(options =>
{
    var descriptions = app.Services.GetRequiredService<IApiVersionDescriptionProvider>()
        .ApiVersionDescriptions;

    foreach (var description in descriptions)
    {
        options.SwaggerDoc(description.GroupName, new OpenApiInfo
        {
            Title = "Orders API",
            Version = description.ApiVersion.ToString(),
            Description = description.IsDeprecated ? "⚠️ This version is deprecated." : null
        });
    }
});

app.UseSwagger();
app.UseSwaggerUI(options =>
{
    foreach (var description in app.Services
        .GetRequiredService<IApiVersionDescriptionProvider>().ApiVersionDescriptions)
    {
        options.SwaggerEndpoint(
            $"/swagger/{description.GroupName}/swagger.json",
            $"Orders API {description.GroupName.ToUpperInvariant()}");
    }
});
```

## Code Example

```csharp
// Complete Program.cs for versioned Minimal API
var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddApiVersioning(o =>
    {
        o.DefaultApiVersion = new ApiVersion(1);
        o.AssumeDefaultVersionWhenUnspecified = true;
        o.ReportApiVersions = true;
        o.ApiVersionReader = new UrlSegmentApiVersionReader();
    })
    .AddApiExplorer(o =>
    {
        o.GroupNameFormat = "'v'VVV";
        o.SubstituteApiVersionInUrl = true;
    });

builder.Services.AddSwaggerGen();
builder.Services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<Program>());

var app = builder.Build();
app.UseSwagger();
app.UseSwaggerUI();

var ordersApi = app.NewApiVersionSet("Orders")
    .HasApiVersion(1)
    .HasApiVersion(2)
    .ReportApiVersions()
    .Build();

app.MapGet("/api/v{version:apiVersion}/orders", (ISender s, CancellationToken ct) => s.Send(new GetOrdersQueryV1(), ct))
    .WithApiVersionSet(ordersApi).MapToApiVersion(1).WithName("GetOrdersV1");

app.MapGet("/api/v{version:apiVersion}/orders", (ISender s, CancellationToken ct) => s.Send(new GetOrdersQueryV2(), ct))
    .WithApiVersionSet(ordersApi).MapToApiVersion(2).WithName("GetOrdersV2");

app.Run();
```

## Common Follow-up Questions

- How do you document breaking changes between API versions in OpenAPI?
- Can you mix controller-based and minimal API versioning in the same application?
- How do you route to a specific version from a TypeScript/React frontend?
- What happens when a client calls a deprecated version — do you return an error?
- How do you handle database schema migrations when API versions have different DTOs?

## Common Mistakes / Pitfalls

- **Missing `{version:apiVersion}` in the route template**: URL versioning requires the `{version:apiVersion}` constraint in the route path. A route like `/api/orders` without it won't work for URL-based versioning.
- **`SubstituteApiVersionInUrl = false` in ApiExplorer**: without this, the Swagger UI shows the raw `{version}` template instead of the actual version numbers.
- **Not calling `MapToApiVersion()` on Minimal API endpoints**: if you omit `MapToApiVersion()`, the endpoint is available at all versions registered in the version set, which may cause unintended routing.
- **Forgetting to install `Asp.Versioning.Mvc.ApiExplorer`**: without this, controller-based APIs don't generate separate OpenAPI documents per version.

## References

- [Asp.Versioning GitHub](https://github.com/dotnet/aspnet-api-versioning)
- [Minimal API versioning — .NET Blog](https://devblogs.microsoft.com/dotnet/asp-versioning-6-0/)  (verify URL)
- [See: api-versioning-strategies.md](./api-versioning-strategies.md)
- [See: openapi-and-swagger.md](./openapi-and-swagger.md)
