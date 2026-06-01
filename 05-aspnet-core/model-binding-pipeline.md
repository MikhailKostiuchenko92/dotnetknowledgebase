# Model Binding Pipeline

**Category:** ASP.NET Core / Routing
**Difficulty:** 🟡 Middle
**Tags:** `model-binding`, `FromBody`, `FromQuery`, `FromRoute`, `FromHeader`, `FromForm`, `binding-source`

## Question

> How does the ASP.NET Core model binding pipeline work? What is the difference between `[FromBody]`, `[FromQuery]`, `[FromRoute]`, `[FromHeader]`, and `[FromForm]`, and what is the default binding order?

## Short Answer

Model binding maps incoming HTTP request data to action method parameters. Without explicit attributes, the framework infers the source based on parameter type and route template. The explicit binding source attributes — `[FromBody]`, `[FromQuery]`, `[FromRoute]`, `[FromHeader]`, `[FromForm]`, `[FromServices]` — override inference and pin the parameter to a specific source. Only one `[FromBody]` parameter is allowed per action; it reads the entire request body.

## Detailed Explanation

### Binding sources

| Attribute | Source | Notes |
|---|---|---|
| `[FromBody]` | Request body (JSON/XML) | Deserializes entire body; one per action |
| `[FromQuery]` | URL query string `?key=value` | Always string-based; framework coerces |
| `[FromRoute]` | URL route segment `{id}` | Must match route template segment name |
| `[FromHeader]` | HTTP request header | Name defaults to parameter name |
| `[FromForm]` | `application/x-www-form-urlencoded` or `multipart/form-data` | Supports `IFormFile` |
| `[FromServices]` | DI container | Injected from `HttpContext.RequestServices` |
| `[FromKeyedServices(key)]` | Keyed DI (.NET 8+) | Keyed service resolution |

### Default inference rules (with `[ApiController]`)

`[ApiController]` enables binding source inference — explicit attributes are often not needed:

| Parameter type | Inferred source |
|---|---|
| Complex type (class/record) | `[FromBody]` |
| `IFormFile` / `IFormFileCollection` | `[FromForm]` |
| Matches a route segment name | `[FromRoute]` |
| Everything else (simple types) | `[FromQuery]` |
| `CancellationToken`, `HttpContext`, etc. | Special binding (not a user parameter) |

Without `[ApiController]`, the default binding order for simple types is: Form → Route → Query.

### `[FromBody]` — JSON deserialization

```csharp
[HttpPost]
public IActionResult Create([FromBody] CreateProductRequest request)
{
    // request is deserialized from the JSON body
    // Uses System.Text.Json by default; Newtonsoft.Json if AddNewtonsoftJson() configured
}
```

- Only one `[FromBody]` per action (reading the body twice is not supported without buffering).
- For empty body, the parameter is `null` for reference types (or model validation error if required).

### `[FromQuery]` — query parameters

```csharp
// GET /products?page=2&size=10&sort=name
[HttpGet]
public IActionResult Get(
    [FromQuery] int page = 1,
    [FromQuery] int size = 20,
    [FromQuery] string? sort = null) { ... }
```

Complex types with `[FromQuery]`:
```csharp
// Binds ?minPrice=10&maxPrice=100&categories=electronics&categories=books
[HttpGet]
public IActionResult Filter([FromQuery] ProductFilterRequest filter) { ... }

public record ProductFilterRequest(
    decimal? MinPrice,
    decimal? MaxPrice,
    string[] Categories); // array bound from repeated key
```

### `[FromRoute]` — route parameters

```csharp
// GET /api/categories/5/products/42
[HttpGet("categories/{categoryId}/products/{productId}")]
public IActionResult GetProduct(
    [FromRoute] int categoryId,
    [FromRoute] int productId) { ... }
```

### `[FromHeader]` — request headers

```csharp
[HttpPost]
public IActionResult Process(
    [FromHeader(Name = "X-Correlation-Id")] string? correlationId,
    [FromHeader(Name = "X-Tenant-Id")] Guid tenantId,
    [FromBody] ProcessRequest request) { ... }
```

### `[FromForm]` — form data and file uploads

```csharp
[HttpPost("upload")]
public async Task<IActionResult> Upload(
    [FromForm] string title,
    [FromForm] IFormFile file,
    CancellationToken ct)
{
    using var stream = file.OpenReadStream();
    await _storage.SaveAsync(file.FileName, stream, ct);
    return Ok();
}
```

### Disabling inference for a parameter

```csharp
// [ApiController] would infer Product from body — suppress with [FromQuery]
[HttpPost]
public IActionResult CreateBatch([FromQuery] bool dryRun, [FromBody] Product[] products) { ... }
```

## Code Example

```csharp
// OrdersController.cs — mixed binding sources
[ApiController]
[Route("api/orders")]
public class OrdersController(IOrderService service) : ControllerBase
{
    // GET /api/orders?status=Pending&page=1&size=20
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] OrderStatus? status,
        [FromQuery] int page = 1,
        [FromQuery] int size = 20,
        CancellationToken ct = default)
        => Ok(await service.GetPagedAsync(status, page, size, ct));

    // GET /api/orders/42
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(
        [FromRoute] int id,                       // explicit (redundant with inference)
        [FromHeader(Name = "X-Include-Items")] bool includeItems = false,
        CancellationToken ct = default)
    {
        var order = await service.GetByIdAsync(id, includeItems, ct);
        return order is null ? NotFound() : Ok(order);
    }

    // POST /api/orders
    [HttpPost]
    public async Task<IActionResult> Create(
        [FromBody] CreateOrderRequest request,    // JSON body
        [FromHeader(Name = "X-Idempotency-Key")] string? idempotencyKey,
        CancellationToken ct = default)
    {
        var order = await service.CreateAsync(request, idempotencyKey, ct);
        return CreatedAtAction(nameof(GetById), new { id = order.Id }, order);
    }

    // POST /api/orders/42/documents — multipart form upload
    [HttpPost("{id:int}/documents")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UploadDocument(
        int id,
        [FromForm] string documentType,
        [FromForm] IFormFile document,
        CancellationToken ct = default)
    {
        await service.AttachDocumentAsync(id, documentType, document, ct);
        return NoContent();
    }
}
```

## Common Follow-up Questions

- What happens when `[ApiController]` inference gets it wrong — how do you override it?
- How does model binding work with arrays and collections in query strings?
- What is the binding order when `[ApiController]` is NOT present?
- How do you bind a custom complex type from a query string (e.g., a date range)?
- How does `[FromServices]` differ from constructor injection in controllers?

## Common Mistakes / Pitfalls

- **Multiple `[FromBody]` parameters** — throws `InvalidOperationException` at startup. Only one body parameter per action.
- **Using `[FromBody]` for simple types in minimal APIs** — `[FromBody]` on a `string` reads the raw body string, not a JSON-encoded string. Be explicit.
- **Forgetting `[FromQuery]` on a complex type** — without `[ApiController]`, complex types default to `[FromBody]`. With `[ApiController]`, complex types default to `[FromBody]` too — you must add `[FromQuery]` explicitly to bind a complex object from the query string.
- **Case sensitivity in header binding** — HTTP header names are case-insensitive, but the `Name` property in `[FromHeader(Name = "x-custom")]` must match how the header is sent (framework normalizes to camel-case in some cases).
- **`IFormFile` with `[FromBody]` content type** — `[FromBody]` expects JSON; `IFormFile` requires `multipart/form-data`. Use `[FromForm]` for file uploads.

## References

- [Microsoft Learn — Model binding in ASP.NET Core](https://learn.microsoft.com/aspnet/core/mvc/models/model-binding?view=aspnetcore-8.0)
- [Microsoft Learn — Binding source inference with [ApiController]](https://learn.microsoft.com/aspnet/core/web-api/?view=aspnetcore-8.0#binding-source-parameter-inference)
- [Microsoft Learn — File uploads in ASP.NET Core](https://learn.microsoft.com/aspnet/core/mvc/models/file-uploads?view=aspnetcore-8.0)
- [Andrew Lock — Model binding deep dive](https://andrewlock.net/tag/model-binding/) (verify URL)
