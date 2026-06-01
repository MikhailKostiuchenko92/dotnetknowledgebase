# Resource Filters in ASP.NET Core

**Category:** ASP.NET Core / Filters
**Difficulty:** 🔴 Senior
**Tags:** `IResourceFilter`, `IAsyncResourceFilter`, `short-circuit`, `caching`, `model-binding`

## Question

> What is the purpose of `IResourceFilter` in ASP.NET Core, and how does it differ from action filters? When would you use a resource filter to short-circuit a request?

## Short Answer

`IResourceFilter` runs **before and after model binding** — making it the earliest point in the MVC pipeline where you can cache an entire request-response cycle or reject a request cheaply before the framework performs expensive model binding and validation. Unlike action filters (which run after model binding), resource filters can short-circuit before the framework allocates and fills model objects. They also wrap the result of action filters and the action itself, making them useful for coarse-grained caching.

## Detailed Explanation

### Where resource filters sit in the pipeline

```
Authorization filters
  ↓
Resource filter OnResourceExecuting  ← Can short-circuit here (before model binding)
  ↓
Model Binding
  ↓
Action Filters + Action
  ↓
Exception Filters
  ↓
Result Filters + Result Execution
  ↓
Resource filter OnResourceExecuted  ← Always runs (even if action filter short-circuited)
```

Key difference from action filters:
- **Resource filter before** → no model binding has happened yet → arguments are not populated
- **Action filter before** → model binding is complete → typed arguments are available

### The interface

```csharp
public interface IResourceFilter
{
    void OnResourceExecuting(ResourceExecutingContext context);
    void OnResourceExecuted(ResourceExecutedContext context);
}

public interface IAsyncResourceFilter
{
    Task OnResourceExecutionAsync(
        ResourceExecutingContext context,
        ResourceExecutionDelegate next);
}
```

### Short-circuiting in `OnResourceExecuting`

Set `context.Result` to short-circuit. This skips:
- Model binding
- Action filters
- The action method
- Exception filters
- **Result filters** (unless `IAlwaysRunResultFilter`)

```csharp
public void OnResourceExecuting(ResourceExecutingContext context)
{
    if (/* cache hit */)
        context.Result = new ContentResult { Content = cachedContent, ContentType = "application/json" };
}
```

### Practical use: response cache filter

ASP.NET Core's built-in `[ResponseCache]` attribute and the response-caching middleware implement a form of this pattern. A resource filter that caches complete responses must serialize and deserialize both request keys and response bodies — complex in practice, which is why the built-in `ResponseCachingMiddleware` and `OutputCachingMiddleware` (.NET 7+) are preferred over custom resource filter caching.

### What resource filters are NOT good for

| Use case | Better option |
|---|---|
| Modifying action arguments | `IActionFilter.OnActionExecuting` |
| Transforming response JSON | `IResultFilter.OnResultExecuting` |
| Handling domain exceptions | `IExceptionFilter` |
| Coarse request/response caching | `OutputCacheMiddleware` (.NET 7+) |
| Authentication/authorization | `IAuthorizationFilter` or `[Authorize]` |

Resource filters are most valuable when:
- You need to wrap the entire inner pipeline (action + result) with a try/finally for cleanup
- You want to conditionally skip model binding for performance (e.g., cached responses)
- You're building library infrastructure that needs the earliest possible MVC pipeline hook after authorization

## Code Example

```csharp
// ETagResourceFilter — short-circuit on If-None-Match header match
public sealed class ETagResourceFilter(IETagStore etagStore) : IAsyncResourceFilter
{
    public async Task OnResourceExecutionAsync(
        ResourceExecutingContext context,
        ResourceExecutionDelegate next)
    {
        var requestTag = context.HttpContext.Request.Headers.IfNoneMatch.ToString();
        var path = context.HttpContext.Request.Path;

        if (!string.IsNullOrEmpty(requestTag) && await etagStore.MatchAsync(path, requestTag))
        {
            // Short-circuit: skip model binding, action, result execution
            context.Result = new StatusCodeResult(StatusCodes.Status304NotModified);
            return;
        }

        // Execute the rest of the pipeline
        var executed = await next();

        // After action + result, capture the new ETag
        if (executed.HttpContext.Response.Headers.ETag.ToString() is { Length: > 0 } newTag)
            await etagStore.StoreAsync(path, newTag);
    }
}
```

```csharp
// Usage as a per-controller attribute via IFilterFactory
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class ETagCacheAttribute : Attribute, IFilterFactory
{
    public bool IsReusable => false;

    public IFilterMetadata CreateInstance(IServiceProvider sp) =>
        ActivatorUtilities.CreateInstance<ETagResourceFilter>(sp);
}

[ETagCache]
[ApiController]
[Route("[controller]")]
public class CatalogController : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await _catalog.GetAllAsync());
}
```

```csharp
// DisableFormValueModelBindingFilter — a classic ASP.NET Core resource filter pattern
// Used when uploading large files to prevent model binding from buffering the entire request
public sealed class DisableFormValueModelBindingFilter : IResourceFilter
{
    public void OnResourceExecuting(ResourceExecutingContext context)
    {
        var factories = context.ValueProviderFactories;
        factories.RemoveType<FormValueProviderFactory>();
        factories.RemoveType<FormFileValueProviderFactory>();
        factories.RemoveType<JQueryFormValueProviderFactory>();
    }

    public void OnResourceExecuted(ResourceExecutedContext context) { }
}
```

## Common Follow-up Questions

- How does a resource filter differ from a middleware in terms of what data is available?
- What happens to result filters when a resource filter short-circuits?
- Why does the built-in `[ResponseCache]` attribute not use a resource filter internally?
- In what order do global resource filters, controller resource filters, and action resource filters run?
- How would you implement a resource filter that disables model binding for large file uploads?

## Common Mistakes / Pitfalls

- **Accessing action arguments in `OnResourceExecuting`** — model binding hasn't happened yet; `ActionArguments` is not available. Use `IActionFilter.OnActionExecuting` instead.
- **Using a resource filter for fine-grained response transformation** — resource filters run too early to inspect the `IActionResult` value. Use result filters for that.
- **Forgetting that result filters are skipped when a resource filter short-circuits** — if you set `context.Result` in a resource filter, `IResultFilter` (but not `IAlwaysRunResultFilter`) does not run.
- **Building response caching in a resource filter** — response body is a stream; reading and replaying it is complex and error-prone. Use `IOutputCache` (.NET 7+) or `ResponseCachingMiddleware` instead.
- **Setting `IsReusable = true` on a stateful resource filter** — resource filter instances must be stateless to be safely reused across requests.

## References

- [Microsoft Learn — Resource filters](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0#resource-filters)
- [Microsoft Learn — Upload files (DisableFormValueModelBinding pattern)](https://learn.microsoft.com/aspnet/core/mvc/models/file-uploads?view=aspnetcore-8.0#upload-large-files-with-streaming)
- [Microsoft Learn — Output caching middleware (.NET 7+)](https://learn.microsoft.com/aspnet/core/performance/caching/output?view=aspnetcore-8.0)
- [Microsoft — ResourceFilterAttribute source](https://github.com/dotnet/aspnetcore/blob/main/src/Mvc/Mvc.Core/src/Filters/ResourceFilterAttribute.cs)
