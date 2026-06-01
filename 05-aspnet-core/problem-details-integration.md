# ProblemDetails Integration in ASP.NET Core

**Category:** ASP.NET Core / Routing
**Difficulty:** 🟡 Middle
**Tags:** `ProblemDetails`, `ValidationProblemDetails`, `IProblemDetailsService`, `RFC-9457`, `error-response`

## Question

> How does `ProblemDetails` work in ASP.NET Core? What is `IProblemDetailsFactory`, `ValidationProblemDetails`, and how do you customize error responses to follow RFC 9457?

## Short Answer

`ProblemDetails` is a standardized error response object defined in RFC 9457 (formerly RFC 7807) containing `status`, `title`, `detail`, `instance`, and `type` fields. ASP.NET Core uses it automatically for `[ApiController]` validation errors (`ValidationProblemDetails`) and exception handling when `AddProblemDetails()` is configured. `IProblemDetailsService` writes `ProblemDetails` to the response, and `IProblemDetailsFactory` creates instances with custom extensions.

## Detailed Explanation

### RFC 9457 structure

```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.5",
  "title": "Not Found",
  "status": 404,
  "detail": "Product with ID 42 was not found.",
  "instance": "/api/products/42",
  "traceId": "00-abc123-def456-00"
}
```

| Field | Required | Purpose |
|---|---|---|
| `type` | Optional | URI reference identifying the problem type |
| `title` | Optional | Human-readable summary (same for all instances of this type) |
| `status` | Optional | HTTP status code |
| `detail` | Optional | Human-readable explanation for this specific occurrence |
| `instance` | Optional | URI reference to the specific occurrence |

Additional custom fields are allowed (extensions).

### `ValidationProblemDetails`

Extends `ProblemDetails` with `Errors` dictionary for field-level validation errors:

```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "Name": ["The Name field is required."],
    "Price": ["Price must be greater than 0."]
  }
}
```

`[ApiController]` returns `ValidationProblemDetails` automatically for `ModelState` failures.

### `AddProblemDetails()` (.NET 7+)

```csharp
builder.Services.AddProblemDetails(); // registers IProblemDetailsService + IProblemDetailsFactory
```

With this registration:
- `UseExceptionHandler()` (without a path) writes `ProblemDetails` for unhandled exceptions.
- Status code pages (`UseStatusCodePages()`) write `ProblemDetails` for 4xx/5xx without a body.

### `IProblemDetailsService` — writing problem details

```csharp
// In an IExceptionHandler
public async ValueTask<bool> TryHandleAsync(
    HttpContext ctx, Exception ex, CancellationToken ct)
{
    ctx.Response.StatusCode = 500;
    return await problemDetailsService.TryWriteAsync(new ProblemDetailsContext
    {
        HttpContext = ctx,
        Exception = ex,
        ProblemDetails =
        {
            Title = "Internal Server Error",
            Detail = "An unexpected error occurred.",
            Extensions = { ["correlationId"] = ctx.TraceIdentifier }
        }
    });
}
```

### `IProblemDetailsFactory` — creating instances with extensions

```csharp
var factory = ctx.RequestServices.GetRequiredService<IProblemDetailsFactory>();

var problem = factory.CreateProblemDetails(
    ctx,
    statusCode: 404,
    title: "Product Not Found",
    detail: $"Product with ID {id} does not exist.",
    instance: ctx.Request.Path);

// Adds standard extensions: traceId, requestId (automatically)
```

### Customizing the factory

```csharp
builder.Services.AddProblemDetails(opts =>
{
    opts.CustomizeProblemDetails = ctx =>
    {
        ctx.ProblemDetails.Extensions["nodeId"] = Environment.MachineName;
        ctx.ProblemDetails.Extensions["version"] = "1.0.0";

        // Override title based on status code
        ctx.ProblemDetails.Title = ctx.HttpContext.Response.StatusCode switch
        {
            404 => "Resource Not Found",
            422 => "Validation Failed",
            _   => ctx.ProblemDetails.Title
        };
    };
});
```

### `UseStatusCodePages` with ProblemDetails

```csharp
// Return ProblemDetails for 4xx/5xx responses that have no body (e.g., 404 from routing)
app.UseStatusCodePages(async ctx =>
{
    ctx.HttpContext.Response.ContentType = "application/problem+json";
    await ctx.HttpContext.Response.WriteAsJsonAsync(new ProblemDetails
    {
        Status = ctx.HttpContext.Response.StatusCode,
        Title = ReasonPhrases.GetReasonPhrase(ctx.HttpContext.Response.StatusCode),
        Instance = ctx.HttpContext.Request.Path
    });
});
```

Or simpler with `AddProblemDetails()`:
```csharp
app.UseStatusCodePagesWithReExecute("/error/{0}");
```

## Code Example

```csharp
// Program.cs — full ProblemDetails setup

builder.Services.AddProblemDetails(opts =>
{
    opts.CustomizeProblemDetails = ctx =>
    {
        var traceId = Activity.Current?.Id ?? ctx.HttpContext.TraceIdentifier;
        ctx.ProblemDetails.Extensions["traceId"] = traceId;

        // Don't expose stack traces in production
        if (!ctx.HttpContext.RequestServices
            .GetRequiredService<IWebHostEnvironment>().IsDevelopment())
        {
            ctx.ProblemDetails.Detail = null;
        }
    };
});

builder.Services.AddExceptionHandler<GlobalExceptionHandler>();

// Customize [ApiController] automatic 400 to use 422 for validation
builder.Services.Configure<ApiBehaviorOptions>(opts =>
{
    opts.InvalidModelStateResponseFactory = ctx =>
    {
        var factory = ctx.HttpContext.RequestServices
            .GetRequiredService<IProblemDetailsFactory>();

        var validationProblem = factory.CreateValidationProblemDetails(
            ctx.HttpContext, ctx.ModelState,
            statusCode: StatusCodes.Status422UnprocessableEntity,
            title: "Validation failed",
            instance: ctx.HttpContext.Request.Path);

        return new UnprocessableEntityObjectResult(validationProblem)
        {
            ContentTypes = { "application/problem+json" }
        };
    };
});

var app = builder.Build();
app.UseExceptionHandler(); // activates GlobalExceptionHandler + ProblemDetails fallback
app.UseStatusCodePages();  // fills empty 4xx/5xx with ProblemDetails
app.MapControllers();
```

```csharp
// Returning ProblemDetails manually in a controller
[HttpGet("{id}")]
public async Task<IActionResult> GetById(int id)
{
    var product = await _service.GetByIdAsync(id);

    if (product is null)
        return Problem(
            detail: $"Product {id} not found",
            statusCode: StatusCodes.Status404NotFound,
            title: "Product Not Found");

    return Ok(product);
}
```

## Common Follow-up Questions

- How do you add custom fields to `ProblemDetails` consistently across the whole API?
- What is the content type for `ProblemDetails` — is it `application/json` or `application/problem+json`?
- How does `ProblemDetails` integrate with client-side error handling (JavaScript `fetch`, `axios`)?
- How do you return `ProblemDetails` from a minimal API that uses `TypedResults`?
- What is the difference between `ProblemDetails` and `ValidationProblemDetails`?

## Common Mistakes / Pitfalls

- **Not registering `AddProblemDetails()`** — `UseExceptionHandler()` (no-path form) requires it; without it, exception handling produces empty 500 responses.
- **Returning `application/json` instead of `application/problem+json`** — RFC 9457 specifies `application/problem+json` as the content type. Some clients use this to detect error responses.
- **Exposing `detail` with exception messages in production** — exception messages can leak internal implementation details. Use `env.IsDevelopment()` to gate the detail field.
- **Creating `ProblemDetails` without using `IProblemDetailsFactory`** — the factory adds standard extensions (traceId, etc.) automatically; manually creating `new ProblemDetails()` skips these.
- **`ValidationProblemDetails.Errors` keys are case-sensitive in JSON** — by default, keys use the original C# property name casing. Configure `JsonSerializerOptions.PropertyNamingPolicy` or FluentValidation error keys to match your API's conventions.

## References

- [RFC 9457 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457)
- [Microsoft Learn — Error handling with ProblemDetails](https://learn.microsoft.com/aspnet/core/web-api/handle-errors?view=aspnetcore-8.0)
- [Microsoft Learn — IProblemDetailsService (.NET 7+)](https://learn.microsoft.com/aspnet/core/fundamentals/error-handling?view=aspnetcore-8.0#problem-details-service)
- [Andrew Lock — ProblemDetails in ASP.NET Core](https://andrewlock.net/exploring-the-dotnet-8-preview-updates-to-the-problem-details-service/) (verify URL)
- [Microsoft — ProblemDetails source](https://github.com/dotnet/aspnetcore/blob/main/src/Http/Http.Abstractions/src/ProblemDetails/ProblemDetails.cs)
