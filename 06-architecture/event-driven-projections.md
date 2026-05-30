# Event-Driven Projections

**Category:** Architecture / Event Sourcing
**Difficulty:** 🔴 Senior
**Tags:** `event-sourcing`, `projections`, `catch-up-subscriptions`, `persistent-subscriptions`, `competing-consumers`, `projection-reset`

## Question

> How do event-driven projections work in Event Sourcing? Compare catch-up subscriptions and persistent subscriptions, explain competing consumer patterns, and describe projection reset and restart strategies.

## Short Answer

Event-driven projections consume events from the event store and maintain derived read models. A **catch-up subscription** starts from a stored checkpoint position and processes all events forward, including historical ones — used for rebuild and initial catch-up. A **persistent subscription** is server-managed: the server remembers the position for a named consumer group, and multiple consumers in the group compete for events — used for scalable, fault-tolerant live projection workers. A **projection reset** discards the read model and replays from position 0, allowing you to deploy changed projection logic and rebuild from history.

## Detailed Explanation

### Catch-Up Subscription

Processes all events from a given global position, including historical events:

```csharp
public class OrderProjectionCatchUpWorker(IEventStore store, IProjectionCheckpoint cp,
    OrderSummaryProjection projection) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // 1. Load last processed global position from persistent storage
        var fromPosition = await cp.GetAsync("order-summary", stoppingToken);

        // 2. Subscribe from that position — replay old + receive new
        await foreach (var envelope in store.SubscribeFromAsync(fromPosition, stoppingToken))
        {
            try
            {
                await HandleEventAsync(envelope, stoppingToken);
                // 3. Save checkpoint every N events — limits replay on restart
                if (envelope.GlobalPosition % 100 == 0)
                    await cp.SaveAsync("order-summary", envelope.GlobalPosition, stoppingToken);
            }
            catch (Exception ex)
            {
                // Dead-letter or retry logic
                _logger.LogError(ex, "Projection failed for {EventType} at position {Pos}",
                    envelope.EventType, envelope.GlobalPosition);
            }
        }
    }
}
```

### Persistent Subscription (EventStoreDB)

Server-managed: EventStoreDB tracks the position on behalf of named consumer groups:

```csharp
// One-time: create the persistent subscription group (idempotent)
await client.CreateToAllAsync(
    groupName: "order-summary-projection",
    settings: PersistentSubscriptionSettings.Create()
        .StartFromBeginning()  // or .StartFrom(StreamPosition.Start)
        .WithCheckPointAfterMs(5000)
        .WithMaxRetryCount(3));

// Worker: subscribe and ack/nack each event
var subscription = await client.SubscribeToAllAsync(
    "order-summary-projection",
    async (sub, evt, retryCount, ct) =>
    {
        try
        {
            await HandleEventAsync(evt, ct);
            await sub.Ack(evt);  // ← tell server this event was processed
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to handle {EventType}", evt.Event.EventType);
            await sub.Nack(PersistentSubscriptionNakEventAction.Retry, ex.Message, evt);
        }
    }, cancellationToken: ct);
```

### Competing Consumers

Multiple instances of a projection worker competing for events from the same subscription group:

```
EventStoreDB persistent subscription group: "order-summary-projection"
  Consumer 1 (pod A) ← processes event #1001
  Consumer 2 (pod B) ← processes event #1002
  Consumer 3 (pod C) ← processes event #1003

Events are distributed (not duplicated) across consumers in the group.
One consumer getting an event means the others don't.
If pod A crashes: events are re-delivered to pod B or C after timeout.
```

```csharp
// All instances subscribe to the same group name — EventStoreDB handles distribution
// In Kubernetes: 3 replicas of the projection worker, all subscribe to same group
builder.Services.AddHostedService<OrderProjectionWorker>();
// Scale the deployment to 3 replicas for parallel processing
```

### Projection Reset Strategy

When projection logic changes, the read model must be rebuilt:

```csharp
public class ProjectionRebuildOrchestrator(
    IEventStore store,
    IProjectionCheckpoint checkpoint,
    IReadModelCleaner cleaner,
    OrderSummaryProjection projection)
{
    public async Task ResetAndRebuildAsync(string projectionName, CancellationToken ct)
    {
        // 1. Stop the live worker (outside this method — orchestrated separately)

        // 2. Clear the read model
        await cleaner.TruncateAsync("OrderSummaries", ct);

        // 3. Reset checkpoint to position 0
        await checkpoint.SaveAsync(projectionName, 0, ct);

        // 4. Replay all events in batches
        long position = 0;
        long processed = 0;
        await foreach (var envelope in store.ReadAllEventsAsync(fromPosition: 1, ct))
        {
            await projection.HandleAsync(envelope.Event, ct);
            position = envelope.GlobalPosition;
            if (++processed % 1000 == 0)
            {
                await checkpoint.SaveAsync(projectionName, position, ct);
                _logger.LogInformation("Rebuilt {Count} events to position {Pos}", processed, position);
            }
        }

        // 5. Save final checkpoint — worker can now resume from this position
        await checkpoint.SaveAsync(projectionName, position, ct);
        _logger.LogInformation("Projection {Name} rebuilt. Total events: {Count}", projectionName, processed);
    }
}
```

### Comparison Table

| | Catch-Up Subscription | Persistent Subscription |
|--|----------------------|----------------------|
| **Checkpoint managed by** | Application code (DB row) | Event store server |
| **Competing consumers** | Manual (partitioning) | Native |
| **Restart recovery** | Load checkpoint from DB | Server remembers position |
| **Replay support** | Yes — start from any position | Limited (some implementations) |
| **Implementation** | More code, full control | Less code, server-managed |

## Code Example

```csharp
// Projection health check — reports lag between event store and projection
public class ProjectionHealthCheck(IEventStore store, IProjectionCheckpoint cp)
    : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext ctx, CancellationToken ct)
    {
        var currentGlobal = await store.GetLastGlobalPositionAsync(ct);
        var projectedPosition = await cp.GetAsync("order-summary", ct);
        var lag = currentGlobal - projectedPosition;

        return lag < 1000
            ? HealthCheckResult.Healthy($"Projection lag: {lag} events")
            : HealthCheckResult.Degraded($"Projection lag: {lag} events (high)");
    }
}
```

## Common Follow-up Questions

- How do you handle event ordering guarantees with competing consumers?
- What happens when a projection worker is down for an extended period — how large can the lag grow?
- How do you implement blue/green projection deployment (new projection logic without downtime)?
- How do you monitor and alert on projection lag?
- What is the difference between an inline projection and an async projection in Marten?

## Common Mistakes / Pitfalls

- **No dead-letter handling**: a projection handler that keeps throwing exceptions stops the worker. Without a dead-letter queue or skip-and-log strategy, one bad event blocks all subsequent events indefinitely.
- **Projection reset without stopping the live worker**: if the live worker is still running during a reset, it races with the rebuild — producing corrupted read model state.
- **Single catch-up worker for all projections**: running 20 different projections in one sequential worker means a slow projection blocks all others. Use separate workers or concurrent handlers per projection type.
- **Ignoring projection replay side effects**: sending emails, calling external APIs, or making payments inside projection handlers is catastrophic during a rebuild. Guard against "is this a replay?" before triggering side effects.

## References

- [EventStoreDB persistent subscriptions documentation](https://developers.eventstore.com/clients/grpc/persistent-subscriptions/)
- [Marten async daemon documentation](https://martendb.io/events/projections/async-daemon.html)
- [See: projections-and-read-models.md](./projections-and-read-models.md)
- [See: event-sourcing-pitfalls.md](./event-sourcing-pitfalls.md)
