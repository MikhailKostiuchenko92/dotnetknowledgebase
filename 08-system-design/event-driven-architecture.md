# Event-Driven Architecture

**Category:** System Design / Messaging
**Difficulty:** 🔴 Senior
**Tags:** `event-driven`, `EDA`, `domain-events`, `integration-events`, `choreography`, `orchestration`, `event-sourcing`, `MassTransit`, `loose-coupling`

## Question

> What is Event-Driven Architecture (EDA)? What distinguishes domain events from integration events, choreography from orchestration, and when does EDA create more problems than it solves?

## Short Answer

Event-Driven Architecture is a style where components communicate by publishing and reacting to events — facts that something happened. **Domain events** are in-process notifications within a bounded context (e.g., `OrderConfirmed` raised inside the Order aggregate). **Integration events** cross service/process boundaries via a message broker (e.g., `OrderPlaced` published to Kafka for Payment and Inventory services). **Choreography** lets services react independently to events with no central coordinator; **orchestration** uses a central process (Saga) that sends commands and awaits responses. EDA excels at loose coupling and scalability but introduces eventual consistency, distributed tracing complexity, and difficult debugging.

## Detailed Explanation

### Domain Events vs Integration Events

| Aspect | Domain Event | Integration Event |
|--------|-------------|------------------|
| Scope | Within one bounded context / service | Across services / process boundary |
| Transport | In-process dispatch (MediatR) | Message broker (RabbitMQ, Kafka, Service Bus) |
| Timing | Synchronous within the same request | Asynchronous; possibly minutes later |
| Failure | Exception propagates in same transaction | At-least-once delivery; consumer may fail independently |
| Example | `OrderConfirmed` → update stock in same service | `OrderPlaced` → Payment Service processes payment |
| Schema contract | Internal; can change freely | Shared contract; breaking changes require versioning |

Domain events are raised inside aggregates and dispatched in-process (often via MediatR's `INotificationHandler`). They are part of the DDD tactical patterns.

Integration events are stored in the Outbox and published to a broker. They cross the service boundary and must be versioned carefully.

[See: outbox-pattern.md](./outbox-pattern.md)

### Choreography

In choreography, each service listens for events and reacts independently. There is no central coordinator.

```
OrderService publishes → OrderPlaced
  PaymentService subscribes → publishes → PaymentProcessed
    InventoryService subscribes → publishes → StockReserved
      ShippingService subscribes → creates shipment
```

**Pros**:
- Maximum autonomy: each service can evolve independently.
- No single point of failure in coordination.
- Natural fit for Kafka streams.

**Cons**:
- Difficult to understand the overall business process ("which service does what?").
- Hard to track progress of a single order across all steps.
- Handling failures and compensations requires each service to listen for failure events.
- Circular event chains possible (A triggers B triggers A).

### Orchestration (Saga)

An orchestrator (central process) sends commands to services and awaits results:

```
OrderSaga:
  1. Send ProcessPayment → await PaymentProcessed / PaymentFailed
  2. Send ReserveStock   → await StockReserved / StockFailed
  3. Send CreateShipment → await ShipmentCreated

On failure at step 2: Send RefundPayment (compensation)
```

**Pros**:
- Business logic is centralised and readable.
- Easy to implement compensating transactions (rollback).
- Clear visibility into order state.

**Cons**:
- Orchestrator is a central coordination point — a coupling point and potential bottleneck.
- Harder to scale the orchestrator independently.

**MassTransit Saga** (state machine) is the .NET-idiomatic approach to orchestration.

### When EDA Hurts

EDA is not always the right choice:

| Scenario | Problem |
|----------|---------|
| Synchronous user-facing requests | "Place order and return an order ID" — async EDA adds unnecessary complexity. Use synchronous HTTP |
| Small team / monolith | EDA over-engineers cross-service communication that doesn't exist yet |
| Strict consistency required | "Debit account and credit another atomically" — eventual consistency isn't acceptable; use 2PC or Saga with compensation |
| Simple CRUD | Adding events for every entity change adds overhead without benefit |
| Read-heavy with no reactions needed | If nobody subscribes to events, there's no benefit to publishing them |

> **Rule of thumb**: introduce EDA when you have genuine temporal decoupling needs (consumer can be down), fan-out to multiple services, or need to decouple services that would otherwise create circular dependencies.

### Event Schema Evolution

Integration events are shared contracts. Breaking changes require careful versioning:

- **Additive change** (new optional field): safe; existing consumers ignore unknown fields.
- **Renaming a field**: breaking — use a versioned event type (`OrderPlacedV2`).
- **Removing a field**: breaking — deprecate with a long sunset period.

Schema registries (Confluent Schema Registry, Azure Schema Registry) enforce backward/forward compatibility.

### Observability in EDA

Events make debugging harder — a request "disappears" into the message bus. Requirements:

- **Correlation ID**: propagate through all events in a workflow.
- **Distributed tracing**: OpenTelemetry spans crossing broker boundaries (W3C TraceContext propagated in message headers).
- **Event log**: store all events for replay and debugging.
- **Saga state**: observable current state of long-running workflows.

## Code Example

```csharp
// ASP.NET Core 8 — Domain events (in-process) + Integration events (broker)
// with MassTransit Saga for orchestration

using MassTransit;
using MediatR;

// ══ DOMAIN EVENTS (in-process via MediatR) ═══════════════════════════

// Raised inside the Order aggregate
public record OrderConfirmedDomainEvent(Guid OrderId, decimal Amount) : INotification;

// In-process handler: sync, same transaction
public sealed class OrderConfirmedHandler(
    AppDbContext db,
    ILogger<OrderConfirmedHandler> log)
    : INotificationHandler<OrderConfirmedDomainEvent>
{
    public async Task Handle(OrderConfirmedDomainEvent evt, CancellationToken ct)
    {
        log.LogInformation("Domain event: order {Id} confirmed", evt.OrderId);
        // Write to outbox in the same DB transaction
        db.Outbox.Add(new OutboxMessage
        {
            Type    = "OrderPlaced",
            Payload = System.Text.Json.JsonSerializer.Serialize(
                new OrderPlaced(evt.OrderId, evt.Amount))
        });
        await db.SaveChangesAsync(ct);
    }
}

// ══ INTEGRATION EVENTS (cross-service via MassTransit) ════════════════

record OrderPlaced(Guid OrderId, decimal Amount);
record PaymentProcessed(Guid OrderId, string TransactionId);
record PaymentFailed(Guid OrderId, string Reason);
record StockReserved(Guid OrderId);
record StockFailed(Guid OrderId, string Reason);

// ══ ORCHESTRATION: MassTransit Saga (state machine) ══════════════════

public class OrderState : SagaStateMachineInstance
{
    public Guid CorrelationId { get; set; }   // = OrderId
    public string CurrentState  { get; set; } = "";
    public string? TransactionId { get; set; }
}

public sealed class OrderStateMachine : MassTransitStateMachine<OrderState>
{
    public State Submitted   { get; private set; } = null!;
    public State PaymentDone { get; private set; } = null!;
    public State Completed   { get; private set; } = null!;
    public State Failed      { get; private set; } = null!;

    public Event<OrderPlaced>       OrderPlaced       { get; private set; } = null!;
    public Event<PaymentProcessed>  PaymentProcessed  { get; private set; } = null!;
    public Event<PaymentFailed>     PaymentFailed     { get; private set; } = null!;
    public Event<StockReserved>     StockReserved     { get; private set; } = null!;
    public Event<StockFailed>       StockFailed       { get; private set; } = null!;

    public OrderStateMachine()
    {
        InstanceState(x => x.CurrentState);

        Event(() => OrderPlaced,
            e => e.CorrelateById(ctx => ctx.Message.OrderId));
        Event(() => PaymentProcessed,
            e => e.CorrelateById(ctx => ctx.Message.OrderId));
        Event(() => PaymentFailed,
            e => e.CorrelateById(ctx => ctx.Message.OrderId));
        Event(() => StockReserved,
            e => e.CorrelateById(ctx => ctx.Message.OrderId));
        Event(() => StockFailed,
            e => e.CorrelateById(ctx => ctx.Message.OrderId));

        Initially(
            When(OrderPlaced)
                .Then(ctx => ctx.Saga.CorrelationId = ctx.Message.OrderId)
                .Send(new Uri("queue:payment-service"),
                    ctx => new ProcessPayment(ctx.Message.OrderId, ctx.Message.Amount))
                .TransitionTo(Submitted));

        During(Submitted,
            When(PaymentProcessed)
                .Then(ctx => ctx.Saga.TransactionId = ctx.Message.TransactionId)
                .Send(new Uri("queue:inventory-service"),
                    ctx => new ReserveStock(ctx.Message.OrderId))
                .TransitionTo(PaymentDone),
            When(PaymentFailed)
                .Then(ctx => Console.WriteLine($"Payment failed: {ctx.Message.Reason}"))
                .TransitionTo(Failed));

        During(PaymentDone,
            When(StockReserved)
                .TransitionTo(Completed)
                .Finalize(),
            When(StockFailed)
                .Send(new Uri("queue:payment-service"),
                    ctx => new RefundPayment(ctx.Message.OrderId, ctx.Saga.TransactionId!))
                .TransitionTo(Failed));
    }
}

record ProcessPayment(Guid OrderId, decimal Amount);
record ReserveStock(Guid OrderId);
record RefundPayment(Guid OrderId, string TransactionId);

// ── Placeholder DbContext ─────────────────────────────────────────────
public class AppDbContext(Microsoft.EntityFrameworkCore.DbContextOptions<AppDbContext> opts)
    : Microsoft.EntityFrameworkCore.DbContext(opts)
{
    public Microsoft.EntityFrameworkCore.DbSet<OutboxMessage> Outbox =>
        Set<OutboxMessage>();
}
public class OutboxMessage { public Guid Id { get; set; } public string Type { get; set; } = ""; public string Payload { get; set; } = ""; }
```

## Common Follow-up Questions

- How do you handle a Saga that has been waiting for a response for 24 hours and the downstream service never replied?
- How do you test an event-driven system — what does a good integration test for a choreography flow look like?
- What is the "event carried state transfer" pattern, and when is it preferable to fetching state from the source service?
- How do you version integration events when you have 10 consumers that need to migrate at different speeds?
- What is the difference between an event, a command, and a query in the context of CQRS + EDA?
- How does MassTransit's `Quartz` scheduler integration help with Saga timeouts?

## Common Mistakes / Pitfalls

- **Domain events published directly to the broker (no Outbox)**: if the broker publish fails after the DB commit, some services miss the event. Always use the Outbox pattern for integration events.
- **Tight coupling through event schema**: treating integration events as "internal DTOs" and sharing domain entity properties causes consumers to depend on implementation details. Design events as public API — include only what consumers need.
- **Choreography without event observability**: a chain of 6 events across 6 services with no correlation ID is impossible to debug. Always propagate a correlation ID (or OpenTelemetry trace context) through all events.
- **Saga state machine not persisted**: a Saga is a long-running process. If the saga state is in-memory only, it's lost on restart. Use EF Core or Redis to persist saga state.
- **Handling all errors with compensation**: some errors mean "invalid request" (bad input), not "process failed and needs rollback." Sending a compensation command for a validation error may cause nonsensical state. Distinguish between technical failures and business failures.
- **No timeout on Saga awaiting a response**: if a downstream service never replies to a command sent in step 2, the Saga waits forever. Always add a timeout event and handle it explicitly (retry command, alert, or transition to a "stuck" state).

## References

- [MassTransit — Saga state machine](https://masstransit.io/documentation/patterns/saga/state-machine)
- [Designing event-driven systems — Ben Stopford (Confluent)](https://www.confluent.io/designing-event-driven-systems/) (verify URL)
- [microservices.io — Saga pattern](https://microservices.io/patterns/data/saga.html)
- [See: distributed-transactions.md](./distributed-transactions.md) — 2PC and Saga choreography
- [See: outbox-pattern.md](./outbox-pattern.md) — reliable integration event publishing
