# IServiceScopeFactory — Manual Scope Management

**Category:** ASP.NET Core / Dependency Injection
**Difficulty:** 🔴 Senior
**Tags:** `IServiceScopeFactory`, `IServiceScope`, `AsyncServiceScope`, `scope-management`, `disposal`

## Question

> How do you use `IServiceScopeFactory` to manually create and manage DI scopes, and what are the async disposal semantics?

## Short Answer

`IServiceScopeFactory.CreateScope()` creates a new child `IServiceScope` with its own `IServiceProvider`. Services resolved from this scope are isolated from the root and from other scopes — Scoped services get new instances, Singletons are shared from the root. Use `CreateAsyncScope()` (returning `AsyncServiceScope`) when services implement `IAsyncDisposable`, and wrap the scope in `await using` to ensure async cleanup runs. The scope (and all Scoped services it contains) is disposed when the scope itself is disposed.

## Detailed Explanation

### `IServiceScope` and `AsyncServiceScope`

```csharp
public interface IServiceScope : IDisposable
{
    IServiceProvider ServiceProvider { get; }
}

// AsyncServiceScope is a value-type wrapper (.NET 6+)
public readonly struct AsyncServiceScope : IServiceScope, IAsyncDisposable
{
    public IServiceProvider ServiceProvider { get; }
    public ValueTask DisposeAsync();
    public void Dispose();
}
```

`AsyncServiceScope` calls `DisposeAsync()` on all `IAsyncDisposable` services in the scope, then falls back to `Dispose()` for `IDisposable`-only services.

### Creating scopes

```csharp
// Synchronous scope (legacy pattern)
using var scope = scopeFactory.CreateScope();
var service = scope.ServiceProvider.GetRequiredService<IMyService>();
service.DoWork();
// Dispose() called at end of using block

// Async scope (preferred for .NET 6+)
await using var scope = scopeFactory.CreateAsyncScope();
var service = scope.ServiceProvider.GetRequiredService<IMyService>();
await service.DoWorkAsync();
// DisposeAsync() called at end of await using block
```

### What gets disposed when a scope is disposed

1. All `IAsyncDisposable` services resolved from the scope (via `DisposeAsync()`).
2. All `IDisposable` services resolved from the scope (via `Dispose()`).
3. The scope itself.

Singleton services are NOT disposed — they are owned by the root scope.

### Scope isolation

```csharp
await using var scope1 = scopeFactory.CreateAsyncScope();
await using var scope2 = scopeFactory.CreateAsyncScope();

// Different DbContext instances
var db1 = scope1.ServiceProvider.GetRequiredService<AppDbContext>();
var db2 = scope2.ServiceProvider.GetRequiredService<AppDbContext>();

Console.WriteLine(db1 == db2); // false — different instances
```

Within a single scope, all resolutions of the same Scoped service return the same instance:
```csharp
await using var scope = scopeFactory.CreateAsyncScope();
var db1 = scope.ServiceProvider.GetRequiredService<AppDbContext>();
var db2 = scope.ServiceProvider.GetRequiredService<AppDbContext>();
Console.WriteLine(db1 == db2); // true — same scope, same instance
```

### Root scope vs child scope

| | Root scope | Child scope |
|---|---|---|
| Lifetime | App lifetime | Explicit disposal |
| Scoped services | ❌ Not allowed (throws with validation) | ✅ |
| Singleton services | ✅ Owned here | ✅ Shared from root |
| Transient services | ✅ (disposed with root on shutdown) | ✅ (disposed with scope) |

The root scope is `app.Services` (or `host.Services`). Resolving Scoped services from it with validation enabled throws `InvalidOperationException`.

### Parallel scopes

Each scope is independent; you can create them in parallel:

```csharp
var tasks = Enumerable.Range(0, 10).Select(async i =>
{
    await using var scope = scopeFactory.CreateAsyncScope();
    var processor = scope.ServiceProvider.GetRequiredService<IMessageProcessor>();
    await processor.ProcessAsync(messages[i], stoppingToken);
});

await Task.WhenAll(tasks);
```

Each `IMessageProcessor` (and its `DbContext`, etc.) is isolated per task — no shared state.

### Passing context into a scope

The DI container doesn't support "parameterized scopes" natively. Common patterns:
1. Pass parameters via method arguments on the resolved service.
2. Use `IHttpContextAccessor` / custom `AsyncLocal<T>` accessor pattern.
3. Register a scope-level parameter as Scoped and set it after creating the scope.

## Code Example

```csharp
// Parallel message processor using scopes
namespace MyApp.Workers;

public sealed class ParallelMessageProcessor(
    IServiceScopeFactory scopeFactory,
    ILogger<ParallelMessageProcessor> logger) : BackgroundService
{
    private const int MaxConcurrency = 5;
    private readonly SemaphoreSlim _semaphore = new(MaxConcurrency);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var batch in GetMessageBatchesAsync(stoppingToken))
        {
            var tasks = batch.Select(msg => ProcessMessageAsync(msg, stoppingToken));
            await Task.WhenAll(tasks);
        }
    }

    private async Task ProcessMessageAsync(Message message, CancellationToken ct)
    {
        await _semaphore.WaitAsync(ct);
        try
        {
            // Each message gets its own scope → own DbContext, own transaction
            await using var scope = scopeFactory.CreateAsyncScope();
            var handler = scope.ServiceProvider.GetRequiredService<IMessageHandler>();

            logger.LogDebug("Processing message {Id}", message.Id);
            await handler.HandleAsync(message, ct);
            logger.LogDebug("Message {Id} processed", message.Id);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to process message {Id}", message.Id);
        }
        finally
        {
            _semaphore.Release();
        }
    }

    private static async IAsyncEnumerable<List<Message>> GetMessageBatchesAsync(
        [EnumeratorCancellation] CancellationToken ct)
    {
        // Stub — would read from queue
        await Task.Delay(1000, ct);
        yield return [new Message(1), new Message(2)];
    }
}
```

```csharp
// Program.cs
builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddScoped<IMessageHandler, MessageHandler>();
builder.Services.AddHostedService<ParallelMessageProcessor>();
```

```csharp
// Unit test — verify scope is created and service resolved
[Fact]
public async Task ProcessMessageAsync_CreatesScope_AndCallsHandler()
{
    var handlerMock = new Mock<IMessageHandler>();
    handlerMock.Setup(h => h.HandleAsync(It.IsAny<Message>(), It.IsAny<CancellationToken>()))
               .Returns(Task.CompletedTask);

    var services = new ServiceCollection();
    services.AddScoped<IMessageHandler>(_ => handlerMock.Object);
    await using var provider = services.BuildServiceProvider();
    var factory = provider.GetRequiredService<IServiceScopeFactory>();

    await using var scope = factory.CreateAsyncScope();
    var handler = scope.ServiceProvider.GetRequiredService<IMessageHandler>();
    await handler.HandleAsync(new Message(1), CancellationToken.None);

    handlerMock.Verify(h => h.HandleAsync(It.IsAny<Message>(), It.IsAny<CancellationToken>()),
        Times.Once);
}
```

## Common Follow-up Questions

- What happens if you don't dispose a scope — are Scoped services leaked?
- How does `AsyncServiceScope.Dispose()` (sync) differ from `DisposeAsync()` — which should you prefer?
- How do you propagate `Activity` / `AsyncLocal` values into a manually created scope?
- What is `IServiceProvider.CreateScope()` extension method vs `IServiceScopeFactory.CreateScope()`?
- How does the DI container track disposable services created within a scope?

## Common Mistakes / Pitfalls

- **Not disposing the scope** — without `using` / `await using`, Scoped services are never disposed. `DbContext` connections accumulate, exhausting the pool.
- **Storing the scope in a long-lived field** — negates isolation; it becomes a second root scope.
- **Using `CreateScope()` (sync) for async-disposable services** — `IAsyncDisposable.DisposeAsync()` is not called; database connections may not be properly released.
- **Resolving Scoped services from `scope.ServiceProvider` before the scope is ready** — fine after `CreateScope()`, but if you store `scope.ServiceProvider` and use it after `scope.Dispose()`, services are invalidated.
- **Creating a scope inside the scope's `DisposeAsync`** — leads to recursive scope creation and eventual `ObjectDisposedException`.

## References

- [Microsoft Learn — IServiceScopeFactory](https://learn.microsoft.com/dotnet/api/microsoft.extensions.dependencyinjection.iservicescopefactory?view=dotnet-plat-ext-8.0)
- [Microsoft Learn — AsyncServiceScope (.NET 6)](https://learn.microsoft.com/dotnet/api/microsoft.extensions.dependencyinjection.asyncservicescope?view=dotnet-plat-ext-8.0)
- [Andrew Lock — Service scope management](https://andrewlock.net/tag/di/) (verify URL)
- [Microsoft — ServiceProvider source](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.DependencyInjection/src/ServiceProvider.cs)
- [Microsoft Learn — Dependency injection in hosted services](https://learn.microsoft.com/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-8.0#consuming-a-scoped-service-in-a-background-task)
