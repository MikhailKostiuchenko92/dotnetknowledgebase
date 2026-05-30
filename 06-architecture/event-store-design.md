# Event Store Design

**Category:** Architecture / Event Sourcing
**Difficulty:** 🟡 Middle
**Tags:** `event-sourcing`, `event-store`, `stream-versioning`, `optimistic-concurrency`, `aggregate-streams`, `schema`

## Question

> How do you design an event store? Describe the schema for storing events, how optimistic concurrency is implemented using stream versions, and the concept of aggregate event streams.

## Short Answer

An event store is an append-only log organised by **streams** — one stream per aggregate instance (e.g., `order-42`). Each event has a sequential `version` (position within the stream). On write, you specify the `expectedVersion` — if it doesn't match the current stream head, the write fails with a `ConcurrencyException`. The minimal schema: `StreamId`, `Version`, `EventType`, `Payload` (JSON), `Timestamp`. This `expectedVersion` check is the Event Sourcing equivalent of an optimistic concurrency token.

## Detailed Explanation

### Core Schema

```sql
-- Event store table (append-only — no UPDATE, no DELETE)
CREATE TABLE EventStreams (
    StreamId     NVARCHAR(200) NOT NULL,         -- e.g., "order-42", "customer-7"
    Version      INT           NOT NULL,          -- per-stream sequence: 1, 2, 3...
    EventType    NVARCHAR(200) NOT NULL,          -- fully qualified type name or discriminator
    Payload      NVARCHAR(MAX) NOT NULL,          -- JSON event payload
    Metadata     NVARCHAR(MAX) NULL,              -- causation-id, correlation-id, user-id
    OccurredAt   DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT PK_EventStreams PRIMARY KEY (StreamId, Version)  -- ← prevents version collision
);
```

The `PRIMARY KEY (StreamId, Version)` enforces optimistic concurrency at the database level: two concurrent writers both trying to append `Version=5` to `order-42` will produce a unique constraint violation.

### Aggregate Streams

Each aggregate instance gets its own stream:
```
Stream: "order-42"
  Version 1: OrderCreatedEvent
  Version 2: OrderLineAddedEvent
  Version 3: OrderLineAddedEvent
  Version 4: OrderSubmittedEvent
  Version 5: OrderConfirmedEvent

Stream: "order-43"
  Version 1: OrderCreatedEvent
  Version 2: OrderSubmittedEvent

Stream: "customer-7"
  Version 1: CustomerRegisteredEvent
  Version 2: CustomerAddressUpdatedEvent
```

### Optimistic Concurrency

```csharp
public class SqlEventStore(string connectionString) : IEventStore
{
    public async Task AppendToStreamAsync(
        string streamId,
        int expectedVersion,
        IEnumerable<EventEnvelope> events,
        CancellationToken ct = default)
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync(ct);
        using var tx = conn.BeginTransaction(IsolationLevel.ReadCommitted);

        // 1. Read current stream version
        var currentVersion = await conn.ExecuteScalarAsync<int?>(
            "SELECT MAX(Version) FROM EventStreams WHERE StreamId = @id",
            new { id = streamId }, tx) ?? 0;

        // 2. Optimistic concurrency check
        if (currentVersion != expectedVersion)
        {
            throw new OptimisticConcurrencyException(
                $"Stream {streamId}: expected version {expectedVersion}, actual {currentVersion}.");
        }

        // 3. Append events
        var nextVersion = expectedVersion;
        foreach (var envelope in events)
        {
            nextVersion++;
            await conn.ExecuteAsync("""
                INSERT INTO EventStreams (StreamId, Version, EventType, Payload, Metadata, OccurredAt)
                VALUES (@StreamId, @Version, @EventType, @Payload, @Metadata, @OccurredAt)
                """,
                new {
                    StreamId = streamId,
                    Version = nextVersion,
                    EventType = envelope.EventType,
                    Payload = JsonSerializer.Serialize(envelope.Event),
                    Metadata = JsonSerializer.Serialize(envelope.Metadata),
                    OccurredAt = DateTime.UtcNow
                }, tx);
        }

        await tx.CommitAsync(ct);
    }

    public async Task<IReadOnlyList<EventEnvelope>> ReadStreamAsync(
        string streamId, int fromVersion = 1, CancellationToken ct = default)
    {
        using var conn = new SqlConnection(connectionString);
        var rows = await conn.QueryAsync<EventRow>(
            "SELECT * FROM EventStreams WHERE StreamId = @id AND Version >= @from ORDER BY Version",
            new { id = streamId, from = fromVersion });
        return rows.Select(Deserialize).ToList();
    }
}
```

### Global Event Position

For catch-up subscriptions (rebuilding projections), you need a global ordering:

```sql
-- Add a global sequence for catch-up subscriptions
ALTER TABLE EventStreams ADD GlobalPosition BIGINT IDENTITY(1,1);

-- Projection rebuild reads in GlobalPosition order
SELECT * FROM EventStreams WHERE GlobalPosition > @checkpoint ORDER BY GlobalPosition;
```

### EventStoreDB vs Custom SQL

| Aspect | Custom SQL Event Store | EventStoreDB |
|--------|----------------------|-------------|
| **Setup** | Already have SQL Server | Extra infrastructure |
| **Concurrency** | Unique constraint on (StreamId, Version) | Native expected version |
| **Catch-up subscriptions** | Manual polling + GlobalPosition | Native persistent subscriptions |
| **Projections** | Write yourself | Native projections (JavaScript) |
| **Scale** | Limited by SQL Server | Optimised for event streams |
| **When to use** | Existing SQL Server, small-medium scale | Purpose-built ES, high throughput |

### Marten (PostgreSQL Event Store)

For .NET teams that want a ready-made event store without EventStoreDB:

```csharp
// Marten — PostgreSQL as event store
builder.Services.AddMarten(options =>
{
    options.Connection(connectionString);
    options.Events.AddEventType<OrderCreatedEvent>();
    options.Events.AddEventType<OrderSubmittedEvent>();
}).UseLightweightSessions();

// Usage: almost identical to the custom SQL store above
public async Task<Order?> LoadAsync(Guid orderId, CancellationToken ct)
{
    await using var session = store.LightweightSession();
    return await session.Events.AggregateStreamAsync<Order>(orderId, token: ct);
}
```

## Code Example

```csharp
// Complete append + load cycle using the custom SQL event store
public class OrderRepository(IEventStore store) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(OrderId id, CancellationToken ct)
    {
        var streamId = $"order-{id.Value}";
        var events = await store.ReadStreamAsync(streamId, ct: ct);
        if (!events.Any()) return null;
        return Order.LoadFrom(events.Select(e => e.Event));
    }

    public async Task SaveAsync(Order order, CancellationToken ct)
    {
        var streamId = $"order-{order.Id.Value}";
        var envelopes = order.GetNewEvents()
            .Select(e => new EventEnvelope(e.GetType().Name, e))
            .ToList();

        await store.AppendToStreamAsync(
            streamId,
            expectedVersion: order.Version - envelopes.Count,  // version before new events
            envelopes, ct);
    }
}
```

## Common Follow-up Questions

- How do you handle event schema evolution when the payload format changes?
- What is a catch-up subscription, and how do you implement one on a custom SQL event store?
- How do you handle long aggregate streams — performance implications of replaying 10,000 events?
- How do you implement event store soft-deletion or stream archival?
- What is the difference between a stream version and a global event position?

## Common Mistakes / Pitfalls

- **No concurrency check**: appending without checking `expectedVersion` allows two concurrent commands to append to the same stream at the same version, corrupting the event sequence.
- **Storing commands instead of events**: `OrderSubmitCommand` is an intent; `OrderSubmitted` is a fact. Only immutable past-tense facts belong in the event store.
- **One global stream for all aggregates**: putting all events in one table with no stream segmentation makes rebuild and per-aggregate queries very slow.
- **Mutable event payloads**: updating an event payload in the store is the cardinal sin of Event Sourcing. Fix event schema bugs with upcasters, not by modifying stored events.

## References

- [EventStoreDB documentation](https://developers.eventstore.com/)
- [Marten — .NET Event Store on PostgreSQL](https://martendb.io/)
- [See: event-sourcing-fundamentals.md](./event-sourcing-fundamentals.md)
- [See: event-schema-evolution.md](./event-schema-evolution.md)
