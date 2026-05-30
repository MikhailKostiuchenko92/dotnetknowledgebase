# Service Decomposition Strategies

**Category:** Architecture / Microservices
**Difficulty:** 🟢 Junior
**Tags:** `microservices`, `bounded-context`, `decomposition`, `business-capability`, `subdomain`, `strangler-fig`

## Question

> How do you decompose a monolith into microservices? What are the main strategies — decompose by business capability vs subdomain — and what is the Strangler Fig pattern?

## Short Answer

Decompose by **business capability** (what the system does: Orders, Payments, Shipping) or **DDD subdomain** (aligning service boundaries with bounded contexts). Both approaches produce similar results for well-designed systems. The **Strangler Fig** pattern extracts features incrementally: a proxy routes requests to either the old monolith or the new service, allowing safe migration without a big-bang rewrite. The key principle: services must own their data — no shared databases between services.

## Detailed Explanation

### Decompose by Business Capability

Business capabilities are stable because they reflect what the company does, not how it's implemented:

```
E-commerce system → business capabilities:
  ┌─────────────────────────────────────────────┐
  │  Product Catalog   │  Order Management      │
  │  Search            │  Inventory             │
  │  Customer Mgmt     │  Pricing & Promotions  │
  │  Payments          │  Shipping & Delivery   │
  │  Notifications     │  Reviews & Ratings     │
  └─────────────────────────────────────────────┘

Each box → potentially a service
Each service owns its own data, has its own deployment
```

### Decompose by DDD Subdomain / Bounded Context

Bounded contexts naturally define service boundaries (see [bounded-context.md](./bounded-context.md)):

```
Core domain (highest business value):
  OrderManagement — complex workflows, high differentiation
  PricingEngine   — competitive advantage, complex rules

Supporting domain:
  InventoryTracking — important but not differentiating
  CustomerProfiles  — necessary but commodity

Generic domain (buy, don't build):
  PaymentProcessing → Stripe / Braintree
  EmailNotifications → SendGrid
  Search             → Elasticsearch
```

```csharp
// Each bounded context = one service
// "Order" means different things in different contexts
// Catalog: Product (name, description, images)
// Inventory: Product (stockLevel, location, warehouseId)
// Shipping: Product (weight, dimensions, hazmatClass)
// → each service has its own Product concept, no shared model
```

### The Strangler Fig Pattern

Named after the fig tree that grows around another tree, eventually replacing it:

```
Before: Monolith handles all requests

Step 1: Add a routing proxy (YARP, NGINX, AWS ALB)
  Proxy → all requests → Monolith (unchanged)

Step 2: Extract OrderService
  Proxy → POST /orders → OrderService (new)
  Proxy → all other requests → Monolith

Step 3: Extract PaymentService
  Proxy → POST /orders → OrderService
  Proxy → POST /payments → PaymentService
  Proxy → all other requests → Monolith

...

Final: Monolith gone, all traffic to new services
```

```csharp
// YARP (Yet Another Reverse Proxy) for .NET: route by path/method
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

// appsettings.json
{
  "ReverseProxy": {
    "Routes": {
      "orders-route": {
        "ClusterId": "order-service",
        "Match": { "Path": "/api/orders/{**catch-all}" }
      },
      "legacy-route": {
        "ClusterId": "monolith",
        "Match": { "Path": "/{**catch-all}" }    // ← catch-all for remaining traffic
      }
    },
    "Clusters": {
      "order-service": { "Destinations": { "default": { "Address": "http://orders-svc:8080/" } } },
      "monolith": { "Destinations": { "default": { "Address": "http://monolith:8080/" } } }
    }
  }
}
```

### Service Decomposition Anti-Patterns

**Decompose by technical layer** (Wrong):
```
DataService    — all database calls
BusinessService — all business logic
ApiService     — all HTTP endpoints
→ This is a distributed monolith — every feature requires all 3 services
```

**Too fine-grained** (Wrong):
```
UserFirstNameService
UserLastNameService
UserEmailService
→ Chatty services, high latency, impossible to maintain
```

**Correct: vertical slices**:
```
UserProfileService — owns ALL of: user data, profile logic, profile API
OrderService       — owns ALL of: order data, order logic, order API
```

## Code Example

```csharp
// Service decomposition health check: verify boundaries haven't been crossed
// NetArchTest ensures no cross-service internal dependencies

[Fact]
public void OrderService_ShouldNotDependOn_InventoryServiceInternals()
{
    var result = Types.InAssembly(typeof(Order).Assembly)
        .ShouldNot()
        .HaveDependencyOnAny("InventoryService.Internal")
        .GetResult();
    Assert.True(result.IsSuccessful, "OrderService references InventoryService internals");
}
```

## Common Follow-up Questions

- How do you handle cross-cutting data that appears in multiple services (e.g., "Customer Name")?
- What is the "two-pizza team" rule, and how does it relate to service size?
- How do you handle foreign key relationships when data is split across services?
- How do you choose which part of the monolith to extract first?
- What is the "anti-corruption layer" pattern, and when do you need it during service extraction?

## Common Mistakes / Pitfalls

- **Sharing a database between extracted services**: `SELECT o.*, c.Name FROM Orders o JOIN [InventoryDB].dbo.Products p ON...` — crossing DB boundaries destroys service independence.
- **Extracting a service before understanding its boundaries**: splitting too early when the domain is poorly understood results in constant service re-merges and re-splits.
- **Starting with the hardest service**: extract a low-risk, leaf-node service first (one with few dependencies) to prove the process before extracting core services.
- **No contract tests**: when a service is extracted, it needs consumer-driven contract tests (Pact) to verify the new service matches what the monolith used to provide.

## References

- [Decompose by business capability — microservices.io](https://microservices.io/patterns/decomposition/decompose-by-business-capability.html) (verify URL)
- [Strangler Fig — Martin Fowler](https://martinfowler.com/bliki/StranglerFigApplication.html) (verify URL)
- [See: microservices-vs-monolith.md](./microservices-vs-monolith.md)
- [See: bounded-context.md](./bounded-context.md)
