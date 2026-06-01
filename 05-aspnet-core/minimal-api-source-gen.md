# Minimal API Source Generation in ASP.NET Core (.NET 8+)

**Category:** ASP.NET Core / Performance & Diagnostics
**Difficulty:** 🟡 Middle
**Tags:** `RequestDelegateGenerator`, `source-generation`, `AOT`, `NativeAOT`, `trimming`, `minimal-api`

## Question

> What is the `RequestDelegateGenerator` (RDG) in ASP.NET Core (.NET 8+) and how does it enable Native AOT compatibility for minimal APIs?

## Short Answer

The `RequestDelegateGenerator` is a Roslyn source generator that analyzes `MapGet`/`MapPost`/etc. calls at **compile time** and generates `RequestDelegate` implementations without reflection. This enables **Native AOT** compilation (no JIT, no runtime reflection) for minimal API apps — resulting in faster startup, smaller binaries, and lower memory use. Controllers still require reflection and are NOT AOT-compatible. RDG is enabled by default in .NET 8 apps and activates automatically when publishing AOT (`PublishAot = true`).

## Detailed Explanation

### What RDG does at compile time

Without RDG (reflection-based at runtime):
```csharp
app.MapGet("/products/{id}", (int id, IProductService svc) => svc.GetById(id));
// At runtime: reflection finds (int id, IProductService svc), reads attributes,
// generates binding/validation code dynamically
```

With RDG (generated at compile time):
```csharp
// Generator emits something like:
var handler = (RequestDelegate)((HttpContext ctx) => {
    var id = int.Parse((string)ctx.Request.RouteValues["id"]!);
    var svc = ctx.RequestServices.GetRequiredService<IProductService>();
    var result = handler_method(id, svc);
    return ctx.Response.WriteAsJsonAsync(result);
});
```

The generated code is placed in `.Generated.cs` files in `obj/`.

### When RDG is active

| Scenario | RDG active |
|---|---|
| `PublishAot = true` | ✅ Required |
| `PublishSingleFile = true` | ✅ Recommended |
| Normal publish | ✅ Active (since .NET 8, for perf even without AOT) |
| Swagger/OpenAPI with metadata | ✅ Works |

### AOT publishing

```xml
<!-- .csproj -->
<PropertyGroup>
    <PublishAot>true</PublishAot>
    <InvariantGlobalization>true</InvariantGlobalization> <!-- reduces AOT size -->
</PropertyGroup>
```

```bash
dotnet publish -r linux-x64 -c Release
# Output: self-contained native binary, ~10MB, starts in <50ms
```

### AOT-incompatible patterns

RDG analyzes your handler signatures; some patterns are NOT AOT-safe:

```csharp
// ❌ Dynamic delegate — generator can't analyze at compile time
app.MapGet("/", Delegate.CreateDelegate(typeof(Func<string>), method));

// ❌ Non-literal route template
var route = GetRoute(); // dynamic
app.MapGet(route, () => "ok");

// ❌ Custom IModelBinder (controllers only — not minimal API)
// Minimal API: implement IBindableFromHttpContext<T> instead

// ✅ Standard handler — fully analyzable
app.MapGet("/products/{id:int}", (int id, IProductService svc, CancellationToken ct) =>
    svc.GetByIdAsync(id, ct));
```

### `IBindableFromHttpContext<T>` — AOT-safe custom binding

```csharp
public sealed record PaginationParams(int Page, int PageSize)
    : IBindableFromHttpContext<PaginationParams>
{
    public static ValueTask<PaginationParams?> BindAsync(HttpContext ctx, ParameterInfo parameter)
    {
        var page = int.TryParse(ctx.Request.Query["page"], out var p) ? p : 1;
        var size = int.TryParse(ctx.Request.Query["pageSize"], out var s) ? s : 20;
        return ValueTask.FromResult<PaginationParams?>(new PaginationParams(page, Math.Min(size, 100)));
    }
}

// Usage — RDG handles this at compile time
app.MapGet("/products", (PaginationParams pagination, IProductService svc) =>
    svc.GetPageAsync(pagination.Page, pagination.PageSize));
```

### AOT-safe JSON serialization

AOT requires source-generated `JsonSerializerContext`:

```csharp
[JsonSerializable(typeof(Product))]
[JsonSerializable(typeof(List<Product>))]
[JsonSerializable(typeof(ProblemDetails))]
internal partial class AppJsonContext : JsonSerializerContext { }

builder.Services.ConfigureHttpJsonOptions(opts =>
    opts.SerializerOptions.TypeInfoResolverChain.Insert(0, AppJsonContext.Default));
```

## Code Example

```csharp
// AOT-compatible minimal API
var builder = WebApplication.CreateSlimBuilder(args); // Slim = trimmed services for AOT

builder.Services.ConfigureHttpJsonOptions(opts =>
    opts.SerializerOptions.TypeInfoResolverChain.Insert(0, AppJsonContext.Default));

builder.Services.AddScoped<IProductService, ProductService>();

var app = builder.Build();

var api = app.MapGroup("/api/v1");

api.MapGet("/products", async (IProductService svc, CancellationToken ct) =>
    TypedResults.Ok(await svc.GetAllAsync(ct)));

api.MapGet("/products/{id:int}", async (int id, IProductService svc, CancellationToken ct) =>
    await svc.GetByIdAsync(id, ct) is { } p ? TypedResults.Ok(p) : TypedResults.NotFound());

api.MapPost("/products", async (CreateProductRequest req, IProductService svc, CancellationToken ct) =>
{
    var p = await svc.CreateAsync(req, ct);
    return TypedResults.Created($"/api/v1/products/{p.Id}", p);
});

app.Run();

[JsonSerializable(typeof(Product))]
[JsonSerializable(typeof(IEnumerable<Product>))]
[JsonSerializable(typeof(CreateProductRequest))]
internal partial class AppJsonContext : JsonSerializerContext { }
```

## Common Follow-up Questions

- How do you diagnose RDG issues when a handler falls back to reflection?
- What is `WebApplication.CreateSlimBuilder` and how does it differ from `CreateBuilder`?
- How does AOT affect third-party libraries like AutoMapper or MediatR?
- What are the startup time and binary size improvements from AOT publishing?
- How does RDG interact with `IEndpointFilter`?

## Common Mistakes / Pitfalls

- **Using `MapGet` with a dynamically created delegate** — RDG can't analyze delegates that aren't statically known at compile time; they fall back to reflection and break AOT.
- **Not adding `[JsonSerializable]` for all types in the response chain** — AOT requires explicit JSON metadata; missing types cause runtime `NotSupportedException` with AOT.
- **Using `WebApplication.CreateBuilder` instead of `CreateSlimBuilder` for AOT targets** — `CreateBuilder` includes MVC, Razor, and other services not needed in minimal API AOT apps, increasing binary size.
- **Expecting controllers to work with AOT** — controllers use reflection heavily and are NOT AOT-compatible. Minimal APIs + RDG is the only supported AOT path.
- **Ignoring analyzer warnings from RDG** — the generator emits warnings when it detects AOT-incompatible patterns; treat them as errors in CI (`<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`).

## References

- [Microsoft Learn — Native AOT in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/native-aot?view=aspnetcore-8.0)
- [Microsoft Learn — RequestDelegateGenerator](https://learn.microsoft.com/aspnet/core/fundamentals/aot/request-delegate-generator/rdg?view=aspnetcore-8.0)
- [Microsoft Blog — Native AOT and ASP.NET Core minimal APIs](https://devblogs.microsoft.com/dotnet/asp-net-core-aot-native/)  (verify URL)
- [Microsoft — RDG source](https://github.com/dotnet/aspnetcore/tree/main/src/Http/Http.Extensions/gen)
