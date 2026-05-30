# Domain Layer Design

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🟡 Middle
**Tags:** `domain-layer`, `clean-architecture`, `DDD`, `rich-domain-model`, `anemic-model`, `business-rules`

## Question

> What is the Domain layer's role in Clean Architecture? How do you design a domain model in .NET that is pure (no framework dependencies), and what is the difference between a rich domain model and an anemic domain model?

## Short Answer

The Domain layer is the innermost ring in Clean Architecture — it contains business entities, value objects, domain events, and the invariant rules that govern the system. It has **zero dependencies** on frameworks, EF Core, or infrastructure. A **rich domain model** enforces business rules inside the entities themselves via methods (`order.Cancel()`, `order.AddLine(product, qty)`). An **anemic domain model** has entities that are just data bags — public setters, no behavior — with all logic scattered in service classes, making rules easy to bypass.

## Detailed Explanation

### What Belongs in the Domain Layer

| Concept | Example | Description |
|---------|---------|-------------|
| Entities | `Order`, `Product`, `Customer` | Objects with identity; mutable via methods |
| Value Objects | `Money`, `Address`, `Email`, `OrderId` | Structural equality, immutable |
| Aggregates | `Order` (root) + `OrderLine` | Consistency boundary |
| Domain Events | `OrderPlacedEvent`, `PaymentFailedEvent` | Something that happened in the domain |
| Domain Services | `PricingService`, `TaxCalculator` | Stateless operations spanning multiple aggregates |
| Domain Exceptions | `InsufficientStockException`, `OrderAlreadyCancelledException` | Business rule violations |
| Interfaces for infra | `IOrderRepository` (if placed in Domain, not Application) | Contracts defined inward |

### Zero Framework Dependencies

The Domain project `.csproj` should contain no third-party NuGet packages:

```xml
<!-- YourApp.Domain.csproj — CORRECT -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
  </PropertyGroup>
  <!-- NO PackageReference here — pure C# only -->
</Project>
```

No `Microsoft.EntityFrameworkCore`, no `MediatR`, no `Newtonsoft.Json`. This ensures:
1. The domain model compiles and runs anywhere
2. Domain tests run in milliseconds with no setup
3. Replacing EF Core or a message broker doesn't touch a single domain file

### Rich vs Anemic Domain Model

**Anemic (anti-pattern)**:
```csharp
// Entity is a data bag — no behavior
public class Order
{
    public int Id { get; set; }
    public string Status { get; set; } = "Pending";  // ← public setter = no invariant
    public decimal Total { get; set; }
}

// Logic scattered across services — can be bypassed
public class OrderService
{
    public void Cancel(Order order)
    {
        if (order.Status != "Pending") throw new InvalidOperationException();
        order.Status = "Cancelled";  // ← external mutation
    }
}
```

**Rich domain model**:
```csharp
public class Order
{
    public int Id { get; private set; }
    public string Status { get; private set; } = "Pending";
    public decimal Total { get; private set; }
    private readonly List<OrderLine> _lines = [];
    public IReadOnlyList<OrderLine> Lines => _lines;

    // Behavior lives on the entity — invariants are always enforced
    public void Cancel()
    {
        if (Status is not "Pending")
            throw new OrderAlreadyCancelledException(Id);
        Status = "Cancelled";
        AddDomainEvent(new OrderCancelledEvent(Id));
    }

    public void AddLine(Product product, int quantity)
    {
        if (quantity <= 0) throw new ArgumentOutOfRangeException(nameof(quantity));
        _lines.Add(new OrderLine(product.Id, quantity, product.Price));
        RecalculateTotal();
    }

    private void RecalculateTotal() => Total = _lines.Sum(l => l.Subtotal);
}
```

With a rich model, there is no way to cancel an order without going through `Cancel()` — the invariant cannot be bypassed.

### Domain Events Pattern

```csharp
// Base event class — no dependencies
public abstract record DomainEvent(DateTime OccurredAt = default)
{
    public DateTime OccurredAt { get; } = OccurredAt == default ? DateTime.UtcNow : OccurredAt;
}

public record OrderPlacedEvent(int OrderId, int CustomerId, decimal Total) : DomainEvent;

// Entity collects events — Application layer dispatches them after SaveChanges
public abstract class AggregateRoot
{
    private readonly List<DomainEvent> _events = [];
    public IReadOnlyList<DomainEvent> DomainEvents => _events;
    protected void AddDomainEvent(DomainEvent e) => _events.Add(e);
    public void ClearDomainEvents() => _events.Clear();
}
```

### When to Use Domain Services

Extract to a Domain Service when the operation:
- Requires input from multiple aggregates
- Doesn't naturally belong on any single entity
- Is stateless

```csharp
// Domain service — logic that spans Order and ShippingQuote
public class ShippingCostCalculator
{
    public Money Calculate(Order order, ShippingAddress destination)
    {
        // Logic that uses both order weight and destination — neither owns it
        var baseRate = destination.IsRemote ? 15m : 5m;
        return new Money(baseRate + order.Lines.Sum(l => l.WeightKg) * 2m, "USD");
    }
}
```

## Code Example

```csharp
// Pure domain model — no framework dependencies
namespace YourApp.Domain.Entities;

public class Order : AggregateRoot
{
    public int Id { get; private set; }
    public int CustomerId { get; private set; }
    public Money Total { get; private set; } = Money.Zero;
    public OrderStatus Status { get; private set; } = OrderStatus.Pending;
    private readonly List<OrderLine> _lines = [];
    public IReadOnlyList<OrderLine> Lines => _lines.AsReadOnly();

    private Order() { }  // EF Core navigation requires parameterless ctor

    public static Order Create(int customerId)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(customerId);
        var order = new Order { CustomerId = customerId };
        order.AddDomainEvent(new OrderCreatedEvent(order.Id, customerId));
        return order;
    }

    public void AddLine(int productId, int quantity, Money unitPrice)
    {
        if (Status != OrderStatus.Pending)
            throw new InvalidOperationException("Cannot add lines to a non-pending order.");
        if (quantity <= 0) throw new ArgumentOutOfRangeException(nameof(quantity));

        var existing = _lines.FirstOrDefault(l => l.ProductId == productId);
        if (existing is not null) existing.IncreaseQuantity(quantity);
        else _lines.Add(new OrderLine(productId, quantity, unitPrice));

        Total = _lines.Aggregate(Money.Zero, (sum, l) => sum + l.Subtotal);
    }

    public void Submit()
    {
        if (!_lines.Any()) throw new InvalidOperationException("Cannot submit an empty order.");
        if (Status != OrderStatus.Pending) throw new InvalidOperationException();
        Status = OrderStatus.Submitted;
        AddDomainEvent(new OrderSubmittedEvent(Id, CustomerId, Total));
    }
}
```

## Common Follow-up Questions

- Where do you put validation that requires database lookups (e.g., "product must exist")?
- How does EF Core interact with a private-setter domain model?
- What is the difference between a Domain Service and an Application Service?
- When should domain logic live in a static factory method vs a constructor?
- How do you test domain entities without any test framework setup?

## Common Mistakes / Pitfalls

- **Public setters on domain entities**: any code can change the state without going through a method, making invariant enforcement impossible. Use `private set` or `init` selectively.
- **Placing validation that requires I/O in the domain**: domain invariants must be checkable without calling a database. "Customer must exist" is an application-layer concern, not a domain invariant.
- **EF Core navigation properties forcing public constructors**: private parameterless constructors with `HasField` Fluent API configuration let you keep domain purity while EF Core hydrates the object.
- **Thin entities with fat services**: if your `Order` entity has only getters and all logic is in `OrderDomainService`, you have an anemic model. The service itself doesn't guarantee invariants.

## References

- [Domain Model pattern — Microsoft Architecture Microservices docs](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- [Anemic Domain Model — Martin Fowler](https://martinfowler.com/bliki/AnemicDomainModel.html) (verify URL)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: application-layer-responsibilities.md](./application-layer-responsibilities.md)
- [See: anemic-vs-rich-domain-model.md](./anemic-vs-rich-domain-model.md)
