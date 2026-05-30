# Aggregate Design

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `aggregate`, `aggregate-root`, `consistency-boundary`, `transactional-boundary`, `invariants`

## Question

> What is an aggregate in DDD? What are the rules for designing aggregate boundaries, and how do you determine what belongs inside vs outside an aggregate? What is the "one transaction per aggregate" rule?

## Short Answer

An **aggregate** is a cluster of domain objects (entities + value objects) treated as a unit for data changes. The **aggregate root** is the single entry point — all changes to the aggregate's members go through the root. The aggregate root enforces invariants that must hold across its members. The key sizing rule: an aggregate should be the **minimum set of objects that must be consistent with each other within a single transaction**. Cross-aggregate consistency is achieved through domain events and eventual consistency, not distributed transactions.

## Detailed Explanation

### The Aggregate Contract

An aggregate has four defining properties:

1. **Consistency boundary**: all objects inside the aggregate are consistent with each other after any operation
2. **Single root**: external objects hold a reference only to the aggregate root (by ID, not by navigation)
3. **Atomic persistence**: the entire aggregate is loaded and saved as a unit
4. **Identity by root**: the aggregate is identified by the root's ID

### The Four Aggregate Design Rules (Vaughn Vernon)

**Rule 1: Model true invariants in consistency boundaries**
Only group objects if they *must* be consistent with each other immediately. An order line's quantity affects the order's total — they must be consistent. A customer's profile doesn't affect order consistency — keep them separate.

**Rule 2: Design small aggregates**
The temptation is to include everything related to `Order` in the Order aggregate: order lines, customer details, shipping address history, payment records. But large aggregates cause: contention (every order operation locks the whole aggregate), high memory usage, and slow saves.

**Rule 3: Reference other aggregates by identity only**
`Order` should hold `CustomerId` (a Value Object wrapping an ID), not a `Customer` navigation property. Loading a Customer when you only need an Order is wasteful and creates hidden coupling.

**Rule 4: Update other aggregates using eventual consistency**
When placing an order needs to reserve inventory, don't include `Inventory` in the `Order` aggregate. Instead: `Order.Place()` emits `OrderPlacedEvent`, which a subscriber uses to call `Inventory.Reserve(...)` in a separate transaction.

### Small Aggregate Example: Order

```csharp
// ✅ GOOD: Order aggregate — includes only what must be consistent immediately
public class Order : AggregateRoot
{
    public OrderId Id { get; private set; }
    public CustomerId CustomerId { get; private set; } // reference by ID, not navigation
    private readonly List<OrderLine> _lines = [];
    public IReadOnlyList<OrderLine> Lines => _lines.AsReadOnly();
    public Money Total { get; private set; } = Money.Zero;
    public OrderStatus Status { get; private set; } = OrderStatus.Draft;

    // Factory: ensures aggregate is always created in a valid state
    public static Order Create(CustomerId customerId)
    {
        var order = new Order { CustomerId = customerId };
        order.AddDomainEvent(new OrderCreatedEvent(order.Id, customerId));
        return order;
    }

    // Mutation through root: invariant enforced here
    public void AddLine(ProductId productId, int quantity, Money unitPrice)
    {
        if (Status != OrderStatus.Draft)
            throw new InvalidOperationException("Cannot add lines to a submitted order.");
        if (quantity <= 0)
            throw new ArgumentOutOfRangeException(nameof(quantity));

        var existing = _lines.FirstOrDefault(l => l.ProductId == productId);
        if (existing is not null) existing.IncreaseQuantity(quantity);
        else _lines.Add(new OrderLine(productId, quantity, unitPrice));

        RecalculateTotal(); // invariant: Total must always equal sum of line subtotals
    }

    public void Submit()
    {
        if (!_lines.Any())
            throw new InvalidOperationException("Cannot submit an empty order.");

        Status = OrderStatus.Submitted;
        AddDomainEvent(new OrderSubmittedEvent(Id, CustomerId, Total));
        // ← Inventory reservation happens in a separate transaction via this event
    }

    private void RecalculateTotal()
        => Total = _lines.Aggregate(Money.Zero, (sum, l) => sum + l.Subtotal);
}

// OrderLine is part of the Order aggregate — but NOT an aggregate root itself
public class OrderLine
{
    public ProductId ProductId { get; private set; }
    public int Quantity { get; private set; }
    public Money UnitPrice { get; private set; }
    public Money Subtotal => UnitPrice * Quantity;

    internal void IncreaseQuantity(int additional)
    {
        if (additional <= 0) throw new ArgumentOutOfRangeException(nameof(additional));
        Quantity += additional;
    }
}
```

### One Transaction Per Aggregate Rule

```csharp
// ❌ WRONG: Two aggregates in one transaction
public async Task Handle(SubmitOrderCommand cmd, CancellationToken ct)
{
    var order = await orders.GetByIdAsync(cmd.OrderId, ct);
    order.Submit();
    await orders.SaveAsync(order, ct);

    // ← Inventory is a separate aggregate — changing it here couples two aggregates
    var inventory = await inventory.GetByProductIdAsync(cmd.ProductId, ct);
    inventory.Reserve(cmd.Quantity);
    await inventory.SaveAsync(inventory, ct); // ← two SaveChanges = two transactions or a distributed transaction
}

// ✅ CORRECT: One aggregate per transaction, cross-aggregate via events
public async Task Handle(SubmitOrderCommand cmd, CancellationToken ct)
{
    var order = await orders.GetByIdAsync(cmd.OrderId, ct);
    order.Submit(); // ← emits OrderSubmittedEvent inside the aggregate
    await orders.SaveAsync(order, ct); // ← ONE transaction

    // OrderSubmittedEvent is dispatched by SaveChanges interceptor or outbox
    // Inventory.Reserve() happens in a SEPARATE transaction, in a separate handler
}
```

## Code Example

```csharp
// Deciding what belongs inside the aggregate:
// Q: "Must these objects be consistent immediately?" → inside
// Q: "Can they be eventually consistent?" → separate aggregate

// INSIDE Order aggregate:
//   OrderLine — total must reflect lines immediately
//   DiscountCode — discount affects total immediately

// OUTSIDE Order aggregate (separate aggregates, reference by ID):
//   Customer — customer address change doesn't affect Order immediately
//   Product — product price change after order placement is irrelevant
//   Shipment — created after order submission; separate lifecycle

public class Shipment : AggregateRoot
{
    public ShipmentId Id { get; private set; }
    public OrderId OrderId { get; private set; }  // ← reference by ID only
    // NOT: public Order Order { get; private set; } — no navigation property
    public ShipmentStatus Status { get; private set; }

    public void Dispatch(TrackingNumber trackingNumber)
    {
        Status = ShipmentStatus.Dispatched;
        AddDomainEvent(new ShipmentDispatchedEvent(Id, OrderId, trackingNumber));
    }
}
```

## Common Follow-up Questions

- How do you handle a business rule that requires reading data from two separate aggregates before deciding?
- What is the performance impact of always loading the full aggregate, and how do you mitigate it?
- How does aggregate sizing affect concurrency — what happens with optimistic locking on large aggregates?
- How do you handle scenarios where eventual consistency isn't acceptable and you need synchronous cross-aggregate consistency?
- How do aggregates relate to microservice boundaries?

## Common Mistakes / Pitfalls

- **God aggregates**: including everything related to a concept in one aggregate (`Order` with full `Customer`, `Inventory`, `Payment`, `Shipment` objects). This creates massive load-and-save operations and heavy contention.
- **Exposing aggregate internals**: allowing external code to call `order.Lines.Add(line)` directly bypasses the aggregate root's invariant enforcement. Collections inside aggregates should always be `private`/`internal` with modification only through root methods.
- **Using navigation properties across aggregate roots**: `Order.Customer` (a navigation property, not just an ID) means EF Core can lazily load `Customer` from inside `Order`, coupling the two aggregates silently.
- **Aggregate = database table**: aggregates are consistency boundaries, not persistence units. A `Customer` aggregate might span `Customers`, `CustomerAddresses`, and `ContactPreferences` tables, or a single `Customers` table with JSON columns.

## References

- [Aggregate design rules — Vaughn Vernon (IDDD)](https://vaughnvernon.com/?p=838) (verify URL)
- [Implementing Domain-Driven Design — Vaughn Vernon](https://vaughnvernon.com/?page_id=168) (verify URL)
- [Aggregate in EF Core — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/net-core-microservice-domain-model)
- [See: domain-layer-design.md](./domain-layer-design.md)
- [See: aggregate-invariants.md](./aggregate-invariants.md)
- [See: large-aggregate-splitting.md](./large-aggregate-splitting.md)
