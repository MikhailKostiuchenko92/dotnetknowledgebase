# Value Object Implementation in C#

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `value-object`, `C#-record`, `EF-Core`, `ComplexType`, `owned-entities`, `immutability`

## Question

> How do you implement Value Objects in C# using records? How does EF Core 8's `[ComplexType]` differ from `OwnsOne` for persisting value objects? Show common examples like `Money`, `Address`, and `Email`.

## Short Answer

In C#, `record` types make ideal Value Objects — they provide structural equality, immutability (`init` properties), and `with`-expression mutation out of the box. Add domain validation in the constructor to enforce the always-valid rule. For persistence, EF Core 8+ introduces `[ComplexType]` (no shadow ID, no separate table — just inline columns), which is cleaner than the older `OwnsOne` approach. `OwnsOne` is still required for navigation and FK-based owned entities; `[ComplexType]` is for pure value types that are part of the owning entity's row.

## Detailed Explanation

### C# Record as Value Object

```csharp
// ✅ C# 12: record with validation — always-valid VO
public record Money
{
    public decimal Amount { get; }
    public string Currency { get; }

    public Money(decimal amount, string currency = "USD")
    {
        if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount), "Amount cannot be negative.");
        if (string.IsNullOrWhiteSpace(currency) || currency.Length != 3)
            throw new ArgumentException("Currency must be a 3-letter ISO code.", nameof(currency));

        Amount = amount;
        Currency = currency.ToUpperInvariant();
    }

    public static Money Zero(string currency = "USD") => new(0, currency);

    public Money Add(Money other)
    {
        EnsureSameCurrency(other);
        return this with { Amount = Amount + other.Amount };  // with-expression = new instance
    }

    public Money Multiply(decimal factor) => this with { Amount = Amount * factor };

    public static Money operator +(Money a, Money b) => a.Add(b);
    public static Money operator *(Money m, decimal factor) => m.Multiply(factor);

    private void EnsureSameCurrency(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException($"Cannot operate on {Currency} and {other.Currency}.");
    }
}
```

### EF Core 8: `[ComplexType]`

`[ComplexType]` maps properties inline without a separate table or shadow PK:

```csharp
// .NET 8 / EF Core 8+
[ComplexType]
public record Money(decimal Amount, string Currency = "USD");

[ComplexType]
public record Address(string Street, string City, string PostalCode, string CountryCode);

public class Order
{
    public int Id { get; private set; }
    public Money Total { get; private set; } = Money.Zero;
    public Address? ShippingAddress { get; private set; }
}

// EF Core generates columns: Total_Amount, Total_Currency, ShippingAddress_Street, etc.
// No configuration needed for simple cases!
```

### EF Core 7 and Earlier: `OwnsOne`

```csharp
// EF Core Fluent API — still needed in EF Core 7 or for custom column names
public class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.OwnsOne(o => o.Total, money =>
        {
            money.Property(m => m.Amount).HasColumnName("TotalAmount").HasPrecision(18, 2);
            money.Property(m => m.Currency).HasColumnName("TotalCurrency").HasMaxLength(3);
        });

        builder.OwnsOne(o => o.ShippingAddress, addr =>
        {
            addr.Property(a => a.Street).HasColumnName("ShipStreet").HasMaxLength(200);
            addr.Property(a => a.City).HasColumnName("ShipCity").HasMaxLength(100);
            addr.Property(a => a.PostalCode).HasColumnName("ShipPostalCode").HasMaxLength(20);
            addr.Property(a => a.CountryCode).HasColumnName("ShipCountryCode").HasMaxLength(2);
        });
    }
}
```

### Common Value Object Examples

```csharp
// Email — wraps a string, validates format
public record Email
{
    public string Value { get; }

    public Email(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || !value.Contains('@'))
            throw new ArgumentException("Invalid email address.", nameof(value));
        Value = value.Trim().ToLowerInvariant();
    }

    public static implicit operator string(Email email) => email.Value;
    public override string ToString() => Value;
}

// Percentage — guards a 0–100 range
public record Percentage
{
    public decimal Value { get; }
    public Percentage(decimal value)
    {
        if (value < 0 || value > 100)
            throw new ArgumentOutOfRangeException(nameof(value), "Percentage must be 0–100.");
        Value = value;
    }
    public static implicit operator decimal(Percentage p) => p.Value;
}

// Strongly-typed ID — prevents OrderId/CustomerId confusion
public record OrderId(int Value)
{
    public static implicit operator int(OrderId id) => id.Value;
    public static implicit operator OrderId(int v) => new(v);
}

// DateRange — ensures start <= end
public record DateRange
{
    public DateOnly Start { get; }
    public DateOnly End { get; }

    public DateRange(DateOnly start, DateOnly end)
    {
        if (end < start) throw new ArgumentException("End must be after Start.");
        Start = start;
        End = end;
    }

    public bool Contains(DateOnly date) => date >= Start && date <= End;
    public int DurationDays => End.DayNumber - Start.DayNumber;
}
```

### Value Object Collection with EF Core

```csharp
// OwnsMany for collection of value objects
public class Customer
{
    public int Id { get; private set; }
    private readonly List<Address> _addresses = [];
    public IReadOnlyList<Address> Addresses => _addresses;

    public void AddAddress(Address address) => _addresses.Add(address);
}

// Configuration:
builder.OwnsMany(c => c.Addresses, addr =>
{
    addr.Property(a => a.Street).HasMaxLength(200);
    addr.Property(a => a.PostalCode).HasMaxLength(20);
    addr.ToTable("CustomerAddresses");  // ← gets its own table with FK
});
```

## Code Example

```csharp
// EF Core 8 ComplexType in action — minimal configuration
[ComplexType]
public record Money(decimal Amount, string Currency = "USD")
{
    public static Money Zero => new(0);
}

[ComplexType]
public record Address(string Street, string City, string PostalCode, string Country);

public class Order
{
    public int Id { get; private set; }
    public Money Price { get; private set; } = Money.Zero;
    public Money ShippingCost { get; private set; } = Money.Zero;
    public Money Total => Price + ShippingCost;  // ← computed, not stored
    public Address? DeliveryAddress { get; private set; }

    public void SetAddress(Address address)
    {
        ArgumentNullException.ThrowIfNull(address);
        DeliveryAddress = address;
    }
}

// EF Core generates:
// Orders table: Id, Price_Amount, Price_Currency, ShippingCost_Amount, ShippingCost_Currency,
//               DeliveryAddress_Street, DeliveryAddress_City, ...
// No joins needed — everything in one row
```

## Common Follow-up Questions

- What is the difference between `[ComplexType]` and `OwnsOne` in EF Core 8?
- How do you handle nullable Value Objects (e.g., optional shipping address) in EF Core?
- Can a Value Object contain a collection of other Value Objects?
- How do you serialize Value Objects to JSON for API responses?
- What is a strongly-typed ID, and how does it interact with EF Core routing and model binding?

## Common Mistakes / Pitfalls

- **Mutable record properties**: using `{ get; set; }` instead of `{ get; init; }` makes the record mutable — the `with`-expression still works but nothing prevents external mutation via the setter.
- **Value Object with nullable properties**: `new Address(null, "NYC", "10001", "US")` should fail at construction, not silently create an invalid address. Always validate in the constructor.
- **EF Core trying to create a PK for `OwnsOne`**: if you don't configure `OwnsOne` correctly, EF Core may try to add a shadow key. `[ComplexType]` in EF Core 8 avoids this entirely.
- **Too-large Value Objects**: a `CustomerProfile` record with 20 properties is not a value object in the DDD sense — it's likely a separate entity or a DTO. Keep VOs focused on a single semantic concept.

## References

- [Value Objects — Microsoft .NET Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/implement-value-objects)
- [ComplexType in EF Core 8 — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-8.0/whatsnew#value-objects-using-complex-types)
- [See: entity-vs-value-object.md](./entity-vs-value-object.md)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: domain-layer-design.md](./domain-layer-design.md)
