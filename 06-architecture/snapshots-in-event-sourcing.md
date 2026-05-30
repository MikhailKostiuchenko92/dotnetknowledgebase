# Snapshots in Event Sourcing

**Category:** Architecture / Event Sourcing
**Difficulty:** 🟡 Middle
**Tags:** `event-sourcing`, `snapshots`, `aggregate-performance`, `large-streams`, `state-reconstruction`

## Question

> What is a snapshot in Event Sourcing, and why do you need one? How do you implement a snapshot strategy, and how does loading an aggregate change when snapshots are available?

## Short Answer

A **snapshot** is a serialized checkpoint of an aggregate's current state at a specific event version. Instead of replaying all events from the beginning on every load, the system loads the latest snapshot and replays only the events that occurred *after* that snapshot version. Without snapshots, an aggregate with 10,000 events becomes increasingly slow to load. A snapshot is taken periodically (every N events, or after writes exceeding a threshold), stored separately from the event stream, and used as a fast starting point for reconstruction.

## Detailed Explanation

### The Problem: Long Streams

```
Without snapshots (10,000 events):
  Load order-42: read 10,000 events from DB → deserialize → apply one by one
  Time: potentially seconds; memory: large

With a snapshot at version 9,900:
  Load order-42: read snapshot at v9,900 → deserialize aggregate state
               + read 100 events (9,901–10,000) → apply
  Time: milliseconds; memory: minimal
```

### Snapshot Storage

Snapshots are stored separately from the event stream — either in a dedicated table or alongside events with a special event type:

```sql
-- Dedicated snapshot table
CREATE TABLE AggregateSnapshots (
    StreamId        NVARCHAR(200) NOT NULL,
    Version         INT           NOT NULL,  -- event version when snapshot was taken
    AggregateType   NVARCHAR(200) NOT NULL,
    State           NVARCHAR(MAX) NOT NULL,  -- serialized aggregate state (JSON)
    CreatedAt       DATETIME2     NOT NULL,
    CONSTRAINT PK_Snapshots PRIMARY KEY (StreamId, Version)
);
```

### Snapshot-Aware Repository

```csharp
public class SnapshotAwareOrderRepository(IEventStore eventStore, ISnapshotStore snapshots)
    : IOrderRepository
{
    private const int SnapshotThreshold = 50; // take snapshot every 50 events

    public async Task<Order?> GetByIdAsync(OrderId id, CancellationToken ct)
    {
        var streamId = $"order-{id.Value}";

        // 1. Try to load the latest snapshot
        var snapshot = await snapshots.GetLatestAsync<OrderSnapshot>(streamId, ct);

        int fromVersion;
        Order order;

        if (snapshot is not null)
        {
            // Start from snapshot state
            order = Order.RestoreFrom(snapshot.State);
            fromVersion = snapshot.Version + 1;  // ← only replay events AFTER snapshot
        }
        else
        {
            // No snapshot: start from scratch
            order = new Order();
            fromVersion = 1;
        }

        // 2. Replay only remaining events
        var events = await eventStore.ReadStreamAsync(streamId, fromVersion: fromVersion, ct);
        if (!events.Any() && snapshot is null) return null;

        foreach (var envelope in events) order.Apply(envelope.Event);

        return order;
    }

    public async Task SaveAsync(Order order, CancellationToken ct)
    {
        var streamId = $"order-{order.Id.Value}";
        var newEvents = order.GetNewEvents().ToList();

        await eventStore.AppendToStreamAsync(streamId,
            expectedVersion: order.Version - newEvents.Count, newEvents, ct);

        // Take a snapshot if threshold crossed
        if (order.Version % SnapshotThreshold == 0)
        {
            await snapshots.SaveAsync(streamId, new OrderSnapshot
            {
                Version = order.Version,
                State = order.CreateSnapshot(),  // serializable state object
                CreatedAt = DateTime.UtcNow
            }, ct);
        }
    }
}
```

### Aggregate Snapshot Contract

```csharp
public class Order : AggregateRoot
{
    // Create a snapshot of current state
    public OrderSnapshotState CreateSnapshot() => new(
        Id: Id.Value,
        Status: Status,
        Total: Total.Amount,
        Currency: Total.Currency,
        LineCount: _lines.Count,
        Version: Version);

    // Restore from snapshot — bypasses full event replay
    public static Order RestoreFrom(OrderSnapshotState state)
    {
        var order = new Order();
        order.Id = new OrderId(state.Id);
        order.Status = state.Status;
        order.Total = new Money(state.Total, state.Currency);
        order._version = state.Version;
        // Note: _lines collection is reconstructed as Count only (or fully if needed)
        return order;
    }
}

public record OrderSnapshotState(
    int Id, OrderStatus Status, decimal Total, string Currency, int LineCount, int Version);
```

### Snapshot Strategies

| Strategy | When to snapshot | Use case |
|----------|-----------------|---------|
| **Every N events** | When aggregate version % N == 0 | Predictable, simple |
| **On write if stale** | If events since last snapshot > threshold | Adaptive — snapshots only when needed |
| **Time-based** | Every hour/day of activity | Long-lived aggregates (contracts, accounts) |
| **Explicit** | Command handler explicitly requests snapshot | Infrequent but high-value aggregates |

### Snapshot Invalidation

When the aggregate's `Apply()` logic changes (new events, changed state shape), old snapshots may be incompatible:

```csharp
// Version the snapshot schema
public record OrderSnapshotState(
    int SchemaVersion,  // ← increment when snapshot shape changes
    int Id, OrderStatus Status, ...);

// When loading: if SchemaVersion is old, discard snapshot and replay from events
if (snapshot?.State.SchemaVersion != OrderSnapshotState.CurrentSchemaVersion)
    return await RebuildFromEventsAsync(streamId, ct);
```

## Code Example

```csharp
// Marten (PostgreSQL): snapshot support built-in
options.Projections.Snapshot<Order>(SnapshotLifecycle.Inline);

// Load: Marten automatically loads snapshot + remaining events
await using var session = store.LightweightSession();
var order = await session.Events.AggregateStreamAsync<Order>(orderId);
// ↑ Marten internally: load latest snapshot + events after snapshot version

// Manual snapshot trigger with Marten
await session.Events.WriteToAggregate<Order>(orderId, stream =>
    stream.AppendOne(new OrderConfirmedEvent(orderId)));
// Marten handles snapshotting per SnapshotLifecycle setting
```

## Common Follow-up Questions

- How do you handle snapshot version incompatibility when the aggregate shape changes?
- Should snapshots be stored in the same DB as events, or separately?
- How do you rebuild snapshots after changing the snapshot schema?
- Is it possible to delete old events once a snapshot exists?
- When is the performance overhead of snapshotting not worth it?

## Common Mistakes / Pitfalls

- **Snapshotting too eagerly (every event)**: if you snapshot every time the aggregate changes, you negate the benefit — the snapshot store becomes as large as the event store.
- **Not versioning snapshot schemas**: adding a new field to the aggregate's state without versioning the snapshot makes old snapshots unloadable after deployment.
- **Assuming snapshots replace events**: snapshots are a performance optimisation. The event log is still the source of truth. Never delete events because a snapshot exists.
- **Snapshot state with complex object graphs**: serializing an aggregate's entire in-memory state (including collections) can produce very large snapshot payloads — model the snapshot state to include only what's necessary for reconstruction.

## References

- [Marten snapshots documentation](https://martendb.io/events/projections/live-aggregates.html)
- [EventStoreDB persistent subscriptions + snapshots](https://developers.eventstore.com/server/v22.10/) (verify URL)
- [See: event-sourcing-fundamentals.md](./event-sourcing-fundamentals.md)
- [See: event-store-design.md](./event-store-design.md)
