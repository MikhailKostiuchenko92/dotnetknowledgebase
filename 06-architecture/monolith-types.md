# Monolith Types

**Category:** Architecture / Modular Monolith
**Difficulty:** 🟢 Junior
**Tags:** `monolith`, `big-ball-of-mud`, `modular-monolith`, `microservices`, `architecture-evolution`, `Conway's-Law`

## Question

> What are the different types of monolith architectures — big ball of mud, well-structured monolith, and modular monolith? When is a monolith a better choice than microservices?

## Short Answer

**Big ball of mud**: no clear structure, everything depends on everything — expensive to change. **Well-structured monolith**: layered/Clean Architecture within a single deployable, clear separation of concerns — the correct starting point for most applications. **Modular monolith**: well-structured plus enforced module boundaries with explicit public APIs between modules — enables future service extraction. A monolith is often better than microservices when: the team is small (≤5 developers), the domain is not yet well understood, deployment simplicity is required, or latency between services would be prohibitive.

## Detailed Explanation

### Big Ball of Mud

```
Characteristics:
  - No layering: controllers call repositories call services call other controllers
  - Shared mutable state across "features"
  - DB schema owned by no-one (every module reads any table)
  - Every change risks regressions everywhere (no boundaries)
  - Testing is near impossible without spinning up the full application

Origin: deadline pressure + no architectural governance over years of growth
Symptoms: "touch anything, break something unrelated"
```

### Well-Structured Monolith

```
Characteristics:
  - Clean Architecture or Layered Architecture
  - Domain / Application / Infrastructure / Presentation layers
  - Dependency inversion: inner layers don't depend on outer layers
  - Testable: domain + application layers are pure, no framework coupling

Limitations:
  - Feature code still physically adjacent to other features
  - No enforced boundaries between e.g. "Orders" and "Inventory"
  - Refactoring grows harder as codebase grows
```

### Modular Monolith

```
Characteristics:
  - Same single deployable process as well-structured monolith
  - Features/subdomains organized as isolated modules
  - Each module has:
    - A public API (interface contracts, DTOs exported outside the module)
    - Internal implementation (hidden from other modules)
    - Its own DB schema/tables (not shared with other modules)
  - Communication between modules via public interfaces only (no direct class calls across boundaries)
  - Enforced by: visibility modifiers (internal), NetArchTest rules, solution structure

Benefits:
  - Preserves simplicity of single-process deployment
  - Each module can evolve and be tested independently
  - Migration path: a well-bounded module can become a microservice later (if justified)
```

### Monolith vs Microservices Decision

| Factor | Monolith | Microservices |
|--------|---------|---------------|
| **Team size** | ≤ 10 developers | 10+ (≥1 team per service) |
| **Domain clarity** | Unclear / evolving | Well-understood, stable |
| **Deployment** | Single artifact | Per-service CI/CD pipelines |
| **Operational complexity** | Low | High (distributed tracing, service mesh, etc.) |
| **Data consistency** | ACID transactions | Eventual consistency only |
| **Latency budget** | N/A (in-process) | Cross-service HTTP/gRPC adds latency |
| **Scaling granularity** | Whole application | Per service (targeted scaling) |
| **Refactoring cost** | Medium | Very high (contract changes across teams) |

> **Guidance**: Start with a modular monolith. Extract services only when a specific module has proven it needs independent scaling, deployment cadence, or team ownership — not because microservices are "modern."

### Conway's Law

```
"Organizations which design systems are constrained to produce designs which are
copies of the communication structures of those organizations."
— Melvin Conway

Implication:
  5-person startup → monolith makes sense (one team, one codebase)
  200-person company with 10 teams → microservices map to team boundaries naturally
  Forcing microservices on a 5-person team creates artificial coordination overhead
```

## Code Example

```csharp
// Modular monolith solution structure (Visual Studio / .NET solution)
// Each module is a separate project within one solution:

// MyApp.sln
// ├── src/
// │   ├── MyApp.Bootstrapper/          ← single entry point (Program.cs)
// │   ├── MyApp.Orders/                ← Orders module (public API + internals)
// │   │   ├── OrdersModule.cs          ← registers DI, exposes IOrderService
// │   │   ├── Api/ (internal)
// │   │   └── Internal/ (internal)
// │   ├── MyApp.Inventory/             ← Inventory module
// │   │   ├── InventoryModule.cs
// │   │   └── ...
// │   └── MyApp.SharedKernel/          ← value objects, base classes, shared interfaces
// └── tests/
//     ├── MyApp.Orders.Tests/
//     └── MyApp.Inventory.Tests/

// Cross-module dependency: Orders → Inventory via public interface only
// MyApp.Orders references MyApp.Inventory ONLY for public API types
// NOT for: InventoryDbContext, InventoryRepository, or any internal class
```

## Common Follow-up Questions

- What is the "Monolith First" approach and who popularized it?
- How does a modular monolith differ from microservices in terms of data isolation?
- What is the "distributed monolith" anti-pattern — worse than a regular monolith?
- How do you extract a module from a modular monolith into a microservice?
- Can a modular monolith scale horizontally — what are the limits?

## Common Mistakes / Pitfalls

- **Skipping to microservices without domain knowledge**: building microservices before understanding the domain leads to wrong service boundaries — expensive to fix (distributed system with wrong split is worse than a monolith).
- **Modular monolith with shared DB schema**: "modular monolith" where all modules share the same tables with no schema isolation is just a well-organized big ball of mud. Module data isolation is non-negotiable.
- **Calling it modular without enforcing boundaries**: organizing code into folders named "Orders" and "Inventory" doesn't enforce module isolation. Use access modifiers (`internal`) + architectural tests (NetArchTest) to enforce boundaries.
- **Distributed monolith**: a "microservices" deployment where services are tightly coupled via shared databases or synchronous chains — you get the operational complexity of microservices with none of the independence benefits.

## References

- [Monolith First — Martin Fowler](https://martinfowler.com/bliki/MonolithFirst.html) (verify URL)
- [Modular Monolith — Kamil Grzybek](https://www.kamilgrzybek.com/blog/posts/modular-monolith-primer) (verify URL)
- [See: modular-monolith-design.md](./modular-monolith-design.md)
- [See: microservices-vs-monolith.md](./microservices-vs-monolith.md)
