# Routing Fundamentals in ASP.NET Core

**Category:** ASP.NET Core / Routing
**Difficulty:** 🟢 Junior
**Tags:** `routing`, `attribute-routing`, `conventional-routing`, `route-templates`, `route-constraints`

## Question

> How does routing work in ASP.NET Core? What is the difference between conventional routing and attribute routing, and how do route constraints work?

## Short Answer

Routing matches an incoming request URL to an endpoint (controller action or minimal API handler). **Conventional routing** defines route patterns centrally via `MapControllerRoute(...)` templates using `{controller}/{action}/{id?}` conventions. **Attribute routing** places route templates directly on controllers and actions via `[Route]`, `[HttpGet]`, etc., giving finer-grained control. Route constraints (e.g., `{id:int}`, `{slug:minlength(3)}`) restrict which values a route segment will match.

## Detailed Explanation

### Routing pipeline phases

1. **`UseRouting()`** — matches the request to a registered endpoint (populates `IEndpointFeature`).
2. **Middleware** — auth, CORS, etc. can inspect the matched endpoint.
3. **`MapControllers()` / `MapGet()` etc.** — endpoint execution (runs matched handler).

In .NET 6+, `UseRouting()` is implicit when you call `MapControllers()`. Explicit `UseRouting()` is only required when you insert middleware between routing and execution.

### Conventional routing

Typically for MVC (Razor Pages/Views). Defined in `Program.cs`:

```csharp
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");
```

- `{controller=Home}` — controller segment, defaults to `Home`.
- `{action=Index}` — action segment, defaults to `Index`.
- `{id?}` — optional id segment.
- Maps `GET /products/details/42` → `ProductsController.Details(42)`.

Conventional routing is **order-sensitive** — routes are matched in declaration order.

### Attribute routing

Preferred for Web APIs. Route templates are attached to controllers and actions:

```csharp
[ApiController]
[Route("api/[controller]")]    // [controller] token → "Products"
public class ProductsController : ControllerBase
{
    [HttpGet]                  // GET /api/products
    public IActionResult GetAll() => Ok();

    [HttpGet("{id:int}")]       // GET /api/products/42 (id must be int)
    public IActionResult GetById(int id) => Ok();

    [HttpGet("search")]        // GET /api/products/search
    public IActionResult Search([FromQuery] string q) => Ok();
}
```

Tokens `[controller]`, `[action]`, `[area]` are replaced with the corresponding value at startup.

### Route constraints

Constraints restrict what a route segment will match:

| Constraint | Syntax | Example |
|---|---|---|
| Integer | `{id:int}` | `/products/42` |
| Long | `{id:long}` | `/items/9999999999` |
| GUID | `{id:guid}` | `/orders/abc-123...` |
| Min/max | `{age:min(18)}` | `/users/25` |
| String length | `{slug:minlength(3)}` | `/tags/net` |
| Regex | `{code:regex(^[A-Z]{3}$)}` | `/codes/USD` |
| Required | `{param:required}` | `/items/value` |
| Alphabetic | `{name:alpha}` | `/users/john` |

Multiple constraints: `{id:int:min(1)}` — id must be a positive integer.

Custom constraints implement `IRouteConstraint`.

### Route order and specificity

Attribute routes are matched by specificity (more specific wins):

```
GET /api/products/search    → [HttpGet("search")]  (literal wins over parameter)
GET /api/products/42        → [HttpGet("{id:int}")]
GET /api/products/foo       → if no int constraint, [HttpGet("{id}")] wins
```

For conventional routes, order of `MapControllerRoute` calls determines priority.

### Named routes and link generation

```csharp
[HttpGet("{id}", Name = "GetProduct")]
public IActionResult GetById(int id) => Ok();

// Elsewhere
var url = linkGenerator.GetPathByName("GetProduct", new { id = 42 }); // /api/products/42
```

## Code Example

```csharp
// ProductsController.cs — attribute routing
[ApiController]
[Route("api/v{version:apiVersion}/products")]
public class ProductsController : ControllerBase
{
    private readonly IProductService _service;

    public ProductsController(IProductService service) => _service = service;

    // GET /api/v1/products
    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] int page = 1, [FromQuery] int size = 20)
        => Ok(await _service.GetPagedAsync(page, size));

    // GET /api/v1/products/42
    [HttpGet("{id:int:min(1)}")]
    public async Task<IActionResult> GetById(int id)
    {
        var product = await _service.GetByIdAsync(id);
        return product is null ? NotFound() : Ok(product);
    }

    // GET /api/v1/products/by-slug/my-product
    [HttpGet("by-slug/{slug:minlength(3):maxlength(100)}")]
    public async Task<IActionResult> GetBySlug(string slug)
        => Ok(await _service.GetBySlugAsync(slug));

    // POST /api/v1/products
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateProductRequest req)
    {
        var product = await _service.CreateAsync(req);
        return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
    }
}
```

```csharp
// Program.cs — conventional route alongside attribute routes
app.MapControllerRoute(
    name: "admin",
    pattern: "admin/{controller=Dashboard}/{action=Index}/{id?}",
    defaults: new { area = "Admin" });

app.MapControllers(); // attribute-routed controllers
```

## Common Follow-up Questions

- How does route matching order differ between conventional and attribute routing?
- What is `[HttpGet("{id}")]` vs `[Route("{id}")]` — when does the HTTP method constraint matter?
- How do you create a custom `IRouteConstraint`?
- What is `LinkGenerator` and how does it differ from `IUrlHelper`?
- How does catch-all route parameters (`{*catchAll}`) work?

## Common Mistakes / Pitfalls

- **Mixing conventional and attribute routing on the same controller** — attribute routing takes precedence; conventional routes are ignored for attribute-routed controllers.
- **Using route constraints for input validation** — constraints only determine if a route matches; 400 validation should be done in model binding or action logic, not constraints.
- **Route tokens `[controller]` not matching expected names** — the token strips the `Controller` suffix. `ProductsController` → token `Products`. If you name it `ProductController`, the token becomes `Product`.
- **Overlapping routes with no disambiguation** — two `[HttpGet("{id}")]` on different actions in the same controller causes `AmbiguousMatchException` at runtime.
- **Expecting conventional routing to work for API controllers** — `[ApiController]` does not prevent conventional routing, but the default template `{controller}/{action}` may conflict with REST conventions.

## References

- [Microsoft Learn — Routing in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/routing?view=aspnetcore-8.0)
- [Microsoft Learn — Attribute routing for REST APIs](https://learn.microsoft.com/aspnet/core/mvc/controllers/routing?view=aspnetcore-8.0)
- [Microsoft Learn — Route constraints](https://learn.microsoft.com/aspnet/core/fundamentals/routing?view=aspnetcore-8.0#route-constraints)
- [Andrew Lock — Routing in ASP.NET Core](https://andrewlock.net/tag/routing/) (verify URL)
