# Message Broker Overview

**Category:** System Design / Messaging
**Difficulty:** 🟢 Junior
**Tags:** `message-broker`, `queue`, `pub-sub`, `RabbitMQ`, `Kafka`, `Azure Service Bus`, `MassTransit`, `async-messaging`

## Question

> What is a message broker and why do distributed systems use them? What problem do they solve that direct HTTP calls don't?

## Short Answer

A message broker is an intermediary that decouples message producers from consumers by storing and forwarding messages asynchronously. Producers publish messages without knowing who will consume them or when; consumers process at their own pace. Brokers solve three problems that HTTP calls can't: **temporal decoupling** (producer and consumer don't need to be online simultaneously), **load levelling** (consumers drain a queue at their own rate, preventing overload), and **reliable delivery** (the broker retains messages until acknowledged, surviving consumer crashes). Common brokers in .NET ecosystems: RabbitMQ, Apache Kafka, Azure Service Bus.

## Detailed Explanation

### The Problem with Direct HTTP Calls

```
Direct HTTP:
  Order Service → [POST /payment] → Payment Service
  
Issues:
  - Payment Service must be UP when Order Service sends
  - If Payment Service is slow, Order Service waits (latency coupling)
  - If Payment Service crashes mid-request, the order may be lost
  - Scaling Payment Service requires upstream callers to know about it
```

### Message Broker Model

```
With a broker:
  Order Service → [publish OrderPlaced] → [BROKER] → Payment Service
                                                    → Notification Service
                                                    → Inventory Service
  
Benefits:
  - Broker stores messages: Payment Service can be down for hours, messages persist
  - Order Service returns immediately: no synchronous wait
  - Multiple consumers can react to the same event
  - Payment Service scales independently; the broker queues excess messages
```

### Core Concepts

| Concept | Definition |
|---------|-----------|
| **Producer** | Sends messages to the broker |
| **Consumer** | Reads and processes messages from the broker |
| **Message** | Payload (usually JSON/bytes) + metadata (headers, routing key) |
| **Queue** | FIFO buffer; one consumer group processes each message once |
| **Topic/Exchange** | Routing mechanism; one message → multiple queues/consumers |
| **Acknowledgement (ACK)** | Consumer confirms successful processing; broker deletes the message |
| **Negative ACK (NACK)** | Consumer rejects the message → requeue or dead-letter |
| **Dead-letter queue** | Holds messages that failed processing after N retries |

### Queue vs Pub/Sub

| Model | Message consumed by | Use case |
|-------|-------------------|---------|
| **Queue (point-to-point)** | Exactly one consumer | Work distribution, task queue |
| **Pub/Sub (topic)** | All subscribers | Event broadcasting, fan-out |

[See: pub-sub-vs-message-queue.md](./pub-sub-vs-message-queue.md)

### Delivery Guarantees

| Guarantee | Meaning | Risk |
|-----------|---------|------|
| **At-most-once** | Fire and forget; no retries | Messages may be lost |
| **At-least-once** | Redelivered until ACK'd | Duplicates possible; consumers must be idempotent |
| **Exactly-once** | Each message processed once | Complex; requires transactions |

[See: at-least-once-vs-exactly-once.md](./at-least-once-vs-exactly-once.md)

### Major Brokers

| Broker | Model | Retention | Throughput | .NET Support |
|--------|-------|-----------|------------|-------------|
| **RabbitMQ** | Queue + exchange routing | Until consumed (or TTL) | High (100K msg/s) | MassTransit, EasyNetQ |
| **Apache Kafka** | Log (topics + partitions) | Configurable (days/forever) | Very high (millions/s) | Confluent.Kafka, MassTransit |
| **Azure Service Bus** | Queue + topic | Until consumed (TTL) | Medium (10K msg/s) | Azure SDK, MassTransit |
| **Azure Event Hubs** | Partitioned log (Kafka-compatible) | Days | Very high | Azure SDK, Confluent.Kafka |

### MassTransit — .NET Abstraction

MassTransit is the dominant .NET message bus abstraction — works with RabbitMQ, Kafka, Azure Service Bus, and others behind a unified API:

```csharp
// Same publish code works with any broker
await bus.Publish(new OrderPlaced(orderId));
```

## Code Example

```csharp
// ASP.NET Core 8 — Message broker basics with MassTransit + RabbitMQ

using MassTransit;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddMassTransit(x =>
{
    // Register consumer
    x.AddConsumer<OrderPlacedConsumer>();

    x.UsingRabbitMq((ctx, cfg) =>
    {
        cfg.Host("localhost", "/", h =>
        {
            h.Username("guest");
            h.Password("guest");
        });
        cfg.ConfigureEndpoints(ctx);   // auto-configure queues from consumers
    });
});

var app = builder.Build();

// ── Producer: publish a message ───────────────────────────────────────
app.MapPost("/orders", async (CreateOrderRequest req, IPublishEndpoint bus) =>
{
    var orderId = Guid.NewGuid();
    // Order saved to DB here...
    
    // Non-blocking publish: returns as soon as broker acknowledges receipt
    await bus.Publish(new OrderPlaced(orderId, req.CustomerId, req.Amount));
    
    return Results.Accepted($"/orders/{orderId}", new { orderId });
});

app.Run();

// ── Consumer: process the message ─────────────────────────────────────
public sealed class OrderPlacedConsumer(ILogger<OrderPlacedConsumer> log) 
    : IConsumer<OrderPlaced>
{
    public async Task Consume(ConsumeContext<OrderPlaced> context)
    {
        var order = context.Message;
        log.LogInformation("Processing payment for order {OrderId}, amount {Amount}",
            order.OrderId, order.Amount);

        // Process payment...
        await Task.Delay(100);   // simulate work

        // Implicit ACK on successful return
        // Throw exception → MassTransit retries (configurable policy)
    }
}

// ── Message contracts (shared between producer and consumer) ──────────
record OrderPlaced(Guid OrderId, Guid CustomerId, decimal Amount);
record CreateOrderRequest(Guid CustomerId, decimal Amount);
```

## Common Follow-up Questions

- When would you choose Azure Service Bus over RabbitMQ in a .NET application?
- How do consumers scale horizontally with a message broker — what happens with competing consumers?
- What is the difference between a message queue and an event stream (Kafka)?
- How do you handle message schema evolution (adding fields to a contract without breaking existing consumers)?
- What is the Outbox pattern and why is it needed with message brokers?
- How do you test code that publishes or consumes messages?

## Common Mistakes / Pitfalls

- **Forgetting ACK — infinite redelivery**: if a consumer processes a message and crashes before ACKing, the broker redelivers it indefinitely. Ensure your consumer ACKs after successful processing (MassTransit does this automatically on normal method return).
- **Non-idempotent consumers with at-least-once delivery**: all production brokers can redeliver messages (network blip, consumer restart). If your consumer isn't idempotent (e.g., it inserts a row without checking for duplicates), you'll get duplicate data. Design consumers to be idempotent.
- **Publishing inside a DB transaction without the Outbox pattern**: if you write to the DB and then publish, but the broker publish fails, the DB has data the broker doesn't know about. Use the Outbox pattern. [See: outbox-pattern.md](./outbox-pattern.md)
- **Large messages in the broker**: brokers are optimised for small messages (< 1 MB). For large payloads, store the data in blob storage and publish a reference (URL) instead.
- **Ignoring dead-letter queues**: failed messages silently disappear if you don't configure and monitor dead-letter queues. Always set up DLQ alerts.
- **Single consumer = single point of failure**: always run at least two consumer instances for critical queues.

## References

- [MassTransit documentation](https://masstransit.io/documentation/concepts)
- [Azure Service Bus — Microsoft Learn](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-messaging-overview)
- [RabbitMQ tutorials](https://www.rabbitmq.com/tutorials)
- [See: kafka-vs-rabbitmq.md](./kafka-vs-rabbitmq.md) — detailed comparison
- [See: outbox-pattern.md](./outbox-pattern.md) — reliable publish with DB transactions
