# OpenAPI and Swagger

**Category:** Architecture / API Design
**Difficulty:** 🟡 Middle
**Tags:** `OpenAPI`, `Swagger`, `Swashbuckle`, `NSwag`, `API-documentation`, `versioned-docs`, `code-generation`

## Question

> What is the difference between OpenAPI and Swagger? Compare Swashbuckle vs NSwag for ASP.NET Core — when would you choose each? How do you generate versioned API documentation?

## Short Answer

**OpenAPI** is the specification (formerly Swagger Specification) — a language-agnostic standard for describing REST APIs. **Swagger** is the tooling ecosystem (Swagger UI, Swagger Editor, SwaggerHub) built around that spec. **Swashbuckle** auto-generates OpenAPI JSON/YAML from ASP.NET Core reflection and XML comments — zero code to maintain, but the generated spec mirrors code structure. **NSwag** also generates the spec but adds powerful client code generation (TypeScript, C#) from `.nswag` config files. Choose Swashbuckle when you want to document your API. Choose NSwag when you also need type-safe generated clients.

## Detailed Explanation

### OpenAPI Specification Basics

An OpenAPI document (`openapi.json` / `openapi.yaml`) describes:
- Endpoints (paths + HTTP methods)
- Request/response schemas
- Authentication schemes
- Error responses
- Server URLs

```yaml
# openapi.yaml — minimal example
openapi: "3.0.4"
info:
  title: Orders API
  version: "2.0"
paths:
  /api/v2/orders:
    get:
      summary: List orders
      parameters:
        - name: page
          in: query
          schema: { type: integer, default: 1 }
      responses:
        "200":
          description: Paged list of orders
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PagedOrderResult'
```

### Swashbuckle: Code-First Spec Generation

```bash
dotnet add package Swashbuckle.AspNetCore
```

```csharp
// Program.cs
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "Orders API", Version = "v1" });

    // Include XML documentation comments in the OpenAPI spec
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    options.IncludeXmlComments(Path.Combine(AppContext.BaseDirectory, xmlFile));

    // JWT bearer auth in Swagger UI
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header
    });
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        [new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } }]
            = Array.Empty<string>()
    });
});

app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "Orders API v1");
    options.RoutePrefix = "swagger";  // ← serve at /swagger
});
```

```csharp
// Controller: XML doc + ProducesResponseType drives the generated spec
/// <summary>Get an order by ID.</summary>
/// <param name="id">The order identifier.</param>
/// <response code="200">Order found.</response>
/// <response code="404">Order not found.</response>
[HttpGet("{id:int}")]
[ProducesResponseType<OrderDto>(StatusCodes.Status200OK)]
[ProducesResponseType(StatusCodes.Status404NotFound)]
public async Task<ActionResult<OrderDto>> Get(int id, CancellationToken ct)
    => await _sender.Send(new GetOrderByIdQuery(id), ct) is { } o ? Ok(o) : NotFound();
```

### NSwag: Code-First + Client Generation

```bash
dotnet add package NSwag.AspNetCore
dotnet tool install -g NSwag.ConsoleX  # ← CLI for client code generation
```

```csharp
// Program.cs — NSwag
builder.Services.AddOpenApiDocument(options =>
{
    options.PostProcess = doc =>
    {
        doc.Info.Title = "Orders API";
        doc.Info.Version = "v2";
    };
    options.AddSecurity("JWT", new OpenApiSecurityScheme
    {
        Type = OpenApiSecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT"
    });
});

app.UseOpenApi();          // ← generates /swagger/v1/swagger.json
app.UseSwaggerUi();        // ← serves Swagger UI at /swagger
```

```json
// nswag.json — generate TypeScript client from running API
{
  "documentGenerator": {
    "fromDocument": {
      "url": "http://localhost:5000/swagger/v1/swagger.json"
    }
  },
  "codeGenerators": {
    "openApiToTypeScriptClient": {
      "className": "OrdersClient",
      "template": "Fetch",
      "output": "frontend/src/api/orders-client.ts"
    }
  }
}
```

### Versioned OpenAPI Documentation

```csharp
// Multiple documents — one per API version (used with Asp.Versioning)
builder.Services.AddSwaggerGen(options =>
{
    var descriptions = app.Services.GetRequiredService<IApiVersionDescriptionProvider>()
        .ApiVersionDescriptions;

    foreach (var description in descriptions)
        options.SwaggerDoc(description.GroupName, new OpenApiInfo
        {
            Title = "Orders API",
            Version = description.ApiVersion.ToString(),
            Description = description.IsDeprecated ? "⚠️ Deprecated version." : null
        });

    options.OperationFilter<SwaggerDefaultValues>(); // ← fixes {version} parameter in Swagger UI
});

app.UseSwaggerUI(options =>
{
    foreach (var description in app.Services.GetRequiredService<IApiVersionDescriptionProvider>()
        .ApiVersionDescriptions.OrderByDescending(d => d.ApiVersion))
    {
        options.SwaggerEndpoint($"/swagger/{description.GroupName}/swagger.json",
            $"Orders API {description.GroupName.ToUpperInvariant()}");
    }
});
```

### Swashbuckle vs NSwag

| | Swashbuckle | NSwag |
|--|------------|-------|
| **Spec generation** | ✅ Reflection-based | ✅ Reflection-based |
| **Client generation** | ❌ No | ✅ TypeScript, C#, more |
| **Community** | Larger, more examples | Smaller |
| **Asp.Versioning compat** | ✅ Well-documented | ✅ Supported |
| **Performance** | ✅ Fast startup | ✅ Comparable |
| **Configuration** | Code + XML comments | Code + nswag.json |
| **Choose when** | Documentation only | Also need generated clients |

## Code Example

```csharp
// .NET 9 built-in OpenAPI (Microsoft.AspNetCore.OpenApi)
// Available from .NET 9 — lightweight alternative without Swashbuckle
builder.Services.AddOpenApi();

app.MapOpenApi();  // ← serves /openapi/v1.json

// Scalar UI instead of Swagger UI (more modern — works with built-in OpenAPI)
// dotnet add package Scalar.AspNetCore
app.MapScalarApiReference();  // ← serves /scalar

// For Swashbuckle: still preferred for complex versioning + security configuration
```

## Common Follow-up Questions

- How do you add authentication/authorization information to the Swagger UI for testing protected endpoints?
- How do you include XML documentation comments in the generated OpenAPI spec?
- What is the difference between `ProducesResponseType` and the OpenAPI `responses` specification?
- How do you generate C# clients from an OpenAPI spec with NSwag?
- What is the new `Microsoft.AspNetCore.OpenApi` package in .NET 9, and how does it differ from Swashbuckle?

## Common Mistakes / Pitfalls

- **Missing `<GenerateDocumentationFile>true</GenerateDocumentationFile>` in .csproj**: XML docs are not generated by default, so `IncludeXmlComments()` has nothing to include — no descriptions appear in Swagger UI.
- **Exposing Swagger UI in production**: Swagger UI in production exposes your full API surface. Restrict it to non-production environments or protect with authentication middleware.
- **Not setting `ProducesResponseType` for non-200 responses**: the OpenAPI spec will show only `200` as a possible response, misleading API consumers about error handling.
- **Swashbuckle + Asp.Versioning without `SwaggerDefaultValues` filter**: the Swagger UI shows `{version}` as an editable parameter instead of being filled in automatically — breaks the try-it-out experience.

## References

- [Swashbuckle GitHub](https://github.com/domaindrivendev/Swashbuckle.AspNetCore)
- [NSwag GitHub](https://github.com/RicoSuter/NSwag)
- [OpenAPI Specification 3.1.0](https://spec.openapis.org/oas/v3.1.0)
- [OpenAPI in .NET 9 — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/overview)
- [See: api-versioning-in-aspnet-core.md](./api-versioning-in-aspnet-core.md)
