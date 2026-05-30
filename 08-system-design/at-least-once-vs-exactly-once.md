# At-Least-Once vs Exactly-Once Delivery

**Category:** System Design / Messaging
**Difficulty:** 🔴 Senior
**Tags:** `at-least-once`, `exactly-once`, `idempotency`, `duplicate-detection`, `Kafka-transactions`, `Azure-Service-Bus`, `MassTransit`

## Question

> What are the three message delivery guarantees (at-most-once, at-least-once, exactly-once), and what are the trade-offs? How do you implement exactly-once semantics in practice, and why is idempotency the more practical solution in most systems?

## Short Answer

**At-most-once** (fire-and-forget) is fast but allows message loss. **At-least-once** guarantees delivery but allows duplicates — the standard for most production systems; consumers must be idempotent. **Exactly-once** guarantees each message is processed exactly once — achievable within a single broker via transactions (Kafka) or duplicate detection (Azure Service Bus), but impossible to guarantee across heterogeneous systems without distributed transactions. In practice, at-least-once delivery combined with **idempotent consumers** (detect and ignore duplicates) gives exactly-once *effect* with lower complexity.

## Detailed Explanation

### The Three Guarantees

```
At-most-once:
  Producer → Broker (fire and forget)
  Consumer reads → crashes before ACK
  Result: message is LOST

At-least-once:
  Producer → Broker (waits for broker ACK)
  Consumer reads → crashes before ACK
  Broker redelivers → consumer processes AGAIN
  Result: possible DUPLICATE

Exactly-once:
  Producer → Broker (idempotent write, deduplication)
  Consumer reads → processes atomically → ACK in same transaction
  Result: processed EXACTLY ONCE even after crash
```

### Why At-Least-Once Is the Standard

Exactly-once requires:
1. **Idempotent producer**: broker deduplicates retried messages from the same producer.
2. **Transactional consumer**: process the message and commit the offset in one atomic operation.
3. **End-to-end idempotency**: even if the broker delivers once, if the consumer writes to a DB and crashes after the write but before ACK, the redelivered message causes a duplicate DB write.

The third point is **unavoidable** with heterogeneous systems. The broker can guarantee exactly-once delivery to the consumer, but the consumer's side effects (DB writes, HTTP calls, emails) are outside the broker's transaction.

> **The core insight**: "exactly-once delivery" is different from "exactly-once processing." The former is a broker guarantee; the latter also requires idempotent side effects. You need both, and the side-effect idempotency is always your responsibility.

### Kafka: Idempotent Producer + Transactions

Kafka supports exactly-once within its own ecosystem since Kafka 0.11:

**Idempotent producer**: each producer is assigned a `ProducerID`; each message has a `SequenceNumber`. Brokers deduplicate retried messages from the same producer session.

**Transactional API**: atomically write to multiple partitions and commit the consumer offset in one Kafka transaction. Used in Kafka Streams for exactly-once stream processing.

```csharp
// Confluent.Kafka — transactional producer
var config = new ProducerConfig
{
    BootstrapServers  = "localhost:9092",
    TransactionalId   = "order-processor-1",  // enables exactly-once
    EnableIdempotence = true
};

using var producer = new ProducerBuilder<string, string>(config).Build();
producer.InitTransactions(TimeSpan.FromSeconds(10));

producer.BeginTransaction();
try
{
    await producer.ProduceAsync("output-topic", new Message<string, string>
        { Key = "order-1", Value = "processed" });

    // Commit both the output message AND the input offset atomically
    producer.SendOffsetsToTransaction(offsets, consumer.ConsumerGroupMetadata,
        TimeSpan.FromSeconds(10));

    producer.CommitTransaction();
}
catch
{
    producer.AbortTransaction();
}
```

**Limitation**: Kafka transactions only cover Kafka → Kafka flows. Writing to a DB inside the transaction is outside the Kafka transaction scope.

### Azure Service Bus: Duplicate Detection

Azure Service Bus supports deduplication via a **MessageId** + a configurable detection window (e.g., 10 minutes). If two messages with the same `MessageId` arrive within the window, the second is silently discarded:

```csharp
var message = new ServiceBusMessage(JsonSerializer.SerializeToUtf8Bytes(order))
{
    MessageId = $"order:{order.Id}",          // unique per logical operation
    ContentType = "application/json"
};
// If this send is retried (network error), the broker discards the duplicate
await sender.SendMessageAsync(message);
```

**Limitation**: detection window is finite (max 2 minutes to 7 days). Retries outside the window are not deduplicated.

### Idempotent Consumer — The Practical Solution

Rather than relying on broker guarantees, design consumers to **detect and ignore duplicates**:

#### Pattern 1: Deduplication Table

Store processed message IDs in a table. Before processing, check if the ID is already there. After processing, insert the ID atomically:

```sql
-- In same DB transaction as the business logic
INSERT INTO processed_messages (message_id, processed_at)
VALUES (@messageId, @now)
-- ON CONFLICT DO NOTHING (PostgreSQL) or equivalent
```

#### Pattern 2: Natural Idempotency

Design the operation so re-executing has the same effect as executing once:
- `INSERT … WHERE NOT EXISTS` — safe to retry
- `UPDATE balance = balance - @amount WHERE message_id NOT IN (…)` — conditional update
- Upsert: `MERGE` / `INSERT OR REPLACE`
- HTTP PUT (idempotent by definition) rather than POST

#### Pattern 3: Optimistic Concurrency / Version Check

Use a version column. Only apply the change if the version matches what was seen when the message was created:

```csharp
var affected = await db.Orders
    .Where(o => o.Id == orderId && o.Version == expectedVersion)
    .ExecuteUpdateAsync(s => s.SetProperty(o => o.Status, OrderStatus.Paid));

if (affected == 0) throw new ConflictException("Order was already updated");
```

### End-to-End Exactly-Once: The Outbox Pattern

Combine idempotent DB writes with the Outbox pattern for reliable messaging:

1. Write business data + outbox message in one DB transaction.
2. Background process reads outbox and publishes to broker.
3. Consumer stores processed message ID with its business operation in one DB transaction.

[See: outbox-pattern.md](./outbox-pattern.md)

## Code Example

```csharp
// .NET 8 — Idempotent consumer with deduplication table
// Exactly-once EFFECT despite at-least-once delivery

using MassTransit;
using Microsoft.EntityFrameworkCore;

public sealed class OrderPlacedConsumer(AppDbContext db, ILogger<OrderPlacedConsumer> log)
    : IConsumer<OrderPlaced>
{
    public async Task Consume(ConsumeContext<OrderPlaced> ctx)
    {
        var messageId = ctx.MessageId?.ToString() ?? ctx.Message.OrderId.ToString();

        // 1. Begin transaction covering both deduplication check and business logic
        await using var tx = await db.Database.BeginTransactionAsync();

        try
        {
            // 2. Check for duplicate (idempotency guard)
            bool alreadyProcessed = await db.ProcessedMessages
                .AnyAsync(m => m.MessageId == messageId);

            if (alreadyProcessed)
            {
                log.LogInformation("Duplicate message {MessageId} — skipping", messageId);
                await tx.CommitAsync();   // commit the no-op, ACK the message
                return;
            }

            // 3. Business logic
            var order = await db.Orders.FindAsync(ctx.Message.OrderId);
            if (order is null)
            {
                log.LogWarning("Order {Id} not found — possibly out-of-order delivery", ctx.Message.OrderId);
                return;   // don't ACK — let it retry (or configure a delay retry)
            }

            order.Status = OrderStatus.Processing;

            // 4. Mark as processed — atomically with business logic
            db.ProcessedMessages.Add(new ProcessedMessage
            {
                MessageId   = messageId,
                ProcessedAt = DateTime.UtcNow
            });

            await db.SaveChangesAsync();
            await tx.CommitAsync();

            log.LogInformation("Successfully processed order {Id}", ctx.Message.OrderId);
        }
        catch
        {
            await tx.RollbackAsync();
            throw;   // MassTransit will retry based on retry policy
        }
    }
}

// ── EF Core entities ──────────────────────────────────────────────────
public class AppDbContext(DbContextOptions<AppDbContext> opts) : DbContext(opts)
{
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<ProcessedMessage> ProcessedMessages => Set<ProcessedMessage>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<ProcessedMessage>(e =>
        {
            e.HasKey(m => m.MessageId);
            e.HasIndex(m => m.ProcessedAt);   // for cleanup of old records
        });
    }
}

public class Order
{
    public Guid OrderId { get; set; }
    public OrderStatus Status { get; set; }
    public int Version { get; set; }  // for optimistic concurrency
}

public class ProcessedMessage
{
    public string MessageId { get; set; } = "";
    public DateTime ProcessedAt { get; set; }
}

public enum OrderStatus { Pending, Processing, Paid }
record OrderPlaced(Guid OrderId, Guid CustomerId, decimal Amount);

// ── Cleanup job: remove old deduplication records ────────────────────
// (run as IHostedService every hour)
// await db.ProcessedMessages
//     .Where(m => m.ProcessedAt < DateTime.UtcNow.AddDays(-7))
//     .ExecuteDeleteAsync();
```

## Common Follow-up Questions

- What is the "zombie writer" problem in distributed systems, and how does it relate to exactly-once delivery?
- How does Kafka's `isolation.level=read_committed` affect consumer semantics for transactional producers?
- In the idempotency table pattern, what happens if the deduplication table grows indefinitely? How do you clean it up safely?
- How do you handle out-of-order message delivery — where message 5 arrives before message 3?
- Can you achieve exactly-once delivery with Azure Service Bus if the consumer also writes to Redis?
- How does MassTransit's saga/state machine help enforce idempotent state transitions?

## Common Mistakes / Pitfalls

- **Assuming broker "exactly-once" covers all side effects**: Kafka's transactional API guarantees exactly-once for Kafka-to-Kafka flows. If your consumer writes to a DB, sends an email, or calls an API, those operations are outside the transaction and can duplicate.
- **Deduplication table without an index on `MessageId`**: looking up a string without an index becomes a full table scan after millions of records. Always index the deduplication key.
- **Using `MessageId` set by the consumer, not the producer**: deduplication works because the producer sets a stable ID before sending. If the broker assigns the ID (e.g., Azure Service Bus auto-generates `MessageId`), retries from the producer get a different ID → no deduplication.
- **Not cleaning up old deduplication records**: a deduplication table without a TTL/cleanup job grows indefinitely. Index on `ProcessedAt` and delete old rows periodically (older than your maximum redelivery window).
- **Non-idempotent compensating transactions in Saga**: a Saga rollback step (compensation) that is not itself idempotent can cause double-refunds, double-cancellations, etc. Treat every Saga step as a message consumer: make it idempotent.
- **Ignoring redelivery after a timeout**: if a consumer takes longer than the broker's visibility timeout (SQS: 30s default, Azure SB: 60s), the broker redelivers to another consumer even while the first is still processing. Size visibility timeouts appropriately, or extend the lock during long operations.

## References

- [Kafka exactly-once semantics documentation](https://kafka.apache.org/documentation/#semantics)
- [Azure Service Bus — duplicate detection](https://learn.microsoft.com/azure/service-bus-messaging/duplicate-detection)
- [MassTransit — idempotency and deduplication](https://masstransit.io/documentation/patterns/idempotent-consumer) (verify URL)
- [See: outbox-pattern.md](./outbox-pattern.md) — reliable publish with exactly-once effect
- [See: idempotency-in-apis.md](./idempotency-in-apis.md) — idempotency in HTTP APIs
