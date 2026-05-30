# DDD and Microservices

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🔴 Senior
**Tags:** `DDD`, `microservices`, `bounded-context`, `service-boundaries`, `Conway's-law`, `context-map`

## Question

> How does Domain-Driven Design inform microservice decomposition? Should every bounded context become a microservice? When do you break the "one bounded context per service" guideline?

## Short Answer

DDD's bounded contexts are the primary guide for microservice decomposition: a bounded context defines where a model is internally consistent and where a Ubiquitous Language applies — these same boundaries make natural service boundaries. However, **one bounded context ≠ always one microservice**. A single service can host multiple small bounded contexts if they share the same deployment lifecycle, team, and operational characteristics. Conversely, a large complex context might justify splitting into multiple services for scalability. The guiding principle is: **deploy together what changes together**, and **align service boundaries with team boundaries** (Conway's Law).

## Detailed Explanation

### Why Bounded Contexts Map Well to Microservices

A bounded context is already designed to be internally consistent and externally loosely coupled. These properties directly enable:

- **Independent deployability**: the context defines its own model — no cross-boundary DB joins, no shared entity classes
- **Team autonomy**: each team owns their context's model, API, and database
- **Technology freedom**: each service can choose its persistence model, language, framework
- **Failure isolation**: a bounded context failure doesn't cascade if integration is via async messaging

### The Mapping Rule

```
Subdomain (business problem space) → Bounded Context (solution space) → Microservice (deployment unit)

Core subdomain:       Orders       → Orders Context      → orders-service
Supporting subdomain: Notifications → Notif. Context    → notification-service
Generic subdomain:    Auth         → Use Auth0/Azure AD  → external SaaS (not a service)
```

### When to Deviate: Multiple Contexts in One Service

**Merge contexts into one service when**:
- Both contexts are owned by the same team and change together frequently
- Operational cost of a separate service (CI/CD, monitoring, networking) exceeds the isolation benefit
- The contexts are so small that a microservice would be "nano-service" level (<500 LOC)

```
// Orders + Pricing: both owned by the same team, always deployed together
// ❌ Over-decomposition:
orders-service
pricing-service (tiny — 2 aggregates, 1 team)

// ✅ Pragmatic:
order-management-service
  ├── Orders bounded context (module)
  └── Pricing bounded context (module) ← modular monolith within one service
```

### When to Deviate: One Context Across Multiple Services

**Split a context across services when**:
- A single bounded context has dramatically different scaling requirements for different operations
- A section of the context has highly sensitive security requirements needing isolation
- Team size demands dividing one context among sub-teams

```
// Cart + Checkout: both in "Shopping" context, but very different scale
// Cart must handle 100k concurrent users; Checkout handles 10k/hour
shopping-service ← too slow to scale just Checkout
↓ split
cart-service      ← scales horizontally for high concurrency
checkout-service  ← fewer instances, more complex transaction logic
```

### Conway's Law and Service Design

Conway's Law: *organizations produce systems that mirror their communication structures*. In practice:

- If two teams own a "single service", they'll fight over API changes, DB schemas, and deployment schedules
- Design services that one team can own end-to-end: API + DB + CI/CD + on-call

```
// ❌ Splits across team boundaries create coordination overhead
Team A: owns orders-service + inventory-service
Team B: also contributes to orders-service for shipping features

// ✅ Aligned with team ownership
Team A: orders-service (full ownership)
Team B: shipping-service (full ownership)
       → integration via events/API only
```

### Context Map to Service Map

Convert a DDD context map to a microservice architecture:

```
Context Map                     →  Service Architecture
────────────────────────────────────────────────────────
Orders Context                  →  orders-service
  OHS/PL → Shipping Context     →  shipping-service
  ACL ← Legacy ERP              →  erp-adapter-service (strangler fig)
Payments Context                →  payments-service (or use Stripe directly)
CRM Context                     →  crm-service
Notifications Context           →  notification-service
Shared Kernel: Money, Address   →  shared-contracts NuGet package
```

### Integration Patterns in Code

```csharp
// Orders service publishes integration event (Published Language)
public record OrderConfirmedIntegrationEvent(int OrderId, decimal Total, string Currency);

// Shipping service subscribes (consumer-side ACL)
public class OrderConfirmedConsumer(IShipmentService shipments)
    : IConsumer<OrderConfirmedIntegrationEvent>
{
    public Task Consume(ConsumeContext<OrderConfirmedIntegrationEvent> ctx)
    {
        // ACL: translate from Orders' language to Shipping's language
        var request = new ShipmentScheduleRequest(
            SourceOrderId: new SourceOrderId(ctx.Message.OrderId),
            EstimatedValue: new ShippingDeclaredValue(ctx.Message.Total, ctx.Message.Currency));
        return shipments.ScheduleAsync(request);
    }
}
```

## Code Example

```csharp
// Service boundary test: Orders service should NOT reference Shipping types
// Enforced by NetArchTest or project structure
[Fact]
public void Orders_Service_Must_Not_Reference_Shipping_Domain()
{
    var result = Types.InAssembly(typeof(Order).Assembly)
        .ShouldNot()
        .HaveDependencyOnAny("YourCompany.Shipping.Domain", "YourCompany.Shipping.Application")
        .GetResult();

    Assert.True(result.IsSuccessful,
        $"Service boundary violation: {string.Join(", ", result.FailingTypeNames ?? [])}");
}

// Integration: Orders → Shipping via Published Language contract only
// Both services reference the shared contract package, not each other's domain
// YourCompany.Contracts NuGet:
public record OrderConfirmedEvent(int OrderId, decimal TotalAmount, string Currency);  // shared DTO
```

## Common Follow-up Questions

- How do you handle a use case that requires strongly consistent data across two microservices?
- What is the "two-pizza team" rule, and how does it apply to service sizing?
- How do you decompose a legacy monolith into microservices using DDD — where do you start?
- How does Saga pattern (orchestration vs choreography) work with DDD aggregates in microservices?
- What is the difference between a bounded context and an API gateway backend-for-frontend (BFF)?

## Common Mistakes / Pitfalls

- **CRUD microservices**: decomposing by entity (`product-service`, `user-service`, `order-service`) rather than business capability — this leads to distributed monoliths where every feature change requires coordinating multiple services.
- **Shared database between services**: two services sharing tables defeats service autonomy. Any schema change requires both services to deploy simultaneously.
- **Nano-services**: a microservice for a single aggregate with 2 commands is an operational anti-pattern — you get all the distributed complexity with none of the independent scaling benefit.
- **Ignoring team topology**: a perfect bounded context design mapped to a service structure that doesn't match team boundaries will be violated within weeks by coordination friction.

## References

- [Microservices and DDD — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/architect-microservice-container-applications/identify-microservice-domain-model-boundaries)
- [Conway's Law — Martin Fowler](https://martinfowler.com/bliki/ConwaysLaw.html) (verify URL)
- [See: bounded-context.md](./bounded-context.md)
- [See: microservices-vs-monolith.md](./microservices-vs-monolith.md)
- [See: choreography-vs-orchestration.md](./choreography-vs-orchestration.md)
