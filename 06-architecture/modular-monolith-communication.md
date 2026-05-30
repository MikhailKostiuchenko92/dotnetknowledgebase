# Modular Monolith Communication

**Category:** Architecture / Modular Monolith
**Difficulty:** 🟡 Middle
**Tags:** `modular-monolith`, `in-process-events`, `loose-coupling`, `MediatR`, `integration-events`, `module-communication`

## Question

> How should modules in a modular monolith communicate — direct method calls via interfaces vs in-process domain/integration events? What are the trade-offs and when is each appropriate?

## Short Answer

Two communication patterns: **synchronous via public interface** (`IOrdersModule.PlaceOrderAsync()`) — simple, strongly typed, easy to reason about, but creates a direct dependency. **Asynchronous via in-process events** (MediatR `INotification` or custom event bus) — decoupled, fan-out capable, but harder to trace. Use synchronous interfaces when: the result is needed immediately (query, synchronous command). Use events when: reaction to an action happens in another module and the originating module doesn't need to know about it (Orders doesn't care who reacts to `OrderPlacedEvent`).

## Detailed Explanation

### Synchronous: Direct Interface Call

```csharp
// Synchronous: Inventory queries Orders when validating a return
// OrdersModule is a dependency of InventoryModule

// IOrdersModule.cs (public contract in Orders.Contracts)
public interface IOrdersModule
{
    Task<OrderDto?> GetOrderAsync(int orderId, CancellationToken ct);
    Task<bool> ExistsAsync(int orderId, CancellationToken ct);
}

// Usage in Inventory module (internal handler)
internal class ProcessReturnHandler(IOrdersModule orders, IStockRepository stocks)
    : IRequestHandler<ProcessReturnCommand>
{
    public async Task Handle(ProcessReturnCommand cmd, CancellationToken ct)
    {
        var order = await orders.GetOrderAsync(cmd.OrderId, ct);
        if (order is null) throw new NotFoundException("Order", cmd.OrderId);
        if (order.Status != "Delivered") throw new InvalidOperationException("Order not delivered");

        await stocks.AddReturnStockAsync(cmd.ProductId, cmd.Quantity, ct);
    }
}
```

### Asynchronous: In-Process Integration Events

```csharp
// Integration event: lives in shared/contracts layer
// DIFFERENT from domain events (which stay within a module)
namespace MyApp.SharedKernel.IntegrationEvents;

public record OrderPlacedIntegrationEvent(int OrderId, int CustomerId, decimal Total) : INotification;

// Orders module: publishes the event AFTER committing (via SaveChanges interceptor or handler)
internal class PlaceOrderHandler(IOrderRepository orders, IUnitOfWork uow, IPublisher publisher)
    : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(new CustomerId(cmd.CustomerId), cmd.Lines);
        await orders.AddAsync(order, ct);
        await uow.SaveChangesAsync(ct);

        // Publish AFTER successful commit
        await publisher.Publish(
            new OrderPlacedIntegrationEvent(order.Id, cmd.CustomerId, order.Total), ct);
        return order.Id;
    }
}

// Inventory module: reacts without coupling back to Orders
internal class ReserveStockOnOrderPlaced
    : INotificationHandler<OrderPlacedIntegrationEvent>
{
    public async Task Handle(OrderPlacedIntegrationEvent ev, CancellationToken ct)
        => await _stocks.ReserveAsync(ev.OrderId, ev.Lines, ct); // ← no Orders reference needed
}

// Notifications module: also reacts
internal class SendOrderConfirmationEmail
    : INotificationHandler<OrderPlacedIntegrationEvent>
{
    public Task Handle(OrderPlacedIntegrationEvent ev, CancellationToken ct)
        => _email.SendOrderConfirmationAsync(ev.CustomerId, ev.OrderId, ct);
}
```

### Custom In-Process Event Bus (Alternative to MediatR)

```csharp
// If MediatR is overkill, a simple event bus suffices for in-process communication
public interface IInProcessEventBus
{
    void Subscribe<T>(Func<T, CancellationToken, Task> handler) where T : class;
    Task PublishAsync<T>(T @event, CancellationToken ct) where T : class;
}

public class InProcessEventBus : IInProcessEventBus
{
    private readonly Dictionary<Type, List<Func<object, CancellationToken, Task>>> _handlers = new();

    public void Subscribe<T>(Func<T, CancellationToken, Task> handler) where T : class
    {
        var key = typeof(T);
        if (!_handlers.TryGetValue(key, out var list))
            _handlers[key] = list = new();
        list.Add((ev, ct) => handler((T)ev, ct));
    }

    public async Task PublishAsync<T>(T @event, CancellationToken ct) where T : class
    {
        if (_handlers.TryGetValue(typeof(T), out var handlers))
            foreach (var handler in handlers)
                await handler(@event, ct);
    }
}
```

### Decision Guide

| Scenario | Pattern | Reason |
|----------|---------|--------|
| Module needs data from another module | Synchronous interface | Result needed to continue |
| Reacting to an event (analytics, email, cache invalidation) | Integration event | Decoupled side-effects |
| Multiple modules react to one action | Integration event | Fan-out |
| Sequential workflow with rollback needs | Synchronous + saga | Explicit control flow |
| High-performance path (millisecond budget) | Synchronous | Events add overhead |

> **Warning**: publishing in-process events before the DB commit is a common bug. If the event handler runs and the commit fails, you have phantom events without matching state. Always publish AFTER successful commit.

## Code Example

```csharp
// Hybrid: synchronous for queries, events for post-commit side effects
// Program.cs
builder.Services.AddOrdersModule(builder.Configuration);
builder.Services.AddInventoryModule(builder.Configuration);

// Orders registers its event handlers via MediatR assembly scanning
// Inventory registers its INotificationHandler for OrderPlacedIntegrationEvent
// They connect only through shared INotification types — no project reference needed
// (Both reference MyApp.SharedKernel.IntegrationEvents, not each other's internals)
```

## Common Follow-up Questions

- How do you handle events reliably when in-process event dispatch is not transactional?
- When does in-process event communication need to be replaced with a message broker?
- How do you version integration events in a modular monolith?
- How do you test cross-module event flows without coupling test projects?
- What is the difference between a domain event and an integration event in a modular monolith context?

## Common Mistakes / Pitfalls

- **Publishing events before DB commit**: if `publisher.Publish()` is called in the handler before `SaveChangesAsync()`, and the save fails, the event has been dispatched but the state was never persisted — phantom events.
- **Circular module dependencies**: Module A subscribes to events from Module B, and Module B subscribes to events from Module A — creates a cycle that causes confusing DI issues and hidden coupling.
- **Using domain events as cross-module integration events**: domain events are internal to an aggregate/module and may contain domain types not suitable for cross-module use. Define separate integration event records with only primitive/DTO types.
- **Forgetting MediatR sequential semantics**: MediatR `Publish()` calls handlers sequentially by default, stopping on the first exception. If Module B's handler throws, Module C's handler never runs. Use a no-throw custom publisher for critical fan-out scenarios.

## References

- [In-process messaging in modular monolith](https://www.kamilgrzybek.com/blog/posts/modular-monolith-integration-styles) (verify URL)
- [See: modular-monolith-structure.md](./modular-monolith-structure.md)
- [See: notification-vs-request.md](./notification-vs-request.md)
- [See: domain-events.md](./domain-events.md)
