# Exception Filters in ASP.NET Core

**Category:** ASP.NET Core / Filters
**Difficulty:** 🟡 Middle
**Tags:** `IExceptionFilter`, `IAsyncExceptionFilter`, `exception-handling`, `ProblemDetails`, `pipeline`

## Question

> When should you use an exception filter (`IExceptionFilter`) instead of exception-handling middleware? What are the limitations of exception filters?

## Short Answer

Use an `IExceptionFilter` when you want **MVC-specific** exception handling — for example, converting `DomainException` subtypes to specific HTTP status codes only for controller actions, without affecting other parts of the pipeline. Exception filters have important limitations: they **do not** catch exceptions thrown by middleware, by routing, by result execution, by other filters (Resource/Result), or after the action method has streamed the response. For a true catch-all, use `UseExceptionHandler` middleware or `IExceptionHandler` (.NET 8+).

## Detailed Explanation

### Exception filter scope

Exception filters catch **unhandled exceptions thrown in**:
- Action filters (`OnActionExecuting`, `OnActionExecuted`)
- The action method itself

They **do NOT** catch exceptions thrown in:
- Middleware (before or after MVC)
- Authorization/Resource filters
- Result filters
- IActionResult execution (response body writing)
- Anything outside the MVC pipeline

```
Middleware (UseExceptionHandler catches here)
  └── MVC pipeline
        ├── Authorization filter  ← exception NOT caught by IExceptionFilter
        ├── Resource filter       ← exception NOT caught by IExceptionFilter
        ├── Action filter (before)
        ├── Action method          ← exceptions caught by IExceptionFilter ✅
        ├── Action filter (after)  ← exceptions caught by IExceptionFilter ✅
        └── Exception filter       ← runs here
              └── Result filter   ← exception in result filter NOT caught ❌
```

### Implementing `IExceptionFilter`

```csharp
public sealed class DomainExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        if (context.Exception is not DomainException ex)
            return; // not our exception; let it propagate

        context.Result = new ObjectResult(new ProblemDetails
        {
            Title = ex.Title,
            Detail = ex.Message,
            Status = (int)ex.HttpStatus
        })
        {
            StatusCode = (int)ex.HttpStatus
        };

        context.ExceptionHandled = true; // suppress the exception
    }
}
```

Setting `context.ExceptionHandled = true` prevents the exception from bubbling to outer exception filters or middleware. If you do not set it, the exception propagates.

### `IAlwaysRunResultFilter`

By default, `IResultFilter` is skipped when an exception filter sets a result. Use `IAlwaysRunResultFilter` to ensure a result filter (e.g., response shaping) runs even when an exception filter produces the result:

```csharp
public sealed class ProblemDetailsShaper : IAlwaysRunResultFilter
{
    public void OnResultExecuting(ResultExecutingContext ctx)
    {
        if (ctx.Result is ObjectResult { Value: ProblemDetails pd })
            pd.Extensions["requestId"] = ctx.HttpContext.TraceIdentifier;
    }

    public void OnResultExecuted(ResultExecutedContext ctx) { }
}
```

### Multiple exception filters and ordering

Multiple exception filters run in scope order (Global → Controller → Action). The first filter to set `ExceptionHandled = true` stops further exception filter execution.

### Async variant

```csharp
public sealed class DomainExceptionFilter : IAsyncExceptionFilter
{
    public async Task OnExceptionAsync(ExceptionContext context)
    {
        if (context.Exception is not DomainException ex)
            return;

        // Async work (e.g., log to external service)
        await LogAsync(ex, context.HttpContext);

        context.Result = Results.Problem(
            title: ex.Title,
            statusCode: (int)ex.HttpStatus).ExecuteAsync(context.HttpContext);

        context.ExceptionHandled = true;
    }
}
```

### Exception filter vs middleware comparison

| Aspect | `IExceptionFilter` | `UseExceptionHandler` / `IExceptionHandler` |
|---|---|---|
| Scope | MVC pipeline only | Entire HTTP pipeline |
| Access to `ActionDescriptor` | ✅ | ❌ |
| Access to `ModelState` | ✅ | ❌ |
| Catches middleware errors | ❌ | ✅ |
| Catches streaming response errors | ❌ | ✅ |
| .NET 8 recommended approach | ❌ | `IExceptionHandler` (.NET 8+) |

> **Tip:** For greenfield projects on .NET 8+, prefer `IExceptionHandler` + `AddProblemDetails()` for a unified exception handling strategy across the entire pipeline, and use exception filters only for fine-grained MVC-specific behavior.

## Code Example

```csharp
// DomainExceptionFilter.cs
public sealed class DomainExceptionFilter(IProblemDetailsService problemDetailsService)
    : IAsyncExceptionFilter
{
    public async Task OnExceptionAsync(ExceptionContext context)
    {
        var (statusCode, title) = context.Exception switch
        {
            NotFoundException e  => (StatusCodes.Status404NotFound, "Resource not found"),
            ConflictException e  => (StatusCodes.Status409Conflict,  "Resource conflict"),
            ValidationException e => (StatusCodes.Status422UnprocessableEntity, "Validation failed"),
            _                    => (0, string.Empty)
        };

        if (statusCode == 0) return; // unrecognized — let middleware handle

        context.HttpContext.Response.StatusCode = statusCode;
        context.ExceptionHandled = await problemDetailsService.TryWriteAsync(
            new ProblemDetailsContext
            {
                HttpContext = context.HttpContext,
                ProblemDetails = { Title = title, Status = statusCode },
                Exception = context.Exception
            });
    }
}
```

```csharp
// Program.cs
builder.Services.AddProblemDetails();
builder.Services.AddScoped<DomainExceptionFilter>();

builder.Services.AddControllers(opts =>
{
    opts.Filters.Add<DomainExceptionFilter>(); // global scope
});
```

## Common Follow-up Questions

- What is the difference between `ExceptionHandled = true` and setting `context.Result`?
- How does `IAlwaysRunResultFilter` differ from `IResultFilter`?
- Can an exception filter access the response body written by the action?
- When would you choose `UseExceptionHandler` with `IExceptionHandler` over `IExceptionFilter`?
- How do you test exception filters in isolation?

## Common Mistakes / Pitfalls

- **Expecting exception filters to catch middleware exceptions** — exception filters only cover the MVC inner pipeline. Middleware-layer exceptions bypass them entirely.
- **Forgetting to set `ExceptionHandled = true`** — if not set, the exception propagates after the filter runs, resulting in double-logging or unexpected behavior.
- **Using `IExceptionFilter` as the only exception handling mechanism** — 404s from routing, exceptions in middleware, and streaming response errors are not covered. Always pair with `UseExceptionHandler`.
- **Setting `context.Result` without setting `ExceptionHandled`** — setting a result alone does NOT suppress the exception; you must also set `ExceptionHandled = true`.
- **Ordering confusion with multiple exception filters** — the filter at the narrowest scope (action) runs first, not the global filter.

## References

- [Microsoft Learn — Exception filters](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0#exception-filters)
- [Microsoft Learn — IExceptionHandler (.NET 8)](https://learn.microsoft.com/aspnet/core/fundamentals/error-handling?view=aspnetcore-8.0#iexceptionhandler)
- [Microsoft Learn — Handle errors in minimal APIs](https://learn.microsoft.com/aspnet/core/fundamentals/error-handling?view=aspnetcore-8.0)
- [Andrew Lock — Exception handling in ASP.NET Core](https://andrewlock.net/tag/exception-handling/) (verify URL)
