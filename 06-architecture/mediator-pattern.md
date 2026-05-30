# Mediator Pattern

**Category:** Architecture / Mediator & Pipeline
**Difficulty:** 🟢 Junior
**Tags:** `mediator`, `GoF`, `design-patterns`, `MediatR`, `decoupling`, `IMediator`

## Question

> What is the Mediator design pattern? How does it reduce coupling between components, and how does MediatR implement it in .NET?

## Short Answer

The **Mediator** pattern (GoF) defines an object that encapsulates how a set of objects interact — objects no longer reference each other directly, they communicate through the mediator. This replaces a web of object-to-object references with a hub-and-spoke topology. In .NET, MediatR implements this: a controller sends a `PlaceOrderCommand` to `IMediator.Send()`, and MediatR routes it to `PlaceOrderHandler` — the controller never imports or knows about the handler class. This reduces coupling and centralizes cross-cutting concerns (validation, logging) in the mediator pipeline.

## Detailed Explanation

### Problem: Tight Coupling Without Mediator

```csharp
// ❌ Without Mediator: controller directly references service classes
[ApiController]
public class OrdersController(
    OrderService orderService,         // ← direct dependency
    InventoryService inventory,        // ← direct dependency
    ValidationService validator,       // ← direct dependency
    LoggingService logger             // ← direct dependency
) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Place(PlaceOrderRequest req)
    {
        logger.LogStart("PlaceOrder");
        var errors = validator.Validate(req);
        if (errors.Any()) return BadRequest(errors);
        var id = await orderService.PlaceOrderAsync(req);
        return CreatedAtAction(nameof(Get), new { id }, id);
    }
}
// Controller knows about 4 different classes — high coupling
// Adding validation/logging requires modifying every controller
```

```csharp
// ✅ With Mediator: controller only knows about IMediator (or ISender)
[ApiController]
public class OrdersController(ISender sender) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Place(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var id = await sender.Send(cmd, ct); // ← mediator routes to correct handler
        return CreatedAtAction(nameof(Get), new { id }, id);
    }
}
// Controller knows about ONE abstraction: ISender
// Validation, logging added as pipeline behaviors — controller unchanged
```

### GoF Mediator Pattern Structure

```
       ┌─────────────────────────────────────────────┐
       │                  Mediator                   │
       │                (IMediator)                  │
       └─────────┬──────────────────┬───────────────┘
                 │                  │
         ┌───────▼──────┐  ┌────────▼──────────┐
         │  Component A │  │    Component B     │
         │(OrderHandler)│  │(ValidationBehavior)│
         └──────────────┘  └───────────────────┘
          Component A and B never reference each other
          All interaction flows through the Mediator
```

### MediatR Request Types

```csharp
// 1. Request with response (single handler)
public record GetOrderQuery(int OrderId) : IRequest<OrderDto?>;

// 2. Request without response (single handler — void)
public record DeleteOrderCommand(int OrderId) : IRequest;

// 3. Notification (fan-out — any number of handlers)
public record OrderConfirmedNotification(int OrderId) : INotification;

// Handlers
public class GetOrderHandler(IOrderRepository orders) : IRequestHandler<GetOrderQuery, OrderDto?>
{
    public async Task<OrderDto?> Handle(GetOrderQuery q, CancellationToken ct)
        => await orders.GetDtoAsync(q.OrderId, ct);
}

public class NotifyWarehouseOnConfirmed : INotificationHandler<OrderConfirmedNotification>
{
    public Task Handle(OrderConfirmedNotification n, CancellationToken ct)
        => _warehouse.NotifyAsync(n.OrderId, ct);
}
```

### When to Use the Mediator Pattern

| Appropriate | Not Appropriate |
|-------------|----------------|
| Application command/query dispatch | Simple 2-class interaction (just inject directly) |
| Cross-cutting concerns via pipeline | Simple CRUD without complex behavior |
| Decoupling UI from application logic | Performance-critical hot paths (reflection overhead) |
| Event fan-out within a process | When the indirection makes code harder to navigate |

## Code Example

```csharp
// DI registration: all handlers auto-discovered from assembly
builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>());

// Pipeline: logging → validation → handler
builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
builder.Services.AddValidatorsFromAssemblyContaining<PlaceOrderCommand>();

// Usage: mediator dispatches to correct handler
// No factory, no type switch, no direct handler reference from caller
var orderId = await sender.Send(new PlaceOrderCommand(CustomerId: 7, Total: 99.99m), ct);
```

## Common Follow-up Questions

- How does MediatR compare to the Service Locator anti-pattern?
- What is the performance overhead of MediatR reflection dispatch?
- When is it better to inject a specific handler directly rather than using MediatR?
- How do you use MediatR notifications for in-process domain events?
- How do you test MediatR handlers in isolation?

## Common Mistakes / Pitfalls

- **Putting business logic in the mediator**: the mediator routes requests — it shouldn't contain domain rules. `PlaceOrderHandler` calls domain methods; it doesn't implement them.
- **Using IMediator everywhere including infrastructure**: Mediator is for the application layer. EF Core DbContext, HTTP clients, and repositories should be injected directly — don't route infrastructure calls through MediatR.
- **One handler per module "god handler"**: `OrderHandler.cs` with 20 handler implementations for every order operation makes the codebase as hard to navigate as a large service class.
- **Confusing MediatR with messaging**: MediatR dispatches in-process, synchronously (in the same request). It's not a message bus — there's no persistence, no retry, no cross-process delivery.

## References

- [MediatR — GitHub](https://github.com/jbogard/MediatR)
- [Mediator pattern — GoF Design Patterns](https://en.wikipedia.org/wiki/Mediator_pattern)
- [See: cqrs-with-mediatr.md](./cqrs-with-mediatr.md)
- [See: pipeline-behaviors.md](./pipeline-behaviors.md)
