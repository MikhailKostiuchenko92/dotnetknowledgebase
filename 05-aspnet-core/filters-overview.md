# Filters Overview in ASP.NET Core

**Category:** ASP.NET Core / Filters
**Difficulty:** 🟢 Junior
**Tags:** `filters`, `IActionFilter`, `IAuthorizationFilter`, `IExceptionFilter`, `IResultFilter`, `IResourceFilter`, `pipeline`

## Question

> What are the different filter types in ASP.NET Core MVC? In what order do they execute?

## Short Answer

ASP.NET Core MVC has five filter types, each running at a different stage of the action pipeline: **Authorization** filters run first; **Resource** filters run before model binding; **Action** filters wrap action execution; **Exception** filters catch unhandled exceptions within the MVC pipeline; **Result** filters wrap result execution. They run in registration scope order (global → controller → action) and can short-circuit at any stage.

## Detailed Explanation

### Filter types and execution order

```
Request
  │
  ▼
[1] Authorization Filter       IAuthorizationFilter / IAsyncAuthorizationFilter
  │
  ▼
[2] Resource Filter (Before)   IResourceFilter.OnResourceExecuting / IAsyncResourceFilter
  │
  ▼
[3] Model Binding
  │
  ▼
[4] Action Filter (Before)     IActionFilter.OnActionExecuting / IAsyncActionFilter
  │
  ▼
[5] Action Execution
  │
  ▼
[4] Action Filter (After)      IActionFilter.OnActionExecuted
  │
  ▼
  ╔═══════════════════════════════╗
  ║   If exception thrown here   ║
  ╚═══════════════════════════════╝
[6] Exception Filter            IExceptionFilter.OnException
  │
  ▼
[7] Result Filter (Before)     IResultFilter.OnResultExecuting / IAsyncResultFilter
  │
  ▼
[8] IActionResult Execution     (e.g., writes JSON to response body)
  │
  ▼
[7] Result Filter (After)      IResultFilter.OnResultExecuted
  │
  ▼
[2] Resource Filter (After)    IResourceFilter.OnResourceExecuted
  │
  ▼
Response
```

### Filter interfaces

| Filter type | Interface(s) |
|---|---|
| Authorization | `IAuthorizationFilter`, `IAsyncAuthorizationFilter` |
| Resource | `IResourceFilter`, `IAsyncResourceFilter` |
| Action | `IActionFilter`, `IAsyncActionFilter` |
| Exception | `IExceptionFilter`, `IAsyncExceptionFilter` |
| Result | `IResultFilter`, `IAsyncResultFilter` |

All filter types have both sync and async variants; prefer `IAsync*` for filters with I/O.

### Filter scope and execution order

Filters can be registered at three scopes:

1. **Global** — via `builder.Services.AddControllers(opts => opts.Filters.Add<T>())`
2. **Controller** — attribute on controller class
3. **Action** — attribute on action method

Within each filter type, they execute in scope order: Global → Controller → Action (before), then Action → Controller → Global (after). The `IOrderedFilter` interface (`Order` property) overrides this.

### Short-circuiting

Any filter can short-circuit the pipeline by setting a result without calling `next`:

```csharp
// Authorization filter short-circuits: action never runs
public void OnAuthorization(AuthorizationFilterContext context)
{
    if (!context.HttpContext.User.Identity?.IsAuthenticated ?? true)
        context.Result = new UnauthorizedResult(); // short-circuit
}
```

### Filter attributes

Most built-in filters have corresponding attribute classes:

```csharp
[Authorize]                    // AuthorizationFilter (built-in)
[ResponseCache]                // ResultFilter (built-in)
[ValidateAntiForgeryToken]     // AuthorizationFilter (built-in)
```

## Code Example

```csharp
// Custom action filter as an attribute
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class LogActionAttribute : ActionFilterAttribute
{
    // ActionFilterAttribute implements both IActionFilter and IResultFilter
    public override void OnActionExecuting(ActionExecutingContext context)
    {
        var action = context.ActionDescriptor.DisplayName;
        Console.WriteLine($"→ Action executing: {action}");
        Console.WriteLine($"  Args: {string.Join(", ", context.ActionArguments.Select(kv => $"{kv.Key}={kv.Value}"))}");
    }

    public override void OnActionExecuted(ActionExecutedContext context)
    {
        var action = context.ActionDescriptor.DisplayName;
        var result = context.Result?.GetType().Name ?? "null";
        Console.WriteLine($"← Action executed: {action}, result: {result}");
    }
}

// Usage
[LogAction]  // controller-scope
public class ProductsController : ControllerBase
{
    [HttpGet("{id}")]
    [LogAction]  // action-scope (runs in addition to controller-scope)
    public IActionResult GetById(int id) => Ok();
}
```

```csharp
// Global registration
builder.Services.AddControllers(opts =>
{
    opts.Filters.Add<LogActionAttribute>();   // global scope (lowest priority)
    opts.Filters.Add(new LogActionAttribute()); // instance (useful for non-DI-friendly filters)
});
```

```csharp
// Filter order control with IOrderedFilter
public sealed class PriorityFilter : IActionFilter, IOrderedFilter
{
    public int Order => -1; // runs before Order=0 (default) filters

    public void OnActionExecuting(ActionExecutingContext context) { }
    public void OnActionExecuted(ActionExecutedContext context) { }
}
```

## Common Follow-up Questions

- What is the difference between an Authorization filter and calling `[Authorize]`?
- When does an Exception filter NOT fire? (When middleware throws, or when a Result filter throws.)
- How does filter scope (Global/Controller/Action) interact with `IOrderedFilter.Order`?
- What is the `IAlwaysRunResultFilter` and when would you use it?
- How do `IResourceFilter` and `IActionFilter` differ in terms of what they can intercept?

## Common Mistakes / Pitfalls

- **Using `IExceptionFilter` as a global exception handler** — it only fires for exceptions within the MVC action pipeline (not middleware, not routing failures). Use `UseExceptionHandler` for complete coverage.
- **Mixing sync and async filter interfaces on the same class** — the framework may call one or the other; prefer `IAsync*` consistently.
- **Registering filters via `services.AddSingleton<T>()` and `opts.Filters.Add<T>()`** — for DI-injected filters, use `TypeFilterAttribute` or `ServiceFilterAttribute` to ensure the correct lifetime.
- **Setting `context.Result` in an action filter's `OnActionExecuted`** — if the action already executed, the result has been produced; setting a new `Result` here overrides it but the pipeline has already advanced.
- **Forgetting that short-circuiting in a Resource filter skips model binding and action filters** — Resource filters that short-circuit prevent ALL subsequent pipeline stages, including Action filters.

## References

- [Microsoft Learn — Filters in ASP.NET Core](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0)
- [Microsoft Learn — Filter types](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0#filter-types)
- [Andrew Lock — Filters in ASP.NET Core](https://andrewlock.net/tag/filters/) (verify URL)
- [Microsoft — FilterAttribute source](https://github.com/dotnet/aspnetcore/blob/main/src/Mvc/Mvc.Core/src/Filters/FilterAttribute.cs)
