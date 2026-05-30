# Outbox Pattern

**Category:** System Design / Messaging
**Difficulty:** 🔴 Senior
**Tags:** `outbox-pattern`, `transactional-outbox`, `reliability`, `at-least-once`, `EF-Core`, `MassTransit`, `Hangfire`, `change-data-capture`

## Question

> What is the Transactional Outbox pattern, and why is it needed? How do you implement it with EF Core and MassTransit, and what are the trade-offs between polling and CDC-based relay?

## Short Answer

The Outbox pattern solves the **dual-write problem**: when you need to both write to a DB and publish a message to a broker, a naive implementation can leave them inconsistent (DB written, broker publish failed — or vice versa). The Outbox stores messages in a DB table within the same transaction as the business data, then a background process reads and publishes them to the broker. This guarantees **at-least-once delivery** with no data loss: if the relay crashes, it republishes from the outbox on restart. EF Core + MassTransit provide a built-in Outbox implementation via `AddEntityFrameworkOutbox`.

## Detailed Explanation

### The Dual-Write Problem

```csharp
// Naive approach — NOT safe
await db.Orders.AddAsync(order);
await db.SaveChangesAsync();           // ← DB write succeeds

await bus.Publish(new OrderPlaced(…)); // ← broker crashes here? Message is LOST.
                                       //   OR: network timeout → publish is retried
                                       //   → duplicate message (broker may have received it)
```

If the process crashes between the DB write and the broker publish, the order exists in the DB but no downstream service was notified. If the publish is retried without deduplication, it may fire twice.

### How the Outbox Works

```
Same DB Transaction:
  1. INSERT INTO orders (…)
  2. INSERT INTO outbox_messages (type, payload, status='Pending')
  COMMIT ← atomic: both succeed or both fail

Background Relay Process:
  3. SELECT * FROM outbox_messages WHERE status = 'Pending'
  4. Publish to broker (at-least-once)
  5. UPDATE outbox_messages SET status = 'Published' WHERE id = @id
```

**Guarantees**:
- If step 1–2 fail: neither the order nor the message is created. Consistent.
- If step 3–4 fail: message remains `Pending`. Relay retries on restart. At-least-once.
- Duplicate messages are possible (relay crashes between step 4 and 5). Consumers must be idempotent.

[See: at-least-once-vs-exactly-once.md](./at-least-once-vs-exactly-once.md)

### Inbox Pattern (Companion to Outbox)

The **Inbox** prevents duplicate processing on the consumer side: store received message IDs in a DB table before processing. On redelivery, detect the duplicate and skip.

Together, Outbox (producer side) + Inbox (consumer side) achieve **exactly-once effect** with at-least-once infrastructure.

### MassTransit Built-In Outbox

MassTransit ships an EF Core Outbox. Messages published inside a `ConsumeContext` or from a DI-provided `IPublishEndpoint` are stored in the DB if the outbox is enabled:

```csharp
// Registration
builder.Services.AddMassTransit(x =>
{
    x.AddEntityFrameworkOutbox<AppDbContext>(o =>
    {
        o.QueryDelay      = TimeSpan.FromSeconds(1);   // relay polling interval
        o.UseSqlServer();                               // or UsePostgres()
        o.UseBusOutbox();                               // enable for all consumers
    });

    x.AddConsumer<OrderPlacedConsumer>();
    x.UsingRabbitMq((ctx, cfg) =>
    {
        cfg.Host("localhost", h => { h.Username("guest"); h.Password("guest"); });
        cfg.ConfigureEndpoints(ctx);
    });
});
```

MassTransit handles:
- Storing messages in `OutboxMessage` table (created by `AddMigration`).
- Background relay that reads and publishes pending messages.
- Deduplication using `InboxState` table (inbox side).

### Polling vs CDC-Based Relay

| Approach | Description | Pros | Cons |
|----------|-------------|------|------|
| **Polling** | Background job polls the outbox table every N seconds | Simple; no extra infrastructure | Added DB load; latency = polling interval; potential "SELECT FOR UPDATE" locking |
| **CDC (Debezium)** | DB change capture reads the WAL/transaction log and streams changes | Near-real-time; no polling DB load | Complex setup; requires WAL access; another component to operate |

For most .NET services, polling is appropriate. CDC is worth the complexity at very high message volumes or when microsecond latency is required.

### Outbox at Scale: Concerns

**Concurrency**: multiple relay instances must not publish the same message twice. Use `SELECT … SKIP LOCKED` (PostgreSQL) or a distributed lock:

```sql
-- PostgreSQL: skip messages locked by other relay instances
SELECT * FROM outbox_messages
WHERE status = 'Pending'
ORDER BY created_at
LIMIT 100
FOR UPDATE SKIP LOCKED;
```

**Ordering**: the outbox preserves message insertion order within a partition/sequence key, but concurrent inserts can arrive out of sequence. If strict ordering is required, use a sequence column and process in order per aggregate ID.

**Retention**: mark messages as published (not deleted) for a replay window. Delete old published messages on a schedule.

**Monitoring**: alert when `Pending` count grows (relay is falling behind or blocked).

## Code Example

```csharp
// ASP.NET Core 8 — Manual Outbox Pattern with EF Core
// (shows the mechanics without MassTransit's built-in outbox)

using Microsoft.EntityFrameworkCore;
using System.Text.Json;

// ── Outbox table entity ────────────────────────────────────────────────
public class OutboxMessage
{
    public Guid   Id          { get; set; } = Guid.NewGuid();
    public string Type        { get; set; } = "";
    public string Payload     { get; set; } = "";
    public string Status      { get; set; } = "Pending";    // Pending | Published | Failed
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? PublishedAt { get; set; }
    public int   RetryCount   { get; set; }
}

public class AppDbContext(DbContextOptions<AppDbContext> opts) : DbContext(opts)
{
    public DbSet<Order> Orders             => Set<Order>();
    public DbSet<OutboxMessage> Outbox     => Set<OutboxMessage>();
}

// ── Application service: write order + outbox in ONE transaction ──────
public sealed class OrderService(AppDbContext db)
{
    public async Task<Guid> PlaceOrderAsync(decimal amount, CancellationToken ct)
    {
        var order = new Order { Id = Guid.NewGuid(), Amount = amount, Status = "Pending" };

        // Atomic: both rows committed or neither
        db.Orders.Add(order);
        db.Outbox.Add(new OutboxMessage
        {
            Type    = nameof(OrderPlaced),
            Payload = JsonSerializer.Serialize(new OrderPlaced(order.Id, amount))
        });

        await db.SaveChangesAsync(ct);
        return order.Id;
    }
}

// ── Outbox relay: runs as IHostedService ─────────────────────────────
public sealed class OutboxRelay(IServiceProvider sp, ILogger<OutboxRelay> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await PublishPendingAsync(stoppingToken);
            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }
    }

    private async Task PublishPendingAsync(CancellationToken ct)
    {
        await using var scope = sp.CreateAsyncScope();
        var db  = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var bus = scope.ServiceProvider.GetRequiredService<MassTransit.IPublishEndpoint>();

        // Fetch batch of pending messages (SKIP LOCKED on PostgreSQL prevents double-publish)
        var messages = await db.Outbox
            .Where(m => m.Status == "Pending" && m.RetryCount < 5)
            .OrderBy(m => m.CreatedAt)
            .Take(100)
            .ToListAsync(ct);

        foreach (var msg in messages)
        {
            try
            {
                // Resolve and publish the message
                var payload = DeserializeMessage(msg.Type, msg.Payload);
                await bus.Publish(payload, ct);

                msg.Status      = "Published";
                msg.PublishedAt = DateTime.UtcNow;
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Failed to publish outbox message {Id} (type: {Type})", msg.Id, msg.Type);
                msg.RetryCount++;
                if (msg.RetryCount >= 5) msg.Status = "Failed";
            }
        }

        await db.SaveChangesAsync(ct);
    }

    private static object DeserializeMessage(string type, string payload) => type switch
    {
        nameof(OrderPlaced) => JsonSerializer.Deserialize<OrderPlaced>(payload)!,
        _ => throw new InvalidOperationException($"Unknown message type: {type}")
    };
}

// ── Contracts ─────────────────────────────────────────────────────────
record OrderPlaced(Guid OrderId, decimal Amount);
public class Order { public Guid Id { get; set; } public decimal Amount { get; set; } public string Status { get; set; } = ""; }

// ── Registration ──────────────────────────────────────────────────────
// builder.Services.AddDbContext<AppDbContext>(…);
// builder.Services.AddScoped<OrderService>();
// builder.Services.AddHostedService<OutboxRelay>();
// builder.Services.AddMassTransit(…);  // configure broker
```

## Common Follow-up Questions

- How does MassTransit's `AddEntityFrameworkOutbox` handle the case where the relay process crashes between publishing and marking the message as sent?
- What is the `InboxState` table in MassTransit's outbox, and how does it prevent duplicate processing on the consumer side?
- How would you implement the Outbox pattern without EF Core (using Dapper or ADO.NET directly)?
- How do you monitor outbox lag in production — what metrics would you track?
- What is the difference between the Outbox pattern and the Saga pattern?
- How does CDC (Debezium + Kafka) replace the polling relay in a high-throughput Outbox implementation?

## Common Mistakes / Pitfalls

- **Publishing the message after `SaveChangesAsync` but before the outer transaction commits**: if the code wraps `SaveChangesAsync` in an ambient `TransactionScope` or a larger transaction, the DB data is not yet committed when the relay reads it. The relay picks up rows that the DB will then roll back. Store outbox messages in the same EF context and call `SaveChangesAsync` once.
- **No `SKIP LOCKED` with multiple relay instances**: two relay processes can read the same `Pending` row simultaneously and publish the same message twice before either marks it `Published`. Use `SKIP LOCKED` (PostgreSQL/SQL Server 2005+) or a distributed lock to prevent this.
- **Not marking a published message before the broker ACK**: if you mark the message `Published` in the DB first and then the broker call fails, you'll never retry. Mark as `Published` only after the broker call returns successfully (or accept the risk and rely on consumer idempotency).
- **Outbox relay with a very short polling interval on cold DB**: polling every 100ms on a table with millions of rows can cause significant DB load. Use `SKIP LOCKED + LIMIT` and a reasonable interval (1–5 seconds for most use cases).
- **Using the Outbox only for critical paths**: if you use the Outbox for payment events but direct publish for "minor" events, a crash at the wrong time still causes inconsistency on those paths. Apply the Outbox consistently across all cross-service message publishing.
- **Forgetting to clean up published messages**: outbox tables grow indefinitely without a cleanup job. Run a nightly DELETE where `Status = 'Published' AND PublishedAt < NOW() - INTERVAL '7 days'`.

## References

- [MassTransit Entity Framework Outbox — documentation](https://masstransit.io/documentation/patterns/transactional-outbox)
- [Transactional Outbox pattern — microservices.io](https://microservices.io/patterns/data/transactional-outbox.html)
- [Debezium — CDC for the Outbox pattern](https://debezium.io/documentation/reference/patterns/outbox.html)
- [See: distributed-transactions.md](./distributed-transactions.md) — Saga and 2PC patterns
- [See: at-least-once-vs-exactly-once.md](./at-least-once-vs-exactly-once.md) — delivery guarantee trade-offs
