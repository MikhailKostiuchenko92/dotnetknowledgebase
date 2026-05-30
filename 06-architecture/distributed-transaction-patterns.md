# Distributed Transaction Patterns

**Category:** Architecture / Microservices
**Difficulty:** 🟡 Middle
**Tags:** `distributed-transactions`, `saga`, `2PC`, `outbox`, `compensating-transactions`, `eventual-consistency`

## Question

> Why does 2PC (Two-Phase Commit) fail in microservices? What patterns replace it — Saga choreography vs orchestration, Outbox pattern, and compensating transactions?

## Short Answer

2PC requires all participants to hold locks during the prepare phase — in microservices across network boundaries, this creates availability/scalability problems and a coordinator single point of failure. The alternatives: the **Saga pattern** coordinates a multi-step distributed workflow using either choreography (services react to events) or orchestration (a saga coordinator issues commands). The **Outbox pattern** guarantees at-least-once reliable event publishing alongside a database write. **Compensating transactions** undo previous steps when a saga fails — they're semantically reversible business operations, not SQL ROLLBACK.

## Detailed Explanation

### Why 2PC Fails in Microservices

```
2PC requires:
1. Prepare phase: coordinator sends PREPARE to all participants
   → Each participant locks resources and responds READY
   → If coordinator crashes here: participants hold locks indefinitely

2. Commit phase: coordinator sends COMMIT
   → If one participant is down: coordinator retries forever or times out

Problems in microservices:
- Network timeout means uncertain state (did it commit or not?)
- Coordinator is a single point of failure
- Locks held across network round-trips kill throughput
- Most microservice DBs (DynamoDB, MongoDB, Cosmos) don't support XA protocol
```

### Saga Pattern: Choreography

Events drive the workflow — each service reacts to events from previous steps:

```
OrderService  ────── OrderCreatedEvent ──────→ InventoryService
                                                     │
                                        StockReservedEvent
                                                     │
                                                     ↓
                                             PaymentService
                                                     │
                                        PaymentProcessedEvent
                                                     │
                                                     ↓
                                            NotificationService
```

```csharp
// InventoryService handles OrderCreatedEvent
public class ReserveStockOnOrderCreated : IConsumer<OrderCreatedIntegrationEvent>
{
    public async Task Consume(ConsumeContext<OrderCreatedIntegrationEvent> ctx)
    {
        var success = await _inventory.TryReserveAsync(ctx.Message.Lines, ctx.CancellationToken);
        if (success)
            await ctx.Publish(new StockReservedEvent(ctx.Message.OrderId));
        else
            await ctx.Publish(new StockReservationFailedEvent(ctx.Message.OrderId, "Out of stock"));
    }
}

// OrderService compensates on failure
public class HandleStockReservationFailed : IConsumer<StockReservationFailedEvent>
{
    public async Task Consume(ConsumeContext<StockReservationFailedEvent> ctx)
    {
        await _orders.CancelAsync(ctx.Message.OrderId, "Insufficient stock", ctx.CancellationToken);
    }
}
```

### Saga Pattern: Orchestration

A central saga coordinator issues commands and tracks state:

```csharp
// MassTransit Saga State Machine — orchestrates the order flow
public class OrderSaga : MassTransitStateMachine<OrderSagaState>
{
    public State Pending { get; private set; } = null!;
    public State StockReserved { get; private set; } = null!;
    public State PaymentFailed { get; private set; } = null!;

    public Event<OrderSubmittedEvent> OrderSubmitted { get; private set; } = null!;
    public Event<StockReservedEvent> StockReserved2 { get; private set; } = null!;
    public Event<PaymentFailedEvent> PaymentFailed2 { get; private set; } = null!;

    public OrderSaga()
    {
        InstanceState(x => x.CurrentState);

        Event(() => OrderSubmitted, x => x.CorrelateById(m => m.Message.OrderId));
        Event(() => StockReserved2, x => x.CorrelateById(m => m.Message.OrderId));
        Event(() => PaymentFailed2, x => x.CorrelateById(m => m.Message.OrderId));

        Initially(
            When(OrderSubmitted)
                .Then(ctx => ctx.Saga.OrderId = ctx.Message.OrderId)
                .Publish(ctx => new ReserveStockCommand(ctx.Saga.OrderId, ctx.Message.Lines))
                .TransitionTo(Pending));

        During(Pending,
            When(StockReserved2)
                .Publish(ctx => new ProcessPaymentCommand(ctx.Saga.OrderId))
                .TransitionTo(StockReserved),
            When(PaymentFailed2)
                .Publish(ctx => new ReleaseStockCommand(ctx.Saga.OrderId))  // ← compensate
                .TransitionTo(PaymentFailed));
    }
}
```

### Outbox Pattern

Guarantees event publishing is atomic with the DB write:

```csharp
// Save order + outbox message in ONE transaction
public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
{
    using var tx = await db.Database.BeginTransactionAsync(ct);
    try
    {
        var order = Order.Create(new CustomerId(cmd.CustomerId));
        order.Submit();
        db.Orders.Add(order);

        // Write to outbox in the same transaction
        db.OutboxMessages.Add(new OutboxMessage
        {
            Id = Guid.NewGuid(),
            Type = nameof(OrderSubmittedIntegrationEvent),
            Payload = JsonSerializer.Serialize(new OrderSubmittedIntegrationEvent(order.Id.Value)),
            Status = OutboxStatus.Pending,
            CreatedAt = DateTime.UtcNow
        });

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return order.Id.Value;
    }
    catch { await tx.RollbackAsync(ct); throw; }
}

// Background worker: relay outbox messages to message bus
public class OutboxRelayWorker(AppDbContext db, IMessageBus bus) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            var pending = await db.OutboxMessages
                .Where(m => m.Status == OutboxStatus.Pending)
                .OrderBy(m => m.CreatedAt).Take(10).ToListAsync(ct);

            foreach (var msg in pending)
            {
                await bus.PublishAsync(msg.Type, msg.Payload, ct);
                msg.Status = OutboxStatus.Sent;
            }

            await db.SaveChangesAsync(ct);
            await Task.Delay(500, ct);
        }
    }
}
```

### Choreography vs Orchestration

| | Choreography | Orchestration |
|--|-------------|--------------|
| **Coordination** | Implicit via events | Explicit saga state machine |
| **Coupling** | Low (services don't know each other) | Medium (coordinator knows all steps) |
| **Visibility** | Hard to trace full workflow | Easy — saga state tracks everything |
| **Failure handling** | Distributed compensation | Centralized compensation |
| **Best for** | Simple linear flows | Complex branching workflows |

## Code Example

```csharp
// MassTransit setup: Saga + consumer registration
builder.Services.AddMassTransit(x =>
{
    x.AddSagaStateMachine<OrderSaga, OrderSagaState>()
        .EntityFrameworkRepository(r =>
        {
            r.ConcurrencyMode = ConcurrencyMode.Optimistic;
            r.AddDbContext<DbContext, SagaDbContext>((p, b) =>
                b.UseSqlServer(conn));
        });

    x.AddConsumer<ReserveStockOnOrderCreated>();
    x.AddConsumer<HandleStockReservationFailed>();
    x.UsingRabbitMq((ctx, cfg) => cfg.ConfigureEndpoints(ctx));
});
```

## Common Follow-up Questions

- How do you handle idempotency when a saga step is retried?
- What is the difference between a compensating transaction and a SQL ROLLBACK?
- How do you test a saga end-to-end without a real message bus?
- How do you implement timeout handling in a saga (e.g., payment not received within 10 minutes)?
- What is the Transactional Outbox pattern, and how does it relate to Change Data Capture?

## Common Mistakes / Pitfalls

- **Using compensating transactions for all failures**: compensation only works for semantically reversible operations. Sending an email cannot be "un-sent" — model side effects as idempotent and accept partial completion.
- **Choreography without a correlation ID**: without a shared correlation ID on all events, tracing a saga through multiple services is nearly impossible.
- **Outbox worker polling too aggressively**: a 100ms outbox poll when there are no messages wastes CPU and DB connections. Use a delay backoff or DB notifications.
- **Saga state in memory**: if the saga coordinator crashes, in-memory saga state is lost. Always persist saga state to a DB with optimistic concurrency.

## References

- [Saga pattern — Microsoft Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga)
- [Transactional Outbox — microservices.io](https://microservices.io/patterns/data/transactional-outbox.html) (verify URL)
- [MassTransit Sagas](https://masstransit.io/documentation/configuration/sagas)
- [See: inter-service-communication.md](./inter-service-communication.md)
