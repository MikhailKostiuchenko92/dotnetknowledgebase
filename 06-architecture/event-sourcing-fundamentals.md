# Event Sourcing Fundamentals

**Category:** Architecture / Event Sourcing
**Difficulty:** 🟢 Junior
**Tags:** `event-sourcing`, `append-only-log`, `state-reconstruction`, `audit-trail`, `Greg-Young`, `EventStoreDB`

## Question

> What is Event Sourcing? How does it differ from traditional state-based persistence, and what are the core benefits (audit trail, temporal queries, event replay)?

## Short Answer

**Event Sourcing** stores the sequence of events that led to the current state, rather than the current state itself. Instead of an `Orders` table with an `Status = "Confirmed"` row, you have an event log: `[OrderCreated, LineAdded, LineAdded, OrderSubmitted, OrderConfirmed]`. Current state is derived by **replaying** these events. The core benefits: a built-in complete audit trail (every change is recorded with who/when/why), the ability to reconstruct the state at any point in time (temporal queries), and the ability to replay events to populate new read models or fix bugs by replaying with corrected logic.

## Detailed Explanation

### Traditional State Persistence vs Event Sourcing

**Traditional (state-based)**:
```
Orders table:
  Id=42, CustomerId=7, Status="Confirmed", Total=149.99, UpdatedAt=2025-11-01

Problems:
  - What was the previous status? Lost.
  - When was it submitted? Lost.
  - Who confirmed it? Not stored (unless you add audit columns).
  - Can you replay the sequence of changes? No.
```

**Event Sourcing (event-based)**:
```
OrderEvents stream (orderId=42):
  1. OrderCreatedEvent    {customerId:7, timestamp:2025-11-01T09:00}
  2. OrderLineAddedEvent  {productId:5, qty:1, price:49.99}
  3. OrderLineAddedEvent  {productId:8, qty:2, price:50.00}
  4. OrderSubmittedEvent  {submittedAt:2025-11-01T09:05}
  5. OrderConfirmedEvent  {confirmedBy:admin1, timestamp:2025-11-01T10:30}

Benefits:
  - Complete audit trail built-in — no extra code
  - Replay events 1-3 to see the state before submission
  - Replay all events to build a new read model
  - Debug by replaying specific events with modified logic
```

### Core Mechanics

**Appending events** (write):
```csharp
// No UPDATE or DELETE — only INSERT new events
await eventStore.AppendToStreamAsync("order-42",
    expectedVersion: 4,  // optimistic concurrency
    events: [new OrderConfirmedEvent(orderId: 42, confirmedBy: "admin1")]);
```

**Rebuilding state** (read):
```csharp
// Load all events for the aggregate, replay them
var events = await eventStore.ReadStreamAsync("order-42");
var order = new Order();
foreach (var @event in events) order.Apply(@event);
// Now order.Status == Confirmed
```

### Why Event Sourcing Exists

| Benefit | Description |
|---------|-------------|
| **Audit trail** | Every change recorded as a fact — who changed what and when |
| **Temporal queries** | Replay events up to a timestamp to get state-at-that-time |
| **Event replay** | Fix bugs by replaying events with corrected logic |
| **New read models** | Build new projections anytime by replaying the full history |
| **Debugging** | Reproduce bugs by replaying the exact event sequence that caused them |
| **Integration** | Events are natural integration points for downstream consumers |

### The Event Log is the Source of Truth

```
State (read model) = f(events)

Events never change or get deleted.
State is derived — it's disposable and rebuilable.
```

### Event Sourcing is NOT

- **Not event-driven architecture in general** (any pub/sub system): Event Sourcing is specifically about storing the source of truth as events, not just publishing events
- **Not required for CQRS**: you can have CQRS without Event Sourcing and vice versa
- **Not suitable for every domain**: high-volume transactional data (financial tick data, IoT streams) may need different approaches; configuration data doesn't benefit from event sourcing

## Code Example

```csharp
// Simple Event Sourcing aggregate — rebuilds state from events
public class Order
{
    public int Id { get; private set; }
    public OrderStatus Status { get; private set; }
    public decimal Total { get; private set; }
    private int _version;
    private readonly List<object> _newEvents = [];

    // Static factory: replay historical events to load existing order
    public static Order LoadFrom(IEnumerable<object> history)
    {
        var order = new Order();
        foreach (var @event in history) order.Apply(@event);
        return order;
    }

    // Create: raises event without loading history
    public static Order Create(int customerId)
    {
        var order = new Order();
        order.RaiseAndApply(new OrderCreatedEvent(customerId, DateTime.UtcNow));
        return order;
    }

    public void Submit()
    {
        if (Status != OrderStatus.Draft) throw new InvalidOperationException();
        RaiseAndApply(new OrderSubmittedEvent(Id, DateTime.UtcNow));
    }

    // Apply: mutates state from event (no validation — events already happened)
    private void Apply(object @event)
    {
        switch (@event)
        {
            case OrderCreatedEvent e:
                Status = OrderStatus.Draft;
                break;
            case OrderSubmittedEvent e:
                Status = OrderStatus.Submitted;
                break;
        }
        _version++;
    }

    // RaiseAndApply: for new events (command path)
    private void RaiseAndApply(object @event)
    {
        _newEvents.Add(@event);
        Apply(@event);
    }

    // After save: these events go to the event store
    public IReadOnlyList<object> GetNewEvents() => _newEvents.AsReadOnly();
}
```

## Common Follow-up Questions

- How do you query current state efficiently if you must replay all events every time?
- What is a snapshot in Event Sourcing, and when do you need one?
- How do you handle event schema evolution — what happens when you add a new field to an event?
- How does Event Sourcing relate to CQRS — do you need both?
- What are the operational challenges of Event Sourcing in production?

## Common Mistakes / Pitfalls

- **Confusing Event Sourcing with event-driven architecture**: publishing domain events to a message bus is NOT Event Sourcing. Event Sourcing means the event log IS the primary store of truth.
- **Storing commands, not events**: `OrderSubmitCommand` is a request; `OrderSubmitted` is a fact. Only store past-tense facts (events), not commands.
- **Using Event Sourcing for every entity**: reference data (countries, categories), user settings, and simple configuration data don't benefit from event sourcing — they just create operational overhead.
- **Forgetting that events are immutable facts**: once an event is written, it cannot be modified. If you discover the event payload was wrong, you write a correcting event — you don't update the original.

## References

- [Event Sourcing — Martin Fowler](https://martinfowler.com/eaaDev/EventSourcing.html) (verify URL)
- [EventStoreDB — eventstoredb.com](https://www.eventstore.com/)
- [Marten — .NET Event Store on PostgreSQL](https://martendb.io/)
- [See: event-sourcing-in-dotnet.md](./event-sourcing-in-dotnet.md)
- [See: cqrs-fundamentals.md](./cqrs-fundamentals.md)
