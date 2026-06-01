# Action Results and IResult

**Category:** ASP.NET Core / Routing
**Difficulty:** 🟢 Junior
**Tags:** `IActionResult`, `IResult`, `TypedResults`, `minimal-api`, `content-negotiation`, `status-codes`

## Question

> What is the difference between `IActionResult` (MVC/controllers) and `IResult` (minimal APIs)? What are `TypedResults` and why are they preferred?

## Short Answer

`IActionResult` is the controller-pipeline result abstraction used in MVC/Web API controllers — it supports content negotiation, formatters, and response metadata. `IResult` is the minimal API result abstraction introduced in .NET 6, simpler and optimized for direct HTTP writing. `TypedResults` (added in .NET 7) are a static factory class that returns concrete result types (e.g., `TypedResults.Ok<T>()`) instead of the `IResult` interface, enabling accurate OpenAPI/Swagger schema generation and compile-time type safety.

## Detailed Explanation

### `IActionResult` in controllers

```csharp
public IActionResult GetById(int id)
{
    var product = _service.Get(id);
    if (product is null) return NotFound();                // 404
    return Ok(product);                                    // 200 + content negotiation
}
```

`ControllerBase` helper methods return implementations of `IActionResult`:
- `Ok(obj)` → `OkObjectResult` (200)
- `NotFound()` → `NotFoundResult` (404)
- `BadRequest(err)` → `BadRequestObjectResult` (400)
- `Created(uri, obj)` → `CreatedResult` (201)
- `CreatedAtAction(action, routeValues, obj)` → `CreatedAtActionResult` (201)
- `NoContent()` → `NoContentResult` (204)
- `StatusCode(code, obj)` → `ObjectResult`
- `Problem(...)` → `ObjectResult` with `ProblemDetails` body

Content negotiation: MVC inspects the `Accept` header and uses `IOutputFormatter` chain to serialize the response (JSON, XML, etc.).

### `IResult` in minimal APIs

```csharp
app.MapGet("/products/{id}", async (int id, IProductService svc) =>
{
    var product = await svc.GetByIdAsync(id);
    return product is null ? Results.NotFound() : Results.Ok(product);
});
```

`Results` static class returns `IResult` implementations:
- `Results.Ok(obj)` — 200 with JSON body
- `Results.NotFound()` — 404
- `Results.Created(uri, obj)` — 201
- `Results.BadRequest(err)` — 400
- `Results.NoContent()` — 204
- `Results.Problem(...)` — RFC 9457 ProblemDetails
- `Results.Json(obj, options)` — 200 with custom serializer options
- `Results.File(path)` — file response

### `TypedResults` vs `Results` (.NET 7+)

`Results.Ok(product)` returns `IResult` — OpenAPI generators cannot infer the response schema because the type is erased. `TypedResults.Ok(product)` returns `Ok<Product>` — the concrete type carries the schema information.

```csharp
// Results — schema unknown to OpenAPI
app.MapGet("/{id}", (int id) => Results.Ok(new Product()));
// OpenAPI shows response type: unknown

// TypedResults — schema known
app.MapGet("/{id}", (int id) => TypedResults.Ok(new Product()));
// OpenAPI shows response type: Product ✅
```

| | `Results.*` | `TypedResults.*` |
|---|---|---|
| Return type | `IResult` | Concrete (`Ok<T>`, `NotFound`, etc.) |
| OpenAPI schema | ❌ Type-erased | ✅ Type-inferred |
| Testability | Interface mock needed | Direct assertion on concrete type |
| Available since | .NET 6 | .NET 7 |

### Returning multiple result types — union types

```csharp
// Annotate for OpenAPI (controller style)
[ProducesResponseType<Product>(200)]
[ProducesResponseType(404)]
public async Task<IActionResult> GetById(int id) { ... }

// Minimal API — use Results<T1, T2> union type (.NET 7+)
app.MapGet("/{id}", async (int id, IProductService svc)
    : Task<Results<Ok<Product>, NotFound>> =>
{
    var product = await svc.GetByIdAsync(id);
    return product is null ? TypedResults.NotFound() : TypedResults.Ok(product);
});
```

`Results<TOk, TNotFound>` is a discriminated union that carries OpenAPI metadata automatically.

## Code Example

```csharp
// Controller — IActionResult with content negotiation
[ApiController, Route("api/products")]
public class ProductsController(IProductService service) : ControllerBase
{
    [HttpGet("{id:int}")]
    [ProducesResponseType<Product>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetById(int id)
    {
        var product = await service.GetByIdAsync(id);
        return product is null ? NotFound() : Ok(product);
    }

    [HttpPost]
    [ProducesResponseType<Product>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create([FromBody] CreateProductRequest request)
    {
        var product = await service.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
    }
}
```

```csharp
// Minimal API — TypedResults with Results<> union for full OpenAPI
var products = app.MapGroup("/api/products").WithTags("Products");

products.MapGet("/{id:int}", async Task<Results<Ok<Product>, NotFound>>
    (int id, IProductService service) =>
{
    var product = await service.GetByIdAsync(id);
    return product is null ? TypedResults.NotFound() : TypedResults.Ok(product);
})
.WithName("GetProductById")
.WithSummary("Get a product by ID");

products.MapPost("/", async Task<Results<Created<Product>, ValidationProblem>>
    (CreateProductRequest req, IProductService service) =>
{
    if (!MiniValidator.TryValidate(req, out var errors))
        return TypedResults.ValidationProblem(errors);

    var product = await service.CreateAsync(req);
    return TypedResults.Created($"/api/products/{product.Id}", product);
});
```

## Common Follow-up Questions

- How does content negotiation work in controllers — what happens when the client sends `Accept: application/xml`?
- What is `ProblemDetails` and how do you return it from both controllers and minimal APIs?
- How do `Results<T1, T2>` union types work with OpenAPI — do they generate a `oneOf` schema?
- How do you return a file (binary) response from a controller vs minimal API?
- How do you unit-test an action that returns `IActionResult` — what do you assert on?

## Common Mistakes / Pitfalls

- **Using `Results.Ok()` instead of `TypedResults.Ok()` in minimal APIs** — loses OpenAPI schema information; Swagger shows `{}` instead of the actual type.
- **Returning 200 OK for a created resource instead of 201 Created** — REST convention requires 201 for POST that creates a resource, with a `Location` header pointing to the new resource.
- **Mixing `IActionResult` and primitive returns in the same controller action** — `[ApiController]` wraps primitive returns in 200 OK, but this is inconsistent; be explicit.
- **Not using `CreatedAtAction` for 201 responses** — manually constructing `Created(url, obj)` with hard-coded URLs breaks when the route changes; `CreatedAtAction` generates the URL from route metadata.
- **Forgetting `[ProducesResponseType]` attributes** — OpenAPI/Swagger cannot infer all possible response types; document them explicitly on controller actions.

## References

- [Microsoft Learn — Action results in controller-based APIs](https://learn.microsoft.com/aspnet/core/web-api/action-return-types?view=aspnetcore-8.0)
- [Microsoft Learn — TypedResults (.NET 7+)](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/responses?view=aspnetcore-8.0#typedresults-vs-results)
- [Microsoft Learn — Results\<T1, T2\> union types](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/responses?view=aspnetcore-8.0#resultsttypedresults)
- [Andrew Lock — TypedResults in minimal APIs](https://andrewlock.net/tag/minimal-api/) (verify URL)
- [RFC 9457 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457)
