# API Gateway Pattern

**Category:** System Design / APIs
**Difficulty:** 🟡 Middle
**Tags:** `API-gateway`, `BFF`, `routing`, `auth`, `rate-limiting`, `aggregation`, `YARP`, `Azure-API-Management`

## Question

> What is the API Gateway pattern? What concerns does it address, and what is the Backend for Frontend (BFF) variant? How would you implement one in .NET?

## Short Answer

An API Gateway is a single entry point for all client requests, handling cross-cutting concerns like routing, authentication, rate limiting, SSL termination, and request aggregation. It decouples clients from the internal service topology. The Backend for Frontend (BFF) variant goes further by creating a dedicated gateway per client type (mobile, web, third-party) so each can evolve its interface independently. In .NET, YARP (Yet Another Reverse Proxy) is the primary library for building custom gateways; Azure API Management and AWS API Gateway are managed alternatives.

## Detailed Explanation

### What an API Gateway Does

Without a gateway, clients must know the address and API contract of every service. Adding authentication, rate limiting, or logging requires duplication across each service.

An API gateway centralises these cross-cutting concerns:

| Concern | Gateway handles | Services focus on |
|---------|----------------|------------------|
| SSL termination | Yes | Plain HTTP internally |
| Authentication/authorisation | Validates JWT, passes claims | Trust gateway, skip auth |
| Rate limiting | Per-client, per-endpoint | Business logic |
| Request routing | URL-based, header-based | Their specific endpoints |
| Request aggregation | Combine multiple service calls | Single responsibility |
| Load balancing | Across service replicas | Stateless processing |
| Logging/tracing | Centralised request logs | Business events |
| Caching | Response caching at edge | Uncached logic |
| Circuit breaking | Protect services from overload | Availability |

### Routing Strategies

- **Path-based routing**: `/orders/*` → OrderService; `/users/*` → UserService
- **Header-based routing**: `X-Client-Version: 2` → new service version (canary)
- **Authentication claim routing**: `role=admin` → admin API; otherwise → public API
- **Weighted routing**: 10% traffic to canary, 90% to stable (blue-green / A/B)

### Aggregation (Composition)

Some clients need data from multiple services in one call. Without aggregation, a mobile app must make 3 calls (user, orders, notifications) — each with network overhead:

```
Mobile App → Gateway (one call)
                ↓
       ┌────────┼────────┐
       ↓        ↓        ↓
   UserSvc  OrderSvc  NotifSvc
       └────────┼────────┘
                ↓
         Gateway aggregates → response
```

The gateway fans out, awaits all, merges, and returns one response. This is the **Aggregator pattern**.

### Backend for Frontend (BFF)

A single gateway serving mobile, web, and third-party clients becomes bloated — each client has different needs:
- Mobile: minimal data, compressed payloads, offline-sync-friendly
- Web: rich data, HATEOAS links, server-side rendering data
- Third-party: stable, versioned, rate-limited public contract

BFF creates **one gateway per client type**:

```
Mobile App   Web App   Partner API
    ↓            ↓           ↓
Mobile BFF   Web BFF   Public API GW
    ↓            ↓           ↓
         Internal Services
```

Each BFF owns its API contract, can evolve independently, and is operated by the team that owns the client.

### Risks and Downsides

- **SPOF / scalability bottleneck**: every request passes through the gateway — it must be highly available and horizontally scalable.
- **Gateway as a monolith**: if teams add business logic to the gateway, it becomes a new monolith. Logic belongs in services; the gateway handles infrastructure concerns only.
- **Latency overhead**: each hop adds ~0.1–1ms. For very latency-sensitive paths, consider service-to-service direct calls.
- **Version coupling**: if the gateway hardcodes service contracts, it becomes tightly coupled to each service's API.

### .NET Options

| Option | Description | When to use |
|--------|-------------|-------------|
| **YARP** (Microsoft) | Reverse proxy library for ASP.NET Core | Custom gateway with full code control |
| **Azure API Management** | Managed, enterprise-grade gateway | Cloud-hosted public APIs, rich policies |
| **AWS API Gateway** | Managed, tight Lambda/ECS integration | AWS ecosystems |
| **Ocelot** | .NET reverse proxy library (older) | Legacy .NET projects |
| **Envoy / Kong** | Infrastructure-level proxy | Platform-level concerns (service mesh) |

## Code Example

```csharp
// YARP-based API Gateway in ASP.NET Core 8
// Handles: routing, JWT validation, rate limiting, request logging
// Package: Yarp.ReverseProxy

using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Http.Resilience;
using Yarp.ReverseProxy.Configuration;

var builder = WebApplication.CreateBuilder(args);

// JWT authentication — gateway validates tokens; downstream services trust gateway
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://login.microsoftonline.com/{tenant}";
        options.Audience  = "api://my-gateway";
    });

builder.Services.AddAuthorization();

// Rate limiting — protect downstream services
builder.Services.AddRateLimiter(options =>
    options.AddFixedWindowLimiter("api-limit", cfg =>
    {
        cfg.PermitLimit = 100;
        cfg.Window = TimeSpan.FromMinutes(1);
    }));

// YARP routes — loaded from config or code
builder.Services.AddReverseProxy()
    .LoadFromMemory(
        routes:
        [
            new RouteConfig
            {
                RouteId  = "orders-route",
                ClusterId = "orders-cluster",
                Match    = new RouteMatch { Path = "/api/orders/{**remainder}" },
                AuthorizationPolicy = "default",          // require valid JWT
                RateLimiterPolicy   = "api-limit"
            },
            new RouteConfig
            {
                RouteId   = "users-route",
                ClusterId = "users-cluster",
                Match     = new RouteMatch { Path = "/api/users/{**remainder}" }
                // public endpoint — no auth required
            }
        ],
        clusters:
        [
            new ClusterConfig
            {
                ClusterId = "orders-cluster",
                Destinations = new Dictionary<string, DestinationConfig>
                {
                    ["orders-1"] = new() { Address = "http://order-service:8080" },
                    ["orders-2"] = new() { Address = "http://order-service-2:8080" }
                    // YARP load-balances across destinations
                }
            },
            new ClusterConfig
            {
                ClusterId = "users-cluster",
                Destinations = new Dictionary<string, DestinationConfig>
                {
                    ["users-1"] = new() { Address = "http://user-service:8080" }
                }
            }
        ]);

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

// Inject correlation ID so downstream services can trace the request
app.Use(async (ctx, next) =>
{
    ctx.Request.Headers["X-Correlation-Id"] =
        ctx.Request.Headers.TryGetValue("X-Correlation-Id", out var id)
            ? id
            : Guid.NewGuid().ToString();
    await next();
});

app.MapReverseProxy();
app.Run();
```

## Common Follow-up Questions

- How does a service mesh (Istio, Linkerd, Dapr) differ from an API gateway?
- How do you implement request aggregation (fan-out) in YARP?
- How do you handle authentication between the gateway and downstream services (mTLS, service tokens)?
- When does the BFF pattern cause more problems than it solves?
- How do you version routes in an API gateway without breaking existing consumers?
- How would you implement circuit breaking in a YARP gateway?

## Common Mistakes / Pitfalls

- **Adding business logic to the gateway**: validating business rules, transforming data, or implementing workflow steps in the gateway turns it into a bottleneck monolith. Keep it to infrastructure concerns.
- **Forgetting the gateway is a SPOF**: running a single gateway instance without HA (redundant instances, health checks, auto-healing) creates a higher-severity SPOF than any individual service.
- **Passing secrets through the gateway to clients**: the gateway should strip internal headers (internal service names, cluster IPs, debug info) before forwarding responses to external clients.
- **Over-aggregating at the gateway**: complex fan-out + join logic in a gateway is better placed in a dedicated aggregation service or GraphQL layer — it's easier to test, version, and scale independently.
- **Not propagating tracing headers**: correlation IDs and OpenTelemetry trace context (`traceparent`) must be forwarded to downstream services; otherwise distributed traces break at the gateway boundary.
- **Forgetting timeout configuration**: if no timeout is set on outbound calls to services, a slow service will hold a gateway thread indefinitely, cascading into gateway unavailability.

## References

- [YARP (Yet Another Reverse Proxy) — Microsoft Learn](https://learn.microsoft.com/aspnet/core/fundamentals/http-requests#yarp)
- [YARP GitHub repository](https://github.com/microsoft/reverse-proxy)
- [Azure API Management documentation](https://learn.microsoft.com/azure/api-management/api-management-key-concepts)
- [Azure Architecture Center — API Gateway pattern](https://learn.microsoft.com/azure/architecture/microservices/design/gateway)
- [Sam Newman — Building Microservices, Chapter 14: User Interfaces (BFF pattern)](https://samnewman.io/patterns/architectural/bff/)
