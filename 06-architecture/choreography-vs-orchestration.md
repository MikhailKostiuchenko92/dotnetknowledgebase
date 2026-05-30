# Choreography vs Orchestration

**Category:** Architecture / Microservices
**Difficulty:** 🔴 Senior
**Tags:** `choreography`, `orchestration`, `saga`, `coupling`, `visibility`, `event-driven`, `process-manager`

## Question

> What is the difference between saga choreography and saga orchestration? When does choreography become problematic, and when does an orchestrator provide clarity? Compare the coupling and observability trade-offs.

## Short Answer

**Choreography**: services react to events from each other — no central coordinator; each service publishes events and others respond. **Orchestration**: a central process manager (orchestrator/saga) knows all steps and explicitly commands each service. Choreography has low coupling but poor workflow visibility — hard to track what stage a workflow is at. Orchestration has higher coupling (orchestrator knows all participants) but excellent visibility and clear compensation logic. Use choreography for simple linear flows; use orchestration for complex, branching workflows with many failure paths.

## Detailed Explanation

### Choreography

```
OrderService: publishes OrderSubmittedEvent
    ↓
InventoryService: consumes → publishes StockReservedEvent
    ↓
PaymentService: consumes → publishes PaymentCapturedEvent
    ↓
ShippingService: consumes → publishes ShipmentCreatedEvent
    ↓
NotificationService: consumes → sends confirmation email
```

```csharp
// InventoryService: purely reactive
public class ReserveStockHandler : IConsumer<OrderSubmittedEvent>
{
    public async Task Consume(ConsumeContext<OrderSubmittedEvent> ctx)
    {
        var success = await _inventory.TryReserveAsync(ctx.Message.Lines, ctx.CancellationToken);
        if (success)
            await ctx.Publish(new StockReservedEvent(ctx.Message.OrderId));
        else
            await ctx.Publish(new StockReservationFailedEvent(ctx.Message.OrderId, "Out of stock"));
        // ← InventoryService doesn't know about PaymentService, ShippingService
        // Loose coupling, but: who is responsible for the overall workflow state?
    }
}

// OrderService: must handle the cascade failure
public class HandleStockFailedHandler : IConsumer<StockReservationFailedEvent>
{
    public async Task Consume(ConsumeContext<StockReservationFailedEvent> ctx)
        => await _orders.CancelAsync(ctx.Message.OrderId, "Stock unavailable", ctx.CancellationToken);
}
```

**Choreography problems with complexity**:
```
Branching: if StockReserved AND credit check OK → proceed; if credit fails → only release stock (not other compensations)
   → Where is this logic? Split across InventoryService and CreditService — invisible from code
   
Debugging: "Why was this order never shipped?"
   → Must trace events across 5 services in distributed tracing — no single place to look
```

### Orchestration

```csharp
// Central saga orchestrator: explicit steps and state
public class OrderSaga : MassTransitStateMachine<OrderSagaState>
{
    public State WaitingForStock { get; private set; } = null!;
    public State WaitingForPayment { get; private set; } = null!;
    public State Completed { get; private set; } = null!;
    public State Failed { get; private set; } = null!;

    public Event<OrderSubmittedEvent> OrderSubmitted { get; private set; } = null!;
    public Event<StockReservedEvent> StockReserved { get; private set; } = null!;
    public Event<PaymentCapturedEvent> PaymentCaptured { get; private set; } = null!;
    public Event<StockReservationFailedEvent> StockFailed { get; private set; } = null!;

    public OrderSaga()
    {
        InstanceState(x => x.CurrentState);

        // Correlate all events by OrderId
        Event(() => OrderSubmitted, x => x.CorrelateById(m => m.Message.OrderId));
        Event(() => StockReserved,  x => x.CorrelateById(m => m.Message.OrderId));
        Event(() => StockFailed,    x => x.CorrelateById(m => m.Message.OrderId));
        Event(() => PaymentCaptured, x => x.CorrelateById(m => m.Message.OrderId));

        Initially(
            When(OrderSubmitted)
                .Send(new Uri("queue:reserve-stock"),
                    ctx => new ReserveStockCommand(ctx.Message.OrderId, ctx.Message.Lines))
                .TransitionTo(WaitingForStock));

        During(WaitingForStock,
            When(StockReserved)
                .Send(new Uri("queue:capture-payment"),
                    ctx => new CapturePaymentCommand(ctx.Saga.OrderId, ctx.Saga.Total))
                .TransitionTo(WaitingForPayment),
            When(StockFailed)
                .Send(new Uri("queue:cancel-order"),
                    ctx => new CancelOrderCommand(ctx.Saga.OrderId, "Stock unavailable"))
                .TransitionTo(Failed));

        During(WaitingForPayment,
            When(PaymentCaptured)
                .TransitionTo(Completed));
    }
}
```

### Comparison

| | Choreography | Orchestration |
|--|-------------|--------------|
| **Coupling** | Low — services don't know each other | Higher — orchestrator knows all steps |
| **Workflow visibility** | Poor — distributed across services | Clear — single state machine |
| **Failure handling** | Each service handles its own compensations | Orchestrator controls all compensations |
| **Debugging** | Hard — distributed tracing required | Easy — check saga state |
| **Testing** | Each service tested in isolation | Saga state machine requires integration test |
| **Complexity limit** | Simple linear flows | Branching, conditional, long-running workflows |
| **Team independence** | High — teams only know their events | Lower — orchestrator team must know all |

## Code Example

```csharp
// Hybrid approach: choreography for notifications (loose coupling fine)
// Orchestration for the core order flow (compensations matter)

// Core order workflow: orchestrated saga (needs full compensation visibility)
public class OrderFulfillmentSaga : MassTransitStateMachine<OrderFulfillmentState> { /* ... */ }

// Side effects: choreography (email, analytics — fire and forget, no compensation needed)
public class SendConfirmationEmail : IConsumer<OrderCompletedEvent>
{
    public Task Consume(ConsumeContext<OrderCompletedEvent> ctx)
        => _emailService.SendConfirmationAsync(ctx.Message.CustomerId, ctx.Message.OrderId);
}

// ↑ No compensation needed if email fails — don't orchestrate this
```

## Common Follow-up Questions

- How do you implement saga timeouts — what happens if a step doesn't complete within 10 minutes?
- How do you test saga state transitions without a real message bus?
- What is a "process manager" vs a "saga" — is there a meaningful distinction?
- How do you monitor saga health in production — how do you know a saga is stuck?
- What happens to in-flight sagas during a deployment?

## Common Mistakes / Pitfalls

- **Using choreography for multi-branch workflows**: when a failure in step 3 must compensate steps 1 and 2 but NOT step 4 (which ran in parallel), choreography becomes a tangled web of condition checks across services.
- **Orchestrator knowing about service internals**: the orchestrator should send commands and receive events — it should not know HOW inventory reserves stock, only THAT it should.
- **No saga state persistence**: in-memory saga state is lost on process restart. Always persist saga state to a DB with optimistic concurrency.
- **"Distributed monolith" through orchestration**: an orchestrator that calls services synchronously (request/response) rather than via async commands/events is just a distributed monolith with extra steps.

## References

- [Saga pattern orchestration vs choreography — Microsoft](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga)
- [MassTransit Saga State Machine](https://masstransit.io/documentation/configuration/sagas/state-machine)
- [See: distributed-transaction-patterns.md](./distributed-transaction-patterns.md)
- [See: inter-service-communication.md](./inter-service-communication.md)
