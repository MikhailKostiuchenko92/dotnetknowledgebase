# Middleware vs Filters

**Category:** ASP.NET Core / Middleware
**Difficulty:** 🟡 Middle
**Tags:** `middleware`, `filters`, `IActionFilter`, `HttpContext`, `ActionContext`, `pipeline`

## Question

> What is the difference between middleware and filters in ASP.NET Core? What does each have access to, and how do you choose between them?

## Short Answer

Middleware operates at the HTTP transport level (`HttpContext`) and runs for every request regardless of whether a controller/endpoint is matched. Filters are part of the MVC/minimal API action pipeline and run only for requests matched to a controller action or endpoint — they have access to `ActionContext`, model binding results, `ActionDescriptor`, and exception details within the action pipeline. Middleware is for cross-cutting concerns across the whole app; filters are for cross-cutting concerns scoped to MVC/API actions.

## Detailed Explanation

### The two pipeline layers

```
Request
  │
  ▼
[Middleware Pipeline]            ← HttpContext only
  UseExceptionHandler
  UseHttpsRedirection
  UseRouting
  UseAuthentication
  UseAuthorization
  │
  ▼ (endpoint matched → MVC pipeline)
[Filter Pipeline]                ← ActionContext + HttpContext
  Authorization filters
  Resource filters
  Model binding
  Action filters
  Action execution
  Exception filters
  Result filters
  Response write
```

Middleware runs for **every** request — even 404s, static files, and health checks. Filters run **only** when an action/endpoint executes.

### What each can access

| Capability | Middleware | Filter |
|---|---|---|
| `HttpContext` | ✅ Full access | ✅ Full access |
| Route data (`RouteData`) | ✅ After `UseRouting` | ✅ Always |
| `ActionDescriptor` (controller, action name) | ❌ | ✅ |
| Model-binding result (`ModelState`) | ❌ | ✅ (Action/Result filters) |
| `IActionResult` / `IResult` before write | ❌ | ✅ (Result filters) |
| Action arguments | ❌ | ✅ (Action filters) |
| Exception within action | ❌ | ✅ (Exception filters) |
| Short-circuit entire pipeline | ✅ | ✅ |
| DI lifetime | Constructor (careful) / `InvokeAsync` | `TypeFilterAttribute` / Scoped |

### Choosing between them

Use **middleware** when:
- The concern applies to all requests (HTTPS redirect, CORS, security headers, logging, compression).
- You don't need action metadata (controller name, route values, model state).
- The concern must run even for non-MVC endpoints (static files, health checks, gRPC).

Use a **filter** when:
- The concern only applies to controller/API actions.
- You need model-binding state (`ModelState.IsValid`).
- You want to inspect or modify `IActionResult` before it's executed.
- You need per-controller or per-action granularity via attributes.
- You need to handle exceptions thrown inside actions and produce structured error responses.

### Filters vs middleware: exception handling

```csharp
// Exception filter — fires only for exceptions inside actions
public class ApiExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        context.Result = new ObjectResult(new ProblemDetails { ... })
        { StatusCode = 500 };
        context.ExceptionHandled = true;
    }
}

// Exception middleware — fires for everything, including filter pipeline exceptions
app.UseExceptionHandler(errApp =>
    errApp.Run(async ctx => await ctx.Response.WriteAsJsonAsync(new ProblemDetails { ... })));
```

Use `IExceptionFilter` for action-specific errors; use `UseExceptionHandler` as a safety net for unhandled exceptions from the entire pipeline.

### Authorization: middleware vs filter

`UseAuthorization()` middleware enforces authorization **after the endpoint is matched** (it reads the `[Authorize]` attribute from endpoint metadata). `IAuthorizationFilter` can also perform authorization but runs deeper in the MVC pipeline. Prefer `UseAuthorization()` middleware for standard authorization.

## Code Example

```csharp
// RequestLoggingMiddleware — cross-cutting, runs for ALL requests including static files
public sealed class RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        logger.LogInformation("→ {Method} {Path}", context.Request.Method, context.Request.Path);
        await next(context);
        logger.LogInformation("← {Status}", context.Response.StatusCode);
    }
}
```

```csharp
// ActionLoggingFilter — only fires for controller actions; has ActionContext
public sealed class ActionLoggingFilter(ILogger<ActionLoggingFilter> logger) : IActionFilter
{
    public void OnActionExecuting(ActionExecutingContext context)
    {
        var controllerName = context.RouteData.Values["controller"];
        var actionName = context.RouteData.Values["action"];
        logger.LogInformation("Action {Controller}.{Action} executing with args: {@Args}",
            controllerName, actionName, context.ActionArguments);
    }

    public void OnActionExecuted(ActionExecutedContext context)
    {
        if (context.Exception is not null)
            logger.LogError(context.Exception, "Action threw");
        else
            logger.LogInformation("Action result: {Result}", context.Result?.GetType().Name);
    }
}
```

```csharp
// Program.cs — registering both
builder.Services.AddControllers(opts =>
    opts.Filters.Add<ActionLoggingFilter>());   // global filter

var app = builder.Build();
app.UseMiddleware<RequestLoggingMiddleware>();   // global middleware
app.UseRouting();
app.UseAuthorization();
app.MapControllers();
app.Run();
```

### Summary decision tree

```
Does it apply to all requests (including static files, health checks)?
  → Middleware

Does it need model-binding results or ActionDescriptor?
  → Filter

Does it need per-controller/per-action granularity via attribute?
  → Filter

Is it authentication/authorization?
  → Middleware (UseAuthentication/UseAuthorization) for the standard flow
  → Filter for custom per-action authorization logic
```

## Common Follow-up Questions

- Can a filter short-circuit the pipeline before model binding occurs? (Yes — Resource filters.)
- How do you apply a filter only to specific controllers or actions?
- What is the execution order when both a global middleware and a global filter handle the same exception?
- Can middleware access the matched route values after `UseRouting()`?
- How does `IResourceFilter` differ from `IActionFilter`?

## Common Mistakes / Pitfalls

- **Using a filter for cross-cutting concerns that need to fire for all requests** — filters don't run for 404s, static files, gRPC, or health checks.
- **Using middleware where you need `ModelState`** — middleware has no model binding context; use an `IActionFilter` instead.
- **Forgetting that filter exceptions propagate to `UseExceptionHandler`** — `IExceptionFilter` catches exceptions inside the action pipeline, but if the filter itself throws, that exception bubbles up to middleware.
- **Registering `IExceptionFilter` globally and also using `UseExceptionHandler`** — both can fire; the exception filter runs first and may swallow the exception before middleware sees it.
- **Applying authorization logic in middleware that depends on action metadata** — the middleware runs before MVC and may not have matched the endpoint; use `IAuthorizationFilter` or endpoint metadata if you need action context.

## References

- [Microsoft Learn — Filters in ASP.NET Core](https://learn.microsoft.com/aspnet/core/mvc/controllers/filters?view=aspnetcore-8.0)
- [Microsoft Learn — ASP.NET Core middleware](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/?view=aspnetcore-8.0)
- [Andrew Lock — Middleware vs Filters](https://andrewlock.net/tag/filters/) (verify URL)
- [Microsoft Learn — IExceptionFilter vs UseExceptionHandler](https://learn.microsoft.com/aspnet/core/fundamentals/error-handling?view=aspnetcore-8.0)
