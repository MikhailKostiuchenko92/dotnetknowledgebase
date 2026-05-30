# Large Aggregate Splitting

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🔴 Senior
**Tags:** `DDD`, `aggregate-design`, `aggregate-splitting`, `eventual-consistency`, `domain-events`, `performance`

## Question

> What are the signs that an aggregate has become too large? How do you decompose a large aggregate, and what patterns do you use to maintain consistency across the resulting smaller aggregates?

## Short Answer

Signs of an oversized aggregate: high contention (many concurrent transactions failing due to optimistic lock conflicts), slow load times (loading a 500-line `Order` to add one status field), complex invariants that really belong to a sub-concept, and memory pressure from loading the full graph. The solution is to extract secondary entities into their own aggregates, keeping only the minimum objects needed for a single consistency boundary together. Cross-aggregate consistency uses **domain events + eventual consistency** — the aggregate raises an event, and a subscriber updates the second aggregate in a separate transaction.

## Detailed Explanation

### Signs of an Over-Sized Aggregate

```csharp
// ❌ GOD AGGREGATE — everything lumped together
public class Order : AggregateRoot
{
    public List<OrderLine> Lines { get; }          // needed for order total invariant ✓
    public Customer Customer { get; }              // only need CustomerId ← SPLIT
    public List<Payment> Payments { get; }         // separate lifecycle ← SPLIT
    public List<Shipment> Shipments { get; }       // separate lifecycle ← SPLIT
    public List<Return> Returns { get; }           // separate lifecycle ← SPLIT
    public List<AuditEntry> AuditLog { get; }      // unbounded ← SPLIT
    public List<OrderNote> Notes { get; }          // unbounded ← SPLIT
}
// Loading this: 7 EF Core includes, loading 200+ rows for a simple status check
```

### Identifying the Real Consistency Boundary

Ask: **"Does this entity need to be consistent with the Order root within a single transaction?"**

| Entity | Needs same transaction? | Decision |
|--------|------------------------|----------|
| `OrderLine` | ✅ Yes — affects `Total` invariant | Keep inside Order |
| `Customer` | ❌ No — customer change doesn't affect Order | Reference by ID |
| `Payment` | ❌ No — payment has its own lifecycle | Separate aggregate |
| `Shipment` | ❌ No — dispatched after order confirmed | Separate aggregate |
| `Return` | ❌ No — returned after shipment | Separate aggregate |

### Decomposed Design

```csharp
// AFTER: Small, focused aggregates

public class Order : AggregateRoot
{
    public OrderId Id { get; private set; }
    public CustomerId CustomerId { get; private set; }    // reference by ID
    private readonly List<OrderLine> _lines = [];         // ONLY lines — needed for total
    public Money Total { get; private set; }
    public OrderStatus Status { get; private set; }

    public void Submit()
    {
        Status = OrderStatus.Submitted;
        Raise(new OrderSubmittedEvent(Id, CustomerId, Total));
        // ← Payment and Shipment are created in SEPARATE transactions by handlers
    }
}

public class Payment : AggregateRoot
{
    public PaymentId Id { get; private set; }
    public OrderId OrderId { get; private set; }          // reference to Order by ID
    public Money Amount { get; private set; }
    public PaymentStatus Status { get; private set; }

    public void Settle(TransactionRef transactionRef)
    {
        Status = PaymentStatus.Settled;
        Raise(new PaymentSettledEvent(Id, OrderId, Amount));
    }
}

public class Shipment : AggregateRoot
{
    public ShipmentId Id { get; private set; }
    public OrderId OrderId { get; private set; }
    public ShipmentStatus Status { get; private set; }

    // Created when OrderSubmittedEvent is handled — separate transaction
    public static Shipment CreateFor(OrderId orderId, Address destination)
        => new() { OrderId = orderId, Status = ShipmentStatus.Pending };
}
```

### Maintaining Consistency via Domain Events

```csharp
// Order submits → event raised → separate handlers create Payment and Shipment

// Handler 1: creates Payment when Order is submitted
public class CreatePaymentOnOrderSubmitted(IPaymentRepository payments)
    : INotificationHandler<OrderSubmittedEvent>
{
    public async Task Handle(OrderSubmittedEvent e, CancellationToken ct)
    {
        var payment = new Payment(e.OrderId, e.Total);
        await payments.AddAsync(payment, ct);
        // ← separate transaction — eventually consistent
    }
}

// Handler 2: schedules shipment when Payment settles
public class ScheduleShipmentOnPaymentSettled(IShipmentRepository shipments, IOrderRepository orders)
    : INotificationHandler<PaymentSettledEvent>
{
    public async Task Handle(PaymentSettledEvent e, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(e.OrderId, ct);
        var shipment = Shipment.CreateFor(e.OrderId, order!.DeliveryAddress);
        await shipments.AddAsync(shipment, ct);
    }
}
```

### Using the Outbox for Reliable Cross-Aggregate Events

When splitting aggregates, the cross-aggregate event must survive process crashes:

```csharp
// Outbox ensures OrderSubmittedEvent is published reliably
// even if the process dies after SaveChanges but before the message broker receives the event
services.AddMassTransitOutbox(o =>
{
    o.QueryDelay = TimeSpan.FromSeconds(1);
    o.UseSqlServer();
    o.UseBusOutbox();
});
```

### Performance Impact of Splitting

| Metric | Before (god aggregate) | After (small aggregates) |
|--------|----------------------|--------------------------|
| Load time for `Order.Submit()` | Load 500+ rows (all joins) | Load 10 rows (Order + Lines only) |
| Concurrency conflicts | High — any Order operation conflicts | Low — Payment operations don't conflict with Order edits |
| Memory per request | Large (full graph) | Small (just the aggregate needed) |
| Write scalability | Low | High — independent transactions |

## Code Example

```csharp
// Before/after comparison of the same business operation

// BEFORE: monolithic aggregate — load everything to change one status
var order = await orders.GetByIdAsync(orderId, ct);  // ← loads Lines, Payments, Shipments, Notes...
order.UpdateStatus(OrderStatus.Confirmed);           // ← updates 1 field
await uow.SaveChangesAsync(ct);

// AFTER: focused aggregate — load only what's needed
var order = await orders.GetByIdAsync(orderId, ct);  // ← loads Order + Lines only
order.Confirm();  // ← raises OrderConfirmedEvent
await uow.SaveChangesAsync(ct);
// ← Shipment.Schedule() and Payment.Capture() happen in separate transactions
//   triggered by OrderConfirmedEvent handlers
```

## Common Follow-up Questions

- When is eventual consistency not acceptable, and what do you do when you need strong consistency across what should be separate aggregates?
- How do you handle a saga/process manager that coordinates multiple aggregates across multiple transactions?
- What is the performance impact of loading a full aggregate on every write — should you consider split loading?
- How do you test eventual consistency scenarios in integration tests?
- How does the Outbox pattern ensure at-least-once delivery of cross-aggregate events?

## Common Mistakes / Pitfalls

- **Splitting too eagerly**: extracting `OrderLine` into its own aggregate because "it feels separate" breaks the `Order.Total` invariant — you can't maintain the total across transactions.
- **Using navigation properties after splitting**: leaving `order.Payments.Add(new Payment(...))` after extracting Payment into its own aggregate maintains the old coupled loading pattern.
- **No Outbox for cross-aggregate events**: if `OrderSubmittedEvent` is dispatched in-process and the process crashes before `Payment.Create()` completes, payment is never created. The Outbox pattern is essential for reliable cross-aggregate consistency.
- **Compensating transactions forgotten**: when splitting, all cross-aggregate operations become eventually consistent. You must design compensating actions for failure cases (e.g., payment failed after shipment was scheduled).

## References

- [Aggregate design — Vaughn Vernon (IDDD)](https://vaughnvernon.com/?p=838) (verify URL)
- [Eventual consistency in microservices — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/architect-microservice-container-applications/distributed-data-management)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: domain-events.md](./domain-events.md)
- [See: outbox-pattern-architecture.md](./outbox-pattern-architecture.md)
