# Saga Pattern

**Category:** System Design / Messaging
**Difficulty:** Senior
**Tags:** `saga`, `choreography`, `orchestration`, `compensating-transactions`, `masstransit`, `distributed-transactions`

## Question

> What is the Saga pattern? How do choreography-based and orchestration-based sagas differ? How do you handle failures with compensating transactions? How do you implement an orchestration saga in .NET using MassTransit?

- When would you choose choreography over orchestration?
- What are the consistency guarantees of a saga compared to a distributed transaction (2PC)?

## Short Answer

A saga is a sequence of local transactions coordinated across multiple services, where each step publishes an event or sends a command to trigger the next step. If a step fails, previously completed steps are reversed by compensating transactions. Choreography sagas react to events with no central coordinator — each service knows what to do next; orchestration sagas use a central state machine (the orchestrator) to command each step. Orchestration is easier to reason about and debug for complex flows; choreography is simpler for short, linear flows. Neither provides the atomicity of ACID transactions — a saga is eventually consistent.

## Detailed Explanation

### Why Sagas?

2PC (two-phase commit) provides atomicity across services but requires all participants to be available simultaneously — impractical in a microservices system where services deploy and fail independently. A saga trades atomicity for availability: each service commits its local transaction immediately, and failures are recovered by running compensating transactions (undo operations) in reverse order.

### Choreography vs Orchestration

| | Choreography | Orchestration |
|--|-------------|--------------|
| Coordinator | None — events trigger reactions | Central saga orchestrator |
| Coupling | Services know what events to react to | Services only know their own step |
| Observability | Hard — flow spans many event handlers | Easy — state machine shows current step |
| Complexity | Grows with number of steps | Contained in the state machine |
| Failure handling | Each service handles its own compensation | Orchestrator directs compensation |
| Good for | 2–3 step linear flows | 4+ step complex flows |

### Choreography Saga Example

```
OrderService  → publishes OrderCreated
InventoryService ← listens to OrderCreated → reserves stock → publishes StockReserved
PaymentService   ← listens to StockReserved → charges card → publishes PaymentCharged
ShippingService  ← listens to PaymentCharged → creates shipment

On failure:
PaymentService fails → publishes PaymentFailed
InventoryService ← listens to PaymentFailed → releases stock (compensation)
OrderService     ← listens to StockReleaseFailed / eventually → cancels order
```

Problem: to understand the full flow, you must trace events across services. Adding a new step (e.g., fraud check) requires modifying multiple services.

### Orchestration Saga (MassTransit State Machine)

MassTransit's `MassTransitStateMachine<T>` provides a first-class saga orchestrator:

```csharp
// Saga state — persisted to DB between steps
public sealed class OrderSagaState : SagaStateMachineInstance
{
    public Guid CorrelationId { get; set; }
    public string CurrentState { get; set; } = default!;
    public Guid OrderId { get; set; }
    public Guid CustomerId { get; set; }
    public decimal TotalAmount { get; set; }

    // Track what to compensate
    public bool StockReserved { get; set; }
    public bool PaymentCharged { get; set; }
}

// State machine — defines the flow and compensations
public sealed class OrderSaga : MassTransitStateMachine<OrderSagaState>
{
    public State ReservingStock  { get; private set; } = default!;
    public State ChargingPayment { get; private set; } = default!;
    public State Completing      { get; private set; } = default!;
    public State Failed          { get; private set; } = default!;

    public Event<OrderCreated>        OrderCreated       { get; private set; } = default!;
    public Event<StockReserved>       StockReserved      { get; private set; } = default!;
    public Event<StockReservationFailed> StockFailed     { get; private set; } = default!;
    public Event<PaymentCharged>      PaymentCharged     { get; private set; } = default!;
    public Event<PaymentFailed>       PaymentFailed      { get; private set; } = default!;

    public OrderSaga()
    {
        InstanceState(x => x.CurrentState);
        Event(() => OrderCreated,   e => e.CorrelateById(m => m.Message.OrderId));
        Event(() => StockReserved,  e => e.CorrelateById(m => m.Message.OrderId));
        Event(() => StockFailed,    e => e.CorrelateById(m => m.Message.OrderId));
        Event(() => PaymentCharged, e => e.CorrelateById(m => m.Message.OrderId));
        Event(() => PaymentFailed,  e => e.CorrelateById(m => m.Message.OrderId));

        // Step 1: OrderCreated → send ReserveStock command
        Initially(
            When(OrderCreated)
                .Then(ctx =>
                {
                    ctx.Saga.OrderId      = ctx.Message.OrderId;
                    ctx.Saga.CustomerId   = ctx.Message.CustomerId;
                    ctx.Saga.TotalAmount  = ctx.Message.TotalAmount;
                })
                .Send(ctx => new Uri("queue:inventory"), ctx => new ReserveStockCommand
                {
                    OrderId  = ctx.Saga.OrderId,
                    Items    = ctx.Message.Items,
                })
                .TransitionTo(ReservingStock));

        // Step 2: Stock reserved → charge payment
        During(ReservingStock,
            When(StockReserved)
                .Then(ctx => ctx.Saga.StockReserved = true)
                .Send(ctx => new Uri("queue:payments"), ctx => new ChargePaymentCommand
                {
                    OrderId    = ctx.Saga.OrderId,
                    CustomerId = ctx.Saga.CustomerId,
                    Amount     = ctx.Saga.TotalAmount,
                })
                .TransitionTo(ChargingPayment),

            // Compensation path: stock reservation failed → cancel order
            When(StockFailed)
                .Publish(ctx => new OrderCancelled { OrderId = ctx.Saga.OrderId, Reason = "OutOfStock" })
                .TransitionTo(Failed));

        // Step 3: Payment charged → complete order
        During(ChargingPayment,
            When(PaymentCharged)
                .Then(ctx => ctx.Saga.PaymentCharged = true)
                .Publish(ctx => new OrderConfirmed { OrderId = ctx.Saga.OrderId })
                .TransitionTo(Completing)
                .Finalize(),

            // Compensation path: payment failed → release stock, cancel order
            When(PaymentFailed)
                .Send(ctx => new Uri("queue:inventory"), ctx => new ReleaseStockCommand
                {
                    OrderId = ctx.Saga.OrderId,
                })
                .Publish(ctx => new OrderCancelled { OrderId = ctx.Saga.OrderId, Reason = "PaymentFailed" })
                .TransitionTo(Failed)
                .Finalize());

        SetCompletedWhenFinalized();  // clean up state from DB on Finalized state
    }
}
```

### Registering the Saga with MassTransit

```csharp
builder.Services.AddMassTransit(mt =>
{
    mt.AddSagaStateMachine<OrderSaga, OrderSagaState>()
        .EntityFrameworkRepository(r =>
        {
            r.ExistingDbContext<AppDbContext>();
            r.UsePostgres();
            r.LockStatementProvider = new PostgresLockStatementProvider(); // optimistic locking
        });

    mt.UsingAzureServiceBus((ctx, asb) =>
    {
        asb.Host(connStr);
        asb.ConfigureEndpoints(ctx);
    });
});

// EF Core: saga state table
builder.Services.AddDbContext<AppDbContext>(o => o.UseNpgsql(connStr));

// In AppDbContext.OnModelCreating:
// modelBuilder.AddInboxStateEntity();
// modelBuilder.AddOutboxMessageEntity();
// modelBuilder.AddOutboxStateEntity();
// modelBuilder.AddSagaClassMap<OrderSagaState>();
```

### Compensating Transactions

A compensating transaction is the business-level undo of a completed step. Compensations are **not** rollbacks — they are new forward-moving transactions that reverse the effect:

| Forward step | Compensating step |
|-------------|------------------|
| Reserve 10 units of inventory | Release 10 units of inventory |
| Charge customer $100 | Refund customer $100 |
| Create shipment | Cancel shipment |
| Send order confirmation email | Send order cancellation email |

> **Warning:** Compensation is not always possible. If the order confirmation email has already been sent, you can't "unsend" it — only send a follow-up cancellation email. Design compensations for every forward step before implementing the saga; some steps may be "pivot transactions" after which compensation is impossible (e.g., physical goods dispatched). Identify the pivot transaction and design to prevent failures after it.

### Saga vs 2PC Consistency

| | 2PC | Saga |
|--|-----|------|
| Atomicity | All-or-nothing | Steps commit independently |
| Consistency window | Instant (or never) | Temporary inconsistency between steps |
| Availability | Low (all services must be available simultaneously) | High (services work independently) |
| Failure recovery | Automatic rollback | Explicit compensating transactions |
| Complexity | Protocol complexity | Business logic complexity |

## Code Example

```csharp
// Idempotent consumer for saga step — handles re-delivery safely
public sealed class ReserveStockConsumer(IInventoryService inventory)
    : IConsumer<ReserveStockCommand>
{
    public async Task Consume(ConsumeContext<ReserveStockCommand> ctx)
    {
        var cmd = ctx.Message;

        // Idempotency check — if already reserved for this order, don't double-reserve
        var existing = await inventory.GetReservationAsync(cmd.OrderId, ctx.CancellationToken);
        if (existing is not null)
        {
            // Already processed — publish success event so saga advances
            await ctx.Publish(new StockReserved { OrderId = cmd.OrderId });
            return;
        }

        var success = await inventory.TryReserveAsync(cmd.OrderId, cmd.Items, ctx.CancellationToken);

        if (success)
            await ctx.Publish(new StockReserved { OrderId = cmd.OrderId });
        else
            await ctx.Publish(new StockReservationFailed { OrderId = cmd.OrderId, Reason = "InsufficientStock" });
    }
}
```

## Common Follow-up Questions

- How do you handle a saga that times out (e.g., the inventory service never responds)?
- How do you replay a saga from a specific state for debugging or data correction?
- What is the difference between MassTransit's Saga and its Routing Slip (Process Manager) pattern?
- How do you query the current state of a saga (e.g., for a customer support screen)?
- What happens if the orchestrator's state store is unavailable — how do you design for that?

## Common Mistakes / Pitfalls

- **Non-idempotent saga steps**: a message may be redelivered if the consumer crashes after processing but before committing the offset; every saga step must be idempotent.
- **No timeout handling**: if a downstream service never responds, the saga waits forever; add a `Schedule` to time out after N minutes and trigger compensation.
- **Compensation that assumes forward-step data is still valid**: by the time compensation runs, the original data may have changed; snapshot the necessary data in the saga state at each step.
- **Long-running sagas without checkpoints**: if a 10-step saga fails at step 9, all 9 compensations must run in order; consider breaking very long sagas into sub-sagas.
- **Using choreography for complex flows**: as the number of steps grows, choreography becomes impossible to trace and debug; switch to orchestration at 4+ steps.

## References

- [Saga pattern — Microsoft Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga)
- [MassTransit Saga State Machines](https://masstransit.io/documentation/patterns/saga/state-machine)
- [Distributed transactions — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/multi-container-microservice-net-applications/implement-ddd-microservices)
- [See: distributed-transactions.md](./distributed-transactions.md)
- [See: outbox-pattern.md](./outbox-pattern.md)
- [See: event-driven-architecture.md](./event-driven-architecture.md)
