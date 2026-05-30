# Outbox Pattern Architecture

**Category:** Architecture / Cross-Cutting Concerns
**Difficulty:** 🔴 Senior
**Tags:** `outbox-pattern`, `transactional-outbox`, `at-least-once-delivery`, `CDC`, `polling-relay`, `eventual-consistency`, `integration-events`

## Question

> Why is directly publishing messages in a command handler unreliable, and how does the Transactional Outbox pattern solve it? Compare polling relay vs CDC (Change Data Capture) for outbox processing.

## Short Answer

Directly calling a message bus in a handler creates a **dual-write problem**: the DB commit and the message publish are two separate operations — if the publish fails after commit (or the process crashes between them), the event is lost. The **Transactional Outbox** pattern writes the event to an `outbox` table in the **same DB transaction** as the state change — guaranteeing atomicity. A separate relay process then publishes outbox entries to the message bus. Two relay approaches: **polling** (background service reads and publishes unprocessed rows every N seconds) and **CDC** (database change stream triggers publish without polling delay).

## Detailed Explanation

### The Dual-Write Problem

```csharp
// BROKEN: two separate operations, no atomicity
public async Task Handle(PlaceOrderCommand cmd, CancellationToken ct)
{
    var order = Order.Create(cmd.CustomerId, cmd.Lines);
    await _orders.AddAsync(order, ct);
    await _db.SaveChangesAsync(ct);  // ← Step 1: DB commit

    // CRASH HERE → order saved, event never published → system inconsistency
    // OR: RabbitMQ unavailable → order saved, event never published

    await _bus.PublishAsync(new OrderPlacedEvent(order.Id), ct); // ← Step 2: message bus
}
```

### Transactional Outbox Pattern

```csharp
// CORRECT: event saved IN the same transaction as the order
public async Task Handle(PlaceOrderCommand cmd, CancellationToken ct)
{
    var order = Order.Create(cmd.CustomerId, cmd.Lines);
    _db.Orders.Add(order);

    // Write to outbox IN THE SAME TRANSACTION
    _db.OutboxMessages.Add(new OutboxMessage(
        Id:       Guid.NewGuid(),
        Type:     typeof(OrderPlacedEvent).FullName!,
        Payload:  JsonSerializer.Serialize(new OrderPlacedEvent(order.Id, cmd.CustomerId)),
        CreatedAt: DateTimeOffset.UtcNow
    ));

    await _db.SaveChangesAsync(ct);
    // ↑ Single atomic operation: order + outbox row both committed or neither
    // Message bus failure is now irrelevant — event is durably stored
}
```

### Outbox Schema

```sql
CREATE TABLE outbox.messages (
    id           UUID            PRIMARY KEY,
    type         VARCHAR(500)    NOT NULL,
    payload      JSONB           NOT NULL,
    created_at   TIMESTAMPTZ     NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ     NULL,   -- ← null = pending; not null = done
    error        TEXT            NULL    -- ← last processing error (for debugging)
);

-- Index for relay query performance
CREATE INDEX idx_outbox_pending ON outbox.messages (created_at)
    WHERE processed_at IS NULL;
```

### Relay: Polling Approach

```csharp
// Background service: polls for unprocessed outbox entries, publishes, marks done
public class OutboxRelayService(IServiceProvider sp, ILogger<OutboxRelayService> log)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            await ProcessBatchAsync(ct);
            await Task.Delay(TimeSpan.FromSeconds(5), ct); // ← polling interval
        }
    }

    private async Task ProcessBatchAsync(CancellationToken ct)
    {
        await using var scope = sp.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var bus = scope.ServiceProvider.GetRequiredService<IMessageBus>();

        var pending = await db.OutboxMessages
            .Where(m => m.ProcessedAt == null)
            .OrderBy(m => m.CreatedAt)
            .Take(100)
            .ToListAsync(ct);

        foreach (var message in pending)
        {
            try
            {
                var type = Type.GetType(message.Type)!;
                var payload = JsonSerializer.Deserialize(message.Payload, type)!;
                await bus.PublishAsync(payload, ct);

                message.ProcessedAt = DateTimeOffset.UtcNow;
                message.Error = null;
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Failed to relay outbox message {Id}", message.Id);
                message.Error = ex.Message;
                // Don't mark as processed — will be retried on next poll
            }
        }

        await db.SaveChangesAsync(ct);
    }
}
```

### Relay: CDC Approach (Change Data Capture)

```
CDC: database streams its own write log (WAL in PostgreSQL, binlog in MySQL)
Tools:
  - Debezium + Kafka: most complete, captures all table changes
  - SQL Server CDC: built-in, can feed Azure Service Bus
  - PostgreSQL logical replication + custom consumer

CDC vs Polling:
  Polling: simple to implement, adds DB load, 5-30s latency
  CDC:     zero polling load, near-realtime, more infrastructure complexity

// PostgreSQL logical replication example (conceptual):
// Debezium watches outbox table changes
// Every INSERT to outbox.messages fires a Kafka message to the relay
// Relay publishes to RabbitMQ/Azure Service Bus/MassTransit
```

### At-Least-Once Delivery

```
Outbox guarantees at-least-once delivery (not exactly-once):
  - If relay crashes after publishing but before marking as processed → republished on restart
  - Consumers MUST be idempotent: process the same message twice without double-processing

Idempotency strategies:
  1. Idempotency key: consumer checks processed messages table before acting
     INSERT INTO processed_messages (message_id) ON CONFLICT DO NOTHING
     → If conflict: already processed → skip

  2. Natural idempotency: operation is inherently idempotent (SET status = 'Shipped' twice = fine)

  3. ETag/version check: consumer loads entity, checks expected version before writing
```

## Code Example

```csharp
// EF Core SaveChanges interceptor: automatically write outbox entries for domain events
public class DomainEventOutboxInterceptor : SaveChangesInterceptor
{
    public override async ValueTask<int> SavingChangesAsync(
        DbContextEventData ev, InterceptionResult<int> result, CancellationToken ct)
    {
        var events = ev.Context?.ChangeTracker.Entries<AggregateRoot>()
            .SelectMany(e => { var evts = e.Entity.GetDomainEvents(); e.Entity.ClearDomainEvents(); return evts; })
            .Select(e => new OutboxMessage(
                Guid.NewGuid(), e.GetType().AssemblyQualifiedName!,
                JsonSerializer.Serialize(e, e.GetType()), DateTimeOffset.UtcNow))
            .ToList();

        if (events?.Count > 0)
            ev.Context!.Set<OutboxMessage>().AddRange(events);

        return await base.SavingChangesAsync(ev, result, ct);
    }
}
```

## Common Follow-up Questions

- How do you ensure outbox messages are published in order when multiple processes run the relay?
- How do you handle outbox table growth — when do you archive processed messages?
- What is the difference between Outbox pattern and Saga orchestration?
- Can `MassTransit` or `NServiceBus` implement the Outbox pattern automatically?
- How does CAP (Consistency, Availability, Partition tolerance) relate to the Outbox pattern?

## Common Mistakes / Pitfalls

- **Publishing events before the outbox commit**: `await bus.Publish()` called before `SaveChangesAsync` means the event is published even if the save fails — the dual-write problem re-introduced.
- **Not marking messages as processed**: relay that publishes but doesn't mark `ProcessedAt` will republish every entry on every poll — infinite re-delivery storm.
- **Non-idempotent consumers**: if the relay sends a message twice (at-least-once) and the consumer double-charges a payment, the Outbox guarantee provides no protection. Consumers must always be idempotent.
- **Relay without locking/ownership**: with multiple relay instances running in parallel, they may both pick up and publish the same outbox message simultaneously. Use optimistic concurrency (`WHERE processed_at IS NULL AND id = @id`) with row locking (`SELECT ... FOR UPDATE SKIP LOCKED` in PostgreSQL).

## References

- [Transactional Outbox pattern — Microsoft Azure Architecture](https://learn.microsoft.com/en-us/azure/architecture/best-practices/transactional-outbox-cosmos) (verify URL)
- [Debezium CDC documentation](https://debezium.io/documentation/)
- [MassTransit Outbox](https://masstransit.io/documentation/patterns/transactional-outbox) (verify URL)
- [See: distributed-transaction-patterns.md](./distributed-transaction-patterns.md)
- [See: domain-events.md](./domain-events.md)
