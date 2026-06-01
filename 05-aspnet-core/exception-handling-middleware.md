# Exception Handling Middleware

**Category:** ASP.NET Core / Middleware
**Difficulty:** 🟡 Middle
**Tags:** `exception-handling`, `UseExceptionHandler`, `IExceptionHandler`, `ProblemDetails`, `error-middleware`

## Question

> How do you handle unhandled exceptions globally in ASP.NET Core? What is `IExceptionHandler` (introduced in .NET 8) and how does it integrate with `ProblemDetails`?

## Short Answer

`UseExceptionHandler` middleware catches unhandled exceptions from downstream components and re-executes the request to an error endpoint or inline handler. In .NET 8, `IExceptionHandler` was introduced as a composable, DI-friendly alternative that lets you register a chain of handlers tried in registration order. Both integrate naturally with `IProblemDetailsService` to return RFC 9457-compliant `ProblemDetails` JSON responses.

## Detailed Explanation

### `UseExceptionHandler` — the classic approach

```csharp
// Re-execute to an error controller action
app.UseExceptionHandler("/error");

// Or inline handler
app.UseExceptionHandler(errApp =>
    errApp.Run(async ctx =>
    {
        var ex = ctx.Features.Get<IExceptionHandlerPathFeature>()?.Error;
        await ctx.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = 500,
            Title = "An error occurred",
            Detail = ex?.Message
        });
    }));
```

The middleware:
1. Wraps the downstream pipeline in a try/catch.
2. On exception: clears the response, resets the status code to 500.
3. Re-executes the request to the configured error path (important: `IExceptionHandlerPathFeature` holds the original path and exception).

> **Warning:** Re-execution runs through the full middleware pipeline again from the error handler path. Ensure the error endpoint does not throw — that would cause an infinite loop or a confusing response.

### `IExceptionHandler` (.NET 8+)

```csharp
public interface IExceptionHandler
{
    ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken);
}
```

- Returns `true` to indicate the exception was handled (stop the chain).
- Returns `false` to pass to the next registered handler (or fall through to `UseExceptionHandler` default behavior).
- Activated by `AddExceptionHandler<T>()` + `UseExceptionHandler()` (no path argument needed).

Multiple handlers are tried in **registration order** — first registered is tried first.

### `ProblemDetails` integration (.NET 7+)

```csharp
builder.Services.AddProblemDetails();         // registers IProblemDetailsService
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();

var app = builder.Build();
app.UseExceptionHandler();   // activates IExceptionHandler chain + ProblemDetails fallback
```

With `AddProblemDetails()`, the default exception handler writes a `ProblemDetails` JSON response automatically for unhandled exceptions, even if no custom `IExceptionHandler` handles them.

### Exception type mapping example

```csharp
public sealed class ValidationExceptionHandler(IProblemDetailsService problemDetails)
    : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext ctx, Exception ex, CancellationToken ct)
    {
        if (ex is not ValidationException validationEx)
            return false; // not mine — try next handler

        ctx.Response.StatusCode = StatusCodes.Status422UnprocessableEntity;
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = ctx,
            Exception = ex,
            ProblemDetails =
            {
                Title = "Validation failed",
                Detail = string.Join("; ", validationEx.Errors),
                Status = 422
            }
        });
    }
}
```

### Comparison: approaches to global exception handling

| Approach | Scope | .NET version | DI-friendly | ProblemDetails |
|---|---|---|---|---|
| `UseExceptionHandler(path)` | Middleware | 2.x+ | ❌ | Manual |
| `UseExceptionHandler(inline)` | Middleware | 2.x+ | Via `RequestServices` | Manual |
| `IExceptionFilter` (global) | MVC actions only | 2.x+ | Via attribute | Manual |
| `IExceptionHandler` | Middleware | 8+ | ✅ Constructor | ✅ Automatic |

## Code Example

```csharp
// GlobalExceptionHandler.cs
namespace MyApp.ExceptionHandlers;

public sealed class GlobalExceptionHandler(
    ILogger<GlobalExceptionHandler> logger,
    IProblemDetailsService problemDetails) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        // Map exceptions to HTTP status codes
        var (status, title) = exception switch
        {
            NotFoundException     => (404, "Resource not found"),
            UnauthorizedException => (401, "Unauthorized"),
            ForbiddenException    => (403, "Forbidden"),
            ValidationException   => (422, "Validation failed"),
            _                     => (500, "An unexpected error occurred")
        };

        logger.LogError(exception, "Unhandled exception: {Title} ({Status})", title, status);

        httpContext.Response.StatusCode = status;

        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            Exception = exception,
            ProblemDetails =
            {
                Status = status,
                Title = title,
                Detail = httpContext.RequestServices
                    .GetRequiredService<IWebHostEnvironment>().IsDevelopment()
                    ? exception.ToString()
                    : null
            }
        });
    }
}
```

```csharp
// Program.cs
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<ValidationExceptionHandler>(); // tried first
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();     // fallback

var app = builder.Build();
app.UseExceptionHandler(); // activates the chain
app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();
app.Run();
```

## Common Follow-up Questions

- What is the difference between `IExceptionHandler` and `IExceptionFilter`? When does each fire?
- How do you return `ProblemDetails` for 404 responses (routes not found) which are never "exceptions"?
- How do you avoid leaking stack traces in production while still returning useful error details?
- How does `UseExceptionHandler` interact with `app.Map()` pipeline branches?
- How do you test exception handling middleware with `WebApplicationFactory`?

## Common Mistakes / Pitfalls

- **Returning exception details (`ex.ToString()`) in production** — leaks internal implementation details to clients. Gate it with `env.IsDevelopment()`.
- **Not resetting `httpContext.Response.StatusCode`** in a custom inline handler — the default 200 may be written if you forget to set it.
- **`IExceptionHandler` returning `false` for all exceptions when it's the last registered handler** — the exception re-throws and produces a plain-text 500 response. Always have a catch-all handler return `true`.
- **Relying on `IExceptionHandler` to catch exceptions inside `IExceptionHandler` itself** — a throwing exception handler causes a 500 response with no body. Add a try/catch inside `TryHandleAsync`.
- **Using `IExceptionFilter` as a global handler for non-MVC exceptions** — it does not fire for middleware exceptions, routing failures, or Kestrel-level errors.

## References

- [Microsoft Learn — Error handling in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/error-handling?view=aspnetcore-8.0)
- [Microsoft Learn — IExceptionHandler (.NET 8)](https://learn.microsoft.com/aspnet/core/fundamentals/error-handling?view=aspnetcore-8.0#iexceptionhandler)
- [Microsoft Learn — Problem details](https://learn.microsoft.com/aspnet/core/web-api/handle-errors?view=aspnetcore-8.0)
- [Andrew Lock — Using IExceptionHandler in .NET 8](https://andrewlock.net/exploring-the-dotnet-8-preview-updates-to-the-problem-details-service/) (verify URL)
- [RFC 9457 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457)
