# DI with Hosted Services — Scoped Services in BackgroundService

**Category:** ASP.NET Core / Dependency Injection
**Difficulty:** 🟡 Middle
**Tags:** `DI`, `BackgroundService`, `IServiceScopeFactory`, `scoped`, `hosted-service`

## Question

> How do you safely use Scoped services (like `DbContext`) inside a `BackgroundService`, and what is the `IServiceScopeFactory` pattern?

## Short Answer

`BackgroundService` is registered as a Singleton, so you cannot inject Scoped services directly into its constructor — that creates a captive dependency. The solution is to inject `IServiceScopeFactory` (which is itself Singleton), then call `CreateAsyncScope()` to create a new DI scope for each unit of work. Within that scope you resolve Scoped services normally, and they are disposed automatically at the end of the `using` block.

## Detailed Explanation

### Why you can't inject Scoped into BackgroundService

`BackgroundService` is registered with `AddHostedService<T>()`, which resolves it as a Singleton from the root `IServiceProvider`. If you inject `AppDbContext` (Scoped) into the constructor:

```csharp
// BUG: captive dependency
public class MyWorker(AppDbContext db) : BackgroundService { ... }
// db is resolved once from the root scope — it's captured for the app lifetime
// All concurrent iterations share the same DbContext — data corruption risk
```

With scope validation enabled (`ValidateScopes = true`), the container throws at startup rather than at runtime.

### The `IServiceScopeFactory` pattern

```csharp
public class MyWorker(IServiceScopeFactory scopeFactory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            // Create a new scope per iteration
            await using var scope = scopeFactory.CreateAsyncScope();

            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var service = scope.ServiceProvider.GetRequiredService<IOrderService>();

            await service.ProcessPendingOrdersAsync(stoppingToken);
            // Scope disposed here → DbContext disposed, connection returned to pool

            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}
```

### `CreateScope` vs `CreateAsyncScope`

| Method | Disposal |
|---|---|
| `CreateScope()` → `IServiceScope` | `scope.Dispose()` (sync) |
| `CreateAsyncScope()` → `AsyncServiceScope` | `await scope.DisposeAsync()` (async) |

Prefer `CreateAsyncScope()` when services implement `IAsyncDisposable` (e.g., `DbContext`). Using `using var scope = ...` with `AsyncServiceScope` correctly calls `DisposeAsync()`.

### When to create a scope

| Scenario | Scope per... |
|---|---|
| Periodic batch job | Loop iteration |
| Message consumer (queue/event bus) | Message |
| Scheduled task | Task execution |
| Long-running pipeline | Pipeline step |

Create scopes at the **boundary of a logical unit of work** — the same granularity you'd use for a database transaction.

### Injecting multiple Scoped services

All services resolved from the same scope share the same instance:

```csharp
await using var scope = scopeFactory.CreateAsyncScope();
var sp = scope.ServiceProvider;

var db      = sp.GetRequiredService<AppDbContext>();     // instance A
var repo    = sp.GetRequiredService<IOrderRepository>(); // gets same instance A (if Scoped)
var service = sp.GetRequiredService<IOrderService>();    // gets same instance A transitively

// All three share the same DbContext — correct for a unit of work
```

### `IServiceScope` vs `AsyncServiceScope`

```csharp
// Synchronous (avoid if services are async-disposable)
using (var scope = scopeFactory.CreateScope())
{
    var service = scope.ServiceProvider.GetRequiredService<IMyService>();
    service.DoWork();
} // sync Dispose() only — IAsyncDisposable.DisposeAsync() NOT called

// Asynchronous (preferred for ASP.NET Core services)
await using (var scope = scopeFactory.CreateAsyncScope())
{
    var service = scope.ServiceProvider.GetRequiredService<IMyService>();
    await service.DoWorkAsync();
} // DisposeAsync() called → async cleanup runs
```

## Code Example

```csharp
// OutboxProcessor.cs — Scoped DbContext via IServiceScopeFactory
namespace MyApp.Workers;

public sealed class OutboxProcessor(
    IServiceScopeFactory scopeFactory,
    ILogger<OutboxProcessor> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Outbox processor started");

        await foreach (var _ in PeriodicTimer(TimeSpan.FromSeconds(5), stoppingToken))
        {
            await ProcessBatchAsync(stoppingToken);
        }
    }

    private async Task ProcessBatchAsync(CancellationToken ct)
    {
        // New scope = new DbContext = isolated unit of work
        await using var scope = scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var publisher = scope.ServiceProvider.GetRequiredService<IMessagePublisher>();

        var messages = await db.OutboxMessages
            .Where(m => !m.ProcessedAt.HasValue)
            .OrderBy(m => m.CreatedAt)
            .Take(50)
            .ToListAsync(ct);

        foreach (var message in messages)
        {
            try
            {
                await publisher.PublishAsync(message, ct);
                message.ProcessedAt = DateTime.UtcNow;
                logger.LogDebug("Published outbox message {Id}", message.Id);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to publish outbox message {Id}", message.Id);
            }
        }

        await db.SaveChangesAsync(ct);
    }

    private static async IAsyncEnumerable<Unit> PeriodicTimer(
        TimeSpan interval,
        [EnumeratorCancellation] CancellationToken ct)
    {
        using var timer = new PeriodicTimer(interval);
        while (await timer.WaitForNextTickAsync(ct))
            yield return default;
    }
}

record struct Unit;
```

```csharp
// Program.cs
builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddScoped<IMessagePublisher, RabbitMqPublisher>();
builder.Services.AddHostedService<OutboxProcessor>();
```

## Common Follow-up Questions

- What is the difference between creating one scope per loop iteration vs one scope per message?
- How do you pass data (e.g., a correlation ID) into the scope created by `IServiceScopeFactory`?
- How do you unit-test a `BackgroundService` that creates scopes internally?
- What happens if a service resolved from the scope throws during construction?
- Can you use `IAsyncDisposable` services inside a scope created by `IServiceScopeFactory`?

## Common Mistakes / Pitfalls

- **Creating one scope for the entire lifetime of `ExecuteAsync`** — all operations share the same `DbContext`, which accumulates tracked entities, increases memory, and is not reset between iterations.
- **Using `CreateScope()` instead of `CreateAsyncScope()` for async-disposable services** — `IAsyncDisposable.DisposeAsync()` is not called; resources like database connections are not released asynchronously.
- **Forgetting `await using` for the scope** — without `await using`, the scope's `DisposeAsync()` is not called (with `AsyncServiceScope`), leaking resources.
- **Resolving from `IServiceProvider` directly (not from scope)** — resolving Scoped services from the root provider creates them in the root scope; they live forever and are never disposed.
- **Not passing `CancellationToken` into scoped service calls** — services may hang indefinitely during shutdown if they don't respect the cancellation token.

## References

- [Microsoft Learn — Background tasks with hosted services](https://learn.microsoft.com/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-8.0#consuming-a-scoped-service-in-a-background-task)
- [Microsoft Learn — Scoped service in BackgroundService](https://learn.microsoft.com/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-8.0#scoped-services)
- [Stephen Cleary — BackgroundService with scoped services](https://blog.stephencleary.com/2020/05/backgroundservice-gotcha-startup.html) (verify URL)
- [Andrew Lock — IServiceScopeFactory in hosted services](https://andrewlock.net/tag/background-tasks/) (verify URL)
