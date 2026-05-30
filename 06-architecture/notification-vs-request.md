# Notification vs Request in MediatR

**Category:** Architecture / Mediator & Pipeline
**Difficulty:** 🟡 Middle
**Tags:** `MediatR`, `INotification`, `IRequest`, `publish`, `send`, `fan-out`, `domain-events`, `integration-events`

## Question

> What is the difference between `IRequest` / `ISender.Send()` and `INotification` / `IPublisher.Publish()` in MediatR? When should you use each, and how do notifications relate to domain events?

## Short Answer

`IRequest` + `ISender.Send()` is **one-to-one**: exactly one `IRequestHandler<>` handles the request and returns a result. Used for commands and queries where a single piece of logic is responsible. `INotification` + `IPublisher.Publish()` is **fan-out**: zero or more `INotificationHandler<T>` handlers receive the notification — no result returned. Used for in-process event dispatch, especially domain events after a command completes. The key difference: `Send()` requires exactly one handler (throws if missing); `Publish()` succeeds with zero handlers.

## Detailed Explanation

### Send: One Handler, One Result

```csharp
// IRequest<TResult>: single handler required, returns a value
public record PlaceOrderCommand(int CustomerId, decimal Total) : IRequest<int>;

// Exactly one IRequestHandler<PlaceOrderCommand, int> must be registered
// If zero: MediatR throws InvalidOperationException
// If two: undefined behavior (last registered wins)

var orderId = await sender.Send(new PlaceOrderCommand(7, 99.99m), ct);
// ↑ Returns: int (the new order ID)
```

### Publish: Fan-Out, No Result

```csharp
// INotification: any number of handlers (0..n)
public record OrderSubmittedNotification(int OrderId, int CustomerId) : INotification;

// Handler 1 — optional, not required
public class SendConfirmationEmail : INotificationHandler<OrderSubmittedNotification>
{
    public Task Handle(OrderSubmittedNotification n, CancellationToken ct)
        => _email.SendAsync(n.CustomerId, n.OrderId, ct);
}

// Handler 2 — also optional
public class UpdateAnalytics : INotificationHandler<OrderSubmittedNotification>
{
    public Task Handle(OrderSubmittedNotification n, CancellationToken ct)
        => _analytics.TrackAsync(n.OrderId, ct);
}

await publisher.Publish(new OrderSubmittedNotification(42, 7), ct);
// ↑ Both handlers called; if zero handlers registered — silently succeeds
```

### Domain Events via Notifications

The most common use case for `INotification`: dispatch domain events after a command completes:

```csharp
// Domain event raised inside aggregate
public class Order : AggregateRoot
{
    public void Submit()
    {
        Status = OrderStatus.Submitted;
        Raise(new OrderSubmittedEvent(Id, CustomerId, Total)); // ← domain event
    }
}

// Application layer: dispatch domain events as MediatR notifications after SaveChanges
public class DomainEventDispatcherInterceptor(IPublisher publisher)
    : SaveChangesInterceptor
{
    public override async ValueTask<int> SavedChangesAsync(
        SaveChangesCompletedEventData eventData, int result, CancellationToken ct)
    {
        var domainEvents = eventData.Context!.ChangeTracker.Entries<AggregateRoot>()
            .SelectMany(e => e.Entity.GetDomainEvents())
            .ToList();

        foreach (var @event in domainEvents)
            // Publish each domain event as a MediatR INotification
            await publisher.Publish(@event, ct);

        return result;
    }
}
```

### Notification Execution Order

By default, MediatR publishes to handlers **sequentially** (not in parallel) and **stops on the first exception**:

```csharp
// Default publisher: sequential, stops on exception
await publisher.Publish(notification, ct); // ← sends 1→2→3, stops if 2 throws

// Custom publisher: publish to all, collect failures
// Register in DI: services.AddTransient<INotificationPublisher, CustomPublisher>()
public class NoThrowPublisher : INotificationPublisher
{
    public async Task Publish(
        IEnumerable<NotificationHandlerExecutor> handlers,
        INotification notification, CancellationToken ct)
    {
        var exceptions = new List<Exception>();
        foreach (var handler in handlers)
        {
            try { await handler.HandlerCallback(notification, ct); }
            catch (Exception ex) { exceptions.Add(ex); }
        }
        if (exceptions.Count > 0) throw new AggregateException(exceptions);
    }
}
```

### When to Use Each

| Use Case | Pattern | Why |
|----------|---------|-----|
| Place order, get order ID | `IRequest<int>` + `Send` | One handler, returns a value |
| Cancel order (void) | `IRequest` + `Send` | One handler, no result |
| Domain event dispatched after save | `INotification` + `Publish` | Multiple side effects, optional handlers |
| Query order by ID | `IRequest<OrderDto?>` + `Send` | One handler, returns data |
| Background notification (email, analytics) | `INotification` + `Publish` | Fan-out, side effects |

## Code Example

```csharp
// Order submission flow: Send command → handler → raises domain event → Publish notification
// The notification dispatches to two independent handlers

// 1. Send the command
var orderId = await sender.Send(new SubmitOrderCommand(42), ct);

// 2. After SaveChanges (in interceptor): domain event becomes notification
// publisher.Publish(new OrderSubmittedEvent(42, customerId)) →
//   → SendConfirmationEmail handler
//   → UpdateAnalytics handler
//   → (any other handlers registered in the future — no code changes needed)
```

## Common Follow-up Questions

- How do you handle exceptions in notification handlers without stopping other handlers?
- Can you make `INotification` publish in parallel?
- What is the relationship between MediatR notifications and integration events?
- Should domain events be `INotification` or a separate in-process event mechanism?
- How do you test code that publishes notifications?

## Common Mistakes / Pitfalls

- **Using `INotification` for commands that need a result**: notifications have no return value. If the caller needs to know the result of an action, use `IRequest<TResult>`.
- **Relying on handler execution order for correctness**: MediatR doesn't guarantee notification handler order. Never write handlers where one must complete before another.
- **Forgetting that `Publish()` stops on the first exception**: a `SendConfirmationEmail` handler that throws will prevent `UpdateAnalytics` from running. Use a no-throw publisher or wrap each handler with try/catch.
- **Domain events as integration events**: MediatR notifications are in-process only. Never use them to communicate across service boundaries — use a message bus + Outbox pattern instead.

## References

- [MediatR notifications documentation](https://github.com/jbogard/MediatR/wiki/Notifications)
- [Custom notification publishers — MediatR v12](https://github.com/jbogard/MediatR/wiki/Behaviors#notification-publisher) (verify URL)
- [See: mediator-pattern.md](./mediator-pattern.md)
- [See: domain-events.md](./domain-events.md)
