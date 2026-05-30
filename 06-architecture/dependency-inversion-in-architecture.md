# Dependency Inversion in Architecture

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🟢 Junior
**Tags:** `dependency-inversion`, `DIP`, `SOLID`, `clean-architecture`, `abstractions`, `policy-vs-detail`

## Question

> What is the Dependency Inversion Principle (DIP) at the architectural level? How does "high-level modules must not depend on low-level modules" apply across architectural layers in a .NET application?

## Short Answer

The Dependency Inversion Principle states that high-level policy modules (business rules, use cases) must not depend on low-level detail modules (databases, file systems, HTTP). Both should depend on abstractions — interfaces or abstract types. At the architectural level this means the domain and application layers define interfaces that infrastructure layers implement, so the arrow of dependency always points toward policy, never toward detail. This lets you swap out databases, message brokers, or email providers without touching business logic.

## Detailed Explanation

### Policy vs Detail

Robert C. Martin's framing is built on one distinction:

- **Policy** = what the system does (business rules, use-case logic)
- **Detail** = how it does it (SQL Server, SendGrid, RabbitMQ, HTTP)

Details are volatile — they change frequently. Policies are stable. DIP says: **stable things must not depend on volatile things**. Instead, introduce an abstraction at the boundary between them.

### Without DIP (Detail-Coupling)

```
OrderService → SqlOrderRepository → SqlConnection → SQL Server
     ↑ policy             ↑ detail                    ↑ volatile infrastructure
```

If you replace SQL Server with PostgreSQL, you change `SqlOrderRepository` — but also risk rippling changes up into `OrderService` if the boundary leaks.

### With DIP Applied

```
OrderService → IOrderRepository ← EfOrderRepository → SQL Server
     ↑ policy    ↑ abstraction      ↑ detail
```

`OrderService` (policy) depends on `IOrderRepository` (abstraction). `EfOrderRepository` (detail) also depends on the same abstraction — it *implements* it. The abstraction **belongs to the policy layer**, not to the detail layer. This is the key difference from a simple "code to interfaces" approach: the interface is defined where it's *used*, not where it's *implemented*.

### Architectural Dependency Rule

In Clean / Onion / Hexagonal architectures the DIP manifests as a dependency rule:

```
Domain (innermost)
  ← Application (defines use cases + interfaces)
    ← Infrastructure (implements interfaces)
      ← Presentation (UI, controllers, consumers)
```

All arrows point inward. No inner layer references an outer layer.

### Practical .NET Solution Layout

```
src/
  YourApp.Domain/          ← entities, value objects, domain events
  YourApp.Application/     ← use cases, IOrderRepository, IEmailSender
  YourApp.Infrastructure/  ← EfOrderRepository, SendGridEmailSender
  YourApp.Api/             ← controllers, DI composition root
```

Project references:
- `Domain` → nothing
- `Application` → `Domain`
- `Infrastructure` → `Application` + `Domain`
- `Api` → `Infrastructure` + `Application`

`Infrastructure` never references `Api`; `Application` never references `Infrastructure`.

### Composition Root

The only place where concrete types are wired to interfaces is the **composition root** — typically `Program.cs` or an extension method in the `Api` project:

```csharp
builder.Services.AddScoped<IOrderRepository, EfOrderRepository>();
builder.Services.AddScoped<IEmailSender, SendGridEmailSender>();
```

Business logic never calls `new EfOrderRepository()` — it only knows `IOrderRepository`.

## Code Example

```csharp
// Domain layer — pure C#, no framework dependencies
namespace YourApp.Domain;

public class Order
{
    public int Id { get; private set; }
    public decimal Total { get; private set; }
    public string Status { get; private set; } = "Pending";

    public void Cancel() 
    {
        if (Status != "Pending") throw new InvalidOperationException("Can only cancel pending orders.");
        Status = "Cancelled";
    }
}

// Application layer — defines the abstraction (interface lives HERE, not in Infrastructure)
namespace YourApp.Application.Contracts;

public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(int id, CancellationToken ct = default);
    Task SaveAsync(Order order, CancellationToken ct = default);
}

// Application use-case — depends only on the abstraction
namespace YourApp.Application.UseCases;

public class CancelOrderCommand(int OrderId) : IRequest;

public class CancelOrderHandler(IOrderRepository orders) : IRequestHandler<CancelOrderCommand>
{
    public async Task Handle(CancelOrderCommand cmd, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(cmd.OrderId, ct)
            ?? throw new NotFoundException(nameof(Order), cmd.OrderId);
        order.Cancel();
        await orders.SaveAsync(order, ct);
    }
}

// Infrastructure layer — implements the abstraction (depends inward on Application)
namespace YourApp.Infrastructure.Persistence;

public class EfOrderRepository(AppDbContext db) : IOrderRepository
{
    public Task<Order?> GetByIdAsync(int id, CancellationToken ct)
        => db.Orders.FindAsync([id], ct).AsTask();

    public async Task SaveAsync(Order order, CancellationToken ct)
    {
        db.Orders.Update(order);
        await db.SaveChangesAsync(ct);
    }
}
```

## Common Follow-up Questions

- How is DIP different from the Dependency Injection (DI) technique?
- Where should `IOrderRepository` be defined — in Domain or Application?
- What happens when you apply DIP and later need to swap EF Core for Dapper?
- How do you handle multi-implementation scenarios (e.g., `IEmailSender` with SendGrid and SMTP)?
- Can DIP be enforced at compile time without using separate projects?

## Common Mistakes / Pitfalls

- **Defining interfaces in Infrastructure**: if `IOrderRepository` lives in the `Infrastructure` project, then `Application` must reference `Infrastructure` to use it — reversing the intended direction.
- **Confusing DI (technique) with DIP (principle)**: dependency injection is a mechanism that *enables* DIP; you can use DI without DIP (e.g., injecting a concrete `SqlOrderRepository` directly).
- **Abstracting everything "just in case"**: DIP is valuable at architectural boundaries that are likely to change. Abstracting `DateTime.UtcNow` or a simple string formatter is premature — apply DIP where volatility actually exists.
- **Leaking infrastructure types through abstractions**: an `IOrderRepository` that returns `IQueryable<Order>` forces callers to depend on LINQ-to-Entities semantics, re-coupling application logic to EF Core behavior.

## References

- [Dependency Inversion Principle — Microsoft .NET docs](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles#dependency-inversion)
- [Clean Architecture — Robert C. Martin (The Clean Code Blog)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) (verify URL)
- [See: layered-vs-clean-architecture.md](./layered-vs-clean-architecture.md)
- [See: clean-architecture-in-dotnet.md](./clean-architecture-in-dotnet.md)
- [See: ports-and-adapters.md](./ports-and-adapters.md)
