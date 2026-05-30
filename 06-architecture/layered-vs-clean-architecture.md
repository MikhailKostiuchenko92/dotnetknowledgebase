# Layered vs Clean Architecture

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🟢 Junior
**Tags:** `clean-architecture`, `layered-architecture`, `n-tier`, `dependency-direction`, `separation-of-concerns`

## Question

> What is the difference between traditional N-tier layered architecture and Clean Architecture? Why does Clean Architecture reverse the dependency direction, and what problem does that solve?

## Short Answer

Traditional N-tier architecture stacks layers (UI → BLL → DAL → DB) where each layer depends on the one below it, coupling the domain model to infrastructure concerns. Clean Architecture (Robert C. Martin) inverts this: the domain and application layers sit at the center with no dependencies on infrastructure or UI. Outer rings (infrastructure, presentation) depend inward — never the reverse. This means the domain model can be tested and evolved independently of databases, frameworks, and delivery mechanisms.

## Detailed Explanation

### Traditional N-Tier Layering

```
┌──────────────────────────┐
│   Presentation (UI)      │  → depends on →
├──────────────────────────┤
│   Business Logic (BLL)   │  → depends on →
├──────────────────────────┤
│   Data Access (DAL)      │  → depends on →
├──────────────────────────┤
│   Database               │
└──────────────────────────┘
```

The flow of dependencies goes **downward**. The key problem: the **domain model leaks infrastructure concerns**. The BLL often references EF Core entities, ADO.NET types, or ORM-specific attributes directly. This creates tight coupling — changing the database layer can ripple through the entire application.

### Clean Architecture

```
              ┌───────────────────────┐
              │    Infrastructure     │
              │  ┌─────────────────┐  │
              │  │   Application   │  │
              │  │  ┌───────────┐  │  │
              │  │  │  Domain   │  │  │
              │  │  └───────────┘  │  │
              │  └─────────────────┘  │
              └───────────────────────┘
                    ↑ all arrows point inward
```

The **Dependency Rule**: source code dependencies must point inward only. The Domain knows nothing about Application; Application knows nothing about Infrastructure.

### The Dependency Inversion Principle (DIP)

Clean Architecture enforces DIP at the architectural level. Instead of:

```
Application → EF Core DbContext (concrete)
```

It uses:

```
Application → IOrderRepository (abstraction defined in Application layer)
               ↑ implemented by
Infrastructure → EfCoreOrderRepository (depends on EF Core)
```

The **interface lives in the inner ring**; the **implementation lives in the outer ring**. Dependency Injection wires them together at startup.

### Comparison Table

| Aspect | N-Tier Layered | Clean Architecture |
|--------|---------------|-------------------|
| Dependency direction | Top-down (UI → DB) | Inward (all → Domain) |
| Domain model purity | Polluted with ORM/framework attributes | Framework-free |
| Testability | BLL requires mocking DAL plumbing | Domain/Application tested in isolation |
| Framework coupling | High — BLL often references EF Core directly | Low — infrastructure at the edge |
| Learning curve | Lower | Higher initial investment |
| Best for | Simple CRUD apps, small teams | Complex domain, long-lived products |

### When to Use Each

**N-Tier is fine when:**
- The application is primarily CRUD with minimal business rules
- The team is small and the codebase is short-lived
- Simplicity and speed-to-market outweigh long-term flexibility

**Clean Architecture pays off when:**
- The domain has real business rules that change independently of the DB
- Multiple delivery mechanisms (Web API + background jobs + CLI) share the same logic
- The database or ORM might change in the future
- Testability without infrastructure is a priority

> **Warning**: Clean Architecture has overhead. A simple CRUD API with 5 endpoints doesn't need 4 projects and abstract repositories. Apply it where complexity justifies the cost.

## Code Example

```csharp
// N-TIER: Application layer directly references EF Core
// BAD — BLL is coupled to infrastructure
public class OrderService(AppDbContext db)
{
    public async Task<Order> GetOrderAsync(int id)
        => await db.Orders.FindAsync(id) ?? throw new KeyNotFoundException();
}

// CLEAN ARCHITECTURE: Application layer depends on an abstraction
// GOOD — Application only knows about the interface, defined in Application layer
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(int id, CancellationToken ct = default);
}

// Application layer use-case
public class GetOrderQuery(int OrderId) : IRequest<OrderDto>;

public class GetOrderHandler(IOrderRepository orders) 
    : IRequestHandler<GetOrderQuery, OrderDto>
{
    public async Task<OrderDto> Handle(GetOrderQuery q, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(q.OrderId, ct)
            ?? throw new NotFoundException(nameof(Order), q.OrderId);
        return new OrderDto(order.Id, order.Total, order.Status);
    }
}

// Infrastructure layer implements the interface (EF Core detail stays here)
public class EfOrderRepository(AppDbContext db) : IOrderRepository
{
    public Task<Order?> GetByIdAsync(int id, CancellationToken ct)
        => db.Orders.FindAsync([id], ct).AsTask();
}
```

## Common Follow-up Questions

- How do you wire up the Clean Architecture layers in an ASP.NET Core DI container?
- Where do validators (FluentValidation) live — Application or Domain?
- What is the difference between Clean Architecture and Onion Architecture?
- How do you handle cross-cutting concerns (logging, validation) in Clean Architecture?
- Can you use Clean Architecture with a single-project structure (Vertical Slice Architecture)?

## Common Mistakes / Pitfalls

- **Putting interfaces in the wrong layer**: `IOrderRepository` must be defined in the Application (or Domain) layer, not in Infrastructure. Placing it in Infrastructure reverses the intended dependency.
- **EF Core entities escaping to the Domain**: when your `Order` entity has `[Column]` or `[Table]` attributes or inherits from a base class from EF Core, the domain is no longer framework-free.
- **Over-engineering small apps**: applying Clean Architecture to a simple admin CRUD panel adds 3 extra projects and 10 extra files per feature for no domain benefit.
- **Confusing "layers" with "projects"**: you can have Clean Architecture in a single project using folders; multiple projects enforce the dependency rule at the compiler level but aren't required.

## References

- [Clean Architecture — Robert C. Martin (The Clean Code Blog)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) (verify URL)
- [Clean Architecture with ASP.NET Core — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures)
- [See: dependency-inversion-in-architecture.md](./dependency-inversion-in-architecture.md)
- [See: clean-architecture-in-dotnet.md](./clean-architecture-in-dotnet.md)
- [See: onion-architecture.md](./onion-architecture.md)
