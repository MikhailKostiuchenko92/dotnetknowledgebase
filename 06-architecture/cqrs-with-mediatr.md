# CQRS with MediatR

**Category:** Architecture / CQRS
**Difficulty:** 🟡 Middle
**Tags:** `CQRS`, `MediatR`, `IRequest`, `IRequestHandler`, `INotification`, `pipeline`, `DI`

## Question

> How do you implement CQRS using MediatR in .NET? Describe the `IRequest` / `IRequestHandler` pattern, how to configure the DI pipeline, and the difference between `ISender.Send()` and `IMediator.Publish()`.

## Short Answer

MediatR is the most common .NET library for implementing CQRS dispatch. Commands and queries implement `IRequest<TResponse>` (single handler, returns a value) or `IRequest` (void). Handlers implement `IRequestHandler<TRequest, TResponse>`. `ISender.Send(request)` routes to exactly one handler. `IMediator.Publish(notification)` fans out to all `INotificationHandler<TNotification>` handlers — used for domain events. The pipeline is extended with `IPipelineBehavior<TRequest, TResponse>` for cross-cutting concerns (validation, logging, caching).

## Detailed Explanation

### Installation and DI Setup

```bash
dotnet add package MediatR
```

```csharp
// Program.cs — register all handlers from an assembly
builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>());

// Inject ISender in controllers/endpoints — preferred over IMediator
// ISender: only Send() — lighter interface, hides Publish()
// IPublisher: only Publish()
// IMediator: both — convenient for App Services that both Send and Publish
```

### Commands (Single Handler)

```csharp
// Command: IRequest<TResult>
public record PlaceOrderCommand(int CustomerId, decimal Total) : IRequest<int>;

// Handler: IRequestHandler<TCommand, TResult>
public class PlaceOrderHandler(IOrderRepository orders)
    : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(new CustomerId(cmd.CustomerId), new Money(cmd.Total));
        await orders.AddAsync(order, ct);
        return order.Id.Value;
    }
}

// Void command: IRequest (no type parameter)
public record CancelOrderCommand(int OrderId, string Reason) : IRequest;

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
```

### Queries (Single Handler, No Side Effects)

```csharp
public record GetOrderByIdQuery(int OrderId) : IRequest<OrderDto?>;

public class GetOrderByIdHandler(IDbConnectionFactory db)
    : IRequestHandler<GetOrderByIdQuery, OrderDto?>
{
    public async Task<OrderDto?> Handle(GetOrderByIdQuery q, CancellationToken ct)
    {
        using var conn = db.CreateConnection();
        return await conn.QueryFirstOrDefaultAsync<OrderDto>(
            "SELECT Id, Status, TotalAmount, CreatedAt FROM Orders WHERE Id = @id",
            new { id = q.OrderId });
    }
}
```

### Notifications (Fan-Out to Multiple Handlers)

```csharp
// Notification: INotification — any number of handlers
public record OrderSubmittedNotification(int OrderId, int CustomerId, decimal Total)
    : INotification;

// Handler 1
public class SendConfirmationEmail(IEmailSender email)
    : INotificationHandler<OrderSubmittedNotification>
{
    public Task Handle(OrderSubmittedNotification n, CancellationToken ct)
        => email.SendOrderConfirmationAsync(n.CustomerId, n.OrderId, ct);
}

// Handler 2
public class UpdateAnalytics(IAnalyticsService analytics)
    : INotificationHandler<OrderSubmittedNotification>
{
    public Task Handle(OrderSubmittedNotification n, CancellationToken ct)
        => analytics.TrackOrderAsync(n.OrderId, n.Total, ct);
}
```

### ISender vs IPublisher vs IMediator

| Interface | Methods | Use when |
|-----------|---------|---------|
| `ISender` | `Send<T>()` | Controllers, endpoints — inject lighter interface |
| `IPublisher` | `Publish()` | Event dispatchers — only publish, never query |
| `IMediator` | `Send()` + `Publish()` | Application services that both command and notify |

```csharp
// Controller: inject ISender — only needs to send requests
[ApiController, Route("api/orders")]
public class OrdersController(ISender sender) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Place(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var id = await sender.Send(cmd, ct);
        return CreatedAtAction(nameof(Get), new { id }, id);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(int id, CancellationToken ct)
    {
        var order = await sender.Send(new GetOrderByIdQuery(id), ct);
        return order is null ? NotFound() : Ok(order);
    }
}
```

### Pipeline Behaviors

```csharp
// Validation behavior (runs for every IRequest)
public class ValidationBehavior<TRequest, TResponse>(IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest req, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        if (!validators.Any()) return await next();

        var context = new ValidationContext<TRequest>(req);
        var failures = validators
            .Select(v => v.Validate(context))
            .SelectMany(r => r.Errors)
            .Where(f => f is not null)
            .ToList();

        if (failures.Count != 0)
            throw new ValidationException(failures);

        return await next();
    }
}

// Register in order: outer behaviors wrap inner ones
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));      // 1st
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));    // 2nd
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(TransactionBehavior<,>));   // 3rd (innermost)
```

## Code Example

```csharp
// Minimal API + MediatR — complete endpoint setup
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>());
builder.Services.AddValidatorsFromAssemblyContaining<PlaceOrderCommand>();
builder.Services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));

var app = builder.Build();

app.MapPost("/orders", async (PlaceOrderCommand cmd, ISender sender, CancellationToken ct)
    => Results.Created($"/orders/{await sender.Send(cmd, ct)}", null));

app.MapGet("/orders/{id:int}", async (int id, ISender sender, CancellationToken ct)
    => await sender.Send(new GetOrderByIdQuery(id), ct) is { } order
        ? Results.Ok(order) : Results.NotFound());
```

## Common Follow-up Questions

- How do you order pipeline behaviors in MediatR — which runs first?
- How do you conditionally apply a pipeline behavior to only commands (not queries)?
- What is `RequestPreProcessor` and `RequestPostProcessor` in MediatR — when do you use them?
- How do you handle exceptions in MediatR — global exception behavior vs middleware?
- What is the performance overhead of MediatR reflection-based dispatch, and when does it matter?

## Common Mistakes / Pitfalls

- **One handler per request violation**: MediatR's `Send()` expects exactly one handler per `IRequest`. Registering multiple `IRequestHandler<PlaceOrderCommand, int>` will throw or silently call only one (depending on DI registration order).
- **Notification handler exceptions stopping other handlers**: by default, if one `INotificationHandler` throws, MediatR stops calling the remaining handlers. Use a `NoThrowPublishStrategy` or catch exceptions inside each handler.
- **Injecting `IMediator` when only `ISender` is needed**: `IMediator` pulls the full implementation. In most scenarios, controllers only need `ISender` — prefer the more specific interface.
- **Pipeline behavior order matters**: registering `TransactionBehavior` before `ValidationBehavior` opens a DB transaction before validating the request — pointless overhead for invalid requests.

## References

- [MediatR — GitHub](https://github.com/jbogard/MediatR)
- [MediatR Wiki — GitHub](https://github.com/jbogard/MediatR/wiki)
- [See: cqrs-fundamentals.md](./cqrs-fundamentals.md)
- [See: pipeline-behaviors.md](./pipeline-behaviors.md)
- [See: command-vs-query.md](./command-vs-query.md)
