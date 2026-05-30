# Global Error Handling

**Category:** Architecture / Cross-Cutting Concerns
**Difficulty:** 🟢 Junior
**Tags:** `error-handling`, `IExceptionHandler`, `ProblemDetails`, `middleware`, `RFC-9457`, `.NET-8`

## Question

> How do you implement global error handling in ASP.NET Core? Compare middleware-based exception handling, `IExceptionHandler` (.NET 8), and `ProblemDetails` factory configuration — including RFC 9457 considerations.

## Short Answer

In .NET 8, use `IExceptionHandler` implementations registered with `builder.Services.AddExceptionHandler<T>()` + `app.UseExceptionHandler()`. Chain multiple handlers — each returns `true` to claim the exception or `false` to pass to the next. `AddProblemDetails()` enables RFC 7807/9457 structured error bodies. For pre-.NET 8: use `UseExceptionHandler(app => ...)` middleware. Never catch exceptions in controllers unless doing explicit business-exception mapping — let the global handler do it.

## Detailed Explanation

### .NET 8 IExceptionHandler (Preferred)

```csharp
// Register multiple handlers — tried in order (first-registered, first-tried)
builder.Services.AddProblemDetails(options =>
    options.CustomizeProblemDetails = ctx =>
        ctx.ProblemDetails.Extensions["traceId"] =
            Activity.Current?.Id ?? ctx.HttpContext.TraceIdentifier);

builder.Services.AddExceptionHandler<NotFoundExceptionHandler>();
builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
builder.Services.AddExceptionHandler<UnauthorizedExceptionHandler>();
builder.Services.AddExceptionHandler<FallbackExceptionHandler>(); // ← last = catch-all

app.UseExceptionHandler();
```

```csharp
// Domain exception → specific HTTP status
public sealed class NotFoundExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext ctx, Exception ex, CancellationToken ct)
    {
        if (ex is not NotFoundException nfe) return false;

        ctx.Response.StatusCode = StatusCodes.Status404NotFound;
        await ctx.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Type     = "https://tools.ietf.org/html/rfc7807#section-3.1",
            Title    = "Resource not found",
            Status   = 404,
            Detail   = nfe.Message,
            Instance = ctx.Request.Path
        }, ct);
        return true;
    }
}

// Catch-all: 500 Internal Server Error
public sealed class FallbackExceptionHandler(ILogger<FallbackExceptionHandler> log) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext ctx, Exception ex, CancellationToken ct)
    {
        log.LogError(ex, "Unhandled exception for {Method} {Path}",
            ctx.Request.Method, ctx.Request.Path);

        ctx.Response.StatusCode = StatusCodes.Status500InternalServerError;
        await ctx.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Type   = "https://tools.ietf.org/html/rfc7807",
            Title  = "An unexpected error occurred",
            Status = 500,
            Detail = "Please retry later or contact support"
        }, ct);
        return true;
    }
}
```

### Pre-.NET 8: Middleware Exception Handler

```csharp
// app.UseExceptionHandler(async context => { ... }) — still valid in .NET 8
app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async ctx =>
    {
        var exceptionFeature = ctx.Features.Get<IExceptionHandlerPathFeature>();
        var ex = exceptionFeature?.Error;

        ctx.Response.ContentType = "application/problem+json";
        ctx.Response.StatusCode = ex switch
        {
            NotFoundException     => 404,
            ValidationException   => 400,
            UnauthorizedException => 401,
            _                     => 500
        };

        await ctx.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Title  = ex is NotFoundException ? "Not Found" : "Error",
            Status = ctx.Response.StatusCode,
            Detail = ex?.Message
        });
    });
});
```

### RFC 9457 (Updated RFC 7807)

```
RFC 9457 (2023) supersedes RFC 7807 (2016) with minor clarifications:
  - "type" should be "about:blank" when the status code is self-descriptive
  - Extension members are now formally allowed in the spec
  - "errors" member (used by ValidationProblemDetails) acknowledged

ASP.NET Core 8 uses RFC 7807 semantics by default.
For full RFC 9457 compliance:
  - Use "about:blank" as type for generic HTTP errors
  - Include "type" URI pointing to documentation for custom error types
```

```json
// RFC 9457 compliant response
{
  "type": "https://api.mycompany.com/errors/order-not-found",
  "title": "Order Not Found",
  "status": 404,
  "detail": "Order with ID 42 was not found.",
  "instance": "/api/orders/42",
  "traceId": "00-abc123-def456-01"
}
```

### Exception Hierarchy Best Practice

```csharp
// Define domain exceptions with consistent mapping
public abstract class DomainException(string message) : Exception(message);

public class NotFoundException(string resource, object id)
    : DomainException($"{resource} with ID {id} was not found");

public class ConflictException(string message) : DomainException(message);
public class BusinessRuleException(string message) : DomainException(message);
public class UnauthorizedException(string? message = null)
    : DomainException(message ?? "Authentication is required");
public class ForbiddenException(string? message = null)
    : DomainException(message ?? "You do not have permission to perform this action");

// HTTP mapping:
// NotFoundException       → 404 Not Found
// ValidationException     → 400 Bad Request  (FluentValidation)
// BusinessRuleException   → 422 Unprocessable Entity
// ConflictException       → 409 Conflict
// UnauthorizedException   → 401 Unauthorized
// ForbiddenException      → 403 Forbidden
```

## Code Example

```csharp
// Complete Program.cs error handling setup (.NET 8)
builder.Services.AddProblemDetails(o =>
    o.CustomizeProblemDetails = ctx =>
        ctx.ProblemDetails.Extensions["traceId"] =
            Activity.Current?.Id ?? ctx.HttpContext.TraceIdentifier);

builder.Services.AddExceptionHandler<NotFoundExceptionHandler>();
builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
builder.Services.AddExceptionHandler<BusinessRuleExceptionHandler>();
builder.Services.AddExceptionHandler<FallbackExceptionHandler>();

var app = builder.Build();
app.UseExceptionHandler(); // ← activates the handler chain
```

## Common Follow-up Questions

- How do you distinguish between `OperationCanceledException` from client disconnect vs from timeout?
- How do you return `ValidationProblemDetails` with an `errors` dictionary for field-level errors?
- What is the `UseStatusCodePages()` middleware and when is it complementary to `UseExceptionHandler()`?
- How do you write integration tests that assert ProblemDetails response format?
- How do you handle exceptions in background services (`IHostedService`) that can't return HTTP responses?

## Common Mistakes / Pitfalls

- **Missing `app.UseExceptionHandler()`**: registering `IExceptionHandler` services without adding the middleware call means exceptions are never intercepted — they propagate to the default ASP.NET Core 500 response.
- **Leaking `ex.Message` or `ex.StackTrace` in production**: exception messages often contain connection strings, SQL, or internal paths. Keep `detail` generic in non-development environments.
- **Returning 500 for all exceptions**: business exceptions (not found, validation) should map to 4xx responses. A `NotFoundException` causing a 500 misleads clients into thinking it's a server fault.
- **Catching exceptions in controllers**: putting `try/catch` in every controller action when a global handler exists is duplication. Reserve controller-level exception handling for specific cases requiring special response bodies.

## References

- [RFC 9457 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457)
- [Handle errors in ASP.NET Core — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/web-api/handle-errors)
- [IExceptionHandler interface — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.diagnostics.iexceptionhandler)
- [See: problem-details-rfc7807.md](./problem-details-rfc7807.md)
