# Microservices Security Patterns

**Category:** Architecture / Microservices
**Difficulty:** 🔴 Senior
**Tags:** `microservices`, `security`, `service-to-service-auth`, `JWT-propagation`, `mTLS`, `zero-trust`, `OAuth2`

## Question

> How do you implement security in microservices? Describe service-to-service authentication options (JWT propagation, mTLS, client credentials), zero-trust network assumptions, and token propagation patterns.

## Short Answer

Microservices require two authentication dimensions: **user-to-service** (what users can do) and **service-to-service** (ensuring service A is legitimately calling service B). JWT propagation passes the user's token downstream — simple but ties service identity to the user's session. **Client Credentials flow** gives each service its own service identity token. **mTLS** (service mesh) provides cryptographic service identity at the network level without application code. Zero-trust assumes every service-to-service call must be authenticated, even within a private network.

## Detailed Explanation

### JWT Propagation (User Context Forwarding)

```csharp
// API Gateway: validates user JWT, extracts claims, forwards as headers
// (see api-gateway-pattern.md)

// Service A (OrderService): receives user JWT, calls Service B
public class OrderHandler(IInventoryClient inventory, IHttpContextAccessor ctx)
{
    public async Task<bool> CheckStockAsync(int productId, CancellationToken ct)
    {
        // Propagate user's JWT to downstream service
        var token = ctx.HttpContext!.Request.Headers.Authorization.ToString().Replace("Bearer ", "");
        return await inventory.CheckStockAsync(productId, token, ct);
    }
}

// Service B (InventoryService): validates the received JWT, extracts user context
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://auth.myapp.com";
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudiences = ["inventory-service", "api"]
        };
    });
```

**Limitation**: this ties authorization to the user's session. If Service A has a batch job with no user JWT, it can't call Service B.

### Service-to-Service: Client Credentials Flow

Each service has its own identity:

```csharp
// InventoryService gets its own OAuth2 client credentials token
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("inventory-service", client =>
    {
        client.TokenEndpoint = "https://auth.myapp.com/connect/token";
        client.ClientId = "order-service";
        client.ClientSecret = builder.Configuration["ServiceCredentials:Secret"];
        client.Scope = "inventory:read inventory:write";
    });

builder.Services.AddHttpClient<IInventoryClient, InventoryHttpClient>()
    .AddClientCredentialsTokenHandler("inventory-service");

// InventoryService validates the service token
// Has scope "inventory:read" → allowed to call /api/stock
// Without "inventory:write" → cannot call /api/stock/reserve
```

### mTLS Service Identity (Service Mesh)

With Istio/Linkerd, every service has a cryptographic identity certificate (SPIFFE/SVID):

```yaml
# Istio: authorize only OrderService to call InventoryService
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: inventory-allow-orders
  namespace: production
spec:
  selector:
    matchLabels:
      app: inventory-service
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/production/sa/order-service"
              # ↑ Only pods using order-service ServiceAccount can call inventory-service
              # No application code needed — enforced at the network layer
```

### Defense in Depth

| Layer | Technology | What it protects |
|-------|-----------|-----------------|
| Network perimeter | VPC, Private subnet | No internet access to internal services |
| Service mesh | Istio mTLS + AuthorizationPolicy | Service-to-service identity verification |
| Application JWT | OAuth2 + JWT scopes | User authorization (what users can do) |
| Client credentials | OAuth2 Client Credentials | Service authorization (what services can do) |
| API Gateway | Auth offloading + rate limiting | First line of user request filtering |

### Token Propagation Anti-Patterns

```csharp
// ❌ Service uses ADMIN credentials for all internal calls
// If OrderService is compromised: attacker has admin access to all services
services.AddHttpClient<IInventoryClient>()
    .AddClientCredentialsTokenHandler("admin-service"); // ← too much privilege

// ✅ Principle of least privilege: OrderService gets only what it needs
services.AddClientCredentialsTokenManagement()
    .AddClient("order-to-inventory", c =>
    {
        c.Scope = "inventory:read";  // ← read only, cannot modify inventory
    });
```

### Zero-Trust Implementation

```csharp
// All internal service-to-service calls require authentication
// No implicit trust based on network location

// AuthorizationPolicy: every endpoint requires authenticated service identity
builder.Services.AddAuthorizationBuilder()
    .AddPolicy("InternalServiceOnly", policy =>
        policy.RequireClaim("client_id") // ← client credentials token always has client_id
              .RequireRole("internal-service")); // ← only service accounts

// Mark internal-only endpoints
[Authorize(Policy = "InternalServiceOnly")]
[HttpGet("internal/stock/{productId}")]
public Task<StockInfo?> GetStockInternal(int productId, CancellationToken ct)
    => _inventory.GetByIdAsync(productId, ct);
```

## Code Example

```csharp
// Complete: validate incoming JWT + propagate service identity outbound
builder.Services.AddAuthentication()
    .AddJwtBearer("user-auth", options =>         // ← validate user JWTs
    {
        options.Authority = "https://auth.example.com";
        options.Audience = "order-service";
    })
    .AddJwtBearer("service-auth", options =>      // ← validate service-to-service tokens
    {
        options.Authority = "https://auth.example.com";
        options.Audience = "order-service";
    });

builder.Services.AddAuthorizationBuilder()
    .AddPolicy("UserOrService", policy =>
        policy.AddAuthenticationSchemes("user-auth", "service-auth")
              .RequireAuthenticatedUser());

// Outbound: automatic token management for calling InventoryService
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("inventory", c =>
    {
        c.TokenEndpoint = "https://auth.example.com/connect/token";
        c.ClientId = "order-service";
        c.ClientSecret = builder.Configuration["ServiceAuth:Secret"];
        c.Scope = "inventory:read";
    });
```

## Common Follow-up Questions

- How do you handle token rotation and secret management (Azure Key Vault, HashiCorp Vault)?
- What is SPIFFE/SVID, and how does it relate to service mesh mTLS?
- How do you audit service-to-service calls for compliance?
- What is the "on-behalf-of" OAuth2 flow, and when do you need it?
- How do you implement zero-trust in a local development environment?

## Common Mistakes / Pitfalls

- **No service-to-service auth on internal network**: "it's inside the VPC so it's safe" violates zero-trust. A compromised service can make arbitrary calls to other services without service identity checks.
- **Sharing a single service credential across all services**: if the shared secret leaks, all service-to-service auth is compromised. Each service should have its own client_id/secret.
- **Long-lived service tokens without rotation**: service credentials should be rotated regularly. Use short-lived tokens (1 hour) refreshed automatically by the token management library.
- **Propagating admin user JWT to background services**: batch jobs and scheduled tasks have no user context. They must use client credentials — never steal an admin user's token for background processing.

## References

- [Service-to-service auth — Duende IdentityServer](https://docs.duendesoftware.com/identityserver/v7/tokens/client_credentials/) (verify URL)
- [Duende.AccessTokenManagement — GitHub](https://github.com/DuendeSoftware/Duende.AccessTokenManagement)
- [Zero-trust security — Microsoft Azure](https://learn.microsoft.com/en-us/security/zero-trust/)
- [See: service-mesh-basics.md](./service-mesh-basics.md)
- [See: api-gateway-pattern.md](./api-gateway-pattern.md)
