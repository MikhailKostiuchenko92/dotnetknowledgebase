# Filter DI and Registration in ASP.NET Core

**Category:** ASP.NET Core / Filters
**Difficulty:** 🟡 Middle
**Tags:** `TypeFilterAttribute`, `ServiceFilterAttribute`, `DI`, `filter-registration`, `IFilterFactory`

## Question

> What are the three ways to register a filter that depends on scoped or transient services in ASP.NET Core, and what are the trade-offs?

## Short Answer

Filters with DI dependencies can be registered via `TypeFilterAttribute` (resolves filter from DI per-request, does not require pre-registration), `ServiceFilterAttribute` (resolves a pre-registered filter instance from DI), or a custom `IFilterFactory` implementation (full control, recommended for reusable library filters). Avoid injecting scoped services via constructor on attribute-based filters — attributes are instantiated once by the CLR and live for the process lifetime, making them effectively singletons.

## Detailed Explanation

### The problem: attribute lifetime

```csharp
// ❌ WRONG — MyService is scoped, but the attribute is a singleton
public sealed class ValidateAttribute(MyService svc) : ActionFilterAttribute { }
```

Attributes are created once by the CLR metadata system. Constructor injection on an attribute produces a single instance shared across all requests — scoped services are captured and reused incorrectly.

### Option 1: `TypeFilterAttribute`

`TypeFilterAttribute` creates a new filter instance per-request using DI to resolve dependencies. The filter type does not need to be registered in the DI container.

```csharp
// The filter itself
public sealed class AuditFilter(IAuditService audit) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext ctx, ActionExecutionDelegate next)
    {
        var executed = await next();
        await audit.LogAsync(ctx.ActionDescriptor.DisplayName, ctx.HttpContext.User);
    }
}

// Usage — TypeFilterAttribute resolves AuditFilter from DI per-request
[TypeFilter(typeof(AuditFilter))]
public class OrdersController : ControllerBase { }
```

You can pass constructor arguments alongside DI dependencies:

```csharp
public sealed class RequireRoleFilter(string role, IAuthorizationService auth) : IAsyncActionFilter { ... }

[TypeFilter(typeof(RequireRoleFilter), Arguments = new object[] { "Admin" })]
public IActionResult GetAdminData() => Ok();
```

### Option 2: `ServiceFilterAttribute`

`ServiceFilterAttribute` resolves the filter instance from the DI container using the filter type as the key. The filter **must** be registered in DI.

```csharp
// Must register first
builder.Services.AddScoped<AuditFilter>();

// Usage
[ServiceFilter(typeof(AuditFilter))]
public class OrdersController : ControllerBase { }
```

| | `TypeFilterAttribute` | `ServiceFilterAttribute` |
|---|---|---|
| Filter pre-registration required | ❌ No | ✅ Yes |
| Lifetime | One per request | Controlled by DI registration |
| Supports extra ctor args | ✅ Via `Arguments` | ❌ No |
| Can be singleton | ✅ If designed safely | ✅ With `AddSingleton` |

### Option 3: `IFilterFactory`

For the most control (testability, reuse, library scenarios), implement `IFilterFactory`:

```csharp
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class RequireRoleAttribute(string role) : Attribute, IFilterFactory
{
    public bool IsReusable => false; // set true only if filter has no request-specific state

    public IFilterMetadata CreateInstance(IServiceProvider serviceProvider)
    {
        var authSvc = serviceProvider.GetRequiredService<IAuthorizationService>();
        return new RequireRoleFilter(role, authSvc);
    }
}
```

`IsReusable = true` tells ASP.NET Core it can cache and reuse the filter instance across requests — only safe if the filter has no mutable per-request state.

### Global filter registration

```csharp
builder.Services.AddControllers(opts =>
{
    opts.Filters.Add<AuditFilter>();             // resolves from DI; must be registered
    opts.Filters.Add(new ValidateModelFilter()); // instance; no DI (no ctor deps)
    opts.Filters.Add(typeof(AuditFilter));       // equivalent to Add<T>()
});
```

## Code Example

```csharp
// IFilterFactory pattern — cleanest DI approach for library-distributed filters
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class IdempotencyAttribute : Attribute, IFilterFactory
{
    public bool IsReusable => false;

    public IFilterMetadata CreateInstance(IServiceProvider serviceProvider) =>
        ActivatorUtilities.CreateInstance<IdempotencyFilter>(serviceProvider);
}

public sealed class IdempotencyFilter(
    IIdempotencyStore store,
    ILogger<IdempotencyFilter> logger) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(
        ActionExecutingContext ctx,
        ActionExecutionDelegate next)
    {
        var key = ctx.HttpContext.Request.Headers["X-Idempotency-Key"].ToString();
        if (string.IsNullOrEmpty(key))
        {
            await next();
            return;
        }

        if (await store.TryGetAsync(key) is { } cached)
        {
            logger.LogDebug("Idempotent reply for key {Key}", key);
            ctx.Result = cached;
            return;
        }

        var executed = await next();
        if (executed.Exception is null)
            await store.StoreAsync(key, executed.Result!);
    }
}
```

```csharp
// Controller usage
[Idempotency]
[HttpPost]
public async Task<IActionResult> PlaceOrder(PlaceOrderRequest req) { ... }
```

## Common Follow-up Questions

- What does `IFilterFactory.IsReusable` control, and when is it safe to set it `true`?
- How do you pass both a constructor argument and a DI service to the same filter using `TypeFilterAttribute`?
- What is `ActivatorUtilities.CreateInstance<T>` and how does it differ from `serviceProvider.GetService<T>()`?
- Can you mix global filter registration with per-controller `ServiceFilterAttribute`? What is the execution order?
- How do you unit-test a filter that implements `IFilterFactory`?

## Common Mistakes / Pitfalls

- **Injecting scoped services in filter attribute constructor** — attributes are singletons; use `TypeFilterAttribute`, `ServiceFilterAttribute`, or `IFilterFactory` to get correct lifetimes.
- **Registering a filter with `opts.Filters.Add<T>()` without a DI registration** — this throws a `InvalidOperationException` at runtime; always register the filter type with the container first.
- **Setting `IsReusable = true` on a filter that reads `HttpContext`** — `HttpContext` is per-request; reusing the filter instance causes data to bleed between requests.
- **Using `ActivatorUtilities.CreateInstance` vs `GetRequiredService`** — `CreateInstance` constructs a new instance each call (not from DI pool); `GetRequiredService` returns the registered instance (which could be singleton-shared).
- **Forgetting `Arguments` property ordering on `TypeFilterAttribute`** — extra constructor arguments via `Arguments` are matched positionally alongside DI-resolved parameters; mismatches throw at filter creation time.

## References

- [Microsoft Learn — ServiceFilterAttribute / TypeFilterAttribute](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0#servicefilterattribute)
- [Microsoft Learn — IFilterFactory](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0#ifilterfactory)
- [Microsoft — ActivatorUtilities source](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.DependencyInjection.Abstractions/src/ActivatorUtilities.cs)
- [Andrew Lock — Using DI in filters](https://andrewlock.net/tag/filters/) (verify URL)
