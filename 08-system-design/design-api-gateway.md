# Design an API Gateway

**Category:** System Design / Classic Problems
**Difficulty:** Middle
**Tags:** `api-gateway`, `routing`, `auth`, `rate-limiting`, `circuit-breaker`

## Question

> Design an API Gateway for a microservices backend. It should handle routing, authentication/authorisation, rate limiting, circuit breaking, SSL termination, and request/response transformation. What are the key trade-offs in building vs buying?

- What does the gateway own vs what should each downstream service own?
- How do you avoid the gateway becoming a single point of failure?
- How does service discovery integrate with routing?

## Short Answer

An API Gateway is a reverse proxy that sits in front of all external traffic and centralises cross-cutting concerns: TLS termination, JWT validation, rate limiting, and routing to internal services. It's stateless (routes loaded from a config store) and deployed in at least 3 active replicas behind a load balancer. The gateway never owns business logic — it enforces *who can access what* and *how fast*, then proxies the enriched request downstream. Build vs buy: use a managed gateway (NGINX, Kong, YARP, Azure API Management) unless custom auth or complex transformation logic demands code-level control.

## Detailed Explanation

### Responsibilities (What the Gateway Owns)

| Concern | Gateway | Downstream Service |
|---------|:-------:|:-----------------:|
| TLS termination | ✅ | ❌ (plain HTTP inside cluster) |
| JWT validation / signature | ✅ | ❌ |
| Rate limiting (global / per-user) | ✅ | ❌ |
| Request routing | ✅ | ❌ |
| Circuit breaking to downstreams | ✅ | ❌ |
| CORS headers | ✅ | Optional (APIM handles) |
| Business validation | ❌ | ✅ |
| Authorisation (resource-level) | ❌ | ✅ |
| Domain logic | ❌ | ✅ |

### Core Components

```
External Client
   │ HTTPS
   ▼
[Load Balancer] (multiple gateway replicas — active/active)
   │
   ▼
┌─────────────────────────────────────────────────────────────┐
│                        API Gateway                           │
│  1. TLS Termination                                         │
│  2. Auth Middleware  (JWT → claims extraction)              │
│  3. Rate Limiter     (Redis sliding window)                 │
│  4. Route Matcher    (path + method → service endpoint)     │
│  5. Request Transform (header injection, path rewriting)    │
│  6. Circuit Breaker  (Polly v8)                             │
│  7. Reverse Proxy    (YARP / HttpClient)                    │
│  8. Response Transform (header stripping, error normalise)  │
└─────────────────────────────────────────────────────────────┘
   │ HTTP (plain, inside private network)
   ▼
Downstream Microservices (Orders, Products, Users, ...)
```

### Routing Table

Routes are stored in a configuration store (Consul, Redis, etcd, or a simple JSON file loaded at startup). Each route maps a path pattern + HTTP method to an upstream cluster:

```json
{
  "routes": [
    {
      "path": "/api/orders/{**catch-all}",
      "methods": ["GET","POST","PUT","DELETE"],
      "upstream": "orders-service",
      "auth": "required",
      "rateLimit": { "policy": "authenticated-user", "limit": 100, "window": "1m" }
    },
    {
      "path": "/api/products/{**catch-all}",
      "methods": ["GET"],
      "upstream": "products-service",
      "auth": "optional",
      "rateLimit": { "policy": "anonymous", "limit": 30, "window": "1m" }
    }
  ],
  "clusters": {
    "orders-service": { "destinations": ["http://orders:8080"] },
    "products-service": { "destinations": ["http://products:8080"] }
  }
}
```

### Service Discovery Integration

In Kubernetes, `destinations` can be DNS names (`http://orders-service.default.svc.cluster.local`) — no dynamic discovery needed; kube-proxy handles load balancing to pods. Outside Kubernetes, use Consul or eureka: the gateway polls Consul for healthy endpoints and updates YARP's cluster at runtime without restart.

### Authentication

The gateway validates JWT signatures using the IdP's JWKS endpoint (`/.well-known/jwks.json`). JWKS keys are cached (rotated every 24 h). On validation success, user claims are forwarded downstream as headers:

```
X-User-Id: usr_123
X-User-Roles: admin,read
X-Correlation-Id: req-uuid-456
```

Downstream services trust these headers (since all external traffic enters through the gateway, not directly). For zero-trust environments, use mTLS instead.

### Rate Limiting (Gateway Layer)

See [rate-limiting-in-aspnet-core.md](./rate-limiting-in-aspnet-core.md) for .NET 7+ details. At the gateway level, distributed rate limiting uses Redis sorted sets so limits are shared across all gateway replicas.

### Circuit Breaking to Downstreams

A gateway circuit breaker prevents a slow or failing downstream service from cascading:

```csharp
// Per-cluster circuit breaker via Polly v8 / Microsoft.Extensions.Resilience
services.AddHttpClient("orders-service")
    .AddResilienceHandler("orders-cb", builder =>
    {
        builder.AddCircuitBreaker(new CircuitBreakerStrategyOptions
        {
            FailureRatio         = 0.5,   // open if 50% of calls fail
            SamplingDuration     = TimeSpan.FromSeconds(30),
            MinimumThroughput    = 10,
            BreakDuration        = TimeSpan.FromSeconds(10),
        });
        builder.AddTimeout(TimeSpan.FromSeconds(5));
        builder.AddRetry(new RetryStrategyOptions
        {
            MaxRetryAttempts = 2,
            Delay            = TimeSpan.FromMilliseconds(100),
            BackoffType      = DelayBackoffType.Exponential,
        });
    });
```

### Build vs Buy

| Option | Pros | Cons |
|--------|------|------|
| **YARP** (.NET, OSS) | Full C# control, custom middleware, Polly integration | Must build dashboards, manage ops |
| **Kong** | Feature-rich, plugin ecosystem, Lua extensions | Separate ops, Postgres dependency |
| **Azure API Management** | Managed, analytics, developer portal | Cost, vendor lock-in, latency (~20 ms overhead) |
| **NGINX** | Ultra-high performance, battle-tested | Config language (Lua/nginx.conf), limited .NET ecosystem |

**Rule of thumb**: use a managed solution (APIM, Kong) unless you need custom auth transformations or embedded .NET middleware. The "just use YARP" option shines for greenfield .NET-shop stacks where routing logic is in C# and the team owns the service.

### High Availability

- **3+ gateway replicas** behind a layer-4 load balancer.
- **No local state**: all rate limit counters and circuit breaker state in Redis (or memory per-replica for non-critical limits).
- **Health check endpoint** (`GET /health/live` and `/health/ready`) consumed by load balancer to drain unhealthy replicas.
- **Graceful shutdown**: on SIGTERM, stop accepting new connections, wait for in-flight requests to complete (30 s timeout), then exit.

> **Warning:** Never store session state or cache in the gateway process. The gateway must be stateless so it can be killed and replaced at any time without service disruption.

## Code Example

```csharp
// YARP-based API Gateway with auth middleware and rate limiting
using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;
using Yarp.ReverseProxy.Configuration;

var builder = WebApplication.CreateBuilder(args);

// YARP reverse proxy — loads routes from appsettings
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

// Rate limiting (per user, sliding window)
builder.Services.AddRateLimiter(options =>
{
    options.AddSlidingWindowLimiter("per-user", limiterOptions =>
    {
        limiterOptions.PermitLimit         = 100;
        limiterOptions.Window              = TimeSpan.FromMinutes(1);
        limiterOptions.SegmentsPerWindow   = 6;
        limiterOptions.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        limiterOptions.QueueLimit          = 0;
    });

    options.RejectionStatusCode = 429;
    options.OnRejected = async (ctx, _) =>
    {
        ctx.HttpContext.Response.Headers.RetryAfter = "60";
        await ctx.HttpContext.Response.WriteAsync("Rate limit exceeded.");
    };
});

var app = builder.Build();

// 1. TLS handled by reverse proxy / ingress upstream
// 2. Auth middleware — validate JWT, inject user headers
app.Use(async (ctx, next) =>
{
    if (ctx.Request.Headers.TryGetValue("Authorization", out var auth) &&
        auth.ToString().StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
    {
        var token = auth.ToString()["Bearer ".Length..];
        // Validate JWT (simplified — use Microsoft.IdentityModel.Tokens in production)
        var claims = JwtValidator.ValidateAndExtract(token);
        if (claims is not null)
        {
            ctx.Request.Headers["X-User-Id"]    = claims.UserId;
            ctx.Request.Headers["X-User-Roles"] = string.Join(",", claims.Roles);
        }
        else
        {
            ctx.Response.StatusCode = 401;
            return;
        }
    }

    // 3. Correlation ID injection
    ctx.Request.Headers["X-Correlation-Id"] =
        ctx.TraceIdentifier; // propagate OpenTelemetry trace ID

    await next(ctx);
});

app.UseRateLimiter();
app.MapReverseProxy();

app.Run();
```

## Common Follow-up Questions

- How do you handle WebSocket upgrades through the gateway without disrupting the connection lifecycle?
- A downstream service is slow (p99 = 30 s). What gateway-level strategies prevent this from blocking all gateway threads?
- How do you do canary deployments (5% traffic to v2) using only gateway routing rules?
- How do you propagate distributed trace context (W3C TraceContext / B3) through the gateway without losing it?
- What is the difference between a gateway and a service mesh? When do you need both?

## Common Mistakes / Pitfalls

- **Putting business logic in the gateway**: validation beyond auth/rate limiting belongs to downstream services; the gateway becomes a deployment bottleneck if it encodes business rules.
- **Synchronous JWKS key fetch on every request**: fetch once at startup and cache; rotate on a background timer. Per-request JWKS fetch adds 200+ ms.
- **No circuit breaker per downstream cluster**: a slow service floods gateway goroutines/threads; isolate failures per upstream cluster.
- **Storing rate limit state in gateway process memory**: counters are lost on pod restart and not shared across replicas; use Redis.
- **Forwarding internal headers to clients**: strip `X-Internal-*`, `X-User-Id`, etc., from responses before returning to external clients.
- **Single gateway instance**: the gateway is the front door — it must be multi-replica with no SPOF.

## References

- [YARP Reverse Proxy — Microsoft Docs](https://microsoft.github.io/reverse-proxy/)
- [Azure API Management Overview](https://learn.microsoft.com/en-us/azure/api-management/api-management-key-concepts)
- [Kong Gateway](https://docs.konghq.com/gateway/latest/)
- [See: api-gateway-pattern.md](./api-gateway-pattern.md)
- [See: rate-limiting-in-aspnet-core.md](./rate-limiting-in-aspnet-core.md)
- [See: circuit-breaker-pattern.md](./circuit-breaker-pattern.md)
