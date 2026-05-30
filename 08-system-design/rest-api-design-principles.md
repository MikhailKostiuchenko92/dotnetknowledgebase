# REST API Design Principles

**Category:** System Design / APIs
**Difficulty:** 🟢 Junior
**Tags:** `REST`, `HTTP`, `API-design`, `idempotency`, `versioning`, `status-codes`, `resources`

## Question

> What are the core principles of REST API design? What HTTP verbs map to CRUD operations, when is an operation idempotent, and how would you version a REST API?

## Short Answer

REST (Representational State Transfer) is an architectural style built on HTTP where resources are addressed by URLs, operations are expressed by HTTP verbs, and responses convey state via status codes. `GET` and `DELETE` are idempotent (repeating them has the same effect); `PUT` is idempotent but `POST` is not. API versioning can be done via URL path (`/v2/`), request header, or content negotiation — URL versioning is the most common and explicit approach.

## Detailed Explanation

### The Six REST Constraints

1. **Client-Server**: UI and data storage are separated; each can evolve independently.
2. **Stateless**: each request contains all information needed; no session state on the server between requests.
3. **Cacheable**: responses must declare cacheability via `Cache-Control` headers.
4. **Uniform Interface**: resources identified by URL; manipulation through representations; self-descriptive messages; HATEOAS (optional in practice).
5. **Layered System**: clients can't tell whether they're talking directly to the server or a proxy/CDN.
6. **Code on Demand** (optional): server can send executable code (JavaScript).

In practice, most "REST APIs" implement constraints 1–4 and are correctly described as REST-ish or HTTP APIs.

### HTTP Verbs and CRUD

| HTTP Verb | Operation | Idempotent? | Safe? | Body? |
|-----------|-----------|-------------|-------|-------|
| `GET` | Read | ✅ | ✅ | No |
| `POST` | Create / action | ❌ | ❌ | Yes |
| `PUT` | Full replace | ✅ | ❌ | Yes |
| `PATCH` | Partial update | ❌ (unless designed so) | ❌ | Yes |
| `DELETE` | Delete | ✅ | ❌ | Rarely |
| `HEAD` | Read headers only | ✅ | ✅ | No |
| `OPTIONS` | Available methods | ✅ | ✅ | No |

**Idempotent**: Calling the operation N times has the same effect as calling it once. `DELETE /users/42` twice: first call deletes the user, second returns 404 — but the end state is the same (user doesn't exist).

**Safe**: Has no side effects; only reads state.

> **Warning:** `PATCH` is only idempotent if you design it as a "set this field to X" operation. A `PATCH /counter` that says "increment by 1" is not idempotent.

### Resource-Oriented URL Design

Use **nouns for resources**, **verbs for HTTP methods**:

```
✅ GET    /orders              # list orders
✅ POST   /orders              # create an order
✅ GET    /orders/{id}         # get specific order
✅ PUT    /orders/{id}         # replace order
✅ PATCH  /orders/{id}         # partial update
✅ DELETE /orders/{id}         # delete order
✅ GET    /orders/{id}/items   # nested resource

❌ POST  /getOrders            # verb in URL — breaks REST convention
❌ POST  /orders/delete/{id}   # use HTTP DELETE verb instead
```

For actions that don't map cleanly to CRUD, use a sub-resource or an action endpoint as a last resort:
```
POST /orders/{id}/cancel       # action endpoint — acceptable when cancel has side effects
```

### Status Codes

| Code | When to use |
|------|------------|
| `200 OK` | Successful GET, PUT, PATCH |
| `201 Created` | Successful POST that created a resource; include `Location` header |
| `204 No Content` | Successful DELETE or PUT with no body |
| `400 Bad Request` | Invalid input; include validation errors in body |
| `401 Unauthorized` | Not authenticated |
| `403 Forbidden` | Authenticated but not authorised |
| `404 Not Found` | Resource doesn't exist |
| `409 Conflict` | Optimistic concurrency conflict, duplicate resource |
| `422 Unprocessable Entity` | Semantically invalid (e.g., end date before start date) |
| `429 Too Many Requests` | Rate limited; include `Retry-After` |
| `500 Internal Server Error` | Unexpected server error (never leak stack traces) |

### Versioning Strategies

| Strategy | Example | Pros | Cons |
|----------|---------|------|------|
| **URL path** | `/api/v2/orders` | Explicit, easy to test in browser | URL changes per version; breaks bookmark |
| **Request header** | `API-Version: 2` | Clean URLs | Less discoverable; must read docs |
| **Query parameter** | `/orders?version=2` | Easy to test | Mixes version with filter params |
| **Content negotiation** | `Accept: application/vnd.myapi.v2+json` | Purist REST | Complex to implement and consume |

**Recommendation**: URL versioning for public APIs; header versioning for internal service-to-service.

ASP.NET Core supports all strategies via `Asp.Versioning.Http` (formerly Microsoft.AspNetCore.Mvc.Versioning).

### Idempotency in POST

`POST` is not inherently idempotent, but you can make it idempotent by requiring clients to send an **idempotency key**:

- Client sends `Idempotency-Key: <uuid>` header.
- Server stores the result keyed by the UUID.
- Duplicate requests return the stored result without re-executing.

[See: idempotency-in-apis.md](./idempotency-in-apis.md)

## Code Example

```csharp
// ASP.NET Core 8 minimal API — REST principles in practice

using Asp.Versioning;
using Asp.Versioning.Builder;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true;   // adds api-supported-versions response header
    options.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),             // /api/v1/orders
        new HeaderApiVersionReader("X-API-Version")); // X-API-Version: 1
});

var app = builder.Build();
var api = app.NewVersionedApi("Orders");

// v1 group
var v1 = api.MapGroup("/api/v{version:apiVersion}/orders").HasApiVersion(1.0);

v1.MapGet("/", () => Results.Ok(new[] { new { Id = 1, Status = "Pending" } }));

v1.MapGet("/{id:int}", (int id) =>
    id == 1
        ? Results.Ok(new { Id = id, Status = "Pending" })
        : Results.NotFound(new ProblemDetails { Title = "Order not found", Status = 404 }));

v1.MapPost("/", ([FromBody] CreateOrderRequest req) =>
{
    if (req.Total <= 0)
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["Total"] = ["Total must be positive"]
        });

    var newOrder = new { Id = 42, req.CustomerId, req.Total, Status = "Pending" };
    // 201 with Location header pointing to the new resource
    return Results.Created($"/api/v1/orders/{newOrder.Id}", newOrder);
});

v1.MapDelete("/{id:int}", (int id) =>
    // Idempotent: 204 whether it existed or not (or 404 if strict)
    Results.NoContent());

// v2: breaking change — renames Status to State
var v2 = api.MapGroup("/api/v{version:apiVersion}/orders").HasApiVersion(2.0);
v2.MapGet("/{id:int}", (int id) =>
    Results.Ok(new { Id = id, State = "Pending" }));  // breaking rename

app.Run();

record CreateOrderRequest(string CustomerId, decimal Total);
```

## Common Follow-up Questions

- What is HATEOAS, and do you need it in a modern REST API?
- How do you design REST endpoints for bulk operations (create 100 orders at once)?
- When would you choose GraphQL or gRPC over REST? [See: rest-vs-grpc-vs-graphql.md](./rest-vs-grpc-vs-graphql.md)
- How do you implement optimistic concurrency in a REST API using ETags?
- What is the difference between a `404` and a `410 Gone` status code?
- How do you handle long-running operations (e.g., `POST /reports`) in a REST API?

## Common Mistakes / Pitfalls

- **Verbs in URLs** (`/getUser`, `/deleteOrder`): the verb is the HTTP method. Verbs in URLs are a code smell indicating the endpoint is action-oriented, not resource-oriented.
- **Using `200 OK` for everything**: returning `200` with `{ success: false }` in the body makes HTTP clients unable to detect errors without parsing the response body.
- **`PUT` that behaves like `PATCH`**: `PUT` must replace the entire resource. If it only updates provided fields, it's a `PATCH`. Inconsistency confuses API consumers.
- **Not setting `Location` header on `201 Created`**: the `Location` header tells clients where to find the created resource without requiring them to construct the URL.
- **Breaking changes in the same API version**: adding a required field, renaming a field, or changing a type in the same version is a breaking change. Version the API or use `PATCH` semantics carefully.
- **Returning 500 for validation errors**: validation failures are `400 Bad Request` or `422 Unprocessable Entity` — a `500` tells the client the server crashed, not that their input was wrong.

## References

- [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md)
- [ASP.NET Core API versioning — Asp.Versioning.Http](https://github.com/dotnet/aspnet-api-versioning)
- [RFC 9110 — HTTP Semantics (replaces RFC 7231)](https://www.rfc-editor.org/rfc/rfc9110)
- [Problem Details for HTTP APIs (RFC 9457)](https://www.rfc-editor.org/rfc/rfc9457) — standard error response format
- [See: rest-vs-grpc-vs-graphql.md](./rest-vs-grpc-vs-graphql.md) — when to choose alternatives
