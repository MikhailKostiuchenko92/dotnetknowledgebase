# Projections and Read Models in Event Sourcing

**Category:** Architecture / Event Sourcing
**Difficulty:** 🟡 Middle
**Tags:** `event-sourcing`, `projections`, `read-models`, `catch-up-subscriptions`, `persistent-subscriptions`, `rebuild`

## Question

> How do projections work in Event Sourcing? What is the difference between synchronous and asynchronous projections? What is a catch-up subscription, and how do you rebuild a projection from scratch?

## Short Answer

A **projection** in Event Sourcing is a handler that reads events from the event store and builds or updates a read model (denormalized view optimised for queries). Synchronous projections update the read model in the same transaction as the event append — strong consistency but slower writes. Asynchronous projections use **catch-up subscriptions** — they replay all events from a checkpoint position and process new events as they arrive. Since the read model is entirely derived from events, it can be dropped and rebuilt at any time by replaying from position 1.

## Detailed Explanation

### Synchronous vs Asynchronous Projections

| | Synchronous | Asynchronous |
|--|-------------|-------------|
| **Transaction** | Same as event append | Separate — eventual consistency |
| **Consistency** | Strong (reads see own writes) | Eventual (seconds/minutes lag) |
| **Performance** | Slower writes (all projections run inline) | Fast writes — projections don't block |
| **Failure handling** | Event append fails if projection fails | Projection can retry independently |
| **Use case** | Critical read models (same-request consistency) | Analytics, search indexes, dashboards |

### Synchronous Projection (In-Process, Same Transaction)

```csharp
// Domain event dispatched within SaveChanges / event append
public class OrderSummaryProjection(AppDbContext db)
    : INotificationHandler<OrderSubmittedEvent>
{
    public async Task Handle(OrderSubmittedEvent e, CancellationToken ct)
    {
        var summary = await db.Set<OrderSummary>().FindAsync([e.OrderId], ct);
        if (summary is not null)
        {
            summary.Status = "Submitted";
            summary.SubmittedAt = e.OccurredAt;
            // No SaveChanges here — runs inside the same EF Core session
        }
    }
}
```

### Asynchronous Projection with Catch-Up Subscription

A catch-up subscription starts from a stored checkpoint and processes all events in order:

```csharp
// Hosted service: starts from last checkpoint, processes new events continuously
public class OrderProjectionWorker(IEventStore store, IProjectionCheckpoint checkpoint, 
    OrderSearchProjection projection) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        // Load last processed position from persistent storage
        long from = await checkpoint.GetAsync("order-search", ct);

        await foreach (var envelope in store.SubscribeFromAsync(from, ct))
        {
            if (envelope.Event is OrderSubmittedEvent e)
                await projection.HandleAsync(e, ct);

            // Save checkpoint every 100 events to limit replay on restart
            if (envelope.GlobalPosition % 100 == 0)
                await checkpoint.SaveAsync("order-search", envelope.GlobalPosition, ct);
        }
    }
}

// Checkpoint stored in DB (survives process restart)
public class DbProjectionCheckpoint(AppDbContext db) : IProjectionCheckpoint
{
    public async Task<long> GetAsync(string name, CancellationToken ct)
    {
        var row = await db.Set<ProjectionCheckpoint>()
            .FirstOrDefaultAsync(c => c.Name == name, ct);
        return row?.Position ?? 0L;
    }

    public async Task SaveAsync(string name, long position, CancellationToken ct)
    {
        var row = await db.Set<ProjectionCheckpoint>()
            .FirstOrDefaultAsync(c => c.Name == name, ct)
            ?? new ProjectionCheckpoint { Name = name };
        row.Position = position;
        if (row.Id == 0) db.Set<ProjectionCheckpoint>().Add(row);
        await db.SaveChangesAsync(ct);
    }
}
```

### Rebuilding a Projection

Because the read model is fully derived from events, it can be rebuilt at any time:

```csharp
public class ProjectionRebuildService(IEventStore store, IDbContextFactory<AppDbContext> factory)
{
    public async Task RebuildOrderSearchAsync(CancellationToken ct)
    {
        using var db = factory.CreateDbContext();

        // 1. Drop all existing read model data
        await db.Database.ExecuteSqlRawAsync("TRUNCATE TABLE OrderSummaries", ct);

        // 2. Replay all events from position 1
        long processed = 0;
        await foreach (var envelope in store.ReadAllEventsAsync(fromPosition: 1, ct))
        {
            switch (envelope.Event)
            {
                case OrderCreatedEvent e:
                    db.Set<OrderSummary>().Add(new OrderSummary
                    {
                        Id = e.OrderId, Status = "Draft", CreatedAt = e.OccurredAt
                    });
                    break;
                case OrderSubmittedEvent e:
                    var row = await db.Set<OrderSummary>().FindAsync([e.OrderId], ct);
                    if (row is not null) row.Status = "Submitted";
                    break;
            }

            // Batch saves to avoid loading all changes in memory
            if (++processed % 500 == 0)
                await db.SaveChangesAsync(ct);
        }

        await db.SaveChangesAsync(ct); // ← save remaining
    }
}
```

### Competing Consumers (Parallel Projection Rebuild)

For high-volume event stores, partition events and rebuild in parallel:

```csharp
// Partition by aggregate stream shard — parallel rebuild per partition
var partitions = Enumerable.Range(0, 8).Select(i =>
    Task.Run(() => RebuildPartitionAsync(partition: i, totalPartitions: 8, ct)));
await Task.WhenAll(partitions);
```

### EventStoreDB Persistent Subscriptions

EventStoreDB has first-class support for projection subscriptions:

```csharp
// Persistent subscription: survives process restart, managed checkpoint
await client.CreateToAllAsync(
    groupName: "order-summary-projection",
    settings: PersistentSubscriptionSettings.Create()
        .StartFromBeginning()
        .WithExtraStatistics());

var sub = await client.SubscribeToAllAsync("order-summary-projection",
    async (_, evt, retryCount, ct) =>
    {
        if (evt.Event.EventType == "OrderSubmitted")
            await HandleOrderSubmitted(Deserialize(evt.Event.Data), ct);
    });
```

## Code Example

```csharp
// Full projection pipeline: event → handler → read model
public class OrderSearchProjection(IElasticClient elastic)
{
    // Handles both replay (rebuild) and live events
    public async Task HandleAsync(object @event, CancellationToken ct) =>
        @event switch
        {
            OrderCreatedEvent e => await elastic.IndexDocumentAsync(
                new OrderSearchDoc(e.OrderId, "Draft", 0m, e.OccurredAt), ct),
            OrderSubmittedEvent e => await elastic.UpdateAsync<OrderSearchDoc>(e.OrderId,
                u => u.Doc(new { Status = "Submitted", SubmittedAt = e.OccurredAt }), ct),
            OrderConfirmedEvent e => await elastic.UpdateAsync<OrderSearchDoc>(e.OrderId,
                u => u.Doc(new { Status = "Confirmed" }), ct),
            _ => Task.CompletedTask
        };
}
```

## Common Follow-up Questions

- How do you handle out-of-order events in an async projection?
- What is a "projection versioning strategy" — how do you handle changing projection logic for existing events?
- How do you test projections — both unit tests and integration tests?
- What is a "competing consumer" projection group, and when do you need one?
- How do you handle projection failures without losing events?

## Common Mistakes / Pitfalls

- **No checkpoint storage**: if the worker restarts and has no checkpoint, it replays all events from position 1 every time — potentially millions of events.
- **SaveChanges after every event**: batch writes (every 100–500 events) are 50–100x faster than committing after each event during rebuild.
- **Projection logic with side effects on rebuild**: a projection that sends emails or calls external APIs should guard against "this is a replay" — only send emails for live events.
- **Sync projection blocking command handling**: running heavy sync projections in the command pipeline (e.g., full-text indexing) dramatically slows write throughput.

## References

- [Projections in EventStoreDB](https://developers.eventstore.com/server/v22.10/projections.html)
- [Marten projections documentation](https://martendb.io/events/projections/)
- [See: event-sourcing-fundamentals.md](./event-sourcing-fundamentals.md)
- [See: event-store-design.md](./event-store-design.md)
