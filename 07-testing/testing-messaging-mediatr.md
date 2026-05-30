# How Do You Test Code That Publishes/Consumes Messages?

**Category:** Testing / Advanced Topics
**Difficulty:** 🟡 Middle
**Tags:** `MediatR`, `RabbitMQ`, `messaging`, `testing`, `pub-sub`, `in-memory`

## Question
> How do you test code that publishes/consumes messages (e.g., via MediatR, RabbitMQ)?

## Short Answer
For MediatR: use the real `Mediator` in-process with in-memory handlers; no mocking needed for the bus itself. For external brokers (RabbitMQ, Azure Service Bus): abstract behind `IMessagePublisher`/`IMessageConsumer` interfaces for unit tests, or use Testcontainers (RabbitMQ Docker container) for integration tests that verify actual message delivery.

## Detailed Explanation

### Testing MediatR Handlers
```csharp
// Register real mediator in tests
services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(typeof(CreateOrderCommand).Assembly));
services.AddScoped<IOrderRepository, InMemoryOrderRepository>();

var sp = services.BuildServiceProvider();
var mediator = sp.GetRequiredService<IMediator>();

// Act
var result = await mediator.Send(new CreateOrderCommand { ProductId = 1, Quantity = 2 });

// Assert
result.OrderId.Should().BePositive();
```

> ✅ Prefer real mediator over `Mock<IMediator>` — mocking the mediator tests nothing; test the handler directly or through the mediator.

### Testing MediatR Notifications (Events)
```csharp
[Fact]
public async Task OrderCreated_Publishes_Notification()
{
    var handler = new Mock<INotificationHandler<OrderCreated>>();
    services.AddSingleton(handler.Object);
    var sp = services.BuildServiceProvider();
    var mediator = sp.GetRequiredService<IMediator>();

    await mediator.Publish(new OrderCreated { OrderId = 1 });

    handler.Verify(h => h.Handle(It.Is<OrderCreated>(e => e.OrderId == 1),
                                  It.IsAny<CancellationToken>()), Times.Once);
}
```

### Testing a Publisher Against an Interface
```csharp
public interface IEventPublisher
{
    Task PublishAsync<T>(T message, CancellationToken ct = default);
}

// Unit test: stub publisher
var publisher = new Mock<IEventPublisher>();
var sut = new OrderService(repo.Object, publisher.Object);
await sut.PlaceOrderAsync(new PlaceOrderRequest());
publisher.Verify(p => p.PublishAsync(It.IsAny<OrderPlaced>(), default), Times.Once);
```

### Integration Test: RabbitMQ via Testcontainers
```csharp
public class RabbitMqTests : IAsyncLifetime
{
    private readonly RabbitMqContainer _rabbit = new RabbitMqBuilder().Build();

    public async Task InitializeAsync() => await _rabbit.StartAsync();
    public async Task DisposeAsync() => await _rabbit.DisposeAsync();

    [Fact]
    public async Task PublishAndConsume_RoundTrip()
    {
        var connectionString = _rabbit.GetConnectionString();
        var publisher = new RabbitMqPublisher(connectionString);
        var consumer = new RabbitMqConsumer(connectionString);
        var received = new List<string>();
        consumer.Subscribe("orders", msg => received.Add(msg));

        await publisher.PublishAsync("orders", "order-created");
        await Task.Delay(200); // allow delivery

        received.Should().Contain("order-created");
    }
}
```

### Azure Service Bus: Use `ServiceBusClient` Test Double
Microsoft provides `ServiceBusSender`/`ServiceBusReceiver` as abstract classes (mockable):
```csharp
var sender = new Mock<ServiceBusSender>();
sender.Setup(s => s.SendMessageAsync(It.IsAny<ServiceBusMessage>(), default))
      .Returns(Task.CompletedTask);
```

## Code Example
```csharp
// Testing MediatR pipeline behaviour end-to-end (no mocks on the bus itself)

[Fact]
public async Task PlaceOrder_ValidCommand_ReturnsOrderId_AndPublishesEvent()
{
    var services = new ServiceCollection();
    services.AddLogging();
    services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<PlaceOrderCommand>());
    services.AddScoped<IOrderRepository, InMemoryOrderRepository>();

    var published = new List<INotification>();
    services.AddSingleton<INotificationHandler<OrderPlacedEvent>>(
        new CapturingHandler<OrderPlacedEvent>(published));

    var sp = services.BuildServiceProvider();
    var mediator = sp.GetRequiredService<IMediator>();

    var result = await mediator.Send(new PlaceOrderCommand { ProductId = 42, Quantity = 1 });

    result.OrderId.Should().BePositive();
    published.OfType<OrderPlacedEvent>()
             .Should().ContainSingle(e => e.OrderId == result.OrderId);
}
```

## Common Follow-up Questions
- Should you mock `IMediator` in unit tests?
- How do you test MediatR pipeline behaviours (validators, decorators)?
- How do you run RabbitMQ in CI using Testcontainers?
- How do you test message ordering and deduplication?
- What is an outbox pattern and how do you test it?

## Common Mistakes / Pitfalls
- **Mocking `IMediator.Send`** — prevents testing the actual handler; mock the handler's dependencies instead.
- **Not cleaning up Testcontainers** — use `IAsyncLifetime.DisposeAsync` to stop the container.
- **Testing infrastructure in unit tests** — RabbitMQ connectivity tests belong in integration tests, not unit tests.
- **Asserting on broker-internal state** — verify that your handler processed the message correctly, not that the broker received it.

## References
- [MediatR GitHub](https://github.com/jbogard/MediatR)
- [Testcontainers.RabbitMq](https://dotnet.testcontainers.org/modules/rabbitmq/)
- [Azure SDK — ServiceBusSender testing](https://github.com/Azure/azure-sdk-for-net) (verify URL)
