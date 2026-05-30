# Event Sourcing vs Traditional Persistence

**Category:** Architecture / Event Sourcing
**Difficulty:** 🔴 Senior
**Tags:** `event-sourcing`, `CRUD`, `audit-trail`, `temporal-queries`, `debugging`, `operational-complexity`

## Question

> What are the concrete advantages of Event Sourcing over traditional state-based persistence? What are the real operational costs? When is Event Sourcing the wrong choice?

## Short Answer

Event Sourcing's concrete advantages are a built-in, unforgeable audit trail, the ability to replay history for debugging or rebuilding read models, and temporal queries (what was the state at a specific point in time?). The real costs are high: more complex infrastructure (event store, projection workers, checkpoint management), no simple SQL queries against current state, eventually consistent read models, snapshot management for long streams, and significant developer ramp-up time. Event Sourcing is most valuable in domains with high audit requirements (finance, healthcare, legal, orders) and least appropriate for simple CRUD-style data with no regulatory audit needs.

## Detailed Explanation

### Concrete Advantages

#### 1. Built-In Audit Trail

```
Traditional approach — adding audit later:
  Orders table:       Id, Status, Total, LastModifiedBy, LastModifiedAt
  OrderAuditLogs:     OrderId, OldStatus, NewStatus, ChangedBy, ChangedAt

  Problems:
  - Must add audit columns to every table
  - Often only tracks the last change, not full history
  - "What was the state 3 months ago?" requires joining multiple audit tables
  - Adding audit tracking is an afterthought — often missed in early dev

Event Sourcing — audit built-in:
  OrderEvents:
    1. OrderCreated      {customerId: 7, createdBy: "john@acme.com"}
    2. OrderLineAdded    {productId: 5, qty: 2}
    3. OrderSubmitted    {at: 2025-01-15T09:05}
    4. OrderConfirmed    {confirmedBy: "manager@acme.com", at: 2025-01-15T10:30}
    5. OrderCancelled    {reason: "Customer requested", by: "support@acme.com"}

  "Who cancelled this order and why?" — answered by reading event 5. Zero extra code.
```

#### 2. Temporal Queries

```csharp
// What was the state of this order on January 20?
public async Task<Order?> GetStateAtAsync(OrderId id, DateTime pointInTime, CancellationToken ct)
{
    var events = await store.ReadStreamAsync($"order-{id.Value}", ct: ct);
    var relevantEvents = events.Where(e => e.OccurredAt <= pointInTime);
    // Replay only events up to the point in time
    var order = new Order();
    foreach (var e in relevantEvents) order.Apply(e.Event);
    return order;
}
```

Traditional persistence: requires dedicated temporal tables (`AS OF SYSTEM TIME` in SQL Server — valid but limited), typically not available in most RDBMS without explicit setup.

#### 3. Replay for Debugging

```csharp
// Reproduce a production bug by replaying the exact event sequence
// No need to recreate complex database state manually
var events = await productionStore.ReadStreamAsync("order-42");
var order = Order.LoadFrom(events.Select(e => e.Event));
// Now order is in the exact state it was in production
// You can step through Apply() calls in a debugger
```

#### 4. New Read Models from History

```csharp
// You need a "revenue by month" report that didn't exist at launch
// With Event Sourcing: replay all OrderConfirmedEvents from day 1
// With traditional persistence: data is gone if you didn't store it
public async Task<Dictionary<YearMonth, decimal>> BuildRevenueHistoryAsync(CancellationToken ct)
{
    var report = new Dictionary<YearMonth, decimal>();
    await foreach (var e in store.ReadAllEventsAsync<OrderConfirmedEvent>(ct))
        report.Merge(YearMonth.FromDate(e.OccurredAt), e.Total.Amount);
    return report;
}
```

### Real Operational Costs

| Cost | Description |
|------|-------------|
| **No simple state queries** | `SELECT * FROM Orders WHERE Status = 'Pending'` doesn't exist — you need projections |
| **Projection management** | Background workers, checkpoints, rebuild procedures — all extra code |
| **Event store infrastructure** | EventStoreDB or Marten requires setup, monitoring, backup |
| **Developer ramp-up** | Most developers don't know Event Sourcing — onboarding time is real |
| **Eventual consistency** | Read model may lag — `POST /orders` then `GET /orders` may not show the new order |
| **Snapshot management** | Long-lived aggregates (3+ years) accumulate thousands of events — snapshots required |
| **Event schema evolution** | Can't alter stored events — must write upcasters for old event versions |
| **Testing complexity** | Integration tests must set up event stores, projection workers |

### When Event Sourcing is Wrong

```
WRONG: User profile management
  - Rarely queried historically
  - High churn on unimportant fields (last_seen_at, preferences)
  - No audit requirement
  - Stream grows indefinitely with low-value events
  → Use traditional state-based persistence

WRONG: Product catalog
  - Infrequent changes, no history needed
  - Reporting is simple SQL
  → Use traditional state-based persistence

RIGHT: Order management
  - Regulatory audit trail required
  - Multiple state transitions with business implications
  - Reports need historical data
  → Event Sourcing makes sense

RIGHT: Financial transactions
  - Immutable by design (legal requirement)
  - Audit trail mandatory
  - Historical reporting is the primary use case
  → Event Sourcing is a natural fit
```

### The "Eventsourcing Tax"

Before choosing Event Sourcing, validate:

1. Do you have a regulatory or compliance audit requirement?
2. Do you need temporal queries (what was the state at T)?
3. Will you build multiple read models from the same event history?
4. Is your team comfortable with the additional infrastructure?

If the answer to most is "no" — use traditional persistence and publish domain events to a message bus. You get integration benefits without the full Event Sourcing overhead.

## Code Example

```csharp
// Temporal query example: "Show me the order state at the time of the dispute"
[HttpGet("orders/{id}/state-at/{timestamp}")]
public async Task<IActionResult> GetStateAt(int id, DateTimeOffset timestamp, CancellationToken ct)
{
    var events = await _store.ReadStreamAsync($"order-{id}", ct: ct);
    var historicalEvents = events.Where(e => e.OccurredAt <= timestamp.UtcDateTime);
    if (!historicalEvents.Any()) return NotFound();

    var order = new Order();
    foreach (var e in historicalEvents) order.Apply(e.Event);

    return Ok(new OrderStateAtDto(
        OrderId: id,
        AsOf: timestamp,
        Status: order.Status.ToString(),
        Total: order.Total.Amount,
        EventCount: historicalEvents.Count()));
}
```

## Common Follow-up Questions

- How do you handle deleting personal data (GDPR right to erasure) in an immutable event store?
- What is the "one stream per aggregate" vs "one stream per category" trade-off?
- How do you enforce access control (who can see which events) in an event store?
- Can you use Event Sourcing for only part of your domain while using traditional persistence elsewhere?
- What is event sourcing's impact on performance benchmarks vs traditional persistence?

## Common Mistakes / Pitfalls

- **Applying Event Sourcing everywhere**: forcing Event Sourcing on entities with no audit or historical requirements (product catalog, reference data, user settings) creates unnecessary overhead.
- **Too fine-grained events**: `FirstNameChanged`, `LastNameChanged`, `PhoneChanged` for a user profile update creates event spam. One meaningful event (`CustomerContactDetailsUpdated`) is usually better.
- **Not planning for GDPR**: once an event is stored, it's immutable. GDPR "right to erasure" requires explicit strategies: event payload encryption with key deletion, or data tokenisation.
- **Tight coupling between event structure and code**: storing `MyApp.Domain.Orders.OrderCreatedEvent, MyApp.Domain, Version=1.0.0.0` as the event type string breaks when you move the class. Use short discriminator strings.

## References

- [Event Sourcing — Martin Fowler](https://martinfowler.com/eaaDev/EventSourcing.html) (verify URL)
- [Greg Young — CQRS and Event Sourcing](https://cqrs.files.wordpress.com/2010/11/cqrs_documents.pdf) (verify URL)
- [See: event-sourcing-fundamentals.md](./event-sourcing-fundamentals.md)
- [See: event-sourcing-pitfalls.md](./event-sourcing-pitfalls.md)
