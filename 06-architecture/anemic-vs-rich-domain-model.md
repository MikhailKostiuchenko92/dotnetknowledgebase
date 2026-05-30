# Anemic vs Rich Domain Model

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `anemic-domain-model`, `rich-domain-model`, `anti-pattern`, `business-logic`, `encapsulation`

## Question

> What is the Anemic Domain Model anti-pattern? How does it differ from a Rich Domain Model, and when are the trade-offs acceptable?

## Short Answer

An **Anemic Domain Model** (Martin Fowler's anti-pattern) has entities that are little more than data bags — public getters and setters, no behavior, no invariant enforcement. All business logic lives in service classes that operate on the entities externally. A **Rich Domain Model** has entities with behavior: the `Order` aggregate has `Submit()`, `Cancel()`, `AddLine()` methods that enforce invariants themselves. Anemic models are easy to start with but become maintenance nightmares as rules multiply — nothing prevents bypassing invariants. Rich models are harder upfront but make invalid states unrepresentable.

## Detailed Explanation

### Anemic Domain Model

```csharp
// ANEMIC: Entity is a data bag
public class Order
{
    public int Id { get; set; }
    public int CustomerId { get; set; }
    public string Status { get; set; } = "Pending";     // ← public setter: anyone can change
    public decimal Total { get; set; }                  // ← no invariant: can be set to -1000
    public List<OrderLine> Lines { get; set; } = [];    // ← list exposed: bypass tracking
    public DateTime CreatedAt { get; set; }
}

// All logic scattered in services — invariants easily bypassed
public class OrderService
{
    public void SubmitOrder(int orderId)
    {
        var order = _repo.GetById(orderId);
        if (order.Status != "Pending")
            throw new InvalidOperationException("Order already submitted.");
        if (!order.Lines.Any())
            throw new InvalidOperationException("Order has no lines.");
        order.Status = "Submitted";       // ← direct property mutation
        order.SubmittedAt = DateTime.UtcNow;
        _repo.Save(order);
    }
}

// The problem: this bypasses the service entirely — no enforcement
order.Status = "Submitted";               // ← oops — no email, no event, no validation
order.Total = -1_000_000;                 // ← valid because no invariant enforced
```

### Rich Domain Model

```csharp
// RICH: Entity has behavior and enforces invariants
public class Order : AggregateRoot
{
    public int Id { get; private set; }
    public int CustomerId { get; private set; }
    public OrderStatus Status { get; private set; } = OrderStatus.Draft;
    public Money Total { get; private set; } = Money.Zero;
    private readonly List<OrderLine> _lines = [];
    public IReadOnlyList<OrderLine> Lines => _lines.AsReadOnly();

    // Factory: always-valid construction
    public static Order Create(int customerId)
    {
        if (customerId <= 0) throw new ArgumentOutOfRangeException(nameof(customerId));
        return new Order { CustomerId = customerId };
    }

    // Behavior: invariant enforced HERE — can't bypass
    public void AddLine(int productId, int qty, Money unitPrice)
    {
        if (Status != OrderStatus.Draft)
            throw new InvalidOperationException("Cannot modify a submitted order.");
        if (qty <= 0)
            throw new ArgumentOutOfRangeException(nameof(qty), "Quantity must be positive.");

        var existing = _lines.FirstOrDefault(l => l.ProductId == productId);
        if (existing is not null) existing.IncreaseQuantity(qty);
        else _lines.Add(new OrderLine(productId, qty, unitPrice));

        Total = _lines.Aggregate(Money.Zero, (s, l) => s + l.Subtotal);
    }

    public void Submit()
    {
        if (!_lines.Any()) throw new InvalidOperationException("Cannot submit empty order.");
        if (Status != OrderStatus.Draft) throw new InvalidOperationException();
        Status = OrderStatus.Submitted;
        Raise(new OrderSubmittedEvent(Id, CustomerId, Total));
    }
}
```

### The Core Trade-off

| Aspect | Anemic | Rich |
|--------|--------|------|
| Invariant protection | None — service must be called correctly | Built-in — impossible to bypass |
| Invalid states | Representable and common | Unrepresentable by construction |
| Business rule location | Scattered in services | Centralised in entities |
| DI needed for entities | No | No |
| ORM compatibility | Easy (EF Core loves public setters) | Requires configuration (`private set`, `HasField`) |
| Learning curve | Low | Higher |
| Complexity threshold | Fine for simple CRUD | Essential for complex domain |

### When Anemic Models Are Acceptable

Despite being called an "anti-pattern," anemic models are pragmatically acceptable for:
- **Simple CRUD applications** with no meaningful business rules
- **Read-side models** in CQRS — read DTOs don't need behavior
- **External models** from third-party APIs — you don't own the business rules
- **Rapid prototyping** when rules are still being discovered

> **Rule of thumb**: if your entity's "behavior" is just getters and setters and the "rules" are things like "required field", you have no domain logic worth protecting — an anemic model is fine. If you have actual business rules (status transitions, invariants, calculations), the rich model is worth the investment.

### Making EF Core Work with Rich Models

```csharp
// EF Core Fluent API to work with private setters and backing fields
public class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.HasKey(o => o.Id);

        // Private setter — EF Core still hydrates via PropertyAccessMode
        builder.Property(o => o.Status)
            .HasConversion<string>()
            .IsRequired();

        // Private backing field for collection
        builder.HasMany(o => o.Lines)
            .WithOne()
            .OnDelete(DeleteBehavior.Cascade);
        builder.Navigation(o => o.Lines)
            .UsePropertyAccessMode(PropertyAccessMode.Field);

        // Owned VO
        builder.OwnsOne(o => o.Total, m =>
        {
            m.Property(x => x.Amount).HasColumnName("TotalAmount");
            m.Property(x => x.Currency).HasColumnName("TotalCurrency").HasMaxLength(3);
        });
    }
}
```

## Code Example

```csharp
// Test showing the difference in safety:

// Anemic — invariant bypass is trivially easy
var anemic = new AnemicOrder { Status = "Submitted" };
anemic.Lines.Add(new AnemicOrderLine());  // adds after submission — no check

// Rich — invariant bypass is impossible
var rich = Order.Create(customerId: 1);
rich.Submit(); // throws: "Cannot submit empty order." — enforced by the entity itself
```

## Common Follow-up Questions

- How do you migrate an existing anemic model to a rich model incrementally without breaking changes?
- Can you use AutoMapper with a rich domain model that has private setters?
- How do you write meaningful unit tests for anemic models vs rich models?
- Does the rich domain model pattern conflict with JSON serialization (e.g., for API responses)?
- When does placing logic in the entity become too much — what belongs in a Domain Service instead?

## Common Mistakes / Pitfalls

- **Rich model by naming convention only**: naming a service `Order.Submit()` as a static method or calling it from a domain service while keeping `Status` as a public setter doesn't make the model rich — the setter still allows bypass.
- **Putting infrastructure in the domain model**: a rich `Order` that calls `IEmailSender.Send()` in `Submit()` is no longer a pure domain object.
- **Applying rich domain model to configuration tables**: `Country`, `Category`, `Currency` entities with no business transitions don't benefit from private setters and `Cancel()` methods — they're lookup data.
- **Hiding all properties with `private set`**: some properties (like read-only calculated values) benefit from public getters. Private setters are about protecting mutability — not hiding all state.

## References

- [Anemic Domain Model — Martin Fowler](https://martinfowler.com/bliki/AnemicDomainModel.html) (verify URL)
- [Domain model implementation in .NET — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/net-core-microservice-domain-model)
- [See: domain-layer-design.md](./domain-layer-design.md)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: domain-services.md](./domain-services.md)
