# Kafka vs RabbitMQ

**Category:** System Design / Messaging
**Difficulty:** 🟡 Middle
**Tags:** `Kafka`, `RabbitMQ`, `message-broker`, `event-streaming`, `partitions`, `consumer-groups`, `log-retention`, `MassTransit`

## Question

> What are the fundamental architectural differences between Apache Kafka and RabbitMQ? When should you choose one over the other, and how do they behave differently in a .NET microservices system?

## Short Answer

Kafka is a **distributed append-only log**: messages are retained on disk for a configurable period regardless of consumption, consumers track their own position (offset), and throughput scales to millions of messages per second. RabbitMQ is a **smart broker / dumb consumer**: it routes messages through exchanges to queues, messages are deleted after ACK, and it supports complex routing (topic, fanout, direct). Choose Kafka for event streaming, audit logs, replaying history, and very high throughput. Choose RabbitMQ for task queues, complex routing, request/reply patterns, and when consumers drive deletion.

## Detailed Explanation

### Architectural Differences

| Aspect | Apache Kafka | RabbitMQ |
|--------|-------------|---------|
| **Storage model** | Append-only log (disk) | In-memory queue (optional persistence) |
| **Message deletion** | After retention period (e.g., 7 days) | After consumer ACK |
| **Consumer model** | Pull — consumer manages offset | Push — broker pushes to consumer |
| **Routing** | Topic + partition key | Exchange types (direct, topic, fanout, headers) |
| **Replay** | ✅ Any consumer can re-read old messages | ❌ Once ACK'd, message is gone |
| **Throughput** | Millions msg/s (sequential disk writes) | 100K–500K msg/s |
| **Latency** | 5–50 ms (batch optimised) | 1–5 ms (lower latency) |
| **Message ordering** | Per-partition ordering guarantee | Per-queue ordering guarantee |
| **Consumer groups** | Multiple independent groups read same data | Competing consumers share a queue |
| **Backpressure** | Producers slow down if brokers are full | Brokers push back or drop |

### Kafka: The Log Model

Kafka topics are partitioned across brokers. Each partition is an ordered, immutable log. Messages are appended, never deleted (until retention). Consumers read by advancing an **offset**:

```
Partition 0: [msg0][msg1][msg2][msg3][msg4] ...
                          ↑
                   Consumer offset = 2 (about to read msg2)
```

**Key implications**:
- **Replayability**: reset offset to 0 to re-process all historical messages (e.g., rebuild a read model, debug a bug).
- **Multiple independent consumers**: Consumer Group A can be at offset 100 while Consumer Group B is at offset 50 — reading the same data independently.
- **Ordering only per partition**: messages with the same partition key are ordered; across partitions there is no ordering guarantee.
- **Horizontal scaling**: add partitions → add consumer instances (one instance per partition).

### RabbitMQ: The Smart Broker Model

RabbitMQ routes messages through **exchanges** to **queues**:

```
Producer → Exchange (type: topic) 
  → [binding: order.*] → Queue: orders
  → [binding: #.error] → Queue: errors
  → [binding: *.paid]  → Queue: payments
```

**Exchange types**:
- `direct`: route by exact routing key
- `topic`: route by wildcard pattern (`order.*`)
- `fanout`: broadcast to all bound queues (pub/sub)
- `headers`: route by message header values

**Key implications**:
- Rich routing logic stays in the broker — consumers don't need to know about routing.
- **Request/reply pattern**: RabbitMQ supports RPC via reply-to queues.
- **Dead-letter exchange**: failed messages routed to a DLX automatically.
- Messages are deleted after ACK — no replay (unless using Streams, a newer RabbitMQ feature).

### When to Choose Kafka

- **Event sourcing / audit log**: you need a durable, replayable history of all events.
- **Multiple independent consumers**: analytics pipeline and notification service both need to read the same OrderPlaced events, independently.
- **Very high throughput**: millions of events per second (IoT telemetry, clickstream).
- **Stream processing**: integrates natively with Kafka Streams, Apache Flink, ksqlDB.
- **Data pipelines**: CDC (change data capture) with Debezium writing to Kafka.

### When to Choose RabbitMQ

- **Task queues**: distribute work across competing workers; delete messages after processing.
- **Complex routing**: different message types need different queues without consumer-side filtering.
- **Low latency**: sub-5ms delivery matters (RabbitMQ push model is faster for individual messages).
- **Request/reply (RPC over messaging)**: built-in correlation ID + reply-to pattern.
- **Transactional messaging**: RabbitMQ supports publisher confirms and consumer transactions.

### Azure Service Bus

A managed cloud alternative positioned between RabbitMQ and Kafka:
- Queues (point-to-point) + Topics/Subscriptions (pub/sub) — RabbitMQ-like model.
- Messages deleted after ACK.
- **Sessions**: ordered processing per session ID (like Kafka partition key but simpler).
- **Scheduled messages**, **message deferral**, **dead-letter** — built-in.
- No replay beyond lock-duration TTL.

For Azure-native workloads, Service Bus is often the right default. Use Event Hubs (Kafka-compatible protocol) for streaming use cases.

## Code Example

```csharp
// .NET 8 — Kafka producer + consumer using Confluent.Kafka
// and RabbitMQ producer + consumer using MassTransit

// ══ KAFKA ═══════════════════════════════════════════════════════════

using Confluent.Kafka;

// ── Kafka Producer ────────────────────────────────────────────────────
var kafkaConfig = new ProducerConfig { BootstrapServers = "localhost:9092" };

using var producer = new ProducerBuilder<string, string>(kafkaConfig).Build();

var result = await producer.ProduceAsync("orders", new Message<string, string>
{
    Key   = orderId.ToString(),   // partition key: same order always goes to same partition
    Value = System.Text.Json.JsonSerializer.Serialize(new OrderPlaced(orderId, customerId, 99.99m))
});

Console.WriteLine($"Delivered to partition {result.Partition.Value}, offset {result.Offset.Value}");

// ── Kafka Consumer ────────────────────────────────────────────────────
var consumerConfig = new ConsumerConfig
{
    BootstrapServers = "localhost:9092",
    GroupId          = "payment-service",   // consumer group — tracks offset per group
    AutoOffsetReset  = AutoOffsetReset.Earliest  // start from beginning if no committed offset
};

using var consumer = new ConsumerBuilder<string, string>(consumerConfig).Build();
consumer.Subscribe("orders");

using var cts = new CancellationTokenSource();

try
{
    while (!cts.IsCancellationRequested)
    {
        var msg = consumer.Consume(cts.Token);
        var order = System.Text.Json.JsonSerializer.Deserialize<OrderPlaced>(msg.Message.Value)!;
        Console.WriteLine($"Processing order {order.OrderId} from partition {msg.Partition.Value}");
        
        consumer.Commit(msg);   // manual offset commit after successful processing
    }
}
catch (OperationCanceledException) { }
finally { consumer.Close(); }

// ══ RABBITMQ (via MassTransit) ═══════════════════════════════════════

using MassTransit;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddMassTransit(x =>
{
    x.AddConsumer<OrderPlacedConsumer>();

    x.UsingRabbitMq((ctx, cfg) =>
    {
        cfg.Host("localhost", h => { h.Username("guest"); h.Password("guest"); });

        // Topic exchange routing: route by message type namespace
        cfg.Message<OrderPlaced>(m => m.SetEntityName("order-events"));
        cfg.ConfigureEndpoints(ctx);

        // Retry policy: 3 retries with exponential back-off
        cfg.UseMessageRetry(r => r.Exponential(3,
            TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(30), TimeSpan.FromSeconds(5)));
    });
});

// ── Comparison: same message, different broker registrations ──────────
// To switch from RabbitMQ to Kafka in MassTransit, change:
//   x.UsingRabbitMq(...) → x.UsingKafka(...)
// Application code (Publish/Consume) stays identical.

var app = builder.Build();
app.MapPost("/orders", async (IPublishEndpoint bus) =>
{
    await bus.Publish(new OrderPlaced(Guid.NewGuid(), Guid.NewGuid(), 49.99m));
    return Results.Accepted();
});
app.Run();

// ── Shared contracts ──────────────────────────────────────────────────
record OrderPlaced(Guid OrderId, Guid CustomerId, decimal Amount);
var orderId = Guid.NewGuid(); var customerId = Guid.NewGuid();

public sealed class OrderPlacedConsumer(ILogger<OrderPlacedConsumer> log) : IConsumer<OrderPlaced>
{
    public Task Consume(ConsumeContext<OrderPlaced> ctx)
    {
        log.LogInformation("RabbitMQ: processing {OrderId}", ctx.Message.OrderId);
        return Task.CompletedTask;
    }
}
```

## Common Follow-up Questions

- How do Kafka consumer groups work, and how does partition count limit parallelism?
- What is the difference between at-least-once and exactly-once delivery in Kafka (idempotent producer, transactions)?
- How does RabbitMQ's Quorum Queues feature compare to Classic Queues for durability?
- When would you use Azure Event Hubs instead of Kafka? (They share the Kafka protocol.)
- How do you handle schema evolution (adding/removing fields) across producer and consumer teams in Kafka?
- How does MassTransit's saga (state machine) feature interact with both RabbitMQ and Kafka?

## Common Mistakes / Pitfalls

- **Using Kafka as a task queue**: Kafka guarantees ordering per partition; once messages are on a partition, you can't reorder or prioritise them. Competing workers within one consumer group are limited by partition count — you can't have more active workers than partitions. RabbitMQ is better for task queues.
- **Committing Kafka offsets before processing**: if you commit offset 5 and then crash while processing message 5, message 5 is lost. Commit AFTER successful processing (or use manual commit with transactions).
- **Too few Kafka partitions**: with 3 partitions, you can only have 3 active consumers in a group. Under-provisioning partitions limits horizontal scaling. Plan partition count for peak concurrency needs (can be increased but requires rebalancing).
- **RabbitMQ without publisher confirms**: the default AMQP publish is fire-and-forget at the broker. Without publisher confirms, message loss is possible. Enable `PublisherAcknowledgements` or use MassTransit (which enables them by default).
- **Treating Kafka as a database**: Kafka retention is finite. Don't use it as the primary store for critical data — compact topics (`log.cleanup.policy=compact`) retain only the latest value per key, but this is not a full DB replacement.
- **Consumer group ID collisions**: two separate services sharing the same `GroupId` compete for messages — one service "steals" messages from the other. Always use unique group IDs per logical consumer.

## References

- [Apache Kafka documentation](https://kafka.apache.org/documentation/)
- [RabbitMQ documentation](https://www.rabbitmq.com/docs)
- [Confluent.Kafka .NET client — GitHub](https://github.com/confluentinc/confluent-kafka-dotnet)
- [MassTransit — Kafka integration](https://masstransit.io/documentation/transports/kafka)
- [Azure Event Hubs — Kafka protocol support](https://learn.microsoft.com/azure/event-hubs/event-hubs-for-kafka-ecosystem-overview)
