# Endpoint Filters in ASP.NET Core (.NET 7+)

**Category:** ASP.NET Core / Routing
**Difficulty:** 🔴 Senior
**Tags:** `IEndpointFilter`, `endpoint-filters`, `minimal-api`, `filter-pipeline`, `factory-pattern`

## Question

> What are endpoint filters in ASP.NET Core minimal APIs (.NET 7+)? How do they differ from action filters, and how do you implement a factory-based endpoint filter?

## Short Answer

`IEndpointFilter` is the minimal API equivalent of MVC's `IActionFilter` — it wraps endpoint execution, allowing pre/post processing, short-circuiting, and exception handling without middleware. Unlike action filters (which operate on `ActionContext`), endpoint filters operate on `EndpointFilterInvocationContext` containing the raw handler arguments as `object[]`. Factory-based filters receive an `EndpointFilterFactoryContext` at registration time, enabling compile-time argument inspection and zero-cost wrappers when the filter is a no-op.

## Detailed Explanation

### `IEndpointFilter` interface

```csharp
public interface IEndpointFilter
{
    ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next);
}
```

- `context.Arguments` — the handler's positional arguments as `object?[]`.
- `context.HttpContext` — the current request context.
- Returns `object?` — the filter can modify or replace the endpoint's return value.
- Call `await next(context)` to invoke the next filter or the endpoint handler.

### Registering endpoint filters

```csharp
// On a single endpoint
app.MapGet("/products/{id}", GetProductById)
   .AddEndpointFilter<ValidationFilter>()
   .AddEndpointFilter<LoggingFilter>();

// On a group
var group = app.MapGroup("/api/v1")
    .AddEndpointFilter<AuthFilter>();
```

Filters run in **registration order** (outermost first), wrapping the handler like middleware.

### Filter execution order

```
Filter 1 (pre) → Filter 2 (pre) → Handler → Filter 2 (post) → Filter 1 (post)
```

### Accessing typed arguments

```csharp
public sealed class ValidationFilter<TRequest>(IValidator<TRequest> validator)
    : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext ctx,
        EndpointFilterDelegate next)
    {
        // Find the TRequest argument by type
        if (ctx.Arguments.OfType<TRequest>().FirstOrDefault() is { } request)
        {
            var result = await validator.ValidateAsync(request, ctx.HttpContext.RequestAborted);
            if (!result.IsValid)
                return TypedResults.ValidationProblem(result.ToDictionary());
        }

        return await next(ctx);
    }
}
```

### Factory-based filters (zero-cost when no-op)

The factory pattern lets the framework inspect the endpoint at registration time — if the filter has nothing to do for a particular handler, it returns `null` (no filter added):

```csharp
app.MapGet("/protected", GetProtectedData)
   .AddEndpointFilterFactory((context, next) =>
   {
       // context.MethodInfo is the handler's MethodInfo
       var hasAuthAttr = context.MethodInfo.GetCustomAttribute<RequireApiKeyAttribute>() is not null;

       if (!hasAuthAttr)
           return invocationCtx => next(invocationCtx); // no-op

       return async invocationCtx =>
       {
           var key = invocationCtx.HttpContext.Request.Headers["X-Api-Key"].ToString();
           if (!IsValidApiKey(key))
               return TypedResults.Unauthorized();
           return await next(invocationCtx);
       };
   });
```

### Endpoint filters vs action filters

| Aspect | `IEndpointFilter` | `IActionFilter` |
|---|---|---|
| API surface | Minimal APIs | MVC controllers |
| Context | `EndpointFilterInvocationContext` | `ActionExecutingContext` |
| Access to typed args | Via `Arguments[index]` / LINQ | Via `ActionArguments` dictionary |
| Access to `ActionDescriptor` | ❌ | ✅ |
| `ModelState` access | ❌ (use in constructor via DI) | ✅ |
| Result type | `object?` | `IActionResult` |
| Filter factory | `AddEndpointFilterFactory` | `TypeFilterAttribute` / `ServiceFilterAttribute` |

### Short-circuiting

```csharp
public async ValueTask<object?> InvokeAsync(
    EndpointFilterInvocationContext ctx,
    EndpointFilterDelegate next)
{
    if (!ctx.HttpContext.User.Identity?.IsAuthenticated ?? true)
        return TypedResults.Unauthorized(); // ← does NOT call next

    return await next(ctx);
}
```

## Code Example

```csharp
// IdempotencyFilter.cs — checks idempotency key before handler runs
public sealed class IdempotencyFilter(
    IIdempotencyStore store,
    ILogger<IdempotencyFilter> logger) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext ctx,
        EndpointFilterDelegate next)
    {
        var key = ctx.HttpContext.Request.Headers["X-Idempotency-Key"].ToString();

        if (string.IsNullOrEmpty(key))
            return await next(ctx); // no key — passthrough

        if (await store.TryGetResponseAsync(key) is { } cached)
        {
            logger.LogDebug("Returning cached response for idempotency key {Key}", key);
            return cached;
        }

        var result = await next(ctx);

        if (ctx.HttpContext.Response.StatusCode is >= 200 and < 300)
            await store.StoreResponseAsync(key, result, TimeSpan.FromHours(24));

        return result;
    }
}
```

```csharp
// Program.cs — applying filters globally via group + per-endpoint
var api = app.MapGroup("/api")
    .RequireAuthorization()
    .AddEndpointFilter<RequestLoggingFilter>(); // applied to all /api/* endpoints

var products = api.MapGroup("/products").WithTags("Products");

products.MapPost("/", async Task<Results<Created<Product>, ValidationProblem>>
    (CreateProductRequest req, IProductService svc, CancellationToken ct) =>
{
    var p = await svc.CreateAsync(req, ct);
    return TypedResults.Created($"/api/products/{p.Id}", p);
})
.AddEndpointFilter<ValidationFilter<CreateProductRequest>>()  // per-endpoint
.AddEndpointFilter<IdempotencyFilter>();                       // per-endpoint
```

```csharp
// Generic ValidationFilter with DI
public sealed class ValidationFilter<T>(IValidator<T> validator) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(
        EndpointFilterInvocationContext ctx,
        EndpointFilterDelegate next)
    {
        if (ctx.Arguments.OfType<T>().FirstOrDefault() is not { } model)
            return await next(ctx);

        var validation = await validator.ValidateAsync(model, ctx.HttpContext.RequestAborted);
        if (!validation.IsValid)
            return TypedResults.ValidationProblem(validation.ToDictionary());

        return await next(ctx);
    }
}
```

## Common Follow-up Questions

- How do you apply an endpoint filter to all endpoints globally (not just a group)?
- How does the factory-based filter pattern enable zero-overhead when the filter doesn't apply?
- Can endpoint filters be applied to controller actions? (No — use `IActionFilter` for controllers.)
- How do endpoint filters interact with `Results<T1, T2>` return types in OpenAPI schema generation?
- How do you unit-test an endpoint filter in isolation?

## Common Mistakes / Pitfalls

- **Using `ctx.Arguments[0]` hardcoded by index** — argument order can change if the handler signature changes. Use `OfType<T>()` or `GetArgument<T>(index)` carefully.
- **Expecting `ModelState` to be available in `IEndpointFilter`** — minimal APIs don't have `ModelState`. Perform validation explicitly via `IValidator<T>` or data annotations with `MiniValidator`.
- **Returning `null` from a filter** — returning `null` sends an empty 200 response. Return a concrete `IResult` or call `next(ctx)`.
- **Registering `IEndpointFilter` on a controller route** — `AddEndpointFilter<T>()` only works on minimal API endpoints. Controller filters use `[ServiceFilter]` or `MvcOptions.Filters`.
- **Filter order confusion** — filters registered via `MapGroup(...).AddEndpointFilter` run before filters added on individual endpoints. The group filter is the outer wrapper.

## References

- [Microsoft Learn — Endpoint filters (.NET 7+)](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/min-api-filters?view=aspnetcore-8.0)
- [Microsoft Learn — Endpoint filter factory](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/min-api-filters?view=aspnetcore-8.0#register-a-filter-using-an-endpoint-filter-factory)
- [Andrew Lock — Endpoint filters in .NET 7](https://andrewlock.net/tag/minimal-api/) (verify URL)
- [Microsoft — IEndpointFilter source](https://github.com/dotnet/aspnetcore/blob/main/src/Http/Http.Abstractions/src/IEndpointFilter.cs)
