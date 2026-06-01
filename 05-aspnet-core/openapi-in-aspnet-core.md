# OpenAPI in ASP.NET Core (.NET 8/9)

**Category:** ASP.NET Core / Web API Design
**Difficulty:** 🟡 Middle
**Tags:** `OpenAPI`, `Swashbuckle`, `NSwag`, `Microsoft.AspNetCore.OpenApi`, `Scalar`, `swagger`

## Question

> What are the options for generating OpenAPI documentation in ASP.NET Core? How does `Microsoft.AspNetCore.OpenApi` (.NET 9) differ from Swashbuckle and NSwag?

## Short Answer

ASP.NET Core supports three main OpenAPI document generation approaches: **Swashbuckle.AspNetCore** (reflection-based, richest ecosystem, works with both controllers and minimal APIs), **NSwag** (also generates TypeScript/C# clients), and **Microsoft.AspNetCore.OpenApi** (built-in from .NET 9, AOT-compatible, source-generation-based, no reflection). Swashbuckle is the most battle-tested for controllers; the built-in `Microsoft.AspNetCore.OpenApi` is the future-facing option for trimmed/AOT-compatible apps and integrates with Scalar UI.

## Detailed Explanation

### Three approaches at a glance

| Feature | Swashbuckle | NSwag | Microsoft.AspNetCore.OpenApi |
|---|---|---|---|
| .NET version | All | All | .NET 9+ (preview in .NET 8) |
| Reflection required | ✅ Yes | ✅ Yes | ❌ No (source gen) |
| AOT compatible | ❌ | ❌ | ✅ |
| Swagger UI | ✅ Built-in | ✅ Built-in | ❌ Use Scalar |
| Client code gen | ❌ | ✅ TypeScript/C# | ❌ |
| Transformers API | ✅ Filters | ✅ DocumentProcessors | ✅ `IOpenApiDocumentTransformer` |
| Minimal API support | ✅ | ✅ | ✅ First-class |
| Multiple doc versions | ✅ | ✅ | ✅ |
| Actively maintained | ⚠️ (slow) | ✅ | ✅ (Microsoft) |

### Swashbuckle setup (.NET 8)

```bash
dotnet add package Swashbuckle.AspNetCore
```

```csharp
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "My API", Version = "v1" });
    c.IncludeXmlComments(Path.Combine(AppContext.BaseDirectory, "MyApi.xml"));
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme { ... });
});

app.UseSwagger();
app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "My API v1"));
```

### Microsoft.AspNetCore.OpenApi (.NET 9)

Built-in package — no extra NuGet needed in .NET 9 Web API template:

```bash
dotnet add package Microsoft.AspNetCore.OpenApi  # only needed if not in template
```

```csharp
builder.Services.AddOpenApi(opts =>
{
    opts.AddDocumentTransformer((doc, ctx, ct) =>
    {
        doc.Info.Title = "My API";
        doc.Info.Version = "v1";
        return Task.CompletedTask;
    });
});

app.MapOpenApi(); // serves at /openapi/v1.json by default
```

### Adding Scalar UI (recommended with built-in OpenAPI)

```bash
dotnet add package Scalar.AspNetCore
```

```csharp
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(); // serves Scalar UI at /scalar/v1
}
```

### Adding operation metadata to minimal APIs

```csharp
app.MapGet("/products/{id}", GetProductById)
   .WithName("GetProductById")
   .WithSummary("Get product by ID")
   .WithDescription("Returns a single product or 404 if not found")
   .Produces<Product>(StatusCodes.Status200OK)
   .Produces(StatusCodes.Status404NotFound)
   .WithTags("Products");
```

### XML documentation on controllers

```xml
<!-- .csproj -->
<PropertyGroup>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <NoWarn>$(NoWarn);1591</NoWarn>
</PropertyGroup>
```

```csharp
/// <summary>Gets a product by ID.</summary>
/// <param name="id">The product ID.</param>
/// <returns>The product or 404.</returns>
/// <response code="200">Product found</response>
/// <response code="404">Product not found</response>
[HttpGet("{id}")]
[ProducesResponseType<Product>(200)]
[ProducesResponseType(404)]
public async Task<ActionResult<Product>> GetById(int id) { ... }
```

## Code Example

```csharp
// .NET 9 built-in OpenAPI + Scalar (recommended for new projects)
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi(opts =>
{
    // Add JWT bearer security scheme to all operations
    opts.AddDocumentTransformer<BearerSecuritySchemeTransformer>();
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();          // /openapi/v1.json
    app.MapScalarApiReference(); // /scalar/v1
}

app.MapGet("/api/products", async (IProductService svc) =>
        TypedResults.Ok(await svc.GetAllAsync()))
    .WithName("GetProducts")
    .WithSummary("List all products")
    .WithTags("Products")
    .RequireAuthorization();

app.Run();
```

```csharp
// Custom document transformer for bearer auth
public sealed class BearerSecuritySchemeTransformer(
    IAuthenticationSchemeProvider schemeProvider) : IOpenApiDocumentTransformer
{
    public async Task TransformAsync(
        OpenApiDocument document,
        OpenApiDocumentTransformerContext context,
        CancellationToken cancellationToken)
    {
        var authSchemes = await schemeProvider.GetAllSchemesAsync();
        if (!authSchemes.Any(x => x.Name == JwtBearerDefaults.AuthenticationScheme))
            return;

        document.Components ??= new OpenApiComponents();
        document.Components.SecuritySchemes["Bearer"] = new OpenApiSecurityScheme
        {
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT"
        };
    }
}
```

## Common Follow-up Questions

- How do you generate separate OpenAPI documents for different API versions?
- How does `[ProducesResponseType]` affect the OpenAPI document for controllers?
- What is the difference between `WithOpenApi()` and `Produces<T>()` on a minimal API endpoint?
- How do you add a global API key security requirement to all Swashbuckle-generated operations?
- Can `Microsoft.AspNetCore.OpenApi` be used in production, or only in development?

## Common Mistakes / Pitfalls

- **Using `Produces<T>()` without `TypedResults`** — `Produces<T>()` provides OpenAPI metadata but is manual and can desync from actual return types; `TypedResults.Ok<T>()` generates schema automatically.
- **Forgetting `.WithOpenApi()` on minimal API endpoints when using Swashbuckle** — in some versions, Swashbuckle requires `.WithOpenApi()` to opt an endpoint into schema generation.
- **Generating XML docs but not calling `IncludeXmlComments`** — the XML file is generated but never read; always add the `IncludeXmlComments` call to include it in the swagger output.
- **Serving OpenAPI in production** — exposing API schemas in production can leak endpoint details. Wrap `app.MapOpenApi()` in `if (app.Environment.IsDevelopment())`.
- **Swashbuckle and .NET 9 incompatibility** — Swashbuckle 6.x does not support .NET 9's built-in OpenAPI endpoint. Use Swashbuckle 7.x or migrate to `Microsoft.AspNetCore.OpenApi`.

## References

- [Microsoft Learn — OpenAPI in ASP.NET Core (.NET 9)](https://learn.microsoft.com/aspnet/core/fundamentals/openapi/overview?view=aspnetcore-9.0)
- [Microsoft Learn — Swashbuckle with ASP.NET Core](https://learn.microsoft.com/aspnet/core/tutorials/getting-started-with-swashbuckle?view=aspnetcore-8.0)
- [Scalar for ASP.NET Core](https://github.com/scalar/scalar/blob/main/packages/scalar.aspnetcore/README.md)
- [NSwag project](https://github.com/RicoSuter/NSwag)
- [Andrew Lock — OpenAPI in .NET 9](https://andrewlock.net/tag/openapi/) (verify URL)
