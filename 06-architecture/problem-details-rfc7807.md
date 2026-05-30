# Problem Details (RFC 7807)

**Category:** Architecture / API Design
**Difficulty:** 🟡 Middle
**Tags:** `ProblemDetails`, `RFC-7807`, `IExceptionHandler`, `ValidationProblemDetails`, `error-responses`, `.NET-8`

## Question

> What is RFC 7807 (Problem Details for HTTP APIs)? How do you implement standardized error responses in ASP.NET Core using `ProblemDetails`, `ValidationProblemDetails`, and the `IExceptionHandler` interface introduced in .NET 8?

## Short Answer

RFC 7807 defines a standard JSON error format for HTTP APIs: `type`, `title`, `status`, `detail`, `instance` properties. `ProblemDetails` is the ASP.NET Core class implementing this spec. In .NET 8, register `AddProblemDetails()` + custom `IExceptionHandler` implementations to map domain exceptions to HTTP status codes and structured error bodies. `ValidationProblemDetails` extends `ProblemDetails` with a `errors` dictionary — the standard for input validation failures (HTTP 400).

## Detailed Explanation

### RFC 7807 JSON Structure

```json
// Standard Problem Details response (RFC 7807)
{
  "type":     "https://tools.ietf.org/html/rfc7807",
  "title":    "Order Not Found",
  "status":   404,
  "detail":   "Order with ID 42 does not exist.",
  "instance": "/api/orders/42",

  // Extension fields (any additional properties allowed by spec)
  "traceId":  "00-abc123-def456-01",
  "orderId":  42
}

// Validation Problem Details (400 Bad Request)
{
  "type":   "https://tools.ietf.org/html/rfc7807",
  "title":  "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "CustomerId": ["Customer ID is required", "Customer ID must be positive"],
    "Lines":      ["Order must have at least one line"]
  }
}
```

### Basic Setup

```csharp
// Program.cs — enable ProblemDetails for all error responses
builder.Services.AddProblemDetails();
// ↑ This makes ASP.NET Core use ProblemDetails format for all non-success responses
// including 404, 405, 500 from the framework itself

// Required for IExceptionHandler chain
builder.Services.AddExceptionHandler<NotFoundException>();
builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
builder.Services.AddExceptionHandler<FallbackExceptionHandler>(); // ← must be last

app.UseExceptionHandler(); // ← activates the handler chain
```

### Custom IExceptionHandler (.NET 8)

```csharp
// Maps domain NotFoundExceptions → 404 ProblemDetails
public class NotFoundExceptionHandler(IProblemDetailsService pds) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext ctx, Exception ex, CancellationToken ct)
    {
        if (ex is not NotFoundException nfe) return false;  // ← pass to next handler if not applicable

        ctx.Response.StatusCode = StatusCodes.Status404NotFound;

        await pds.WriteAsync(new ProblemDetailsContext
        {
            HttpContext = ctx,
            Exception = ex,
            ProblemDetails = new ProblemDetails
            {
                Type    = "https://tools.ietf.org/html/rfc7807",
                Title   = "Resource Not Found",
                Status  = StatusCodes.Status404NotFound,
                Detail  = nfe.Message,
                Instance = ctx.Request.Path
            }
        }, ct);

        return true; // ← handled — stop chain
    }
}

// Maps FluentValidation ValidationExceptions → 400 ValidationProblemDetails
public class ValidationExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext ctx, Exception ex, CancellationToken ct)
    {
        if (ex is not ValidationException ve) return false;

        ctx.Response.StatusCode = StatusCodes.Status400BadRequest;

        var errors = ve.Errors
            .GroupBy(e => e.PropertyName)
            .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());

        await ctx.Response.WriteAsJsonAsync(new ValidationProblemDetails(errors)
        {
            Instance = ctx.Request.Path
        }, ct);

        return true;
    }
}

// Catch-all fallback — must be registered last
public class FallbackExceptionHandler(IProblemDetailsService pds) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext ctx, Exception ex, CancellationToken ct)
    {
        ctx.Response.StatusCode = StatusCodes.Status500InternalServerError;

        await pds.WriteAsync(new ProblemDetailsContext
        {
            HttpContext = ctx,
            Exception = ex,
            ProblemDetails = new ProblemDetails
            {
                Title  = "An unexpected error occurred",
                Status = 500,
                Detail = "Please contact support if the problem persists"
                // ← do NOT include ex.Message in production (security)
            }
        }, ct);

        return true;
    }
}
```

### Extension Properties

```csharp
// Add trace ID and custom extensions to all ProblemDetails responses
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = ctx =>
    {
        ctx.ProblemDetails.Extensions["traceId"] =
            Activity.Current?.Id ?? ctx.HttpContext.TraceIdentifier;

        ctx.ProblemDetails.Extensions["timestamp"] =
            DateTimeOffset.UtcNow.ToString("O");

        // In development only: include exception details
        if (ctx.HttpContext.RequestServices
                .GetRequiredService<IWebHostEnvironment>().IsDevelopment()
            && ctx.Exception is not null)
        {
            ctx.ProblemDetails.Extensions["exception"] = ctx.Exception.ToString();
        }
    };
});
```

### Type URIs

RFC 7807 recommends `type` be a dereferenceable URI pointing to documentation:

```csharp
public static class ProblemTypes
{
    public const string Validation  = "https://api.mycompany.com/errors/validation";
    public const string NotFound    = "https://api.mycompany.com/errors/not-found";
    public const string Conflict    = "https://api.mycompany.com/errors/conflict";
    public const string Forbidden   = "https://api.mycompany.com/errors/forbidden";
}
```

## Code Example

```csharp
// Minimal API with ProblemDetails — automatic validation + exception mapping
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddProblemDetails(opts =>
    opts.CustomizeProblemDetails = ctx =>
        ctx.ProblemDetails.Extensions["traceId"] =
            Activity.Current?.Id ?? ctx.HttpContext.TraceIdentifier);

builder.Services.AddExceptionHandler<NotFoundExceptionHandler>();
builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
builder.Services.AddExceptionHandler<FallbackExceptionHandler>();

var app = builder.Build();
app.UseExceptionHandler();

app.MapGet("/api/orders/{id:int}", async (int id, ISender sender, CancellationToken ct) =>
{
    // NotFoundException thrown inside → NotFoundExceptionHandler → 404 ProblemDetails
    var order = await sender.Send(new GetOrderByIdQuery(id), ct);
    return Results.Ok(order);
});
```

## Common Follow-up Questions

- How do you test that your exception handlers produce the correct ProblemDetails JSON?
- What is the difference between `UseExceptionHandler()` and `UseStatusCodePages()`?
- How do you produce ProblemDetails responses from Minimal API `TypedResults.Problem()`?
- How do you handle `OperationCanceledException` (client disconnected) without logging it as an error?
- What is the HTTP 422 Unprocessable Entity status, and when should it be preferred over 400 Bad Request?

## Common Mistakes / Pitfalls

- **Leaking exception details in production**: `ProblemDetails.Detail = ex.Message` can expose stack traces, internal error messages, or connection strings. Keep `detail` generic in production.
- **Not registering a fallback handler**: if no `IExceptionHandler` returns `true`, the middleware re-throws the exception, resulting in an empty 500 response with no `ProblemDetails` body.
- **Missing `app.UseExceptionHandler()`**: registering `IExceptionHandler` services without `app.UseExceptionHandler()` in the middleware pipeline — handlers are never called.
- **Forgetting `AddProblemDetails()`**: without this, `IProblemDetailsService` is not registered, and `NotFoundExceptionHandler` using `pds.WriteAsync()` will throw a DI exception.

## References

- [RFC 7807 — Problem Details for HTTP APIs](https://datatracker.ietf.org/doc/html/rfc7807)
- [ProblemDetails in ASP.NET Core — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/web-api/handle-errors)
- [IExceptionHandler in .NET 8 — Microsoft Blog](https://devblogs.microsoft.com/dotnet/asp-net-core-updates-in-dotnet-8-preview-5/) (verify URL)
- [See: api-versioning-strategies.md](./api-versioning-strategies.md)
- [See: command-validation-pipeline.md](./command-validation-pipeline.md)
