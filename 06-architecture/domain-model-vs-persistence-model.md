# Domain Model vs Persistence Model

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🔴 Senior
**Tags:** `DDD`, `domain-model`, `persistence-model`, `EF-Core`, `mapping`, `impedance-mismatch`, `separation-of-concerns`

## Question

> When should you use a separate domain model and persistence model? What are the mapping strategies between them, and when does the complexity cost outweigh the benefits?

## Short Answer

A **separate domain model** means your business entities (`Order`, `Customer`) are pure C# objects with no ORM attributes, while a **persistence model** is a set of EF Core entity classes optimised for mapping. Mapping between them eliminates impedance mismatch (ORM requirements vs domain purity) but adds complexity: mapper classes, more code per entity, two class hierarchies to maintain. Use separate models when domain complexity is high, when the persistence shape differs significantly from the domain shape, or when the domain must be framework-free. For simple to moderate domains, EF Core Fluent API can map directly to domain classes without a separate persistence layer.

## Detailed Explanation

### When EF Core Maps Directly to Domain Classes (No Separate Model)

EF Core's Fluent API is powerful enough to map to domain classes with private setters and backing fields. For most applications, this is the right approach:

```csharp
// Domain entity — no EF Core attributes, private setters
public class Order : AggregateRoot
{
    public OrderId Id { get; private set; }
    private readonly List<OrderLine> _lines = [];
    public IReadOnlyList<OrderLine> Lines => _lines.AsReadOnly();
    public Money Total { get; private set; } = Money.Zero;
    public OrderStatus Status { get; private set; } = OrderStatus.Draft;
}

// EF Core configuration — maps directly to domain class
public class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.HasKey(o => o.Id);
        builder.Property(o => o.Status).HasConversion<string>();
        builder.Navigation(o => o.Lines).UsePropertyAccessMode(PropertyAccessMode.Field);
        builder.OwnsOne(o => o.Total, m =>
        {
            m.Property(x => x.Amount).HasColumnName("TotalAmount");
            m.Property(x => x.Currency).HasColumnName("TotalCurrency");
        });
    }
}
```

This works for ~80% of cases. No separate persistence model needed.

### When a Separate Persistence Model Is Warranted

**Scenario 1**: The domain model's shape is fundamentally different from the DB schema:

```csharp
// Domain: OrderLine uses a typed quantity
public class OrderLine
{
    public Quantity Quantity { get; }          // ← custom type with business rules
    public ProductId ProductId { get; }       // ← strongly-typed ID
    public Money UnitPrice { get; }           // ← VO
}

// Persistence: flat row with primitive types
public class OrderLineRecord
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public int ProductId { get; set; }        // ← just an int
    public int Quantity { get; set; }         // ← just an int
    public decimal UnitPriceAmount { get; set; }
    public string UnitPriceCurrency { get; set; } = "";
}
```

**Scenario 2**: The ORM would require breaking domain design:

- EF Core requires a parameterless constructor, but the domain design forbids creating an empty `Order`
- EF Core requires a virtual navigation property, but the domain design uses a sealed class
- The domain model uses inheritance (DDD state objects) that maps poorly to DB columns

### Mapping Strategy: Manual Mapper

```csharp
// Infrastructure/Persistence/Mappers/OrderMapper.cs
public static class OrderMapper
{
    // DB → Domain: reconstruct aggregate from data
    public static Order ToDomain(OrderRecord record, IEnumerable<OrderLineRecord> lineRecords)
    {
        var lines = lineRecords.Select(l => new OrderLine(
            new ProductId(l.ProductId),
            new Quantity(l.Quantity),
            new Money(l.UnitPriceAmount, l.UnitPriceCurrency)));

        return Order.Reconstitute(
            new OrderId(record.Id),
            new CustomerId(record.CustomerId),
            Enum.Parse<OrderStatus>(record.Status),
            lines,
            new Money(record.TotalAmount, record.TotalCurrency));
    }

    // Domain → DB: flatten aggregate to data records
    public static (OrderRecord, IEnumerable<OrderLineRecord>) ToRecords(Order order)
    {
        var record = new OrderRecord
        {
            Id = order.Id.Value,
            CustomerId = order.CustomerId.Value,
            Status = order.Status.ToString(),
            TotalAmount = order.Total.Amount,
            TotalCurrency = order.Total.Currency
        };

        var lineRecords = order.Lines.Select((l, i) => new OrderLineRecord
        {
            OrderId = order.Id.Value,
            ProductId = l.ProductId.Value,
            Quantity = l.Quantity.Value,
            UnitPriceAmount = l.UnitPrice.Amount,
            UnitPriceCurrency = l.UnitPrice.Currency
        });

        return (record, lineRecords);
    }
}
```

### Aggregate Reconstitution Pattern

To map back to the domain, the aggregate needs a "reconstitution" factory that bypasses normal construction guards:

```csharp
public class Order : AggregateRoot
{
    private Order() { }

    public static Order Create(CustomerId customerId) { ... }

    // Used ONLY by the repository/mapper when loading from DB
    // Does NOT trigger domain events or run business rules
    internal static Order Reconstitute(
        OrderId id, CustomerId customerId, OrderStatus status,
        IEnumerable<OrderLine> lines, Money total)
    {
        var order = new Order
        {
            Id = id,
            _customerId = customerId,
            Status = status,
            Total = total
        };
        foreach (var line in lines) order._lines.Add(line);
        return order;
    }
}
```

### Decision Framework

```
Use EF Core directly on domain classes when:
  ✅ The domain is small to medium complexity
  ✅ EF Core Fluent API can represent all domain constraints
  ✅ Value objects can be owned/complex types
  ✅ Team size and timeline don't support extra mapping layer

Use separate domain + persistence models when:
  ✅ The domain model's shape differs significantly from DB schema
  ✅ Domain requirements (sealed classes, no parameterless ctor) conflict with EF Core
  ✅ Multiple persistence stores (read from SQL, write to event store)
  ✅ The domain model must be testable without any ORM knowledge
```

## Code Example

```csharp
// Repository using manual mapping
public class EfOrderRepository(AppDbContext db) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(OrderId id, CancellationToken ct)
    {
        var record = await db.Set<OrderRecord>()
            .FirstOrDefaultAsync(r => r.Id == id.Value, ct);
        if (record is null) return null;

        var lines = await db.Set<OrderLineRecord>()
            .Where(l => l.OrderId == id.Value)
            .ToListAsync(ct);

        return OrderMapper.ToDomain(record, lines);  // DB records → domain object
    }

    public async Task SaveAsync(Order order, CancellationToken ct)
    {
        var (record, lineRecords) = OrderMapper.ToRecords(order);  // domain → DB records

        var existing = await db.Set<OrderRecord>().FindAsync([record.Id], ct);
        if (existing is null) db.Set<OrderRecord>().Add(record);
        else db.Entry(existing).CurrentValues.SetValues(record);

        // Handle line records (upsert)
        var existingLines = await db.Set<OrderLineRecord>()
            .Where(l => l.OrderId == record.Id).ToListAsync(ct);
        db.Set<OrderLineRecord>().RemoveRange(existingLines);
        db.Set<OrderLineRecord>().AddRange(lineRecords);

        await db.SaveChangesAsync(ct);
    }
}
```

## Common Follow-up Questions

- What is the performance cost of the extra mapping layer, and how do you benchmark it?
- How do you handle complex inheritance hierarchies in the domain model vs persistence model?
- When would you use AutoMapper for domain-to-persistence mapping vs hand-written mappers?
- How does Event Sourcing relate to the domain/persistence model separation?
- How do you test the mapping layer to ensure domain objects round-trip correctly?

## Common Mistakes / Pitfalls

- **Premature separation**: building a full domain/persistence model split for a 5-entity CRUD app adds 50% more classes for no domain complexity benefit.
- **Mapping layer leaking domain knowledge**: a persistence mapper that knows about aggregate invariants (`if order.Status == "Cancelled" then...`) defeats the purpose of separating the models.
- **Reconstitution method that triggers domain events**: loading an `Order` from the DB should not fire `OrderCreatedEvent`. The reconstitution factory must bypass event raising.
- **Forgetting to test the round-trip**: if `ToDomain(ToRecords(order))` doesn't produce an equivalent aggregate, mapping bugs cause silent data corruption. Write round-trip tests.

## References

- [Microservice domain model — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/net-core-microservice-domain-model)
- [EF Core — Value Objects with ComplexType](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-8.0/whatsnew#value-objects-using-complex-types)
- [See: domain-layer-design.md](./domain-layer-design.md)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: value-object-implementation.md](./value-object-implementation.md)
