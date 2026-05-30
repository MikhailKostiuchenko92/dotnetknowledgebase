# Dead-Letter Queues

**Category:** System Design / Messaging
**Difficulty:** 🟡 Middle
**Tags:** `dead-letter-queue`, `DLQ`, `poison-message`, `error-handling`, `retry`, `RabbitMQ`, `Azure-Service-Bus`, `MassTransit`

## Question

> What is a Dead-Letter Queue (DLQ) and why is it essential in any message-driven system? What causes messages to be dead-lettered, and how do you handle and monitor them in practice?

## Short Answer

A Dead-Letter Queue (DLQ) is a special queue that receives messages that could not be successfully processed after all retry attempts. Without a DLQ, failed messages are either silently dropped (data loss) or loop forever (blocking queue progress). A DLQ acts as a **safety net** — it preserves unprocessable messages for inspection and reprocessing while allowing the main queue to keep flowing. Every production messaging system must have DLQs configured, monitored, and with a plan for how to handle messages that land in them.

## Detailed Explanation

### Why DLQs Exist

Consider a consumer that throws an exception processing message M:

```
Without DLQ:
  Option A: drop message on failure → silent data loss
  Option B: retry forever           → queue is stuck; no other messages processed

With DLQ:
  Retry 3 times → move to DLQ → main queue continues → ops team investigates
```

The DLQ decouples **message failure** from **queue availability**. Other messages keep flowing while the failed message is parked for investigation.

### What Causes Dead-Lettering

| Cause | RabbitMQ | Azure Service Bus |
|-------|---------|------------------|
| Max retries exceeded | `x-death` count ≥ policy | `DeliveryCount` ≥ `MaxDeliveryCount` |
| Message TTL expired | Per-message or per-queue TTL | `TimeToLive` header |
| Consumer rejects with no-requeue | `basic.reject(requeue=false)` | Session lock expired + not renewed |
| Queue length exceeded | `x-max-length` policy | N/A |
| Subscription filter evaluation error | N/A | Filter exception |

### Retry Strategy Before Dead-Lettering

Dead-lettering should be the last resort after exhausting retries. A good retry strategy:

1. **Immediate retry** (1–3 times): transient failures like connection timeouts.
2. **Delayed retry with back-off** (e.g., 30s, 5m, 30m): infrastructure issues that need time to recover.
3. **Dead-letter** after all retries exhausted.

MassTransit retry configuration:
```csharp
cfg.UseMessageRetry(r =>
{
    r.Incremental(3,                           // 3 retries
        initialInterval:  TimeSpan.FromSeconds(5),
        intervalIncrement: TimeSpan.FromSeconds(10));
    // Retry immediately for specific exceptions
    r.Ignore<ValidationException>();           // don't retry validation errors → DLQ immediately
});
```

### Handling DLQ Messages

After a message lands in the DLQ:

1. **Investigate**: read the DLQ message + its error metadata (exception message, stack trace).
2. **Fix**: deploy a fix for the consumer bug, schema issue, or data problem.
3. **Replay**: move messages from DLQ back to the original queue. Options:
   - Manual via management UI (RabbitMQ Management Plugin, Azure Portal).
   - Script using the broker's API.
   - Dedicated replay service that reads from DLQ and republishes.

> **Warning:** Do NOT automatically replay all DLQ messages without reviewing them first. A bug causing dead-lettering may also have caused partial state mutations. Blindly replaying may cause duplicate effects. Always understand why a message failed before replaying.

### Poison Messages

A **poison message** is a message that will *always* fail regardless of retries — typically due to a corrupted payload, schema mismatch, or a bug in the consumer that affects all instances. Without a DLQ, a poison message blocks the queue indefinitely.

Signs of a poison message:
- Same message ID appears in retry logs multiple times.
- Processing time is extremely short (failing immediately, not after I/O).
- No pattern to which messages fail vs succeed.

### RabbitMQ DLQ Configuration

```csharp
// RabbitMQ: configure DLX (Dead-Letter Exchange) via queue arguments
var args = new Dictionary<string, object>
{
    ["x-dead-letter-exchange"]    = "order-dlx",        // exchange to route dead letters
    ["x-dead-letter-routing-key"] = "order-dlq",        // routing key on the DLX
    ["x-message-ttl"]             = 3_600_000,           // 1 hour TTL (ms)
    ["x-max-length"]              = 10_000               // max queue depth before dead-lettering
};
channel.QueueDeclare("orders", durable: true, exclusive: false, autoDelete: false, args);
channel.ExchangeDeclare("order-dlx", ExchangeType.Direct);
channel.QueueDeclare("order-dlq", durable: true, exclusive: false, autoDelete: false);
channel.QueueBind("order-dlq", "order-dlx", "order-dlq");
```

### Azure Service Bus DLQ

Azure Service Bus has a built-in DLQ on every queue and topic subscription — no configuration required:

- DLQ path: `{queue-name}/$DeadLetterQueue`
- Message properties added: `DeadLetterReason`, `DeadLetterErrorDescription`.
- Can be configured via `MaxDeliveryCount` (default: 10).

## Code Example

```csharp
// ASP.NET Core 8 — DLQ handling with MassTransit + Azure Service Bus

using MassTransit;
using Azure.Messaging.ServiceBus;

// ── MassTransit: configure retries and fault consumer (dead-letter handler) ──
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddMassTransit(x =>
{
    x.AddConsumer<OrderPlacedConsumer>();

    // Register a "fault consumer" — receives Fault<OrderPlaced> when consumer fails all retries
    x.AddConsumer<OrderPlacedFaultConsumer>();

    x.UsingAzureServiceBus((ctx, cfg) =>
    {
        cfg.Host(builder.Configuration["ServiceBus:ConnectionString"]);

        cfg.ReceiveEndpoint("order-placed", ep =>
        {
            // Retry: 3 attempts with exponential back-off
            ep.UseMessageRetry(r => r.Exponential(3,
                TimeSpan.FromSeconds(5), TimeSpan.FromMinutes(5), TimeSpan.FromSeconds(10)));

            // Skip dead-lettering for these exceptions (retry won't help)
            ep.UseMessageRetry(r => r.Ignore<ArgumentNullException>());

            ep.ConfigureConsumer<OrderPlacedConsumer>(ctx);
        });

        // Fault consumer: called when all retries are exhausted
        cfg.ReceiveEndpoint("order-placed-faults", ep =>
        {
            ep.ConfigureConsumer<OrderPlacedFaultConsumer>(ctx);
        });

        cfg.ConfigureEndpoints(ctx);
    });
});

// ── Main consumer ─────────────────────────────────────────────────────
public sealed class OrderPlacedConsumer(ILogger<OrderPlacedConsumer> log) : IConsumer<OrderPlaced>
{
    public Task Consume(ConsumeContext<OrderPlaced> ctx)
    {
        if (ctx.Message.Amount <= 0)
            throw new ArgumentException("Invalid amount — this will be dead-lettered immediately");

        log.LogInformation("Processing order {Id}", ctx.Message.OrderId);
        return Task.CompletedTask;
    }
}

// ── Fault consumer: receives Fault<T> when all retries are exhausted ──
public sealed class OrderPlacedFaultConsumer(ILogger<OrderPlacedFaultConsumer> log)
    : IConsumer<Fault<OrderPlaced>>
{
    public Task Consume(ConsumeContext<Fault<OrderPlaced>> ctx)
    {
        var fault  = ctx.Message;
        var order  = fault.Message;

        log.LogError("Order {Id} failed after {Count} retries. Exceptions: {Errors}",
            order.OrderId,
            fault.Exceptions.Length,
            string.Join("; ", fault.Exceptions.Select(e => e.Message)));

        // Options: alert ops, write to audit log, schedule for manual review
        // Do NOT republish without investigation

        return Task.CompletedTask;
    }
}

// ── Manual DLQ inspection (Azure Service Bus SDK) ─────────────────────
public sealed class DlqInspector(ServiceBusClient client)
{
    public async Task InspectAsync(string queueName, CancellationToken ct)
    {
        var dlqPath = ServiceBusAdministrationClient.GetDeadLetterQueueName(queueName);
        await using var receiver = client.CreateReceiver(dlqPath,
            new ServiceBusReceiverOptions { ReceiveMode = ServiceBusReceiveMode.PeekLock });

        var messages = await receiver.PeekMessagesAsync(maxMessages: 20, cancellationToken: ct);

        foreach (var msg in messages)
        {
            Console.WriteLine($"""
                MessageId:  {msg.MessageId}
                Reason:     {msg.DeadLetterReason}
                Error:      {msg.DeadLetterErrorDescription}
                Body:       {msg.Body}
                ---
            """);
        }
    }

    // Replay: move from DLQ back to original queue
    public async Task ReplayAsync(string queueName, int count, CancellationToken ct)
    {
        var dlqPath = ServiceBusAdministrationClient.GetDeadLetterQueueName(queueName);
        await using var receiver = client.CreateReceiver(dlqPath,
            new ServiceBusReceiverOptions { ReceiveMode = ServiceBusReceiveMode.PeekLock });
        await using var sender   = client.CreateSender(queueName);

        var messages = await receiver.ReceiveMessagesAsync(count, cancellationToken: ct);
        foreach (var msg in messages)
        {
            await sender.SendMessageAsync(new ServiceBusMessage(msg.Body)
            {
                MessageId   = msg.MessageId,
                ContentType = msg.ContentType
            }, ct);
            await receiver.CompleteMessageAsync(msg, ct);
        }
    }
}

record OrderPlaced(Guid OrderId, decimal Amount);
```

## Common Follow-up Questions

- How do you automatically alert on DLQ depth growing beyond a threshold in production?
- What is the difference between a "skip" (ignore) and a "dead-letter" in MassTransit's error handling?
- Should DLQ replay be automatic or always manual? How do you decide?
- How do you handle a poison message that was dead-lettered because the consumer had a bug, after you've deployed the fix?
- How do you distinguish between a transient failure (should retry) and a permanent failure (should dead-letter immediately)?
- How would you design a DLQ monitoring dashboard for a system with 20 queues?

## Common Mistakes / Pitfalls

- **No DLQ configured**: messages that fail all retries are silently dropped. You never know about lost data until a user complains. Always configure DLQ.
- **Infinite retry loops without dead-lettering**: `cfg.UseMessageRetry(r => r.Interval(int.MaxValue, …))` means a poison message retries forever, blocking all queue progress. Always set a finite retry limit.
- **Not monitoring DLQ depth**: a DLQ filling up silently means business data is being lost. Add a metric/alert on DLQ message count — alert when > 0 for critical queues.
- **Auto-replay without investigation**: automatically moving DLQ messages back to the original queue after a deploy can re-trigger a bug that hasn't been fully fixed, or replay messages whose state has already been compensated manually.
- **DLQ schema drift**: DLQ messages may use an old message schema (from before a breaking change). Replaying them against a new consumer that expects a new schema causes immediate re-dead-lettering. Add schema version metadata and handle migration in replay logic.
- **Retrying non-retriable exceptions**: retrying on `ArgumentNullException` (bad input data) wastes 3 retries × delay before dead-lettering. Use `Ignore<TException>` in MassTransit to dead-letter immediately for known permanent failures.

## References

- [MassTransit — error handling and dead-lettering](https://masstransit.io/documentation/concepts/exceptions)
- [Azure Service Bus — dead-letter queues](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-dead-letter-queues)
- [RabbitMQ — dead letter exchanges](https://www.rabbitmq.com/docs/dlx)
- [See: message-broker-overview.md](./message-broker-overview.md) — broker fundamentals
- [See: at-least-once-vs-exactly-once.md](./at-least-once-vs-exactly-once.md) — delivery guarantees
