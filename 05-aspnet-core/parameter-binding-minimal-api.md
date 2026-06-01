# Parameter Binding in Minimal APIs

**Category:** ASP.NET Core / Routing
**Difficulty:** 🟡 Middle
**Tags:** `minimal-api`, `parameter-binding`, `IFormFile`, `HttpContext`, `CancellationToken`, `IBindableFromHttpContext`

## Question

> How does parameter binding work in minimal APIs? What are the special types that are bound automatically (like `HttpContext`, `CancellationToken`, `IFormFile`)?

## Short Answer

Minimal APIs bind handler parameters by inspecting their type and name. Simple types and strings are bound from route segments first, then query string. Complex types are bound from the JSON body. Special framework types — `HttpContext`, `HttpRequest`, `HttpResponse`, `CancellationToken`, `ClaimsPrincipal`, `IFormFile`, `IFormFileCollection` — are injected directly from the request context without any attribute. Services registered in DI are injected if they match a DI-registered type, without needing `[FromServices]` in .NET 7+.

## Detailed Explanation

### Binding priority (inference order)

1. **Route segment** — if parameter name matches a route segment (e.g., `{id}` → `int id`).
2. **Body (JSON)** — if parameter is a complex type (not a special type, not from DI).
3. **Query string** — if parameter is a simple type not matching a route segment.
4. **Special binding** — `HttpContext`, `CancellationToken`, etc.
5. **DI** — if the type is registered in the DI container (.NET 7+, auto-inferred).

```csharp
app.MapGet("/categories/{categoryId}/products/{id}", (
    int categoryId,        // → [FromRoute] (matches route segment)
    int id,                // → [FromRoute] (matches route segment)
    string? sort,          // → [FromQuery] (simple, no route match)
    IProductService svc,   // → [FromServices] (in DI)
    CancellationToken ct   // → special binding
) => Results.Ok());
```

### Special automatically-bound types

| Type | What it provides |
|---|---|
| `HttpContext` | Full HTTP context |
| `HttpRequest` | Request properties |
| `HttpResponse` | Response stream and headers |
| `CancellationToken` | `HttpContext.RequestAborted` |
| `ClaimsPrincipal` | `HttpContext.User` |
| `IFormFile` | Single uploaded file |
| `IFormFileCollection` | All uploaded files |
| `Stream` / `PipeReader` | Raw request body |

These types are recognized without any attribute — adding `[FromServices]` or `[FromBody]` for them is unnecessary and may cause errors.

### `IBindableFromHttpContext<T>` — custom special binding (.NET 7+)

```csharp
public sealed class TenantId : IParsable<TenantId>
{
    public Guid Value { get; }
    // ... IParsable implementation
}

// Or implement IBindableFromHttpContext<T>
public sealed class TenantContext : IBindableFromHttpContext<TenantContext>
{
    public Guid TenantId { get; init; }

    public static ValueTask<TenantContext?> BindAsync(
        HttpContext context, ParameterInfo parameter)
    {
        if (context.Request.Headers.TryGetValue("X-Tenant-Id", out var v)
            && Guid.TryParse(v, out var id))
            return ValueTask.FromResult<TenantContext?>(new() { TenantId = id });

        return ValueTask.FromResult<TenantContext?>(null);
    }
}
```

```csharp
app.MapGet("/data", (TenantContext tenant) =>
    Results.Ok($"Tenant: {tenant.TenantId}")); // bound via IBindableFromHttpContext
```

### `IParsable<T>` — automatic query/route binding for custom types

Types implementing `IParsable<T>` (C# 7+) can be bound from strings (route segments, query params):

```csharp
public sealed record DateRange(DateOnly From, DateOnly To) : IParsable<DateRange>
{
    public static DateRange Parse(string s, IFormatProvider? provider)
    {
        var parts = s.Split("..");
        return new(DateOnly.Parse(parts[0]), DateOnly.Parse(parts[1]));
    }

    public static bool TryParse(string? s, IFormatProvider? provider, out DateRange result)
    {
        // ...
        result = default!;
        return false;
    }
}

// Route: /reports?range=2024-01-01..2024-12-31
app.MapGet("/reports", (DateRange range) => Results.Ok(range));
```

### Explicit attributes in minimal APIs

```csharp
app.MapPost("/upload", async (
    [FromQuery] string folder,
    [FromForm] IFormFile file,
    [FromHeader(Name = "X-Idempotency-Key")] string? idempotencyKey,
    IStorageService storage,
    CancellationToken ct) =>
{
    await storage.SaveAsync(folder, file, ct);
    return TypedResults.NoContent();
});
```

### DI inference vs `[FromServices]` (.NET 7+)

In .NET 7+, parameters whose type is registered in DI are auto-resolved without `[FromServices]`. If a type is both parseable from query string AND registered in DI, DI takes precedence:

```csharp
// ILogger<T> is registered in DI → auto-injected (no attribute needed)
app.MapGet("/", (ILogger<Program> logger) =>
{
    logger.LogInformation("Request received");
    return Results.Ok();
});
```

## Code Example

```csharp
// Comprehensive binding example

app.MapPost("/api/shipments/{orderId}/documents",
    async (
        int orderId,                                // [FromRoute] — matches route segment
        string documentType,                        // [FromQuery] — simple type, not in route
        IFormFile document,                         // special — form file
        [FromHeader(Name = "X-Correlation-Id")]
        string? correlationId,                      // explicit header binding
        IShipmentService service,                   // [FromServices] — auto (in DI)
        ILogger<Program> logger,                    // [FromServices] — auto (in DI)
        ClaimsPrincipal user,                       // special — current user
        CancellationToken ct                        // special — request cancellation
    ) =>
{
    logger.LogInformation(
        "Uploading {Type} for order {Id}, correlation={CorrelationId}",
        documentType, orderId, correlationId);

    if (document.Length > 10 * 1024 * 1024)
        return Results.Problem("File too large (max 10MB)", statusCode: 413);

    var uploadedBy = user.FindFirstValue(ClaimTypes.NameIdentifier) ?? "unknown";
    var fileId = await service.UploadDocumentAsync(orderId, documentType, document, uploadedBy, ct);

    return TypedResults.Created($"/api/shipments/{orderId}/documents/{fileId}",
        new { FileId = fileId });
});
```

```csharp
// Custom type with IBindableFromHttpContext
public sealed class PaginationOptions : IBindableFromHttpContext<PaginationOptions>
{
    public int Page { get; init; } = 1;
    public int Size { get; init; } = 20;

    public static ValueTask<PaginationOptions?> BindAsync(
        HttpContext context, ParameterInfo parameter)
    {
        var query = context.Request.Query;
        int.TryParse(query["page"], out var page);
        int.TryParse(query["size"], out var size);
        return ValueTask.FromResult<PaginationOptions?>(new()
        {
            Page = page > 0 ? page : 1,
            Size = size is > 0 and <= 100 ? size : 20
        });
    }
}

app.MapGet("/api/products", (PaginationOptions pagination, IProductService svc) =>
    svc.GetPagedAsync(pagination.Page, pagination.Size));
```

## Common Follow-up Questions

- What happens when a required parameter cannot be bound — does the request fail silently or return an error?
- How do you bind from the request body in a minimal API without using `[FromBody]` (implicit binding)?
- How does `IBindableFromHttpContext<T>` interact with OpenAPI schema generation?
- What is the difference between binding `Stream` and `PipeReader` from the request body?
- How do you handle multipart form data with multiple files in a minimal API?

## Common Mistakes / Pitfalls

- **Declaring `HttpContext` with `[FromServices]`** — `HttpContext` is a special type; `[FromServices]` forces DI lookup which fails since `HttpContext` is not registered as a DI service.
- **Adding `[FromBody]` to `IFormFile`** — form files require `multipart/form-data` content type, not `application/json`. `[FromBody]` with `IFormFile` returns 415.
- **Using the same parameter name as a route segment but with a different type** — e.g., a string `id` when the route has `{id:int}`. The route constraint rejects the request before binding.
- **Not handling `null` for optional parameters with missing binding sources** — a missing query parameter gives the default value for value types or `null` for reference types; add null checks or use default values.
- **Expecting complex type auto-binding from query string** — without `IParsable<T>` or `IBindableFromHttpContext<T>`, complex types are bound from the body, not the query string.

## References

- [Microsoft Learn — Minimal API parameter binding](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/parameter-binding?view=aspnetcore-8.0)
- [Microsoft Learn — Special types in minimal APIs](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/parameter-binding?view=aspnetcore-8.0#special-types)
- [Microsoft Learn — IBindableFromHttpContext](https://learn.microsoft.com/dotnet/api/microsoft.aspnetcore.http.ibindablefromhttpcontext-1?view=aspnetcore-8.0)
- [Andrew Lock — Minimal API parameter binding](https://andrewlock.net/tag/minimal-api/) (verify URL)
