# Event Sourcing Pitfalls

**Category:** Architecture / Event Sourcing
**Difficulty:** 🔴 Senior
**Tags:** `event-sourcing`, `anti-patterns`, `pitfalls`, `stale-projections`, `long-streams`, `granularity`, `testing`

## Question

> What are the most common pitfalls when implementing Event Sourcing? Describe problems with stale projections in the UI, excessively long event streams, wrong event granularity, and testing complexity.

## Short Answer

The most common Event Sourcing pitfalls are: stale projections causing broken user experiences (UI shows state before a just-executed command), excessively long streams that make aggregate loading slow without snapshots, wrong event granularity (either too coarse — "CustomerUpdated" — or too fine — "FirstNameChanged"), and testing complexity from the need to set up event stores and projection workers in every test. Most of these are not bugs in the concept but failures to plan for them from the start.

## Detailed Explanation

### Pitfall 1: Stale Projections in the UI

```
User submits order → command handler → event appended → async projection starts
User immediately navigates to order list → GET /api/orders → reads from projection
Projection not yet updated → order doesn't appear → user refreshes → appears

Result: "ghost submit" bug — user submits twice because they thought it failed
```

**Mitigation**:
```csharp
// Option A: Return the write result directly — client doesn't need to re-query
public class PlaceOrderHandler : IRequestHandler<PlaceOrderCommand, PlaceOrderResult>
{
    public async Task<PlaceOrderResult> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        // ... create order, append events ...
        return new PlaceOrderResult(
            OrderId: order.Id.Value,
            Status: "Pending",
            Total: order.Total.Amount);
        // Client uses this directly — no read-after-write needed
    }
}

// Option B: Synchronous inline projection for critical read models
// See: projections-and-read-models.md — SnapshotLifecycle.Inline
```

### Pitfall 2: Excessively Long Event Streams

```
BankAccount aggregate: one stream per account
  10 years × 5 transactions/day × 365 days = 18,250 events

Loading account: deserialize 18,250 events → O(n) with no snapshots
Aggregate load time grows linearly with account age
```

**Signs of this problem**:
- Aggregate load time increases over time
- Queries like "load this account" take > 100ms in production

**Mitigation**:
```csharp
// Pre-plan snapshot strategy before going to production
// Don't wait until streams are long — add snapshots from day 1
options.Projections.Snapshot<BankAccount>(SnapshotLifecycle.Inline);

// Or in custom store: snapshot every 50 events
if (aggregate.Version % 50 == 0)
    await snapshotStore.SaveAsync(aggregate.Id, aggregate.TakeSnapshot(), ct);
```

### Pitfall 3: Wrong Event Granularity

**Too coarse (lost context)**:
```csharp
// ❌ Too coarse: entire aggregate state in one event — not event sourcing
public record CustomerUpdatedEvent(
    int Id, string Name, string Email, string Phone, Address Address, ...);
// 15 fields change at different times for different reasons
// Audit trail: "something changed" — not useful
```

**Too fine (event spam)**:
```csharp
// ❌ Too fine: one event per field — meaningless
public record FirstNameChangedEvent(int CustomerId, string NewFirstName);
public record LastNameChangedEvent(int CustomerId, string NewLastName);
public record PhoneNumberChangedEvent(int CustomerId, string NewPhone);
// One "edit profile" form produces 3-10 events with no business meaning
```

**Right granularity (business intent)**:
```csharp
// ✅ Business-meaningful events
public record CustomerContactDetailsUpdatedEvent(
    int CustomerId, string Email, string Phone, DateTimeOffset OccurredAt);
// One business action → one event → meaningful audit entry
// "Customer updated contact details on 2025-11-01"

public record OrderShippingAddressChangedEvent(
    int OrderId, Address NewAddress, string Reason, DateTimeOffset OccurredAt);
```

### Pitfall 4: Testing Complexity

Event Sourcing requires more test infrastructure than CRUD:

```csharp
// ❌ Complex integration test setup
public class OrderTests : IAsyncLifetime
{
    private EventStoreDbContainer? _container;
    private EventStoreClient? _client;

    public async Task InitializeAsync()
    {
        _container = new EventStoreDbContainer();
        await _container.StartAsync();
        _client = new EventStoreClient(EventStoreClientSettings.Create(_container.GetConnectionString()));
        // Setup stream for every test...
    }
    // ...
}

// ✅ Better: test aggregate in isolation without event store infrastructure
[Fact]
public void SubmitOrder_WithLines_ChangesStatusAndRaisesEvent()
{
    // Arrange: build aggregate from events (Given-When-Then pattern)
    var order = Order.LoadFrom([
        new OrderCreatedEvent(orderId: 1, customerId: 7),
        new OrderLineAddedEvent(orderId: 1, productId: 5, qty: 2, price: 49.99m)
    ]);

    // Act: execute domain method
    order.Submit();

    // Assert: check new events raised (not state directly)
    Assert.Single(order.GetNewEvents().OfType<OrderSubmittedEvent>());
    Assert.Equal(OrderStatus.Submitted, order.Status);
}
```

### Pitfall 5: Commands Stored as Events

```csharp
// ❌ WRONG: storing the command (intent), not the event (fact)
await store.AppendAsync("order-42", new SubmitOrderCommand(42));
// "SubmitOrderCommand" is an instruction, not something that happened

// ✅ RIGHT: store past-tense facts
await store.AppendAsync("order-42", new OrderSubmittedEvent(42, submittedAt: now));
```

### Pitfall 6: GDPR Right to Erasure

```
Event log is immutable → you can't delete personal data → GDPR violation risk

Mitigation options:
1. Encrypt PII in event payloads with a per-customer encryption key → delete the key
2. Store PII in a side table (referenced by ID in events) → delete the side table row
3. Event payload "crypto-shredding" strategy
```

## Code Example

```csharp
// Given-When-Then test pattern for Event Sourcing — no event store needed
public static class OrderAggregate
{
    public static IReadOnlyList<object> When(
        IEnumerable<object> given, params Func<Order, object[]>[] commands)
    {
        var aggregate = Order.LoadFrom(given);
        var produced = new List<object>();
        foreach (var cmd in commands)
        {
            var events = cmd(aggregate);
            produced.AddRange(events);
            foreach (var e in events) aggregate.Apply(e);
        }
        return produced;
    }
}

[Fact]
public void SubmitOrder_ProducesSubmittedEvent()
{
    var given = new object[] { new OrderCreatedEvent(1, 7), new OrderLineAddedEvent(1, 5, 2, 99m) };
    var produced = OrderAggregate.When(given, order => order.Submit().ToArray());
    Assert.Single(produced.OfType<OrderSubmittedEvent>());
}
```

## Common Follow-up Questions

- How do you handle GDPR "right to erasure" in an immutable event store?
- How do you prevent event granularity mistakes — what review process catches them?
- How do you test async projection workers in isolation?
- What is event sourcing's impact on team velocity compared to traditional persistence?
- How do you migrate from Event Sourcing back to traditional persistence if it proves too costly?

## Common Mistakes / Pitfalls

- **No snapshot strategy defined before launch**: deciding to add snapshots after 2 years of production is much harder than designing it in from the start.
- **Domain events = integration events**: domain events (OrderSubmitted within a bounded context) should not be sent directly to other services — they're internal implementation details. Publish integration events separately.
- **Rebuilding all projections in the same DB transaction**: a rebuild that processes 1 million events in one DB transaction will lock the DB and likely timeout.
- **No dead-letter / error handling for projection workers**: a projection handler that keeps failing will stop the entire worker, falling further and further behind the event stream.

## References

- [Event Sourcing pitfalls — Oskar Dudycz](https://event-driven.io/en/event_sourcing_is_not_about_history/) (verify URL)
- [See: event-sourcing-fundamentals.md](./event-sourcing-fundamentals.md)
- [See: event-schema-evolution.md](./event-schema-evolution.md)
- [See: projections-and-read-models.md](./projections-and-read-models.md)
