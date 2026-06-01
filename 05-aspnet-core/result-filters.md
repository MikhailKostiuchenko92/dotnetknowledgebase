# Result Filters in ASP.NET Core

**Category:** ASP.NET Core / Filters
**Difficulty:** 🟡 Middle
**Tags:** `IResultFilter`, `IAsyncResultFilter`, `IAlwaysRunResultFilter`, `result-execution`, `response-shaping`

## Question

> What is the purpose of `IResultFilter` in ASP.NET Core? When does it run, and how does it differ from action filters for post-processing responses?

## Short Answer

`IResultFilter` wraps `IActionResult` execution — `OnResultExecuting` fires just before the result writes to the response, and `OnResultExecuted` fires just after. Unlike action filters, result filters can inspect and modify the `IActionResult` object before it serializes the response body. Crucially, result filters are **skipped when an exception filter handles an exception** — use `IAlwaysRunResultFilter` if you need to always run post-response logic regardless of how the result was produced.

## Detailed Explanation

### When result filters run

```
[Action filter (before)]
    → Action executes
[Action filter (after)]
    ↓
[Exception filter, if exception thrown]
    ↓
[Result filter OnResultExecuting]  ← You are here
    → IActionResult.ExecuteResultAsync()  (writes response)
[Result filter OnResultExecuted]   ← And here
```

### `IResultFilter` interface

```csharp
public interface IResultFilter
{
    void OnResultExecuting(ResultExecutingContext context);
    void OnResultExecuted(ResultExecutedContext context);
}
```

Key properties:

| Context | Property | Use |
|---|---|---|
| `ResultExecutingContext` | `context.Result` | Read/replace the `IActionResult` before execution |
| `ResultExecutingContext` | `context.Cancel` | Set `true` to short-circuit result execution (no response written) |
| `ResultExecutedContext` | `context.Result` | The result that was executed |
| `ResultExecutedContext` | `context.Exception` | Any exception thrown during result execution |
| `ResultExecutedContext` | `context.ExceptionHandled` | Set `true` to suppress a result-execution exception |

### When result filters are skipped

- When a **Resource filter short-circuits** (result filters run before Resource filters restore).
- When an **Exception filter handles the exception** — the exception filter sets a new result and result filters do NOT run by default.

Use `IAlwaysRunResultFilter` to ensure a filter runs regardless:

```csharp
public class AlwaysRunFilter : IAlwaysRunResultFilter
{
    public void OnResultExecuting(ResultExecutingContext ctx) { /* always runs */ }
    public void OnResultExecuted(ResultExecutedContext ctx) { }
}
```

### Replacing the result

```csharp
public void OnResultExecuting(ResultExecutingContext context)
{
    if (context.Result is OkObjectResult { Value: PagedList<object> pagedResult })
    {
        context.HttpContext.Response.Headers["X-Total-Count"] =
            pagedResult.TotalCount.ToString();
        // Result itself doesn't change; headers are added pre-serialization
    }
}
```

### Async variant

```csharp
public class TraceResultFilter : IAsyncResultFilter
{
    public async Task OnResultExecutionAsync(
        ResultExecutingContext context,
        ResultExecutionDelegate next)
    {
        var sw = Stopwatch.StartNew();
        var executed = await next(); // Execute the result
        sw.Stop();
        executed.HttpContext.Response.Headers["X-Result-Time-Ms"] =
            sw.ElapsedMilliseconds.ToString();
    }
}
```

### Result filter vs action filter for post-processing

| Scenario | Use |
|---|---|
| Modify result object before serialization | `IResultFilter.OnResultExecuting` |
| Log after response written | `IResultFilter.OnResultExecuted` |
| Add response headers after action | Either; prefer `IResultFilter` (closer to response) |
| Handle exceptions from action | `IActionFilter.OnActionExecuted` or `IExceptionFilter` |
| Cache/transform response body | `IResultFilter` + `IResponseCachingFeature` (complex) |
| Needs `ActionDescriptor`/`ModelState` | `IActionFilter` (result filters don't have `ActionDescriptor`) |

## Code Example

```csharp
// Add pagination metadata headers from a paged result
public sealed class PaginationHeaderFilter : IResultFilter
{
    public void OnResultExecuting(ResultExecutingContext context)
    {
        if (context.Result is not ObjectResult { Value: IPagedResult paged })
            return;

        var headers = context.HttpContext.Response.Headers;
        headers.Append("X-Total-Count", paged.TotalCount.ToString());
        headers.Append("X-Page", paged.Page.ToString());
        headers.Append("X-Page-Size", paged.PageSize.ToString());
        headers.Append("X-Total-Pages",
            ((int)Math.Ceiling((double)paged.TotalCount / paged.PageSize)).ToString());
    }

    public void OnResultExecuted(ResultExecutedContext context) { }
}
```

```csharp
// Add request trace ID to every ProblemDetails response — always runs
public sealed class ProblemDetailsEnricher : IAlwaysRunResultFilter
{
    public void OnResultExecuting(ResultExecutingContext ctx)
    {
        if (ctx.Result is ObjectResult { Value: ProblemDetails pd })
        {
            pd.Extensions["traceId"] = ctx.HttpContext.TraceIdentifier;
            pd.Extensions["timestamp"] = DateTimeOffset.UtcNow;
        }
    }

    public void OnResultExecuted(ResultExecutedContext ctx) { }
}
```

```csharp
// Global registration
builder.Services.AddControllers(opts =>
{
    opts.Filters.Add<PaginationHeaderFilter>();
    opts.Filters.Add<ProblemDetailsEnricher>();
});
```

## Common Follow-up Questions

- Why is `IAlwaysRunResultFilter` needed? What scenario requires it?
- Can a result filter modify the response body after `IActionResult.ExecuteResultAsync` runs?
- How does `context.Cancel = true` in `OnResultExecuting` affect the pipeline?
- What is the difference between `IResultFilter` and a response-rewriting middleware?
- Does `ActionFilterAttribute` implement `IResultFilter`? (Yes — it implements both `IActionFilter` and `IResultFilter`.)

## Common Mistakes / Pitfalls

- **Trying to modify response headers in `OnResultExecuted`** — headers are already sent once the result has been executed (especially for streaming results). Modify them in `OnResultExecuting` instead.
- **Expecting result filters to run after exception handling** — exception filters bypass result filters by default. Use `IAlwaysRunResultFilter` to ensure consistent behavior.
- **Reading `context.Result.Value` without type-checking** — the result type varies; always guard with `is` pattern matching before accessing typed properties.
- **Modifying `context.Result` in `OnResultExecuted`** — too late; the response has already been written to the body.
- **Using sync `IResultFilter` for async I/O operations** — use `IAsyncResultFilter` to avoid `GetAwaiter().GetResult()` deadlocks.

## References

- [Microsoft Learn — Result filters](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0#result-filters)
- [Microsoft Learn — IAlwaysRunResultFilter](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0#ialwaysrunresultfilter-and-iasyncalwaysrunresultfilter)
- [Microsoft — ActionFilterAttribute source](https://github.com/dotnet/aspnetcore/blob/main/src/Mvc/Mvc.Core/src/Filters/ActionFilterAttribute.cs)
- [Andrew Lock — Filters in ASP.NET Core](https://andrewlock.net/tag/filters/) (verify URL)
