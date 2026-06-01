# Minimal API Routing

**Category:** ASP.NET Core / Routing
**Difficulty:** 🟡 Middle
**Tags:** `minimal-api`, `MapGet`, `RouteGroupBuilder`, `endpoint-metadata`, `IEndpointRouteBuilder`

## Question

> How does routing work in minimal APIs? What is `RouteGroupBuilder` and how do you organize endpoints with it?

## Short Answer

Minimal APIs register endpoints via `MapGet`, `MapPost`, `MapPut`, `MapDelete`, and `MapMethods` directly on `WebApplication` (which implements `IEndpointRouteBuilder`). `RouteGroupBuilder`, returned by `app.MapGroup(prefix)`, lets you apply a common route prefix, metadata (tags, auth requirements, CORS policies, filters), and endpoint conventions to a group of endpoints without repeating code on each one.

## Detailed Explanation

### Basic endpoint registration

```csharp
app.MapGet("/products",      handler);    // GET  /products
app.MapPost("/products",     handler);    // POST /products
app.MapPut("/products/{id}", handler);    // PUT  /products/42
app.MapDelete("/products/{id}", handler); // DELETE /products/42
app.MapMethods("/products/{id}", ["PATCH"], handler); // PATCH
```

The `handler` is a delegate — lambda, local function, or static method. Parameters are bound from route, query, body, headers, or DI depending on their type and binding attributes.

### `MapGroup` — route prefix and shared metadata

```csharp
var productsGroup = app.MapGroup("/api/products")
    .WithTags("Products")               // Swagger tag for all endpoints in group
    .RequireAuthorization()             // auth policy applied to all
    .WithOpenApi();                     // auto-generate OpenAPI descriptions

productsGroup.MapGet("/", GetAllProducts);
productsGroup.MapGet("/{id:int}", GetProductById);
productsGroup.MapPost("/", CreateProduct);
productsGroup.MapDelete("/{id:int}", DeleteProduct);
```

Without `MapGroup`, each endpoint would need `.RequireAuthorization().WithTags("Products")` individually.

### Nested groups

```csharp
var api = app.MapGroup("/api").RequireAuthorization(); // base auth

var v1 = api.MapGroup("/v1");
var products = v1.MapGroup("/products").WithTags("Products");
var orders = v1.MapGroup("/orders").WithTags("Orders");

products.MapGet("/", GetAll);
orders.MapGet("/", GetAllOrders);
// Resulting routes: GET /api/v1/products, GET /api/v1/orders
```

### Endpoint metadata and conventions

Fluent methods on endpoints or groups add metadata:

```csharp
app.MapGet("/products/{id}", GetById)
    .WithName("GetProductById")          // route name (for link generation)
    .WithSummary("Get a product by ID")  // Swagger summary
    .WithDescription("Returns the full product details") // Swagger description
    .Produces<Product>(200)              // OpenAPI response metadata
    .Produces(404)
    .RequireCors("MyPolicy")
    .RequireRateLimiting("fixed")        // .NET 7+ rate limiting
    .AddEndpointFilter<ValidationFilter>()
    .CacheOutput(p => p.Expire(TimeSpan.FromMinutes(5))); // output caching
```

### `IEndpointRouteBuilder` — extension point

Library authors extend `IEndpointRouteBuilder` with extension methods:

```csharp
public static IEndpointRouteBuilder MapProductsApi(this IEndpointRouteBuilder routes)
{
    var group = routes.MapGroup("/products");
    group.MapGet("/", GetAll);
    group.MapPost("/", Create);
    return routes;
}

// Usage
app.MapProductsApi(); // clean Program.cs
```

This is the minimal API equivalent of feature-based controller registration.

### Organizing endpoints in separate files

```csharp
// ProductEndpoints.cs
public static class ProductEndpoints
{
    public static IEndpointRouteBuilder MapProductEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/products").WithTags("Products");
        group.MapGet("/",       GetAll);
        group.MapGet("/{id:int}", GetById);
        group.MapPost("/",      Create);
        group.MapPut("/{id:int}", Update);
        group.MapDelete("/{id:int}", Delete);
        return app;
    }

    private static async Task<IResult> GetAll(IProductService svc) =>
        TypedResults.Ok(await svc.GetAllAsync());

    private static async Task<Results<Ok<Product>, NotFound>> GetById(
        int id, IProductService svc)
    {
        var p = await svc.GetByIdAsync(id);
        return p is null ? TypedResults.NotFound() : TypedResults.Ok(p);
    }

    // ... other handlers
}
```

```csharp
// Program.cs
app.MapProductEndpoints();
app.MapOrderEndpoints();
```

## Code Example

```csharp
// Full minimal API example with versioned groups and filters

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthorization();
builder.Services.AddScoped<IProductService, ProductService>();

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();

// Public endpoints — no auth required
var public_ = app.MapGroup("/api");

public_.MapGet("/health", () => TypedResults.Ok("healthy"))
    .WithTags("Health")
    .AllowAnonymous();

// V1 API — authentication required for all
var v1 = app.MapGroup("/api/v1").RequireAuthorization();

// Products sub-group
var products = v1.MapGroup("/products")
    .WithTags("Products")
    .WithOpenApi();

products.MapGet("/", async (IProductService svc, CancellationToken ct)
    : Task<Ok<IReadOnlyList<Product>>> =>
{
    var list = await svc.GetAllAsync(ct);
    return TypedResults.Ok(list);
});

products.MapGet("/{id:int}", async Task<Results<Ok<Product>, NotFound>>
    (int id, IProductService svc, CancellationToken ct) =>
{
    var p = await svc.GetByIdAsync(id, ct);
    return p is null ? TypedResults.NotFound() : TypedResults.Ok(p);
})
.WithName("GetProduct");

products.MapPost("/", async Task<Results<Created<Product>, ValidationProblem>>
    (CreateProductRequest req, IProductService svc, CancellationToken ct) =>
{
    var product = await svc.CreateAsync(req, ct);
    return TypedResults.Created($"/api/v1/products/{product.Id}", product);
})
.AddEndpointFilter<ValidationFilter<CreateProductRequest>>();

app.Run();
```

## Common Follow-up Questions

- How do you apply a global `IEndpointFilter` to all endpoints without calling `AddEndpointFilter` on each?
- How do `MapGroup` metadata propagate — can a child endpoint override a group-level policy?
- How do you test minimal API endpoints in isolation without starting the full web server?
- What is the difference between `WithName` and route template names for link generation?
- How do minimal APIs handle parameter binding for complex types (records, custom types)?

## Common Mistakes / Pitfalls

- **Not calling `.RequireAuthorization()` at the group level and applying it per-endpoint** — easy to miss an endpoint. Apply auth at the highest-level group and use `.AllowAnonymous()` for exceptions.
- **Using `Results.Ok()` instead of `TypedResults.Ok()` in route handlers** — loses OpenAPI schema inference.
- **Defining endpoint handlers as lambdas directly in `Program.cs`** — fine for demos, but for production apps use static methods in separate files for testability and readability.
- **Forgetting to add `app.UseAuthorization()` when using `.RequireAuthorization()`** — the middleware must be in the pipeline for the requirement to be enforced.
- **Route prefix collision with `MapGroup`** — if both the group prefix and the endpoint pattern start with `/`, paths may double up. `MapGroup("/api")` + `MapGet("/products")` → `/api/products` (correct); `MapGet("products")` without leading slash also works.

## References

- [Microsoft Learn — Minimal APIs routing](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/route-handlers?view=aspnetcore-8.0)
- [Microsoft Learn — Route groups](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/route-handlers?view=aspnetcore-8.0#route-groups)
- [Andrew Lock — Minimal API routing and groups](https://andrewlock.net/tag/minimal-api/) (verify URL)
- [Microsoft — IEndpointRouteBuilder source](https://github.com/dotnet/aspnetcore/blob/main/src/Http/Routing/src/IEndpointRouteBuilder.cs)
