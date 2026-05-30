# Kafka Fundamentals

**Category:** System Design / Messaging
**Difficulty:** Middle
**Tags:** `kafka`, `partitions`, `consumer-groups`, `offsets`, `log-compaction`, `ordering`, `retention`

## Question

> How does Apache Kafka work? What are partitions, consumer groups, and offsets? How does Kafka guarantee ordering and what are its limitations? What are the key configuration decisions when using Kafka with .NET?

- What is log compaction and when would you use it?
- How does Kafka differ from a traditional message queue (e.g., RabbitMQ or Azure Service Bus)?

## Short Answer

Kafka is an append-only distributed log where producers write messages to topics, which are split into ordered partitions across broker nodes. Consumers track their position in each partition using offsets and are grouped into consumer groups where each partition is assigned to exactly one consumer — enabling parallel processing. Ordering is guaranteed only within a single partition, not across a topic. Key trade-offs versus traditional queues: Kafka retains messages for a configurable period (even after consumption), supports replay from any offset, and scales horizontally by adding partitions; but it has no built-in per-message TTL, no native fan-out without consumer groups, and complex operational overhead.

## Detailed Explanation

### Core Architecture

```
Topic: orders
├── Partition 0: [msg0][msg1][msg2][msg3] ← producer key hashes to P0
├── Partition 1: [msg4][msg5]             ← producer key hashes to P1
└── Partition 2: [msg6][msg7][msg8]       ← producer key hashes to P2

Each partition: append-only log, messages assigned monotonically increasing offsets
Each partition: replicated across N brokers (replication factor)
```

**Key properties:**
- **Producers** write to a partition determined by the message key (or round-robin if no key).
- **Consumers** commit offsets — they read from where they last left off.
- **Consumer groups**: each consumer group gets its own copy of all messages; within a group, each partition is consumed by exactly one member.
- **Retention**: messages are retained for a configured period (e.g., 7 days) regardless of whether they've been consumed. Consumers can replay from any offset.

### Partitions and Ordering

| Ordering guarantee | When true |
|-------------------|-----------|
| Within a partition | Always (Kafka is an ordered log per partition) |
| Across partitions in a topic | **Never** (no global ordering) |
| For a given key | Always — same key → same partition → ordered |

**Choosing a partition key:**

```csharp
// .NET Confluent Kafka producer — key determines partition assignment
using Confluent.Kafka;

var producer = new ProducerBuilder<string, string>(new ProducerConfig
{
    BootstrapServers = "kafka:9092",
    Acks = Acks.All,        // wait for all replicas to acknowledge
    MessageSendMaxRetries = 3,
    EnableIdempotence = true, // exactly-once semantics (Kafka >= 0.11)
}).Build();

// All events for the same order go to the same partition (ordered by order ID)
await producer.ProduceAsync("orders.events", new Message<string, string>
{
    Key   = orderId.ToString(),    // partition key — ensures ordering per order
    Value = JsonSerializer.Serialize(orderEvent),
    Headers = new Headers
    {
        { "event-type", Encoding.UTF8.GetBytes(orderEvent.GetType().Name) },
        { "correlation-id", Encoding.UTF8.GetBytes(correlationId.ToString()) },
    }
});
```

### Consumer Groups and Parallelism

```
Topic: orders (3 partitions)

Consumer Group A (orders-processor):
  Consumer 1 → Partition 0
  Consumer 2 → Partition 1
  Consumer 3 → Partition 2
  (max parallelism = partition count)

Consumer Group B (analytics-processor):
  Consumer 1 → Partition 0, 1  (fewer consumers than partitions)
  Consumer 2 → Partition 2
```

Adding a 4th consumer to Group A: it sits idle — Kafka can't split a partition across consumers within a group. **More partitions = more parallelism** (but more operational complexity and leader election overhead).

### .NET Consumer with Offset Management

```csharp
using Confluent.Kafka;

var consumer = new ConsumerBuilder<string, string>(new ConsumerConfig
{
    BootstrapServers     = "kafka:9092",
    GroupId              = "orders-processor",
    AutoOffsetReset      = AutoOffsetReset.Earliest, // start from beginning if no committed offset
    EnableAutoCommit     = false,  // manual commit — don't lose messages on crash
    SessionTimeoutMs     = 30_000,
    MaxPollIntervalMs    = 300_000, // max time between polls before rebalance
}).Build();

consumer.Subscribe("orders.events");

try
{
    while (!ct.IsCancellationRequested)
    {
        var result = consumer.Consume(ct);
        if (result is null) continue;

        try
        {
            await ProcessMessageAsync(result.Message, ct);
            // Commit only after successful processing — at-least-once
            consumer.Commit(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process offset {Offset}", result.Offset);
            // Don't commit — same message will be redelivered on restart
            // Dead-letter after N retries (handled separately)
        }
    }
}
finally
{
    consumer.Close();  // triggers graceful partition revocation + final offset commit
}
```

### Offset Strategies

| Strategy | Commit when | Risk |
|----------|-----------|------|
| **Auto-commit** (`EnableAutoCommit: true`) | Periodically (every 5s) | Can lose or re-process messages |
| **After processing** (manual, `Commit` after work) | After successful processing | At-least-once; may re-process on crash mid-batch |
| **Before processing** (manual, `Commit` before work) | Before processing | At-most-once; can lose messages |
| **Exactly-once** (transactions) | Inside a transaction | Complex; requires transactional producer + consumer |

### Retention and Log Compaction

**Time-based retention** (default): messages deleted after `retention.ms` (default 7 days).

**Log compaction**: instead of deleting by time, Kafka retains only the **latest message per key**. Old versions of a key are garbage-collected; a tombstone (null value) deletes the key entirely:

```
Before compaction:
  user-123: {name: "Alice"}   offset 0
  user-456: {name: "Bob"}     offset 1
  user-123: {name: "Alice M"} offset 2  ← newer version of user-123

After compaction:
  user-456: {name: "Bob"}     offset 1  ← retained (only version)
  user-123: {name: "Alice M"} offset 2  ← retained (latest)
```

**Use case**: event-sourced read model snapshots, user profiles, configuration topics — anywhere you want the current state of each key, not full history.

```bash
# Topic configuration for log compaction
kafka-topics.sh --create \
  --topic user-profiles \
  --config cleanup.policy=compact \
  --config min.cleanable.dirty.ratio=0.1 \
  --config segment.ms=3600000  # compact at least every hour
```

### MassTransit with Kafka

For .NET services using MassTransit, Kafka integration provides a high-level abstraction:

```csharp
builder.Services.AddMassTransit(mt =>
{
    mt.UsingKafka((ctx, kafka) =>
    {
        kafka.Host("kafka:9092");
        kafka.TopicEndpoint<OrderCreatedEvent>("orders.created", "orders-processor-group", e =>
        {
            e.ConfigureConsumer<OrderCreatedConsumer>(ctx);
            e.AutoOffsetReset = AutoOffsetReset.Earliest;
            e.ConcurrentDeliveryLimit = 10;
        });
    });
});
```

> **Warning:** Kafka's exactly-once semantics (`enable.idempotence=true` + transactions) add significant complexity and performance overhead. For most .NET services, at-least-once with idempotent consumers is the right choice — simpler and sufficient.

## Common Follow-up Questions

- How does Kafka handle consumer rebalancing when a consumer joins or leaves the group?
- What is the difference between `assign` (manual partition assignment) and `subscribe` (group-managed)?
- How do you implement a dead-letter mechanism for Kafka (there is no built-in DLQ)?
- What is Kafka Streams and how does it differ from a standard consumer loop?
- How do you monitor consumer group lag in Kafka?

## Common Mistakes / Pitfalls

- **Ordering across partitions**: assuming Kafka provides global ordering across a topic — it does not; ordering is only within a partition.
- **Too few partitions**: partitions can't be reduced once created; under-partitioning limits future parallelism. Over-partitioning has overhead (leader election, file handles). Start with 3–12 and scale up.
- **Auto-commit with slow processing**: `EnableAutoCommit: true` commits offsets even if the application hasn't finished processing, causing message loss on crash.
- **Not closing the consumer cleanly**: `consumer.Close()` triggers a controlled rebalance; `Dispose()` without `Close()` causes a session timeout (up to 30 seconds) during which partitions are unassigned.
- **Long `MaxPollIntervalMs`**: if processing a batch takes longer than `max.poll.interval.ms`, Kafka assumes the consumer is dead and triggers a rebalance; set it to at least 2× your maximum processing time.

## References

- [Apache Kafka documentation](https://kafka.apache.org/documentation/)
- [Confluent .NET client](https://docs.confluent.io/kafka-clients/dotnet/current/overview.html)
- [MassTransit Kafka integration](https://masstransit.io/documentation/transports/kafka)
- [Kafka: The Definitive Guide (O'Reilly)](https://www.oreilly.com/library/view/kafka-the-definitive/9781491936153/)
- [See: kafka-vs-rabbitmq.md](./kafka-vs-rabbitmq.md)
- [See: ordering-in-distributed-systems.md](./ordering-in-distributed-systems.md)
