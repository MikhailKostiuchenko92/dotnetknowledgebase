# MediatR Setup and Usage

**Category:** Architecture / Mediator & Pipeline
**Difficulty:** 🟡 Middle
**Tags:** `MediatR`, `DI`, `IRequest`, `IRequestHandler`, `INotification`, `assembly-scanning`, `registration`

## Question

> How do you set up MediatR in an ASP.NET Core application? Walk through DI registration, assembly scanning, request/handler types, and how to send requests from controllers and minimal APIs.

## Short Answer

Install `MediatR`, call `AddMediatR()` in `Program.cs` with `RegisterServicesFromAssemblyContaining<T>()` to auto-discover all handlers via assembly scanning. Commands and queries implement `IRequest<TResult>` (single handler returns a value) or `IRequest` (void). Handlers implement `IRequestHandler<TRequest, TResult>`. Domain events implement `INotification`; any number of handlers implement `INotificationHandler<T>`. Inject `ISender` (for commands/queries) or `IPublisher` (for notifications) — never `IMediator` unless you genuinely need both.

## Detailed Explanation

### Installation and Basic Registration

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// Register MediatR: scans the specified assembly for all IRequestHandler<> and INotificationHandler<>
builder.Services.AddMediatR(cfg =>
{
    cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>(); // ← scans this assembly

    // Or multiple assemblies:
    // cfg.RegisterServicesFromAssemblies(
    //     typeof(PlaceOrderCommand).Assembly,
    //     typeof(GetOrderQuery).Assembly);
});
```

### Request Types

```csharp
// ── Commands (change state, single handler) ──────────────────────────
public record PlaceOrderCommand(int CustomerId, decimal Total)
    : IRequest<int>;  // ← returns the new order ID

public record CancelOrderCommand(int OrderId, string Reason)
    : IRequest;       // ← void — no return value

// ── Queries (read-only, single handler) ──────────────────────────────
public record GetOrderByIdQuery(int OrderId)
    : IRequest<OrderDto?>;

public record GetOrdersQuery(int? CustomerId, int Page)
    : IRequest<PagedResult<OrderSummaryDto>>;

// ── Notifications (fan-out, any number of handlers) ───────────────────
public record OrderSubmittedNotification(int OrderId, int CustomerId)
    : INotification;
```

### Handler Types

```csharp
// Single-handler for requests
public class PlaceOrderHandler(IOrderRepository orders, IUnitOfWork uow)
    : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(new CustomerId(cmd.CustomerId), new Money(cmd.Total));
        await orders.AddAsync(order, ct);
        await uow.SaveChangesAsync(ct);
        return order.Id.Value;
    }
}

// Void handler (IRequest without TResult)
public class CancelOrderHandler(IOrderRepository orders, IUnitOfWork uow)
    : IRequestHandler<CancelOrderCommand>
{
    public async Task Handle(CancelOrderCommand cmd, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(new OrderId(cmd.OrderId), ct)
            ?? throw new NotFoundException(nameof(Order), cmd.OrderId);
        order.Cancel(cmd.Reason);
        await uow.SaveChangesAsync(ct);
    }
}

// Notification handler (multiple can exist)
public class SendConfirmationOnSubmitted : INotificationHandler<OrderSubmittedNotification>
{
    public Task Handle(OrderSubmittedNotification n, CancellationToken ct)
        => _email.SendConfirmationAsync(n.CustomerId, n.OrderId, ct);
}

public class UpdateAnalyticsOnSubmitted : INotificationHandler<OrderSubmittedNotification>
{
    public Task Handle(OrderSubmittedNotification n, CancellationToken ct)
        => _analytics.TrackOrderAsync(n.OrderId, ct);
}
```

### Injection and Usage

```csharp
// Controller: inject ISender (not IMediator)
[ApiController, Route("api/orders")]
public class OrdersController(ISender sender) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Place([FromBody] PlaceOrderCommand cmd, CancellationToken ct)
    {
        var id = await sender.Send(cmd, ct);
        return CreatedAtAction(nameof(Get), new { id }, id);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id, CancellationToken ct)
    {
        var order = await sender.Send(new GetOrderByIdQuery(id), ct);
        return order is null ? NotFound() : Ok(order);
    }
}

// Minimal API: inject ISender via DI in route handler
app.MapPost("/orders", async ([FromBody] PlaceOrderCommand cmd, ISender sender, CancellationToken ct)
    => Results.Created($"/orders/{await sender.Send(cmd, ct)}", null));

// Notification: use IPublisher (or IMediator for both)
app.MapPost("/orders/{id}/notify",
    async (int id, IPublisher publisher, CancellationToken ct)
        => await publisher.Publish(new OrderSubmittedNotification(id, 7), ct));
```

### Interface Hierarchy

```
IMediator : ISender, IPublisher
  ISender     → Send<TResponse>(IRequest<TResponse>) — single handler
  IPublisher  → Publish(INotification)               — fan-out to all handlers

Prefer:
  ISender    in controllers/endpoints (only need to send requests)
  IPublisher in event dispatchers (only need to publish)
  IMediator  in application services that do both
```

## Code Example

```csharp
// Full DI registration with pipeline behaviors
builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>());

// FluentValidation validators (auto-discovered from same assembly)
builder.Services.AddValidatorsFromAssemblyContaining<PlaceOrderCommand>();

// Pipeline behaviors (order matters: first registered = outermost wrapper)
builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
```

## Common Follow-up Questions

- How does MediatR find handlers — does it use reflection or source generators?
- What happens if no handler is registered for a request type?
- How do you register a handler that spans multiple assemblies?
- Can a single class implement multiple `IRequestHandler<,>` interfaces?
- How do you unit test a MediatR handler — do you need MediatR in the test?

## Common Mistakes / Pitfalls

- **Registering handlers manually** instead of using `RegisterServicesFromAssemblyContaining<T>()`: manual registration is fragile and easy to forget when adding new handlers.
- **Injecting `IMediator` when only `ISender` is needed**: `IMediator` pulls the full implementation and signals to readers that the code both sends and publishes.
- **Transient vs scoped handler registration**: by default, `AddMediatR` registers handlers as `Transient`. If a handler needs `DbContext` (Scoped), MediatR creates a new handler per request — which works correctly since `IRequestHandler<>` is transient per request scope.
- **Multiple `IRequestHandler` implementations for the same `IRequest<>`**: MediatR resolves a single handler per `IRequest<>`. Multiple registrations cause undefined behavior — the last registered wins.

## References

- [MediatR GitHub — registration docs](https://github.com/jbogard/MediatR/wiki)
- [See: mediator-pattern.md](./mediator-pattern.md)
- [See: pipeline-behaviors.md](./pipeline-behaviors.md)
- [See: cqrs-with-mediatr.md](./cqrs-with-mediatr.md)
