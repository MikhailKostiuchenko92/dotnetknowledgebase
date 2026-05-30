# Monolith vs Microservices

**Category:** System Design / Microservices
**Difficulty:** Junior
**Tags:** `monolith`, `microservices`, `architecture`, `team-topology`, `trade-offs`

## Question

> When would you choose a monolithic architecture over microservices, and vice versa? What are the real costs of microservices that teams often underestimate?

- Walk me through the factors you'd consider before splitting a monolith.
- What is a "distributed monolith" and how do you avoid it?

## Short Answer

A monolith is the right default for new products and small teams: it's simpler to develop, test, deploy, and debug. Microservices pay off when independent scalability, team autonomy, or technology heterogeneity becomes a genuine bottleneck — not a hypothetical one. The most underestimated costs of microservices are operational complexity (N services × observability, deployment, on-call), distributed systems problems (network partitions, eventual consistency), and the cognitive overhead of cross-service contracts. A "distributed monolith" — multiple services that must deploy together or share a database — gives you the worst of both worlds.

## Detailed Explanation

### Monolith: The Underrated Default

A well-structured monolith co-locates all business logic in a single deployable unit. It is:

- **Simple to run locally**: one process, one database, breakpoints work.
- **Cheap to test**: in-process calls, no mocking of HTTP clients.
- **Fast to iterate**: change spans multiple domains with no API contract negotiation.
- **Easy to refactor**: rename a method across the entire codebase in seconds.

The monolith is not a "bad" architecture. It is the optimal choice until specific scaling or organisational pressures justify the complexity of distribution.

### When Microservices Make Sense

| Signal | Example |
|--------|---------|
| Independent scalability | Checkout service needs 10× scale during Black Friday; catalogue does not |
| Team autonomy | Two teams of 30+ engineers blocked on each other's deployments |
| Technology heterogeneity | ML model serving in Python, core APIs in C# |
| Regulatory isolation | PCI DSS scope must be limited to a single payment service |
| Fault isolation | A bug in recommendations must not crash checkout |
| Different release cadences | Mobile API frozen for months; backend iterates daily |

### The Real Costs of Microservices

**1. Operational explosion**: N services × (logs, metrics, traces, alerts, dashboards, on-call runbooks, Kubernetes configs). A monolith has one deployment pipeline; 20 microservices have 20.

**2. Distributed systems problems**: network calls fail; timeouts, retries, idempotency, and partial failures become your problem. In a monolith, a function call either returns or throws — in a distributed system, it may just hang.

**3. Data management**: each service owning its database means no cross-service JOINs. Queries that were trivial SQL become multi-service aggregation with eventual consistency.

**4. Testing complexity**: integration tests require spinning up N services. Contract testing (Pact) adds discipline but requires investment.

**5. Latency tax**: in-process method calls are nanoseconds; cross-service HTTP/gRPC calls are milliseconds. A flow that traverses 5 services synchronously accumulates latency.

### The Distributed Monolith Anti-Pattern

A distributed monolith has the cost structure of microservices without the benefits:

| Symptom | Example |
|---------|---------|
| Shared database | Two services JOIN each other's tables |
| Synchronous deploy dependency | Service A's API change requires Service B to deploy first |
| Chatty synchronous calls | Service A calls B calls C calls D on every request |
| Shared domain model library | `Common.dll` imported by all services |

**Avoid by**: enforcing strict service boundaries (each service owns its data), async messaging for cross-service state propagation, and API versioning before any breaking change.

### Strangler Fig: Migrating a Monolith

Don't attempt a "big bang" rewrite. Use the Strangler Fig pattern:

1. Place an HTTP facade (reverse proxy) in front of the monolith.
2. Identify a single bounded context to extract (e.g., User Management).
3. Implement the new service; redirect specific routes to it via the facade.
4. Migrate data incrementally with a dual-write period.
5. Delete the extracted code from the monolith.

This allows incremental migration with each step being independently deployable and reversible.
See [strangler-fig-pattern.md](./strangler-fig-pattern.md) for details.

### Team Topology Alignment (Conway's Law)

> "Organisations which design systems are constrained to produce designs which are copies of the communication structures of those organisations."

A microservices architecture only makes sense if your team structure supports it. Ideal structure:
- Small, autonomous teams (5–8 people) each own one or two services end-to-end.
- Teams communicate via APIs, not Slack channels about shared code.
- Platform team provides infrastructure (CI/CD, observability) as a product.

If your organisation has a single back-end team, a monolith (or modular monolith) will likely outperform microservices.

### Modular Monolith: The Middle Ground

A modular monolith organises the codebase into strongly-bounded modules (assemblies in .NET) with clear internal APIs, but deploys as a single process. Benefits:
- Enforces boundaries at compile time (no circular dependencies).
- Simple to operate.
- Can be split into true microservices later, with boundaries already clear.

```
Solution
 ├── Api/                  (entry point)
 ├── Modules/
 │    ├── Orders/          (Orders.csproj — module boundary)
 │    ├── Inventory/       (Inventory.csproj)
 │    └── Payments/        (Payments.csproj — no direct reference from Orders)
 └── Infrastructure/
```

## Code Example

```csharp
// Modular monolith: enforcing bounded context isolation via project references
// Orders module cannot directly reference Inventory implementation —
// it must go through IInventoryService interface (defined in Contracts project)

// Contracts/IInventoryService.cs (shared interfaces, no implementations)
namespace Contracts.Inventory;

public interface IInventoryService
{
    Task<int> GetStockAsync(Guid productId, CancellationToken ct = default);
    Task ReserveAsync(Guid productId, int quantity, CancellationToken ct = default);
}

// Orders/Services/OrderService.cs — depends on interface, not Inventory internals
namespace Orders.Services;

using Contracts.Inventory;

public sealed class OrderService(IInventoryService inventory)
{
    public async Task PlaceOrderAsync(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var stock = await inventory.GetStockAsync(cmd.ProductId, ct);
        if (stock < cmd.Quantity)
            throw new InsufficientStockException(cmd.ProductId);

        await inventory.ReserveAsync(cmd.ProductId, cmd.Quantity, ct);
        // ... create order record
    }
}

// When ready to extract Inventory as a microservice:
// 1. Implement IInventoryService as an HTTP client that calls the new service
// 2. Swap DI registration — Orders module unchanged
// 3. Deploy Inventory service separately
// 4. Remove Inventory module from monolith solution

// Program.cs — dependency injection wires up the in-process implementation today
builder.Services.AddScoped<IInventoryService, Inventory.Services.InventoryService>();
// Future: builder.Services.AddHttpClient<IInventoryService, InventoryHttpClient>(...);
```

## Common Follow-up Questions

- How do you handle transactions that span multiple microservices (e.g., place order AND reserve inventory)?
- What is the Saga pattern and when is it preferable to a two-phase commit?
- How do you version inter-service APIs without coordinating deployments?
- What metrics would you monitor to decide when a module in a monolith is "ready" to be extracted?
- How does Domain-Driven Design (bounded contexts) guide microservice boundaries?

## Common Mistakes / Pitfalls

- **Microservices-first for a new product**: premature decomposition creates artificial boundaries before the domain is well understood; incorrect boundaries are expensive to fix in a distributed system.
- **One service per entity**: `UserService`, `AddressService`, `PhoneNumberService` — these are not bounded contexts, they are database tables in disguise.
- **Shared database across services**: the fastest path to a distributed monolith; each service must own its own schema.
- **Synchronous chain of calls**: `A → B → C → D` multiplies latency and couples availability (if D has 99.9% uptime, A–D chain has 99.6%).
- **Skipping contract testing**: without consumer-driven contracts (Pact), a provider change silently breaks consumers.
- **Splitting before establishing observability**: you need distributed tracing, structured logs, and health checks in place before you can diagnose production issues across services.

## References

- [Microservices — Martin Fowler](https://martinfowler.com/articles/microservices.html)
- [Modular Monolith — Kamil Grzybek](https://www.kamilgrzybek.com/design/modular-monolith-primer/) (verify URL)
- [Team Topologies — Matthew Skelton & Manuel Pais (book summary)](https://teamtopologies.com/key-concepts)
- [.NET Microservices Architecture Guide — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/)
- [See: domain-driven-microservices.md](./domain-driven-microservices.md)
- [See: strangler-fig-pattern.md](./strangler-fig-pattern.md)
