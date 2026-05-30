# How Do You Test Background Services (IHostedService, BackgroundService)?

**Category:** Testing / Advanced Topics
**Difficulty:** 🟡 Middle
**Tags:** `IHostedService`, `BackgroundService`, `testing`, `hosted-service`, `cancellation`, `IHost`

## Question
> How do you test background services (`IHostedService`, `BackgroundService`) in .NET?

## Short Answer
For unit tests, call `StartAsync`/`StopAsync` directly on the service, pass a `CancellationToken` to control execution, and inject mocked dependencies. For integration tests, use `IHostBuilder` or `WebApplicationFactory` to start the real host, let the service run for a short duration, then cancel and assert side effects via injected fakes or a shared in-memory store.

## Detailed Explanation

### Unit Testing a `BackgroundService`
```csharp
public class OrderCleanupService(IOrderRepository repo, ILogger<OrderCleanupService> logger)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await repo.DeleteExpiredOrdersAsync(stoppingToken);
            await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }
}
```

```csharp
[Fact]
public async Task ExecuteAsync_CallsDeleteExpired_Once()
{
    var repo = new Mock<IOrderRepository>();
    using var cts = new CancellationTokenSource(TimeSpan.FromMilliseconds(100));

    var sut = new OrderCleanupService(repo.Object, NullLogger<OrderCleanupService>.Instance);
    await sut.StartAsync(cts.Token);
    await Task.Delay(50); // let it run at least once
    cts.Cancel();
    await sut.StopAsync(CancellationToken.None);

    repo.Verify(r => r.DeleteExpiredOrdersAsync(It.IsAny<CancellationToken>()), Times.AtLeastOnce);
}
```

### Replacing `Task.Delay` for Deterministic Tests
Inject `TimeProvider` (see [testing-task-delay.md](testing-task-delay.md)) and use `FakeTimeProvider` to advance time without waiting.

### Integration Testing with `IHost`
```csharp
[Fact]
public async Task BackgroundService_ProcessesMessages()
{
    var processed = new List<string>();
    var host = Host.CreateDefaultBuilder()
        .ConfigureServices(services =>
        {
            services.AddSingleton(processed);
            services.AddHostedService<MessageProcessorService>();
        })
        .Build();

    using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(2));
    await host.StartAsync(cts.Token);
    await Task.Delay(500, CancellationToken.None); // let messages process
    await host.StopAsync(CancellationToken.None);

    processed.Should().NotBeEmpty();
}
```

### Testing `IHostedService.StartAsync` / `StopAsync` Directly
For simpler services (no loop):
```csharp
[Fact]
public async Task StartAsync_RegistersSubscription()
{
    var bus = new Mock<IMessageBus>();
    var sut = new SubscriberService(bus.Object);

    await sut.StartAsync(CancellationToken.None);

    bus.Verify(b => b.Subscribe(It.IsAny<string>(), It.IsAny<Func<Message, Task>>()), Times.Once);
}
```

### Testing Graceful Shutdown
```csharp
[Fact]
public async Task StopAsync_CancelsPendingWork_Gracefully()
{
    var cts = new CancellationTokenSource();
    var sut = new LongRunningService();

    var runTask = sut.StartAsync(cts.Token);
    await Task.Delay(50);

    await sut.StopAsync(CancellationToken.None); // triggers stoppingToken

    await runTask.Should().CompleteWithinAsync(TimeSpan.FromSeconds(1));
}
```

## Code Example
```csharp
[Fact]
public async Task OutboxProcessor_PublishesMessages_FromOutbox()
{
    var bus = new Mock<IEventBus>();
    var outbox = new InMemoryOutbox();
    outbox.Add(new OutboxMessage { Id = 1, Payload = "{}" });

    using var cts = new CancellationTokenSource();
    var sut = new OutboxProcessorService(outbox, bus.Object,
                  NullLogger<OutboxProcessorService>.Instance);

    await sut.StartAsync(cts.Token);
    await Task.Delay(100); // let one iteration run
    cts.Cancel();
    await sut.StopAsync(CancellationToken.None);

    bus.Verify(b => b.PublishAsync(It.IsAny<OutboxMessage>(), default), Times.Once);
    outbox.All.Should().AllSatisfy(m => m.ProcessedAt.Should().NotBeNull());
}
```

## Common Follow-up Questions
- How do you test a `PeriodicTimer`-based background service?
- How do you ensure a background service doesn't swallow exceptions silently?
- How do you verify that a background service stops within a deadline?
- How do `IHostApplicationLifetime` events affect background service testing?
- How do you test a Quartz.NET or Hangfire scheduled job?

## Common Mistakes / Pitfalls
- **Not cancelling the service** — tests hang indefinitely waiting for an infinite loop.
- **Using `Task.Delay` for timing** — non-deterministic; use `FakeTimeProvider` for controllable delays.
- **Not checking the stopped task** — `await sut.StopAsync(...)` returns before `ExecuteAsync` completes; await the task returned by `StartAsync` to confirm completion.
- **Starting multiple services in the same host without isolation** — services interfere; use a fresh host per test.

## References
- [Microsoft Learn — BackgroundService](https://learn.microsoft.com/en-us/dotnet/core/extensions/workers)
- [Microsoft Learn — IHostedService](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services)
- [See also: testing-task-delay.md](testing-task-delay.md)
