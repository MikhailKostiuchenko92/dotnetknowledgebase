# Distributed Transactions and Sagas

**Category:** Data Access / Transactions
**Difficulty:** 🔴 Senior
**Tags:** `distributed-transactions`, `2PC`, `saga`, `outbox`, `DTC`, `microservices`, `eventual-consistency`

## Question

> Why are distributed transactions (2PC/MSDTC) impractical in modern cloud and microservices architectures? What are the alternatives — how do sagas and the outbox pattern replace distributed transactions in practice?

## Short Answer

Two-phase commit (2PC) / MSDTC provides strong ACID guarantees across multiple resources but has fatal practical flaws in cloud environments: coordinator single point of failure, blocking during coordinator failure, scalability limits, no HTTP service support, and Azure SQL/PaaS services don't support DTC. The modern alternative is the **Saga pattern**: decompose a multi-step operation into a sequence of local transactions, with **compensating transactions** to undo previous steps on failure. The **Outbox pattern** ensures reliable event publication in the first local transaction, enabling downstream saga steps without distributed transactions.

## Detailed Explanation

### What Is 2PC and Why It's Problematic

Two-phase commit coordinates multiple resource managers (databases, message queues):

1. **Prepare phase**: Coordinator asks all participants "can you commit?". Each participant acquires locks and responds yes/no.
2. **Commit phase**: If all say yes, coordinator sends commit to all.

**Problems in cloud/microservices:**

| Problem | Impact |
|---------|--------|
| Blocking protocol | If coordinator fails after Prepare, all participants hold locks indefinitely |
| MSDTC not supported by Azure SQL, Cosmos DB, Service Bus | Can't use 2PC for most cloud data stores |
| Requires DTC on every node | Complex infrastructure, no container support |
| Scalability | Every participant holds locks during both phases → contention at scale |
| Microservices communicate via HTTP | HTTP is not an XA-compatible resource manager |

> **Azure SQL explicitly does not support DTC/MSDTC.** `TransactionScope` with multiple connections on Azure SQL throws a `NotSupportedException` ("Transactions distributed across databases on different SQL Database servers are not supported").

### The Saga Pattern

A saga is a sequence of local transactions where each step has a **compensating transaction** that undoes its effect if a later step fails:

```
PlaceOrder saga:
  Step 1: Reserve inventory     → Compensate: Release reservation
  Step 2: Charge payment        → Compensate: Issue refund
  Step 3: Schedule shipment     → Compensate: Cancel shipment
  Step 4: Confirm order

Failure at Step 3:
  → Execute compensate(Step 2): Issue refund
  → Execute compensate(Step 1): Release reservation
```

**Two styles:**

**Choreography**: Each service publishes events; other services react. No central coordinator.
- Pro: loose coupling, simple implementation.
- Con: hard to trace, circular dependency risk.

**Orchestration**: Central Saga Orchestrator calls each service and manages compensations on failure.
- Pro: explicit flow, easier to debug, single source of truth.
- Con: orchestrator is a coupling point.

### The Outbox Pattern

Ensures that a local database write and a message publication are atomic **without** a distributed transaction:

```csharp
// Instead of: db.SaveChanges() + messageQueue.Publish() (two separate operations)
// Use: db.SaveChanges() + db.OutboxMessages.Add() (single local transaction)

public async Task PlaceOrderAsync(PlaceOrderCommand cmd, CancellationToken ct)
{
    var order = new Order(cmd.CustomerId, cmd.Items);
    db.Orders.Add(order);

    // Write the event to outbox table in the SAME transaction as the order
    db.OutboxMessages.Add(new OutboxMessage
    {
        EventType = nameof(OrderPlacedEvent),
        Payload = JsonSerializer.Serialize(new OrderPlacedEvent(order.Id, order.CustomerId)),
        CreatedAt = DateTimeOffset.UtcNow
    });

    await db.SaveChangesAsync(ct);  // ← SINGLE local transaction: order + outbox message
}

// Separate background worker: reads outbox and publishes to message bus
// Idempotency: marks outbox messages as "sent" after successful publish
// If publish fails: retry later — message remains in outbox
```

The outbox guarantees **at-least-once delivery** (not at-most-once) — downstream handlers must be idempotent.

### EF Core + Outbox Implementation

```csharp
public class OutboxMessage
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string EventType { get; set; } = "";
    public string Payload { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? ProcessedAt { get; set; }
    public int RetryCount { get; set; }
}

// Background service (Quartz.NET or IHostedService)
public class OutboxProcessor(AppDb db, IMessageBus bus) : IJob
{
    public async Task Execute(IJobExecutionContext ctx)
    {
        var messages = await db.OutboxMessages
            .Where(m => m.ProcessedAt == null && m.RetryCount < 5)
            .OrderBy(m => m.CreatedAt)
            .Take(100)
            .ToListAsync(ctx.CancellationToken);

        foreach (var msg in messages)
        {
            try
            {
                await bus.PublishAsync(msg.EventType, msg.Payload, ctx.CancellationToken);
                msg.ProcessedAt = DateTimeOffset.UtcNow;
            }
            catch
            {
                msg.RetryCount++;
            }
        }

        await db.SaveChangesAsync(ctx.CancellationToken);
    }
}
```

### Saga Libraries for .NET

- **MassTransit**: Built-in saga state machine, outbox, retry, compensations.
- **NServiceBus**: Enterprise saga framework with outbox.
- **Wolverine**: Lightweight saga + outbox for .NET 8.
- **Dapr**: Platform-agnostic workflow + actor model.

## Code Example

```csharp
// MassTransit saga (orchestration-style via StateMachine)
public class OrderSaga : MassTransitStateMachine<OrderState>
{
    public OrderSaga()
    {
        InstanceState(x => x.CurrentState);

        Initially(
            When(OrderPlaced)
                .Then(ctx => ctx.Saga.OrderId = ctx.Message.OrderId)
                .TransitionTo(AwaitingPayment)
                .Publish(ctx => new ReserveInventoryCommand(ctx.Saga.OrderId)));

        During(AwaitingPayment,
            When(PaymentSucceeded)
                .TransitionTo(AwaitingShipment)
                .Publish(ctx => new ScheduleShipmentCommand(ctx.Saga.OrderId)),
            When(PaymentFailed)
                .Then(ctx => logger.LogWarning("Payment failed for order {Id}", ctx.Saga.OrderId))
                .TransitionTo(Cancelled)
                .Publish(ctx => new ReleaseInventoryCommand(ctx.Saga.OrderId)));
    }

    public State AwaitingPayment { get; private set; } = null!;
    public State AwaitingShipment { get; private set; } = null!;
    public State Cancelled { get; private set; } = null!;

    public Event<OrderPlacedEvent> OrderPlaced { get; private set; } = null!;
    public Event<PaymentSucceededEvent> PaymentSucceeded { get; private set; } = null!;
    public Event<PaymentFailedEvent> PaymentFailed { get; private set; } = null!;
}
```

## Common Follow-up Questions

- What is the CAP theorem, and how does it relate to the choice between 2PC and sagas?
- How do you ensure idempotency in saga handlers?
- What is the difference between a choreography saga and an orchestration saga — which should you choose?
- How does the outbox pattern guarantee at-least-once delivery — and what happens if the outbox processor fails mid-batch?
- How do you handle long-running sagas that span hours or days (e.g., an order that hasn't shipped in 3 days)?

## Common Mistakes / Pitfalls

- **Assuming `TransactionScope` with `Suppress` options provides distributed atomicity**: Suppressing a transaction creates a new connection without a transaction — this abandons atomicity entirely, it doesn't create a distributed one.
- **Not implementing compensating transactions**: A saga without compensations is a workflow that leaves the system in an inconsistent partial state on failure. Every step must have a well-defined undo.
- **Compensating transactions as best-effort**: Compensations themselves can fail. Sagas need retry and dead-letter handling for failed compensations, not just for forward steps.
- **Using the outbox with a non-idempotent event handler**: Outbox guarantees at-least-once delivery — handlers will receive the same message multiple times (on retry). Without idempotency guards, you'll double-charge, double-ship, or double-reserve.
- **Building a saga as a long-lived database transaction**: A saga that holds a SQL transaction across multiple service calls is not a saga — it's a distributed transaction with worse failure semantics. Each saga step must commit its local transaction before proceeding.

## References

- [Saga pattern — Microsoft Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga)
- [Outbox pattern — Microsoft Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/best-practices/transactional-outbox-cosmos)
- [MassTransit Sagas — MassTransit docs](https://masstransit.io/documentation/patterns/saga)
- [See: transaction-basics.md](./transaction-basics.md)
- [See: ambient-transactions.md](./ambient-transactions.md)
