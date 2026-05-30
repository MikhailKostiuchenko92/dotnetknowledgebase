# Pub/Sub vs Message Queue

**Category:** System Design / Messaging
**Difficulty:** 🟡 Middle
**Tags:** `pub-sub`, `message-queue`, `fan-out`, `competing-consumers`, `topic`, `subscription`, `RabbitMQ`, `Azure Service Bus`, `MassTransit`

## Question

> What is the difference between a message queue (point-to-point) and a pub/sub (publish/subscribe) pattern? When should you use each, and how are they implemented in practice with RabbitMQ and Azure Service Bus?

## Short Answer

In a **message queue**, each message is consumed by exactly one worker from a pool of competing consumers — ideal for distributing work. In **pub/sub**, a single published message is delivered to all subscribers simultaneously — ideal for event notification where multiple systems react to the same event. The key distinction is "one consumer processes this job" vs "all interested parties are notified of this event." Most real systems use both: queues for task distribution within a service and pub/sub for cross-service event propagation.

## Detailed Explanation

### Message Queue (Point-to-Point)

```
Producer → [Queue: process-order] → Consumer A  ← one of these processes each message
                                   → Consumer B
                                   → Consumer C
```

- Each message is received and acknowledged by **exactly one** consumer.
- Multiple consumers (competing consumers) enable horizontal scaling — add workers to drain faster.
- The broker distributes messages round-robin or to the next idle consumer.
- Typical use: background job processing, email sending, image resizing.

**Guarantees**:
- Load balancing: slow consumers don't block fast ones (each takes messages independently).
- No duplication (with at-least-once + idempotent consumer or exactly-once delivery).

### Pub/Sub (Publish/Subscribe)

```
Publisher → [Topic: order-placed] → Subscription: payments   → Payment Service
                                  → Subscription: inventory  → Inventory Service
                                  → Subscription: emails     → Email Service
```

- Each message is delivered to **all subscriptions** independently.
- Each subscription behaves like a separate queue — one consumer per subscription processes each message.
- Typical use: domain events ("OrderPlaced"), notifications, fan-out.

**Guarantees**:
- Every subscriber gets every message (that was published after they subscribed).
- Each subscriber can consume at its own pace; backlogs are per-subscription.

### Side-by-Side Comparison

| Dimension | Message Queue | Pub/Sub Topic |
|-----------|--------------|---------------|
| Message routing | One consumer from the pool | All subscriptions |
| Use case | Work distribution, job queue | Event notification, fan-out |
| Scaling workers | Add competing consumers | Independent per subscription |
| Missed messages | Only if all consumers are down | Subscription must exist before publish |
| Late subscriber | Gets messages already in queue | Misses messages published before subscription |
| Message retention | Until ACK'd | Until ACK'd per subscription |
| Example | Process payment (one service processes per payment) | OrderPlaced event (3 services react) |

### Hybrid Pattern: Topic + Queue Fan-Out

Most production architectures combine both:

```
OrderService publishes OrderPlaced (pub/sub topic)
  → Subscription: payment-events → [Payment Queue] → Payment Worker × N
  → Subscription: inventory-events → [Inventory Queue] → Inventory Worker × N
  → Subscription: email-events → [Email Queue] → Email Worker × N
```

The topic does fan-out; each subscription acts as an independent queue for competing workers.

### RabbitMQ Implementation

RabbitMQ uses **exchanges** for routing:

| Exchange type | Behaviour | When to use |
|--------------|-----------|------------|
| `direct` | Route by exact routing key | Point-to-point task queue |
| `fanout` | Broadcast to all bound queues | Simple pub/sub |
| `topic` | Route by wildcard pattern | Filtered pub/sub |
| `headers` | Route by message headers | Complex conditional routing |

```csharp
// Fanout exchange = pub/sub: all bound queues receive every message
channel.ExchangeDeclare("order-events", ExchangeType.Fanout);
channel.QueueBind("payment-queue",   "order-events", routingKey: "");
channel.QueueBind("inventory-queue", "order-events", routingKey: "");
```

### Azure Service Bus Implementation

- **Queue**: standard point-to-point; competing consumers.
- **Topic + Subscriptions**: pub/sub; each subscription filters messages independently.

```csharp
// Topic subscription with filter: only messages where Amount > 1000
await adminClient.CreateSubscriptionAsync(
    new CreateSubscriptionOptions("order-events", "high-value"),
    new CreateRuleOptions("amount-filter",
        new SqlRuleFilter("Amount > 1000")));
```

### MassTransit — Unified Abstraction

MassTransit maps `Publish` to pub/sub (all consumers of that message type receive it) and `Send` to point-to-point (direct to a queue):

```csharp
// Pub/sub: all consumers of OrderPlaced receive this
await bus.Publish(new OrderPlaced(...));

// Point-to-point: send directly to payment-queue
await bus.Send<ProcessPayment>(new Uri("queue:payment-queue"), new ProcessPayment(...));
```

## Code Example

```csharp
// ASP.NET Core 8 — Queue vs Pub/Sub with MassTransit + RabbitMQ

using MassTransit;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddMassTransit(x =>
{
    // ── Competing consumers (queue / point-to-point) ──────────────────
    // Three instances of ImageResizeConsumer compete for work
    x.AddConsumer<ImageResizeConsumer>();

    // ── Pub/Sub: multiple independent consumers for same event ─────────
    x.AddConsumer<PaymentConsumer>();
    x.AddConsumer<InventoryConsumer>();
    x.AddConsumer<EmailNotificationConsumer>();

    x.UsingRabbitMq((ctx, cfg) =>
    {
        cfg.Host("localhost", h => { h.Username("guest"); h.Password("guest"); });

        // Task queue: all ImageResizeConsumer instances share one queue
        cfg.ReceiveEndpoint("image-resize-queue", ep =>
        {
            ep.PrefetchCount = 10;     // each consumer fetches 10 at a time
            ep.ConfigureConsumer<ImageResizeConsumer>(ctx);
        });

        // Pub/Sub: each consumer gets its OWN queue bound to the OrderPlaced exchange
        // MassTransit does this automatically with ConfigureEndpoints
        cfg.ConfigureEndpoints(ctx);
    });
});

var app = builder.Build();

// ── Publish to pub/sub topic (all 3 consumers receive OrderPlaced) ────
app.MapPost("/orders", async (IPublishEndpoint bus) =>
{
    await bus.Publish(new OrderPlaced(Guid.NewGuid(), Guid.NewGuid(), 149.99m));
    // PaymentConsumer, InventoryConsumer, EmailNotificationConsumer all get this
    return Results.Accepted();
});

// ── Send to specific queue (competing consumers) ──────────────────────
app.MapPost("/images", async (ISendEndpointProvider sendProvider, ResizeRequest req) =>
{
    var endpoint = await sendProvider.GetSendEndpoint(new Uri("queue:image-resize-queue"));
    await endpoint.Send(new ResizeImage(req.ImageId, req.Width, req.Height));
    // Exactly ONE ImageResizeConsumer processes this message
    return Results.Accepted();
});

app.Run();

// ── Consumers ─────────────────────────────────────────────────────────
public sealed class PaymentConsumer(ILogger<PaymentConsumer> log) : IConsumer<OrderPlaced>
{
    public Task Consume(ConsumeContext<OrderPlaced> ctx)
    {
        log.LogInformation("Processing payment for order {Id}", ctx.Message.OrderId);
        return Task.CompletedTask;
    }
}

public sealed class InventoryConsumer(ILogger<InventoryConsumer> log) : IConsumer<OrderPlaced>
{
    public Task Consume(ConsumeContext<OrderPlaced> ctx)
    {
        log.LogInformation("Reserving inventory for order {Id}", ctx.Message.OrderId);
        return Task.CompletedTask;
    }
}

public sealed class EmailNotificationConsumer(ILogger<EmailNotificationConsumer> log) : IConsumer<OrderPlaced>
{
    public Task Consume(ConsumeContext<OrderPlaced> ctx)
    {
        log.LogInformation("Sending confirmation email for order {Id}", ctx.Message.OrderId);
        return Task.CompletedTask;
    }
}

public sealed class ImageResizeConsumer(ILogger<ImageResizeConsumer> log) : IConsumer<ResizeImage>
{
    public Task Consume(ConsumeContext<ResizeImage> ctx)
    {
        log.LogInformation("Resizing image {ImageId} to {W}x{H}",
            ctx.Message.ImageId, ctx.Message.Width, ctx.Message.Height);
        return Task.CompletedTask;
    }
}

// ── Contracts ─────────────────────────────────────────────────────────
record OrderPlaced(Guid OrderId, Guid CustomerId, decimal Amount);
record ResizeImage(Guid ImageId, int Width, int Height);
record ResizeRequest(Guid ImageId, int Width, int Height);
```

## Common Follow-up Questions

- How does RabbitMQ's topic exchange differ from Azure Service Bus topic subscriptions with SQL filters?
- Can a single consumer receive the same message in both the queue and a pub/sub subscription simultaneously?
- What happens to published messages when no subscription exists yet (durable vs auto-delete subscriptions)?
- How do you implement fan-out with exactly-once processing per subscriber?
- What is the difference between broadcast (all instances of a service receive) vs fan-out (one instance per service receives)?
- How does Kafka's consumer group model map to queue vs pub/sub semantics?

## Common Mistakes / Pitfalls

- **Multiple consumers bound to the same queue name for pub/sub**: with RabbitMQ, if two different services bind to the same queue on a fanout exchange, they compete — only one gets each message. Each subscriber needs its own uniquely named queue.
- **Auto-delete subscriptions missing messages**: if a subscriber's queue is auto-deleted while the subscriber is offline (e.g., a temporary queue), messages published during downtime are lost. Use durable queues with explicit names for important subscribers.
- **Ordering assumptions with competing consumers**: with 3 workers draining the same queue, message A published before message B may be processed after B if workers have different processing times. Never assume ordering with competing consumers.
- **Using pub/sub for work that must happen exactly once**: if all three subscribers (payment, inventory, email) receive OrderPlaced, and OrderPlaced includes "process payment," you'll charge the customer three times. Commands should go to a queue; events go to pub/sub topics.
- **Forgetting prefetch count**: without a prefetch limit, RabbitMQ can dispatch all queued messages to the first consumer that connects, starving other consumers. Set `PrefetchCount` appropriate to your processing concurrency.
- **Conflating "events" and "commands"**: publishing a `ProcessPayment` command to a fanout topic causes all subscribers to attempt payment processing. Reserve topics for events (facts that happened); use queues for commands (requests for action).

## References

- [MassTransit — publish vs send](https://masstransit.io/documentation/concepts/producers)
- [Azure Service Bus — topics and subscriptions](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-queues-topics-subscriptions)
- [RabbitMQ — exchanges, routing keys, bindings](https://www.rabbitmq.com/tutorials/amqp-concepts)
- [See: kafka-vs-rabbitmq.md](./kafka-vs-rabbitmq.md) — detailed broker comparison
- [See: message-broker-overview.md](./message-broker-overview.md) — foundational concepts
