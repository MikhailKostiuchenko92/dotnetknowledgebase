# Action Filters in ASP.NET Core

**Category:** ASP.NET Core / Filters
**Difficulty:** 🟡 Middle
**Tags:** `IActionFilter`, `IAsyncActionFilter`, `ActionExecutingContext`, `ActionExecutedContext`, `cross-cutting`

## Question

> How do you implement a reusable `IActionFilter` in ASP.NET Core? What can you do in `OnActionExecuting` vs `OnActionExecuted`, and how do you inject services into a filter?

## Short Answer

`IActionFilter` wraps MVC action execution — `OnActionExecuting` runs before the action (with access to arguments, allows short-circuiting by setting `context.Result`), and `OnActionExecuted` runs after (with access to the result or any thrown exception). To inject scoped/transient dependencies, use `TypeFilterAttribute` or `ServiceFilterAttribute` rather than constructor injection on attribute-based filters, because attribute instances are created once and live for the lifetime of the process.

## Detailed Explanation

### The two filter execution points

```
Request → [OnActionExecuting] → Action Method → [OnActionExecuted] → Result execution
```

#### `OnActionExecuting(ActionExecutingContext context)`

| Property | Type | Purpose |
|---|---|---|
| `context.ActionArguments` | `IDictionary<string, object?>` | Bound action parameters |
| `context.ActionDescriptor` | `ActionDescriptor` | Metadata about the action |
| `context.HttpContext` | `HttpContext` | Full request context |
| `context.ModelState` | `ModelStateDictionary` | Validation state |
| `context.Result` | `IActionResult?` | Set to short-circuit (skip action + result filters) |

Setting `context.Result` prevents the action from executing. Subsequent action filters' `OnActionExecuted` still fires with `context.Canceled = true`.

#### `OnActionExecuted(ActionExecutedContext context)`

| Property | Purpose |
|---|---|
| `context.Result` | The action's return value; can be replaced |
| `context.Exception` | Any unhandled exception from the action; set to `null` to suppress |
| `context.ExceptionHandled` | Set `true` to suppress exception (filter handles it) |
| `context.Canceled` | `true` if a preceding filter short-circuited |

### Async variant

Prefer `IAsyncActionFilter` when your filter does any I/O:

```csharp
public class MyFilter : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        // Pre-action logic
        var executed = await next(); // Execute the action
        // Post-action logic (executed.Result, executed.Exception)
    }
}
```

### Injecting services into filters

**❌ Wrong — field injection on an attribute (attribute is a singleton):**

```csharp
public class CacheFilter(IDistributedCache cache) : ActionFilterAttribute { }
// This causes IDistributedCache to be captured for the process lifetime
```

**✅ Use `TypeFilterAttribute` (resolves from DI per-request):**

```csharp
[TypeFilter(typeof(CacheFilter))]
public IActionResult Get() => Ok();
```

**✅ Use `ServiceFilterAttribute` (instance from DI — must be registered):**

```csharp
builder.Services.AddScoped<CacheFilter>();

[ServiceFilter(typeof(CacheFilter))]
public IActionResult Get() => Ok();
```

**✅ Preferred: factory attribute pattern (DI-friendly + typed):**

```csharp
public sealed class RequireScopeAttribute(string scope) : TypeFilterAttribute(typeof(RequireScopeFilter))
{
    public RequireScopeAttribute(string scope) : this(scope) =>
        Arguments = [scope];
}
```

## Code Example

```csharp
// AuditFilter.cs — log who called which action and what result they got
public sealed class AuditFilter(IAuditLogger auditLogger) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(
        ActionExecutingContext context,
        ActionExecutionDelegate next)
    {
        var user = context.HttpContext.User.Identity?.Name ?? "anonymous";
        var action = $"{context.RouteData.Values["controller"]}.{context.RouteData.Values["action"]}";

        var executed = await next();

        var statusCode = executed.Result switch
        {
            ObjectResult r => r.StatusCode,
            StatusCodeResult r => r.StatusCode,
            _ => null
        };

        await auditLogger.LogAsync(new AuditEntry(user, action, statusCode,
            executed.Exception?.Message));
    }
}
```

```csharp
// ValidateModelFilter.cs — DRY alternative to [ApiController] automatic 400
public sealed class ValidateModelFilter : IActionFilter
{
    public void OnActionExecuting(ActionExecutingContext context)
    {
        if (!context.ModelState.IsValid)
        {
            context.Result = new UnprocessableEntityObjectResult(context.ModelState);
        }
    }

    public void OnActionExecuted(ActionExecutedContext context) { }
}
```

```csharp
// Program.cs — register globally and per-controller
builder.Services.AddScoped<AuditFilter>();
builder.Services.AddControllers(opts =>
{
    opts.Filters.Add<ValidateModelFilter>(); // globally; ValidateModelFilter has no ctor deps
});

[ServiceFilter(typeof(AuditFilter))]  // per-controller, resolved from DI
[ApiController]
[Route("[controller]")]
public class OrdersController : ControllerBase
{
    [HttpPost]
    public Task<IActionResult> PlaceOrder(PlaceOrderRequest req) => ...;
}
```

## Common Follow-up Questions

- How do you access the HTTP response body in an action filter?
- What is the difference between short-circuiting in an action filter vs a resource filter?
- How does `ActionFilterAttribute` reduce boilerplate compared to implementing `IActionFilter` directly?
- When would you use `IResultFilter` instead of `IActionFilter.OnActionExecuted`?
- How do action filters interact with `[ApiController]` automatic model validation?

## Common Mistakes / Pitfalls

- **Injecting scoped services via constructor into a filter registered as global** — global filters are singletons; scoped dependencies will be captured. Use `IServiceProvider` + `CreateScope()` or `TypeFilterAttribute`/`ServiceFilterAttribute`.
- **Modifying `context.Result` in `OnActionExecuted` when `context.Exception` is set** — if the action threw, result may be null; check for null before accessing.
- **Assuming `OnActionExecuted` fires on exception** — it does fire (with `context.Exception` set), but if you want to suppress the exception, set `context.ExceptionHandled = true`. If you don't, the exception propagates to exception filters.
- **Using `ActionFilterAttribute` (sync) for async I/O** — calling `.GetAwaiter().GetResult()` causes deadlocks in ASP.NET Core. Always use `IAsyncActionFilter` for async work.
- **Registering the same filter both globally and per-controller** — it runs twice. Use `IOrderedFilter` and consistent registration strategy.

## References

- [Microsoft Learn — Action filters](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0#action-filters)
- [Microsoft Learn — Dependency injection in filter](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0#dependency-injection)
- [Andrew Lock — Deep dive into action filters](https://andrewlock.net/tag/action-filter/) (verify URL)
- [Microsoft — ActionFilterAttribute source](https://github.com/dotnet/aspnetcore/blob/main/src/Mvc/Mvc.Core/src/Filters/ActionFilterAttribute.cs)
