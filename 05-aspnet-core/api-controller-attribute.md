# `[ApiController]` Attribute in ASP.NET Core

**Category:** ASP.NET Core / Web API Design
**Difficulty:** 🟡 Middle
**Tags:** `ApiController`, `automatic-400`, `binding-inference`, `ProblemDetails`, `model-validation`

## Question

> What features does the `[ApiController]` attribute enable in ASP.NET Core? What is "automatic HTTP 400 response" and how does it work?

## Short Answer

`[ApiController]` enables four convenience features: **automatic HTTP 400 responses** when `ModelState.IsValid` is false (before the action even executes), **binding source inference** (`[FromBody]` inferred for complex types, `[FromRoute]` for route params, `[FromQuery]` for primitives), **multipart/form-data inference** for `IFormFile`/`IFormFileCollection`, and **problem details response** in the standard RFC 9457 format. These features reduce boilerplate but introduce implicit behavior that must be understood to avoid surprises.

## Detailed Explanation

### Automatic HTTP 400 response

Without `[ApiController]`, you manually check:

```csharp
[HttpPost]
public IActionResult Create(CreateRequest req)
{
    if (!ModelState.IsValid)
        return BadRequest(ModelState);
    // ...
}
```

With `[ApiController]`, a `ModelStateInvalidFilter` is automatically added to the filter pipeline. If `ModelState.IsValid` is `false` after model binding, the filter **short-circuits** with a `ValidationProblemDetails` response (HTTP 400) — the action method never runs.

The response body follows RFC 9457 problem details format:

```json
{
  "type": "https://tools.ietf.org/html/rfc9457",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "Name": ["The Name field is required."],
    "Price": ["The field Price must be between 0 and 1000000."]
  }
}
```

### Binding source inference

`[ApiController]` applies `InferParameterBindingInfoConvention` which infers binding attributes:

| Parameter type | Inferred source | Example |
|---|---|---|
| Complex type (class/record) | `[FromBody]` (one per action max) | `CreateRequest req` |
| Route segment name match | `[FromRoute]` | `int id` when route has `{id}` |
| Simple type, no route match | `[FromQuery]` | `string? filter` |
| `IFormFile` / `IFormFileCollection` | `[FromForm]` | `IFormFile file` |
| `CancellationToken` | From `HttpContext` | `CancellationToken ct` |
| `IFormCollection` | `[FromForm]` | `IFormCollection form` |

> **Warning:** If an action has multiple complex parameters, inference breaks — only the first is inferred as `[FromBody]`. Explicitly annotate the others with `[FromQuery]`, `[FromRoute]`, etc.

### Customizing the automatic 400 response

You can override the response factory via `ApiBehaviorOptions`:

```csharp
builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(opts =>
    {
        opts.InvalidModelStateResponseFactory = context =>
        {
            var errors = context.ModelState
                .Where(e => e.Value?.Errors.Count > 0)
                .ToDictionary(
                    e => e.Key,
                    e => e.Value!.Errors.Select(x => x.ErrorMessage).ToArray());

            return new UnprocessableEntityObjectResult(new
            {
                Title = "Validation failed",
                Errors = errors,
                TraceId = context.HttpContext.TraceIdentifier
            });
        };
    });
```

### Disabling individual features

```csharp
builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(opts =>
    {
        opts.SuppressModelStateInvalidFilter = true;           // disable auto-400
        opts.SuppressInferBindingSourcesForParameters = true;  // disable inference
        opts.SuppressConsumesConstraintForFormFileParameters = true;
        opts.SuppressMapClientErrors = true;                    // disable ProblemDetails for 4xx
    });
```

### Applying `[ApiController]` at assembly level

```csharp
[assembly: ApiController] // applies to all controllers in the assembly
```

### `[ApiController]` vs `ControllerBase`

`[ApiController]` is an **attribute** that configures behavior; `ControllerBase` is the **base class** providing helper methods (`Ok()`, `NotFound()`, `CreatedAtAction()`, etc.). You need both:

```csharp
[ApiController]
[Route("[controller]")]
public class ProductsController : ControllerBase { }
```

## Code Example

```csharp
public sealed record CreateProductRequest(
    [Required, MaxLength(200)] string Name,
    [Range(0.01, 1_000_000)] decimal Price,
    [Required] string CategoryId);

[ApiController]
[Route("api/[controller]")]
public class ProductsController(IProductService svc) : ControllerBase
{
    // With [ApiController]:
    // 1. If Name/Price/CategoryId fail DataAnnotations → automatic HTTP 400 before method runs
    // 2. 'req' inferred as [FromBody] (complex type)
    // 3. 'ct' inferred from HttpContext
    [HttpPost]
    public async Task<ActionResult<Product>> Create(
        CreateProductRequest req,
        CancellationToken ct)
    {
        var product = await svc.CreateAsync(req, ct);
        return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
    }

    // 'id' inferred as [FromRoute] (matches route segment)
    // 'includeDeleted' inferred as [FromQuery]
    [HttpGet("{id}")]
    public async Task<ActionResult<Product>> GetById(
        int id,
        bool includeDeleted = false,
        CancellationToken ct = default)
        => await svc.GetByIdAsync(id, includeDeleted, ct) is { } p ? Ok(p) : NotFound();
}
```

```csharp
// Customized problem details factory
builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(opts =>
    {
        opts.InvalidModelStateResponseFactory = ctx =>
        {
            var pd = new ValidationProblemDetails(ctx.ModelState)
            {
                Status = StatusCodes.Status422UnprocessableEntity,
                Instance = ctx.HttpContext.Request.Path
            };
            pd.Extensions["traceId"] = ctx.HttpContext.TraceIdentifier;
            return new UnprocessableEntityObjectResult(pd)
            {
                ContentTypes = { "application/problem+json" }
            };
        };
    });
```

## Common Follow-up Questions

- How does `[ApiController]` interact with FluentValidation replacing DataAnnotations validation?
- What is `ApiBehaviorOptions.ClientErrorMapping` and how does it customize 4xx responses?
- Can you apply `[ApiController]` to a base controller class so all derived controllers inherit it?
- What happens when two complex type parameters exist on an action — how does binding inference resolve?
- How does the automatic 400 response behave when `SuppressModelStateInvalidFilter = true`?

## Common Mistakes / Pitfalls

- **Suppressing `[ApiController]` validation to return a custom format, then forgetting to re-add validation** — if `SuppressModelStateInvalidFilter = true`, you must manually check `ModelState.IsValid`.
- **Having two `[FromBody]` complex parameters on one action** — binding inference only applies `[FromBody]` to the first; the second must be explicitly decorated, otherwise a binding error occurs at startup.
- **Returning `BadRequest(ModelState)` when `[ApiController]` is applied** — the filter already returned the 400 before your action ran; this code is unreachable unless you suppress the filter.
- **Applying `[ApiController]` to a controller inheriting `Controller` (not `ControllerBase`)** — `Controller` includes View support; for pure Web API use `ControllerBase` to avoid unnecessary MVC View machinery.
- **Confusing `[ApiController]` response format with `AddProblemDetails()`** — `[ApiController]` produces `ValidationProblemDetails`; `AddProblemDetails()` in middleware enriches generic error responses. They complement each other.

## References

- [Microsoft Learn — [ApiController] attribute](https://learn.microsoft.com/aspnet/core/web-api/?view=aspnetcore-8.0#apicontroller-attribute)
- [Microsoft Learn — Automatic HTTP 400 responses](https://learn.microsoft.com/aspnet/core/web-api/?view=aspnetcore-8.0#automatic-http-400-responses)
- [Microsoft Learn — Binding source parameter inference](https://learn.microsoft.com/aspnet/core/web-api/?view=aspnetcore-8.0#binding-source-parameter-inference)
- [Microsoft — ApiBehaviorOptions source](https://github.com/dotnet/aspnetcore/blob/main/src/Mvc/Mvc.Core/src/ApiBehaviorOptions.cs)
