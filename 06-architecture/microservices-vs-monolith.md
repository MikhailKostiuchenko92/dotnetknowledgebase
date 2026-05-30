# Microservices vs Monolith

**Category:** Architecture / Microservices
**Difficulty:** 🟢 Junior
**Tags:** `microservices`, `monolith`, `Conway's-law`, `distributed-systems`, `trade-offs`, `scalability`

## Question

> What are the trade-offs between a microservices architecture and a monolith? When is a monolith the right choice, and what are the most common fallacies about microservices?

## Short Answer

Microservices offer independent deployment, polyglot technology choices, and per-service scaling — but at the cost of distributed system complexity: network failures, eventual consistency, distributed tracing, operational overhead, and significantly higher infrastructure cost. A **modular monolith** (single deployable, internal modules with enforced boundaries) delivers most of the organisational benefits without the distributed systems tax. The "start with microservices" advice is almost always wrong for new products — Conway's Law means your architecture will reflect your team structure, and prematurely splitting a monolith creates distributed monolith hell.

## Detailed Explanation

### Monolith Advantages

- **Single deployment**: one build, one deploy, one log stream, one debugger
- **Simple transactions**: ACID across all tables in a single DB
- **Easy refactoring**: rename a class with an IDE refactor across all code
- **Simpler testing**: one integration test database, no service mocking
- **Faster initial development**: no inter-service contracts, no API versioning

### Microservices Advantages

- **Independent deployment**: deploy OrderService without touching PaymentService
- **Independent scaling**: scale ProductSearchService 10x without scaling CheckoutService
- **Isolation of failure**: a crash in RecommendationService doesn't bring down CheckoutService
- **Technology choice**: OrderService in .NET, ML scoring in Python
- **Team autonomy**: team A owns OrderService end-to-end; no coordination with team B

### The Distributed Systems Tax

Every microservices benefit comes with a cost:

| Benefit | Cost |
|---------|------|
| Independent deployment | API versioning contracts, deployment pipelines per service |
| Independent scaling | Kubernetes, service discovery, load balancer per service |
| Failure isolation | Circuit breakers, retries, timeouts, fallbacks, distributed tracing |
| Tech choice | Polyglot expertise, cross-language debugging |
| Data isolation | No cross-service ACID transactions, sagas, eventual consistency |

### Conway's Law

> "Any organization that designs a system (defined broadly) will produce a design whose structure is a copy of the organization's communication structure." — Mel Conway, 1967

```
2 devs → 1 monolith (natural)
5-person team → modular monolith (reasonable)
50 people, 5 teams → microservices (each team owns a service)
500 people, 50 teams → microservices are almost mandatory (coordination cost otherwise unbearable)
```

Microservices make sense when **team autonomy** is the primary driver — not technology or performance.

### Modular Monolith: Best of Both Worlds

For teams under ~50 developers:

```csharp
// Modular monolith: separate project per module, enforced by build
// Each module has its own public API contract (interfaces only)
MyApp.Modules.Orders/
  Public/
    IOrderModule.cs         ← interface: what other modules can call
  Internal/
    OrderService.cs         ← implementation: hidden from other modules
    OrderRepository.cs
  OrdersModule.cs           ← DI registration, module bootstrap

// Cross-module calls only through public interfaces
// Never reference Internal classes from another module
// Boundary violation fails NetArchTest in CI
```

### Common Fallacies

1. **"Microservices are the future, monoliths are legacy"** — Amazon, Netflix, and Google did NOT start with microservices. They migrated to them after hitting scale that justifies the complexity.
2. **"Microservices are easier to scale"** — Scaling a monolith's DB with read replicas is usually simpler than coordinating 10 independent services.
3. **"Each microservice should have its own database"** — Correct principle, but implementing this with eventual consistency requires sagas, outbox patterns, and significant operational investment.
4. **"Microservices make refactoring easier"** — Changing an API contract between two services requires coordinating deployment of both services and potentially versioning the API.

## Code Example

```csharp
// Strangler Fig: start with a monolith, extract services incrementally
// Step 1: Identify the boundary in the monolith

// Before (everything in one app):
public class OrderService(IProductRepository products, IPaymentService payments) { ... }

// Step 2: Define the public contract (interface + DTOs)
// (This will become the API contract when extracted)
public interface IOrderModule
{
    Task<PlaceOrderResult> PlaceOrderAsync(PlaceOrderRequest req, CancellationToken ct);
    Task<OrderDto?> GetOrderAsync(int orderId, CancellationToken ct);
}

// Step 3 (later): Replace IOrderModule implementation with HTTP client
// The rest of the monolith never knew the difference
public class OrderServiceHttpClient(HttpClient http) : IOrderModule
{
    public Task<PlaceOrderResult> PlaceOrderAsync(PlaceOrderRequest req, CancellationToken ct)
        => http.PostAsJsonAsync<PlaceOrderResult>("/orders", req, ct);
}
```

## Common Follow-up Questions

- What is the "distributed monolith" anti-pattern — how do you identify one?
- How do you decide when to extract a service from a modular monolith?
- What is the Strangler Fig pattern, and how does it de-risk microservice extraction?
- How do cross-cutting concerns (auth, logging, tracing) work in a microservices architecture?
- What team/org size typically justifies a microservices architecture?

## Common Mistakes / Pitfalls

- **Starting with microservices**: premature decomposition before domain boundaries are understood leads to incorrect service splits that are painful to change.
- **Shared database across "microservices"**: if two services share a DB schema, they're not microservices — they're a distributed monolith with extra overhead.
- **Over-fragmenting services**: 30 services owned by a 5-person team means more coordination cost, not less. Services should align with team boundaries (Conway's Law).
- **Treating the network as reliable**: in a monolith, calls between components are in-process and instant. In microservices, every call can fail, time out, or return stale data.

## References

- [Monolith to Microservices — Sam Newman](https://samnewman.io/books/monolith-to-microservices/) (verify URL)
- [Microservices — Martin Fowler](https://martinfowler.com/articles/microservices.html) (verify URL)
- [See: modular-monolith-design.md](./modular-monolith-design.md)
- [See: service-decomposition-strategies.md](./service-decomposition-strategies.md)
