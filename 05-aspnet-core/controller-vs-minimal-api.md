# Controllers vs Minimal APIs in ASP.NET Core

**Category:** ASP.NET Core / Web API Design
**Difficulty:** 🟢 Junior
**Tags:** `controllers`, `minimal-api`, `WebAPI`, `MapGet`, `ControllerBase`, `architecture`

## Question

> When would you choose ASP.NET Core controllers over minimal APIs, and vice versa? What are the trade-offs?

## Short Answer

Minimal APIs (introduced in .NET 6) are lighter-weight, reduce ceremony, and are better suited for microservices or simple endpoints; they use delegates and `MapGet`/`MapPost`/etc. with no controller class required. Controllers offer richer MVC features — `ModelState`, action filters, `IActionResult` conventions, XML formatters, and conventions-based routing — making them better for large apps with cross-cutting MVC concerns. As of .NET 8, feature parity is nearly complete; the choice is mainly architectural and team-preference.

## Detailed Explanation

### What minimal APIs look like

```csharp
var app = WebApplication.Create(args);

app.MapGet("/products/{id}", async (int id, IProductService svc) =>
    await svc.GetByIdAsync(id) is { } product
        ? TypedResults.Ok(product)
        : TypedResults.NotFound());

app.Run();
```

### What controllers look like

```csharp
[ApiController]
[Route("[controller]")]
public class ProductsController(IProductService svc) : ControllerBase
{
    [HttpGet("{id}")]
    public async Task<ActionResult<Product>> GetById(int id)
    {
        var product = await svc.GetByIdAsync(id);
        return product is null ? NotFound() : Ok(product);
    }
}
```

### Feature comparison

| Feature | Controllers | Minimal APIs |
|---|---|---|
| Action filters | ✅ Full | ✅ `IEndpointFilter` (.NET 7+) |
| Model binding | ✅ Full (incl. complex sources) | ✅ Most scenarios; no `IModelBinderProvider` chain |
| ModelState validation | ✅ `[ApiController]` auto-400 | ❌ Manual (FluentValidation / `MiniValidator`) |
| XML formatter | ✅ AddXmlSerializerFormatters | ❌ Not built-in |
| Content negotiation | ✅ Full Accept-header | ❌ Limited (JSON default) |
| OpenAPI / Swagger | ✅ Swashbuckle / NSwag | ✅ `Microsoft.AspNetCore.OpenApi` (.NET 9), Swashbuckle |
| Views / Razor Pages | ✅ | ❌ |
| Route conventions | ✅ Attribute + conventional | ✅ Attribute only |
| Area support | ✅ | ❌ |
| File size / startup speed | Heavier | ✅ Lighter |
| AOT compatibility | Partial | ✅ Full (RequestDelegateGenerator, .NET 8+) |
| Test readability | Medium | ✅ Easy with `WebApplicationFactory` |

### When to use controllers

- Large application with many shared action filters (audit logging, validation, caching)
- Need XML content negotiation or complex custom model binders
- Team is familiar with MVC conventions and has existing controller-heavy codebase
- Application uses Views, Razor Pages, or areas
- Relying on `[ApiController]` for automatic model-state validation and binding inference

### When to use minimal APIs

- Microservice or function-like endpoint with minimal ceremony
- AOT-compiled deployment (NativeAOT / trimming — minimal APIs support `RequestDelegateGenerator`)
- Need the fastest possible startup and smallest memory footprint
- Prototyping or small internal APIs
- Prefer co-location of route + handler in a single place (no class ceremony)

### Hybrid approach (common in .NET 8+)

Many teams use both in the same app:

```csharp
// Complex, filter-heavy CRUD controllers stay as ControllerBase
app.MapControllers();

// Lightweight utility endpoints as minimal APIs
app.MapGet("/version", () => new { Version = "1.0.0", Environment.MachineName });
app.MapGet("/ping", () => TypedResults.Ok("pong"));
```

## Code Example

```csharp
// Minimal API with groups (equivalent to a controller)
var products = app.MapGroup("/api/products")
    .RequireAuthorization()
    .WithTags("Products")
    .AddEndpointFilter<ValidationFilter<CreateProductRequest>>();

products.MapGet("/", async (IProductService svc, CancellationToken ct) =>
    TypedResults.Ok(await svc.GetAllAsync(ct)));

products.MapGet("/{id:int}", async (int id, IProductService svc, CancellationToken ct) =>
    await svc.GetByIdAsync(id, ct) is { } p ? TypedResults.Ok(p) : TypedResults.NotFound());

products.MapPost("/", async (CreateProductRequest req, IProductService svc, CancellationToken ct) =>
{
    var created = await svc.CreateAsync(req, ct);
    return TypedResults.Created($"/api/products/{created.Id}", created);
});
```

```csharp
// Equivalent controller
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProductsController(IProductService svc) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Product>>> GetAll(CancellationToken ct)
        => Ok(await svc.GetAllAsync(ct));

    [HttpGet("{id:int}")]
    public async Task<ActionResult<Product>> GetById(int id, CancellationToken ct)
        => await svc.GetByIdAsync(id, ct) is { } p ? Ok(p) : NotFound();

    [HttpPost]
    public async Task<ActionResult<Product>> Create(CreateProductRequest req, CancellationToken ct)
    {
        var created = await svc.CreateAsync(req, ct);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }
}
```

## Common Follow-up Questions

- How do you organize many minimal API endpoints without one huge `Program.cs`?
- Can you apply the same authorization middleware to both controllers and minimal API groups?
- Does using minimal APIs affect OpenAPI document generation?
- How do `IEndpointFilter` capabilities compare to MVC action filters in .NET 8?
- What is the performance difference between controllers and minimal APIs at the HTTP layer?

## Common Mistakes / Pitfalls

- **Assuming minimal APIs have no filter support** — `.AddEndpointFilter<T>()` on groups and endpoints provides before/after execution hooks equivalent to action filters (.NET 7+).
- **Mixing return types in minimal API handlers** — returning `IResult` vs `T` directly affects OpenAPI schema generation; prefer `TypedResults.Ok<T>()` for accurate Swagger docs.
- **Putting all minimal API endpoints in `Program.cs`** — extract into extension methods or separate `IEndpointRouteBuilder` extension classes to keep code maintainable.
- **Expecting automatic model validation in minimal APIs** — `[ApiController]`'s auto-400 doesn't apply; validate manually or via a validation endpoint filter.
- **Forgetting AOT limitations with controllers** — `ControllerBase` uses reflection; for AOT/NativeAOT scenarios, minimal APIs with `RequestDelegateGenerator` are required.

## References

- [Microsoft Learn — Choose between controllers and minimal APIs](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/vs-controllers?view=aspnetcore-8.0)
- [Microsoft Learn — Minimal APIs overview](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis?view=aspnetcore-8.0)
- [Andrew Lock — Organizing minimal API endpoints](https://andrewlock.net/tag/minimal-api/) (verify URL)
- [Microsoft — MapGroup source](https://github.com/dotnet/aspnetcore/blob/main/src/Http/Routing/src/Builder/EndpointRouteBuilderExtensions.cs)
