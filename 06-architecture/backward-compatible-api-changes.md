# Backward-Compatible API Changes

**Category:** Architecture / API Design
**Difficulty:** 🟡 Middle
**Tags:** `API-design`, `backward-compatibility`, `breaking-changes`, `deprecation`, `sunset-header`, `additive-changes`

## Question

> What constitutes a breaking vs non-breaking (additive) change in a REST API? How do you deprecate old versions and communicate sunset dates to API consumers?

## Short Answer

**Additive changes** are safe: adding optional request fields, adding response fields, adding new endpoints, adding new enum values (with caution). **Breaking changes** require a version bump: removing/renaming fields, changing field types, changing semantics of existing fields, removing endpoints, making previously optional fields required. To deprecate: mark the version with `[ApiVersion("1.0", Deprecated = true)]`, respond with `Deprecation: true` + `Sunset: <date>` + `Link: <docs>` headers, and communicate a migration guide. Never silently remove a deprecated version — give clients a migration window (typically 6–12 months).

## Detailed Explanation

### Additive (Non-Breaking) Changes

```csharp
// ✅ SAFE: Add new optional response field
// Before:
public record OrderDto(int Id, decimal Total, OrderStatus Status);

// After (backward compatible — existing clients ignore unknown fields with JSON deserialization):
public record OrderDto(int Id, decimal Total, OrderStatus Status, string? TrackingCode = null);

// ✅ SAFE: Add new optional request field
public record PlaceOrderCommand(int CustomerId, decimal Total, string? PromoCode = null);

// ✅ SAFE: Add new endpoint
app.MapGet("/api/v1/orders/{id}/lines", ...);  // ← new endpoint, existing clients unaffected

// ✅ SAFE: Add new enum value (with caution — see pitfalls)
public enum OrderStatus { Pending, Submitted, Shipped, Delivered, Cancelled, OnHold /* new */ }
```

### Breaking Changes

```csharp
// ❌ BREAKING: Remove field — existing clients that read this field get null/default
// Before:
public record OrderDto(int Id, decimal Total, string CustomerEmail);
// After (removed CustomerEmail):
public record OrderDto(int Id, decimal Total); // ← breaks clients using CustomerEmail

// ❌ BREAKING: Rename field
// Before: { "total": 99.99 }
// After:  { "orderTotal": 99.99 }  ← clients reading "total" get null

// ❌ BREAKING: Change type
// Before: { "orderId": 42 }
// After:  { "orderId": "ORD-00042" }  ← type changed int → string

// ❌ BREAKING: Make optional field required
// Before: PlaceOrderCommand(int CustomerId, string? Notes = null)
// After:  PlaceOrderCommand(int CustomerId, string Notes)  ← clients not sending Notes fail

// ❌ BREAKING: Change HTTP method semantics
// Before: GET /api/orders/42/lines → returns lines
// After:  GET /api/orders/42/lines → deletes and returns lines (semantic change)

// ❌ BREAKING: Change authentication scheme
// Before: Bearer token
// After:  API key required  ← all existing clients lose access
```

### Deprecation Headers

```csharp
// Add Deprecation + Sunset + Link headers to deprecated endpoint responses
public class DeprecationMiddleware(RequestDelegate next)
{
    private static readonly Dictionary<string, (DateTimeOffset Sunset, string Link)> _deprecated = new()
    {
        ["/api/v1/"] = (new DateTimeOffset(2025, 12, 31, 0, 0, 0, TimeSpan.Zero),
                        "https://docs.myapi.com/migration/v2")
    };

    public async Task InvokeAsync(HttpContext ctx)
    {
        foreach (var (prefix, (sunset, link)) in _deprecated)
        {
            if (ctx.Request.Path.StartsWithSegments(prefix))
            {
                ctx.Response.Headers["Deprecation"] = "true";
                ctx.Response.Headers["Sunset"] = sunset.ToString("R");  // RFC 1123: Tue, 31 Dec 2025 00:00:00 GMT
                ctx.Response.Headers["Link"] = $"<{link}>; rel=\"successor-version\"";
                break;
            }
        }
        await next(ctx);
    }
}

// Or use Asp.Versioning Sunset policy (see api-versioning-in-aspnet-core.md)
builder.Services.AddApiVersioning(options =>
{
    options.Policies.Sunset(1.0)
        .Effective(DateTimeOffset.Parse("2025-12-31"))
        .Link("https://docs.myapi.com/migration/v2");
});
```

### Deprecation Checklist

```
Step 1: Release v2 with all improvements (no v1 changes yet)
Step 2: Mark v1 as deprecated:
  - [ApiVersion("1.0", Deprecated = true)]
  - Add Deprecation/Sunset headers to all v1 responses
  - Update API documentation + changelog
Step 3: Communicate to consumers (email, docs, blog, SDK release notes)
Step 4: Wait for migration window (minimum 3–6 months; 12 months for large APIs)
Step 5: Monitor v1 traffic — reach out to active consumers
Step 6: Sunset: return 410 Gone (or 301 Redirect) after sunset date
Step 7: Remove v1 code after 1-2 release cycles post-sunset
```

### Enum Addition Caution

```csharp
// Adding new enum values is technically additive but requires client handling
// Robust clients should use JsonNumberHandling or [JsonStringEnumConverter]
// and handle unknown enum values gracefully:

[JsonConverter(typeof(JsonStringEnumConverter))]  // ← serialize as "Pending" not 0
public enum OrderStatus
{
    Unknown = 0,  // ← fallback for unknown values received from newer API versions
    Pending,
    Submitted,
    Shipped,
    Delivered,
    Cancelled
}
```

## Code Example

```csharp
// Full deprecation + sunset via Asp.Versioning
builder.Services
    .AddApiVersioning(options =>
    {
        options.ReportApiVersions = true;
        options.Policies.Sunset(1.0)
            .Effective(new DateTimeOffset(2025, 12, 31, 0, 0, 0, TimeSpan.Zero))
            .Link("https://docs.myapi.com/v2");
    });

[ApiController, ApiVersion("1.0", Deprecated = true), ApiVersion("2.0")]
[Route("api/v{version:apiVersion}/orders")]
public class OrdersController : ControllerBase
{
    // v1: returns simplified DTO (deprecated)
    [HttpGet("{id}"), MapToApiVersion("1.0")]
    public Task<OrderDtoV1?> GetV1(int id, ...) { ... }

    // v2: returns enriched DTO with pagination context
    [HttpGet("{id}"), MapToApiVersion("2.0")]
    public Task<OrderDtoV2?> GetV2(int id, ...) { ... }
}
// Response for v1 request includes:
// api-deprecated-versions: 1.0
// api-supported-versions: 1.0, 2.0
// Sunset: Wed, 31 Dec 2025 00:00:00 GMT
```

## Common Follow-up Questions

- How do you handle a database schema migration when the new API version changes the data model?
- What HTTP status code should a deprecated but still-functional endpoint return?
- How do you automate detection of breaking changes in a CI pipeline?
- What is the difference between `410 Gone` and `301 Moved Permanently` for sunset endpoints?
- How do you communicate breaking changes to SDK consumers (NuGet packages, npm clients)?

## Common Mistakes / Pitfalls

- **Treating new enum values as non-breaking**: clients that use strict enum deserialization (throws on unknown values) will break when a new enum value is added to the API response. Publish enum additions as breaking changes or use string-based enums.
- **No sunset date in deprecation announcement**: announcing deprecation without a concrete date leaves API consumers uncertain about urgency. Always include a specific sunset date.
- **Immediate removal after deprecation announcement**: clients need time to migrate. Removing a deprecated API version in the same sprint as the deprecation announcement breaks production systems.
- **Renaming JSON properties with `[JsonPropertyName]` in the same version**: changing the serialized JSON property name (even via attribute) is a breaking change regardless of whether the C# property name changed.

## References

- [RFC 8594 — The Sunset HTTP Header Field](https://www.rfc-editor.org/rfc/rfc8594)
- [Microsoft REST API Guidelines — Deprecation](https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md#deprecation) (verify URL)
- [See: api-versioning-in-aspnet-core.md](./api-versioning-in-aspnet-core.md)
- [See: api-versioning-strategies.md](./api-versioning-strategies.md)
