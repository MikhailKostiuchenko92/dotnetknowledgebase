# Azure Service Bus Patterns

**Category:** System Design / Messaging
**Difficulty:** Middle
**Tags:** `azure-service-bus`, `queues`, `topics`, `sessions`, `dead-letter`, `message-lock`, `scheduled-messages`

## Question

> What are the key features of Azure Service Bus? When do you use queues vs topics/subscriptions? How do sessions, dead-letter queues, and message locks work? What are the common .NET patterns for reliable message processing?

- What is the difference between Azure Service Bus and Azure Event Hub?
- How do you implement ordered processing of messages per customer using sessions?

## Short Answer

Azure Service Bus is a fully managed enterprise message broker supporting queues (point-to-point) and topics/subscriptions (pub/sub). Key features that distinguish it from simpler queues: sessions (ordered, stateful processing per session key), dead-letter queue (automatic parking of failed messages), message lock (pessimistic processing lock prevents duplicate delivery while being processed), duplicate detection (idempotent delivery window), and scheduled messages. For .NET services, MassTransit or the `Azure.Messaging.ServiceBus` SDK are the standard choices; MassTransit adds retry, circuit breaking, and saga orchestration on top of the raw SDK.

## Detailed Explanation

### Queue vs Topic/Subscription

| | Queue | Topic + Subscription |
|--|-------|---------------------|
| Pattern | Point-to-point (competing consumers) | Pub/sub (fan-out to multiple subscribers) |
| Consumers | Multiple, each message delivered to one | Each subscription gets a copy of the message |
| Use case | Work queue: process each order once | Event fanout: notify inventory, email, analytics |

```
Queue: orders-to-process
  [OrderCreated] → one of: Consumer A, Consumer B, Consumer C (load balanced)

Topic: order-events
  [OrderCreated] → Subscription: inventory-sub → Inventory Service
               └─► Subscription: email-sub    → Email Service
               └─► Subscription: analytics-sub → Analytics Service
```

### Message Lock and At-Least-Once Delivery

When a consumer receives a message, Service Bus places a **lock** on it (default: 60 seconds). The message stays on the queue but is invisible to other consumers. The consumer must:
- **Complete** the message (delete from queue) when processing succeeds.
- **Abandon** the message (release lock) to make it visible again immediately.
- **Defer** the message (keep it locked, process later).
- Let the lock **expire** (Service Bus re-enqueues it after `LockDuration`).

```csharp
// Azure.Messaging.ServiceBus SDK — manual lock management
await using var client    = new ServiceBusClient(connStr, new DefaultAzureCredential());
await using var receiver  = client.CreateReceiver("orders-queue");

var messages = await receiver.ReceiveMessagesAsync(maxMessages: 10, maxWaitTime: TimeSpan.FromSeconds(5), ct);

foreach (var message in messages)
{
    try
    {
        var order = message.Body.ToObjectFromJson<OrderCreatedEvent>();
        await ProcessOrderAsync(order, ct);
        await receiver.CompleteMessageAsync(message, ct);  // ✅ remove from queue
    }
    catch (Exception ex) when (IsTransient(ex))
    {
        await receiver.AbandonMessageAsync(message, ct);   // 🔄 retry immediately
    }
    catch (Exception ex)
    {
        // Non-transient failure: send to DLQ after max delivery count
        await receiver.DeadLetterMessageAsync(message,
            deadLetterReason: "ProcessingFailed",
            deadLetterErrorDescription: ex.Message, ct);
    }
}
```

**Lock renewal** for long-running processing:

```csharp
// Renew lock in background to prevent expiry during processing
using var renewalCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
var renewalTask = Task.Run(async () =>
{
    while (!renewalCts.Token.IsCancellationRequested)
    {
        await Task.Delay(TimeSpan.FromSeconds(30), renewalCts.Token);
        await receiver.RenewMessageLockAsync(message, renewalCts.Token);
    }
}, renewalCts.Token);

try
{
    await SlowProcessingAsync(message.Body, ct);
    await receiver.CompleteMessageAsync(message, ct);
}
finally
{
    renewalCts.Cancel();
    await renewalTask.IgnoreExceptions();
}
```

### Sessions: Ordered Processing Per Key

Sessions group related messages under a `SessionId` and guarantee that all messages for a given session are processed by one consumer at a time — enabling ordered per-entity processing:

```csharp
// Producer: set SessionId to ensure ordered delivery per customer
await sender.SendMessageAsync(new ServiceBusMessage(body)
{
    SessionId        = customerId.ToString(),  // all messages for this customer = same session
    MessageId        = eventId.ToString(),     // for duplicate detection
    ContentType      = "application/json",
    Subject          = "OrderCreated",
}, ct);
```

```csharp
// Consumer: accept a session — processes one customer's messages at a time (ordered)
await using var sessionReceiver = await client.AcceptNextSessionAsync("orders-queue",
    new ServiceBusSessionReceiverOptions { ReceiveMode = ServiceBusReceiveMode.PeekLock }, ct);

string customerId = sessionReceiver.SessionId;
_logger.LogInformation("Processing session for customer {CustomerId}", customerId);

await foreach (var message in sessionReceiver.ReceiveMessagesAsync(ct))
{
    await ProcessOrderAsync(message.Body.ToObjectFromJson<OrderCreatedEvent>(), ct);
    await sessionReceiver.CompleteMessageAsync(message, ct);
}
```

**Use cases for sessions**:
- Order processing where events must be applied in sequence (OrderPlaced → PaymentReceived → Shipped).
- Per-user sagas where concurrent processing of the same user's messages would corrupt state.

### Dead-Letter Queue (DLQ)

Every queue and subscription has a built-in DLQ (`orders-queue/$DeadLetterQueue`). Messages move to the DLQ when:
- `MaxDeliveryCount` is exceeded (default: 10 retries).
- The application explicitly dead-letters the message.
- Message TTL expires (if `DeadLetteringOnMessageExpiration` is enabled).

```csharp
// Monitor and process DLQ
await using var dlqReceiver = client.CreateReceiver("orders-queue",
    new ServiceBusReceiverOptions
    {
        SubQueue = SubQueue.DeadLetter,
        ReceiveMode = ServiceBusReceiveMode.PeekLock,
    });

var deadMessages = await dlqReceiver.ReceiveMessagesAsync(100, ct);
foreach (var msg in deadMessages)
{
    _logger.LogError("Dead-lettered message {MessageId}: {Reason} — {Description}",
        msg.MessageId,
        msg.DeadLetterReason,
        msg.DeadLetterErrorDescription);

    // Option A: requeue to original queue after manual investigation
    await sender.SendMessageAsync(new ServiceBusMessage(msg.Body), ct);
    await dlqReceiver.CompleteMessageAsync(msg, ct);

    // Option B: write to storage for offline analysis, then complete
}
```

### Scheduled and Deferred Messages

```csharp
// Schedule a reminder 3 days from now
long sequenceNumber = await sender.ScheduleMessageAsync(
    new ServiceBusMessage(reminderBody) { Subject = "PaymentReminder" },
    DateTimeOffset.UtcNow.AddDays(3), ct);

// Cancel the scheduled message if payment received
await sender.CancelScheduledMessageAsync(sequenceNumber, ct);

// Defer: pull it off the queue now but process it later (keyed by sequence number)
await receiver.DeferMessageAsync(message, ct);
long deferred = message.SequenceNumber;
// ... later:
var deferredMsg = await receiver.ReceiveDeferredMessageAsync(deferred, ct);
```

### MassTransit with Azure Service Bus (Recommended for .NET)

```csharp
builder.Services.AddMassTransit(mt =>
{
    mt.AddConsumer<OrderCreatedConsumer>();
    mt.AddSagaStateMachine<OrderSaga, OrderSagaState>()
        .EntityFrameworkRepository(r => r.ExistingDbContext<SagaDbContext>());

    mt.UsingAzureServiceBus((ctx, asb) =>
    {
        asb.Host(builder.Configuration["ServiceBus:ConnectionString"]);
        asb.ConfigureEndpoints(ctx);

        // Retry configuration
        asb.UseMessageRetry(r => r.Exponential(5,
            TimeSpan.FromSeconds(1),
            TimeSpan.FromSeconds(30),
            TimeSpan.FromSeconds(3)));
    });
});
```

MassTransit handles lock renewal, retry with exponential backoff, dead-letter routing, and saga state persistence automatically.

> **Warning:** Service Bus message locks default to 60 seconds. If processing takes longer, the message is re-delivered and processed twice. Either: increase `LockDuration` (up to 5 minutes), renew the lock programmatically, or use MassTransit which handles this automatically.

## Code Example

```csharp
// Full producer pattern: reliable fire-and-forget with duplicate detection
await using var client = new ServiceBusClient(
    $"{serviceBusNamespace}.servicebus.windows.net",
    new DefaultAzureCredential());   // Managed Identity — no connection string

await using var sender = client.CreateSender("orders.events");

// Batch messages for efficiency (up to 256KB per batch)
using ServiceBusMessageBatch batch = await sender.CreateMessageBatchAsync(ct);

foreach (var evt in pendingEvents)
{
    var msg = new ServiceBusMessage(BinaryData.FromObjectAsJson(evt))
    {
        MessageId   = evt.EventId.ToString(),   // duplicate detection key
        SessionId   = evt.CustomerId.ToString(), // session ordering
        Subject     = evt.GetType().Name,
        ContentType = "application/json",
        TimeToLive  = TimeSpan.FromDays(7),
    };

    if (!batch.TryAddMessage(msg))
    {
        // Batch full — send current batch and start new one
        await sender.SendMessagesAsync(batch, ct);
        // ... create new batch, add message
    }
}

await sender.SendMessagesAsync(batch, ct);
```

## Common Follow-up Questions

- When should you use Azure Service Bus vs Azure Event Hubs vs Azure Event Grid?
- How do subscription filters work in Service Bus topics?
- How does Service Bus Premium tier differ from Standard, and what features require Premium?
- How do you implement an outbox pattern with Service Bus to ensure exactly-once delivery?
- What is the maximum message size in Service Bus and how do you handle payloads that exceed it?

## Common Mistakes / Pitfalls

- **Not renewing message lock for long operations**: the lock expires and the message is redelivered, causing duplicate processing; use MassTransit or explicit lock renewal.
- **Catching all exceptions and completing messages**: a bug that throws an exception should let the message fail and be retried; only complete on success.
- **Using `ReceiveMode.ReceiveAndDelete` (fire-and-forget)**: messages are deleted on receipt — if processing fails, the message is lost; always use `PeekLock`.
- **Not monitoring the DLQ**: a growing DLQ is silent unless you alert on it; set an alert on `DeadLetteredMessageCount > 0`.
- **Session consumer holding an idle session**: a session receiver holds the session lock even when there are no more messages for up to 5 minutes; set a short `SessionIdleTimeout` to release sessions faster.

## References

- [Azure Service Bus documentation — Microsoft Docs](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-messaging-overview)
- [Azure.Messaging.ServiceBus SDK](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-dotnet-get-started-with-queues)
- [Service Bus sessions — Microsoft Docs](https://learn.microsoft.com/en-us/azure/service-bus-messaging/message-sessions)
- [MassTransit Azure Service Bus](https://masstransit.io/documentation/transports/azure-service-bus)
- [See: dead-letter-queues.md](./dead-letter-queues.md)
- [See: saga-pattern.md](./saga-pattern.md)
