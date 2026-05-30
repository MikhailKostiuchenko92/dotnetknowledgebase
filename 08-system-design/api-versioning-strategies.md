# API Versioning Strategies

**Category:** System Design / APIs
**Difficulty:** 🟡 Middle
**Tags:** `API-versioning`, `breaking-changes`, `deprecation`, `ASP.NET-Core`, `URL-versioning`, `header-versioning`

## Question

> What strategies exist for versioning a REST API? How do you manage the deprecation lifecycle? How does ASP.NET Core support API versioning?

## Short Answer

The four main API versioning strategies are: URL path versioning (`/api/v2/`), query parameter (`?api-version=2`), request header (`API-Version: 2`), and content negotiation (`Accept: application/vnd.myapi.v2+json`). URL versioning is the most explicit and discoverable; header versioning keeps URLs clean for true REST purists. Deprecation requires communicating sunset dates via `Deprecated` and `Sunset` response headers, maintaining old versions for a defined support window, and providing migration guides.

## Detailed Explanation

### Strategy Comparison

| Strategy | Example | Pros | Cons |
|----------|---------|------|------|
| **URL path** | `GET /api/v2/orders` | Explicit, easy to test and link, works in browser | URL changes per version; "ugly" to REST purists |
| **Query parameter** | `GET /orders?api-version=2` | Easy to add without changing URL structure | Mixes version with filter params; easy to omit |
| **Request header** | `API-Version: 2` | Clean URLs; semantically correct (version is metadata) | Less discoverable; requires docs/tooling to find |
| **Content negotiation** | `Accept: application/vnd.myapi.v2+json` | Purist REST; standard HTTP mechanism | Complex to produce/consume; poor tooling support |

**Industry practice**: URL versioning dominates public APIs (Stripe, GitHub, Azure). Header versioning is popular for internal service-to-service APIs. Content negotiation is rare.

### What Constitutes a Breaking Change?

Always increment the major version for:

| Change | Breaking? |
|--------|----------|
| Remove a field from response | ✅ Yes |
| Rename a field | ✅ Yes |
| Change a field's type | ✅ Yes |
| Change an HTTP verb or URL | ✅ Yes |
| Add a **required** request field | ✅ Yes |
| Add an **optional** request field | ❌ No |
| Add a new response field | ❌ No (if clients ignore unknowns) |
| New optional endpoint | ❌ No |
| Bug fix that changes incorrect behaviour | ⚠️ Depends — may break clients relying on the bug |

> **Rule of thumb**: Be liberal in what you accept (Postel's Law), conservative in what you produce. Adding new optional fields to responses is non-breaking if clients use tolerant readers.

### Deprecation Lifecycle

1. **Announce deprecation**: add `Deprecated: true` (RFC 8594) and `Sunset: Sat, 31 Dec 2025 23:59:59 GMT` headers to all responses on the deprecated version.
2. **Provide migration guide**: link in `Link` header (`Link: <https://docs.api.com/migration/v1-to-v2>; rel="deprecation"`).
3. **Support window**: typically 6–24 months for public APIs; 3–6 months for internal APIs.
4. **Monitor usage**: track version-specific usage metrics; reach out to active consumers before sunset.
5. **Sunset**: return `410 Gone` for all endpoints on the sunset date; don't silently redirect.

### Versioning Granularity

**Version the whole API**: `/api/v2/` applies to all endpoints. Simpler but forces a new version even for unrelated changes.

**Version per endpoint**: `/api/orders/v2` or via content negotiation per resource. More fine-grained but more complex routing.

**Version per breaking change only**: v2 only exists where v1 behaviour differed; v2 inherits v1 handlers for unchanged endpoints. `Asp.Versioning` supports this via `MapToApiVersion` + version inheritance.

### ASP.NET Core Implementation

`Asp.Versioning.Http` (the continuation of `Microsoft.AspNetCore.Mvc.Versioning`) provides:
- Attribute-based or fluent versioning
- Multiple readers combined (`UrlSegment` + `Header`)
- Version-specific route groups (minimal APIs)
- Auto-generated deprecation headers
- API Explorer integration (Swagger/OpenAPI shows only versions you specify)

## Code Example

```csharp
// ASP.NET Core 8 minimal API — URL + header versioning with deprecation
// Package: Asp.Versioning.Http

using Asp.Versioning;
using Asp.Versioning.Builder;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(2, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;

    // Accept version from URL segment AND X-Api-Version header
    options.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),
        new HeaderApiVersionReader("X-Api-Version"));

    options.ReportApiVersions = true;
    // Adds: api-supported-versions: 1.0, 2.0
    //        api-deprecated-versions: 1.0
})
.AddApiExplorer(setup =>
{
    setup.GroupNameFormat           = "'v'VVV";
    setup.SubstituteApiVersionInUrl = true;
});

var app = builder.Build();

var orders = app.NewVersionedApi("Orders");

// ── v1 (deprecated) ───────────────────────────────────────────────────
var v1 = orders.MapGroup("/api/v{version:apiVersion}/orders")
               .HasApiVersion(1.0)
               .HasDeprecatedApiVersion(1.0);   // marks v1 as deprecated

v1.MapGet("/", () =>
{
    // Old response shape (legacy field names)
    return Results.Ok(new[] { new { order_id = 1, order_status = "pending" } });
})
.WithName("ListOrders_v1");

// ── v2 (current) ──────────────────────────────────────────────────────
var v2 = orders.MapGroup("/api/v{version:apiVersion}/orders")
               .HasApiVersion(2.0);

v2.MapGet("/", () =>
{
    // New response shape (renamed fields — breaking change → new version)
    return Results.Ok(new[] { new { id = 1, status = "Pending" } });
})
.WithName("ListOrders_v2");

v2.MapGet("/{id:int}", (int id) =>
    Results.Ok(new { id, status = "Pending", createdAt = DateTime.UtcNow }));

v2.MapPost("/", ([FromBody] CreateOrderRequest req) =>
{
    var order = new { id = 42, req.customerId, req.total, status = "Pending" };
    return Results.Created($"/api/v2/orders/{order.id}", order);
});

// Middleware: add Sunset header to all v1 responses
app.Use(async (ctx, next) =>
{
    await next();
    // Inject Sunset header if the request was for a deprecated version
    if (ctx.GetRequestedApiVersion()?.MajorVersion == 1)
    {
        ctx.Response.Headers["Sunset"] = "Sat, 31 Dec 2025 23:59:59 GMT";
        ctx.Response.Headers["Deprecation"] = "true";
        ctx.Response.Headers["Link"] = "</docs/migration/v1-to-v2>; rel=\"deprecation\"";
    }
});

app.Run();

record CreateOrderRequest(string customerId, decimal total);
```

## Common Follow-up Questions

- How do you version a gRPC API? What are the rules for backward-compatible `.proto` changes?
- How do you version a GraphQL schema without breaking existing clients?
- How do you track which API versions are still actively used before you sunset one?
- What is the `Sunset` HTTP header (RFC 8594), and how does it differ from `Deprecation`?
- How do you handle backward compatibility when you have hundreds of services consuming an internal API?
- What is hypermedia-driven versioning (HATEOAS), and is it practical?

## Common Mistakes / Pitfalls

- **Breaking changes in the same version**: the most common mistake — renaming a field or making an optional field required in a v1 that's already in production breaks all existing clients.
- **No Sunset header on deprecated endpoints**: clients don't know they need to migrate. Without machine-readable deprecation signals, you'll have consumers on v1 long after the announced sunset.
- **Versioning every endpoint separately**: inconsistent versioning across endpoints makes client code complex (different URLs for different operations). Version the API holistically.
- **Removing old versions too quickly**: an industry minimum for public APIs is 6 months' notice. Internal APIs with known consumers should still give at least 1–3 months.
- **Returning 301 redirect from old version**: redirecting `/v1/orders` → `/v2/orders` silently hides breaking changes and may cause incorrect behaviour if the response shape changed.
- **Not testing deprecated versions**: once deprecated, old versions often stop getting updated — including security patches. Actively monitor and patch deprecated versions until they're fully sunset.

## References

- [Asp.Versioning.Http — GitHub](https://github.com/dotnet/aspnet-api-versioning)
- [RFC 8594 — The Sunset HTTP Header Field](https://www.rfc-editor.org/rfc/rfc8594)
- [Microsoft REST API Guidelines — Versioning](https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md#versioning)
- [Stripe API versioning strategy](https://stripe.com/blog/api-versioning)
- [ASP.NET Core API versioning docs — Microsoft Learn](https://learn.microsoft.com/aspnet/core/web-api/advanced/formatting) (verify URL)
