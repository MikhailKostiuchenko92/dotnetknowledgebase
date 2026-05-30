# API Gateway Pattern

**Category:** Architecture / Microservices
**Difficulty:** 🟡 Middle
**Tags:** `API-gateway`, `BFF`, `YARP`, `Ocelot`, `Azure-API-Management`, `aggregation`, `auth-offloading`

## Question

> What is the API Gateway pattern? Describe the Backend for Frontend (BFF) variant, common gateway responsibilities (auth, rate limiting, routing, aggregation), and .NET implementation options (YARP, Ocelot, Azure API Management).

## Short Answer

An **API Gateway** is a single entry point that routes requests to downstream microservices — handling cross-cutting concerns like auth, rate limiting, SSL termination, logging, and request aggregation. The **BFF (Backend for Frontend)** variant creates a dedicated gateway per client type (mobile BFF, web BFF) to serve client-specific data shapes without polluting service contracts. In .NET, YARP is the production-grade reverse proxy library; Ocelot is an older API gateway; Azure API Management is the managed cloud option for production.

## Detailed Explanation

### API Gateway Responsibilities

```
Client → API Gateway → [OrderService, InventoryService, UserService, ...]

Gateway handles:
  ✓ Authentication (validate JWT, forward user context to services)
  ✓ Authorization (check scopes before routing)
  ✓ SSL/TLS termination (services communicate over plain HTTP internally)
  ✓ Rate limiting (throttle per client or per IP)
  ✓ Request routing (path prefix → service)
  ✓ Load balancing (round-robin, least connections)
  ✓ Response aggregation (combine multiple service responses)
  ✓ Caching (cache stable responses)
  ✓ Logging / distributed tracing (add correlation headers)
  ✓ Request/response transformation (header injection, payload transformation)
```

### YARP (Yet Another Reverse Proxy)

Microsoft's production-grade reverse proxy for .NET — the recommended choice for .NET teams:

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

var app = builder.Build();
app.MapReverseProxy(pipeline =>
{
    // Add auth before routing
    pipeline.UseMiddleware<JwtValidationMiddleware>();
    pipeline.UseProxyMiddleware(); // ← built-in YARP proxy middleware
});
app.Run();
```

```json
// appsettings.json — YARP route configuration
{
  "ReverseProxy": {
    "Routes": {
      "orders": {
        "ClusterId": "orders-cluster",
        "Match": { "Path": "/api/orders/{**catch-all}" },
        "Transforms": [{ "RequestHeader": "X-Forwarded-For", "Append": "{RemoteIpAddress}" }]
      },
      "inventory": {
        "ClusterId": "inventory-cluster",
        "Match": { "Path": "/api/inventory/{**catch-all}" }
      }
    },
    "Clusters": {
      "orders-cluster": {
        "LoadBalancingPolicy": "RoundRobin",
        "Destinations": {
          "orders-1": { "Address": "http://orders-svc-1:8080/" },
          "orders-2": { "Address": "http://orders-svc-2:8080/" }
        }
      }
    }
  }
}
```

### BFF Pattern (Backend for Frontend)

Different clients need different data shapes:

```
Mobile App           Web App              Admin Dashboard
    │                    │                      │
    ↓                    ↓                      ↓
Mobile BFF          Web BFF              Admin BFF
(compact responses, (full responses,    (aggregated stats,
 fewer fields,       web-optimised,      management APIs)
 push-friendly)      server-side caching)
    │                    │                      │
    └────────────────────┴──────────────────────┘
                         │
                 [Microservices]
          OrderService  InventoryService  UserService
```

```csharp
// Web BFF: aggregates order + customer in one response
[HttpGet("orders/{id}/detail")]
public async Task<ActionResult<OrderDetailViewModel>> GetOrderDetail(
    int id, [FromServices] ISender sender, CancellationToken ct)
{
    // Parallel calls to two services (or read model) — aggregate in BFF
    var (order, customer) = await (
        sender.Send(new GetOrderQuery(id), ct),
        sender.Send(new GetCustomerQuery(id), ct)
    ).WhenAll();

    return order is null ? NotFound() : Ok(new OrderDetailViewModel(order, customer));
}

// Mobile BFF: returns a compact mobile-specific response
[HttpGet("orders/{id}/mobile-summary")]
public async Task<ActionResult<MobileOrderSummary>> GetMobileSummary(int id, CancellationToken ct)
    => Ok(await _mobileOrderService.GetSummaryAsync(id, ct));
```

### Authentication Offloading at the Gateway

```csharp
// Gateway: validate JWT and add claims as forwarded headers
public class JwtValidationMiddleware(RequestDelegate next, ITokenValidator validator)
{
    public async Task InvokeAsync(HttpContext ctx)
    {
        var token = ctx.Request.Headers.Authorization.FirstOrDefault()?.Split(" ").Last();
        if (token is null) { ctx.Response.StatusCode = 401; return; }

        var claims = await validator.ValidateAsync(token);
        if (claims is null) { ctx.Response.StatusCode = 401; return; }

        // Forward user identity to downstream services as headers
        ctx.Request.Headers["X-User-Id"] = claims.UserId;
        ctx.Request.Headers["X-User-Roles"] = string.Join(",", claims.Roles);

        await next(ctx);
    }
}

// Downstream service: trust forwarded headers (internal network only)
var userId = httpContext.Request.Headers["X-User-Id"].FirstOrDefault();
```

## Code Example

```csharp
// Rate limiting in YARP pipeline (ASP.NET Core rate limiting)
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("api-default", o =>
    {
        o.PermitLimit = 100;
        o.Window = TimeSpan.FromMinutes(1);
        o.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        o.QueueLimit = 10;
    });
});

app.UseRateLimiter();

app.MapReverseProxy(pipeline =>
{
    pipeline.UseMiddleware<JwtValidationMiddleware>();
    pipeline.UseRateLimiter("api-default");
    pipeline.UseProxyMiddleware();
});
```

## Common Follow-up Questions

- What is the difference between a gateway and a service mesh (Istio, Linkerd)?
- How do you handle long-polling or WebSocket connections through a reverse proxy?
- How do you version APIs at the gateway level vs at the service level?
- When should you NOT use an API Gateway?
- How do you handle authentication in BFF when the BFF itself is a public API?

## Common Mistakes / Pitfalls

- **Too much logic in the gateway**: business logic (pricing, validation, orchestration) in the gateway creates a "god gateway" that must be deployed on every business change.
- **Single gateway for all clients**: mobile and web clients have very different data needs. A single gateway that tries to serve both typically over-fetches for mobile or under-fetches for web.
- **Synchronous aggregation without timeouts**: an aggregation endpoint that calls 3 downstream services and one is slow causes ALL gateway requests to be slow. Use `Task.WhenAll` with timeouts.
- **No circuit breaker at the gateway**: if a downstream service is down, the gateway should fail fast (circuit breaker) rather than accumulating timeout threads.

## References

- [YARP documentation — Microsoft](https://microsoft.github.io/reverse-proxy/)
- [API Gateway pattern — Microsoft Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/microservices/design/gateway)
- [Backend for Frontend pattern — Microsoft](https://learn.microsoft.com/en-us/azure/architecture/patterns/backends-for-frontends)
- [See: inter-service-communication.md](./inter-service-communication.md)
