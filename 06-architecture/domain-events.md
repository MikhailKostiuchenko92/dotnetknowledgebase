# Domain Events

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `domain-events`, `aggregate`, `MediatR`, `INotification`, `eventual-consistency`, `application-layer`

## Question

> What are domain events in DDD? How do you raise them inside an aggregate and dispatch them in the application layer using MediatR? What is the difference between domain events and integration events?

## Short Answer

A **domain event** is something meaningful that happened in the domain — expressed in past tense from the domain expert's vocabulary: `OrderSubmitted`, `PaymentFailed`, `CustomerUpgraded`. Aggregates raise domain events internally by adding them to a collection; the application layer (or a `SaveChangesAsync` interceptor) dispatches them after the transaction commits. Domain events are **in-process** and synchronous or asynchronous within the same bounded context. **Integration events** are published to a message broker for cross-context communication — a domain event is often the origin of an integration event, but they are separate concepts.

## Detailed Explanation

### Domain Event Anatomy

```csharp
// Base type — no dependencies, lives in Domain layer
public abstract record DomainEvent
{
    public DateTime OccurredAt { get; } = DateTime.UtcNow;
    public Guid EventId { get; } = Guid.NewGuid();
}

// Specific events — named in past tense, contain all context needed by handlers
public record OrderSubmittedEvent(
    OrderId OrderId,
    CustomerId CustomerId,
    Money Total,
    int LineCount) : DomainEvent;

public record OrderCancelledEvent(
    OrderId OrderId,
    CustomerId CustomerId,
    string Reason) : DomainEvent;
```

### Raising Events Inside the Aggregate

The aggregate collects events; it never dispatches them directly (no DI, no message bus in Domain):

```csharp
public abstract class AggregateRoot
{
    private readonly List<DomainEvent> _events = [];
    public IReadOnlyList<DomainEvent> DomainEvents => _events;

    protected void Raise(DomainEvent @event) => _events.Add(@event);
    public void ClearDomainEvents() => _events.Clear();
}

public class Order : AggregateRoot
{
    public void Submit()
    {
        if (!Lines.Any()) throw new InvalidOperationException("Empty order.");
        if (Status != OrderStatus.Draft) throw new InvalidOperationException();

        Status = OrderStatus.Submitted;

        // Raise — does NOT dispatch; just queues in memory
        Raise(new OrderSubmittedEvent(Id, CustomerId, Total, Lines.Count));
    }

    public void Cancel(string reason)
    {
        Status = OrderStatus.Cancelled;
        Raise(new OrderCancelledEvent(Id, CustomerId, reason));
    }
}
```

### Dispatching After SaveChanges (Recommended Pattern)

Dispatch events AFTER the transaction commits — otherwise a handler might act on an event for data not yet persisted:

```csharp
// EF Core SaveChanges interceptor — dispatches events after successful save
public class DomainEventDispatcher(IMediator mediator) : SaveChangesInterceptor
{
    public override async ValueTask<int> SavedChangesAsync(
        SaveChangesCompletedEventData eventData,
        int result,
        CancellationToken ct)
    {
        var db = eventData.Context;
        if (db is null) return result;

        var aggregates = db.ChangeTracker.Entries<AggregateRoot>()
            .Select(e => e.Entity)
            .Where(a => a.DomainEvents.Any())
            .ToList();

        var events = aggregates.SelectMany(a => a.DomainEvents).ToList();
        aggregates.ForEach(a => a.ClearDomainEvents());

        foreach (var domainEvent in events)
            await mediator.Publish(domainEvent, ct);

        return result;
    }
}

// Register in DI:
services.AddScoped<DomainEventDispatcher>();
services.AddDbContext<AppDbContext>((sp, options) =>
    options.UseSqlServer(connectionString)
           .AddInterceptors(sp.GetRequiredService<DomainEventDispatcher>()));
```

### MediatR Domain Event Handler

```csharp
// MediatR: domain event implements INotification for fan-out (multiple handlers)
public record OrderSubmittedEvent(...) : DomainEvent, INotification;

// Handler 1: Send confirmation email
public class SendOrderConfirmationEmail(IEmailSender email)
    : INotificationHandler<OrderSubmittedEvent>
{
    public Task Handle(OrderSubmittedEvent notification, CancellationToken ct)
        => email.SendOrderConfirmationAsync(notification.CustomerId, notification.OrderId, ct);
}

// Handler 2: Reserve inventory  
public class ReserveInventoryOnOrderSubmitted(IInventoryService inventory)
    : INotificationHandler<OrderSubmittedEvent>
{
    public Task Handle(OrderSubmittedEvent notification, CancellationToken ct)
        => inventory.ReserveForOrderAsync(notification.OrderId, ct);
}
```

### Domain Events vs Integration Events

| Aspect | Domain Event | Integration Event |
|--------|-------------|-------------------|
| **Scope** | Within a single bounded context | Cross-context (microservice-to-microservice) |
| **Transport** | In-process (memory / MediatR) | Message broker (RabbitMQ, Azure Service Bus) |
| **Timing** | During or after the transaction | After transaction commits (via Outbox) |
| **Serialization** | Not required | Required (JSON, Avro, Protobuf) |
| **Schema versioning** | Not needed | Critical — consumers must handle old versions |
| **Retry** | Application-level | At-least-once by broker |
| **Example** | `OrderSubmittedEvent` in Orders context | `OrderConfirmedIntegrationEvent` published to Shipping context |

A common pattern: the domain event handler publishes an integration event to the outbox:

```csharp
public class PublishOrderIntegrationEvent(IOutboxService outbox)
    : INotificationHandler<OrderSubmittedEvent>
{
    public Task Handle(OrderSubmittedEvent e, CancellationToken ct)
        => outbox.PublishAsync(new OrderConfirmedIntegrationEvent(
            e.OrderId.Value, e.Total.Amount, e.Total.Currency), ct);
}
```

## Code Example

```csharp
// End-to-end flow: command → aggregate method → domain event → handler
// 1. Handler submits order
public class SubmitOrderHandler(IOrderRepository orders) 
    : IRequestHandler<SubmitOrderCommand>
{
    public async Task Handle(SubmitOrderCommand cmd, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(cmd.OrderId, ct)
            ?? throw new NotFoundException(nameof(Order), cmd.OrderId);

        order.Submit(); // ← raises OrderSubmittedEvent internally

        await orders.SaveAsync(order, ct);
        // SaveChangesAsync interceptor dispatches OrderSubmittedEvent here
        // → SendOrderConfirmationEmail.Handle(...)
        // → ReserveInventoryOnOrderSubmitted.Handle(...)
    }
}
```

## Common Follow-up Questions

- Should domain event handlers run in the same transaction as the aggregate change?
- How do you handle domain event handler failures — retry, dead letter, compensate?
- What is the Outbox pattern, and why do domain events need it for cross-context reliability?
- How do you test aggregates that raise domain events without a full MediatR pipeline?
- What is the difference between `mediator.Send()` (command) and `mediator.Publish()` (event)?

## Common Mistakes / Pitfalls

- **Dispatching domain events before `SaveChanges`**: if the handler sends an email before the transaction commits, and the commit fails, the email is sent for an order that doesn't exist.
- **Using domain events for cross-context integration**: a domain event inside the Orders context should not be subscribed to by the Shipping context directly. Publish an integration event via the Outbox instead.
- **Including infrastructure types in domain events**: a `DomainEvent` record that holds `HttpRequestMessage`, `SqlConnection`, or EF Core entities violates domain purity.
- **Forgetting to clear events after dispatch**: if `ClearDomainEvents()` is not called, the next `SaveChanges` in the same request will re-dispatch the same events.

## References

- [Domain Events in EF Core — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation)
- [MediatR INotification — GitHub](https://github.com/jbogard/MediatR/wiki)
- [See: aggregate-design.md](./aggregate-design.md)
- [See: outbox-pattern-architecture.md](./outbox-pattern-architecture.md)
- [See: cqrs-and-ddd.md](./cqrs-and-ddd.md)
