# Entity vs Value Object

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🟢 Junior
**Tags:** `DDD`, `entity`, `value-object`, `identity`, `equality`, `immutability`, `C#-records`

## Question

> What is the difference between a DDD Entity and a Value Object? How do you implement a Value Object in C# using records? Give examples of each from a real domain.

## Short Answer

An **Entity** has a unique identity — two orders are different even if every field is identical, because they represent distinct things in the real world. A **Value Object** has no identity — two `Money(100, "USD")` instances are equal because they represent the same value, not two separate objects. Value Objects are **immutable**: you don't change a `Money` value, you replace it with a new one. In C#, `record` types make ideal Value Objects because they get structural equality and immutability by default. Entities get reference equality by default and require explicit `Id`-based equality.

## Detailed Explanation

### Entity Characteristics

| Characteristic | Description |
|----------------|-------------|
| **Identity** | Has a unique ID (`int`, `Guid`, `string`, strongly-typed ID) |
| **Equality** | Two entities are equal if their IDs are equal |
| **Mutability** | State changes over time (order status, customer address) |
| **Lifecycle** | Created, modified, possibly deleted |
| **Examples** | `Order`, `Customer`, `Product`, `Invoice`, `User` |

```csharp
public class Order : IEquatable<Order>
{
    public OrderId Id { get; private set; }
    public string Status { get; private set; } = "Pending";

    // Identity-based equality — two orders are the same order if they have the same ID
    public bool Equals(Order? other) => other is not null && Id == other.Id;
    public override bool Equals(object? obj) => Equals(obj as Order);
    public override int GetHashCode() => Id.GetHashCode();
}
```

### Value Object Characteristics

| Characteristic | Description |
|----------------|-------------|
| **No identity** | No ID field; identity comes from its values |
| **Equality** | Two VOs are equal if all their properties are equal |
| **Immutability** | Never mutated — operations return new instances |
| **Replaceability** | Replace, don't modify: `order.Total = order.Total + fee` |
| **Examples** | `Money`, `Address`, `Email`, `PhoneNumber`, `DateRange`, `Color`, `Coordinates` |

### C# Record as Value Object

```csharp
// C# record: structural equality + immutability by default
public record Money(decimal Amount, string Currency = "USD")
{
    // Guard in constructor — always-valid VO
    public Money(decimal amount, string currency = "USD") : this(amount, currency)
    {
        if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
        if (string.IsNullOrWhiteSpace(currency)) throw new ArgumentException("Currency required");
        Amount = amount;
        Currency = currency;
    }

    // Operations return NEW instances — immutability preserved
    public Money Add(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException($"Cannot add {Currency} and {other.Currency}");
        return this with { Amount = Amount + other.Amount };
    }

    public static Money operator +(Money a, Money b) => a.Add(b);
    public static Money Zero(string currency = "USD") => new(0, currency);
}

// Usage:
var price = new Money(99.99m);
var tax = new Money(8.50m);
var total = price + tax;  // → new Money(108.49, "USD") — original unchanged

// Structural equality:
var a = new Money(100, "USD");
var b = new Money(100, "USD");
Console.WriteLine(a == b);   // true — same value
```

### Domain Examples

**Value Objects (no identity, equality by value)**:
- `Money(100, "USD")` — represents an amount
- `Address("123 Main St", "New York", "NY", "10001", "US")`
- `Email("user@example.com")`
- `DateRange(start: 2025-01-01, end: 2025-12-31)`
- `Coordinates(lat: 40.7128, lng: -74.0060)`
- `Percentage(15.0m)` — a discount rate

**Entities (have identity, equality by ID)**:
- `Order(Id: 42)` — a specific purchase transaction
- `Customer(Id: 7)` — a specific person
- `Product(Id: "SKU-123")` — a specific product in a catalog
- `Invoice(Id: "INV-2025-001")` — a specific billing document

### When the Same Concept Is an Entity or VO Depends on Context

An `Address` is typically a VO — two orders shipped to "123 Main St" are the same address. But in a **Customer Address Book**, the address has identity: `Address(Id: 1, street: "123 Main")` because the customer might say "use my second address." The distinction is always contextual.

### EF Core Integration

EF Core 8+ supports `ComplexType` for Value Objects without a separate table:

```csharp
// .NET 8 ComplexType — owned with no separate table or key
[ComplexType]
public record Money(decimal Amount, string Currency);

public class Order
{
    public int Id { get; private set; }
    public Money Total { get; private set; } = new(0, "USD");
}

// EF Core will create columns: Total_Amount, Total_Currency in the Orders table
// For older versions, use OwnsOne:
modelBuilder.Entity<Order>().OwnsOne(o => o.Total, m =>
{
    m.Property(x => x.Amount).HasColumnName("TotalAmount");
    m.Property(x => x.Currency).HasColumnName("TotalCurrency");
});
```

## Code Example

```csharp
// Strongly-typed ID — a Value Object wrapping an entity's identity
// Prevents passing wrong ID type: OrderId vs CustomerId
public record OrderId(int Value)
{
    public static implicit operator int(OrderId id) => id.Value;
    public static implicit operator OrderId(int value) => new(value);
}

// Entity using strongly-typed ID
public class Order
{
    public OrderId Id { get; private set; }
    public CustomerId CustomerId { get; private set; }
    public Money Total { get; private set; } = Money.Zero();

    private Order() { }

    public static Order Create(CustomerId customerId, Money initialTotal)
    {
        ArgumentNullException.ThrowIfNull(customerId);
        return new Order { CustomerId = customerId, Total = initialTotal };
    }

    // Entity equality by ID
    public override bool Equals(object? obj)
        => obj is Order other && Id == other.Id;
    public override int GetHashCode() => Id.GetHashCode();
}

// Value Object — Email with validation
public record Email
{
    public string Value { get; }

    public Email(string value)
    {
        if (!value.Contains('@')) throw new ArgumentException("Invalid email");
        Value = value.ToLowerInvariant();
    }

    public static implicit operator string(Email email) => email.Value;
}
```

## Common Follow-up Questions

- How does EF Core persist Value Objects that are C# records?
- What is a strongly-typed ID, and why does it help prevent parameter confusion bugs?
- When should a Value Object validation throw vs return a `Result<T>` type?
- How do you handle collections of Value Objects (e.g., `IReadOnlyList<Money>`) with EF Core?
- Can a Value Object contain an Entity reference? (Short answer: rarely, and with care)

## Common Mistakes / Pitfalls

- **Mutable Value Objects**: using a class with public setters for `Money` means `order.Total.Amount = 0` is possible — bypassing any invariants. Use `record` or make properties `init`-only.
- **Using `class` for Value Objects and relying on `==`**: plain `class` equality is reference-based. `new Money(100) == new Money(100)` returns `false` unless you override `Equals` and `GetHashCode`. Use `record` instead.
- **Giving entities structural equality**: an `Order` overriding `Equals` to compare all fields means two different orders with the same data are treated as equal — which is wrong in a financial system.
- **Large anemic Value Objects**: a `CustomerInfo` record with 15 properties and no behavior is often just a DTO masquerading as a Value Object. True VOs encapsulate meaning and validation.

## References

- [Value Objects in DDD — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/implement-value-objects)
- [C# records as Value Objects — Stephen Cleary](https://blog.stephencleary.com/) (verify URL)
- [ComplexType in EF Core 8 — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-8.0/whatsnew#value-objects-using-complex-types)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: value-object-implementation.md](./value-object-implementation.md)
