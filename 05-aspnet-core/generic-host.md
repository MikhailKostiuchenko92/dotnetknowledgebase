# Generic Host — IHost, IHostedService, BackgroundService

**Category:** ASP.NET Core / Hosting
**Difficulty:** 🟢 Junior
**Tags:** `generic-host`, `IHost`, `IHostedService`, `BackgroundService`, `hosted-service`

## Question

> What is the .NET Generic Host, what is `IHostedService`, and how does `BackgroundService` relate to it?

## Short Answer

The Generic Host (`IHost`) is the infrastructure that manages an application's lifetime, DI container, configuration, and logging — for both web and non-web workloads. `IHostedService` is the interface that lets you hook into the host's `StartAsync`/`StopAsync` lifecycle. `BackgroundService` is an abstract base class implementing `IHostedService` that simplifies writing long-running background loops via a single `ExecuteAsync` method.

## Detailed Explanation

### The Generic Host (`Microsoft.Extensions.Hosting`)

Introduced in .NET Core 2.1, the Generic Host decoupled the hosting infrastructure from HTTP. It provides:

- **DI container** — `IServiceProvider`
- **Configuration** — `IConfiguration`
- **Logging** — `ILoggerFactory`
- **Lifetime management** — start, run, stop, and graceful shutdown

`WebApplication.CreateBuilder` wraps the Generic Host internally; the host is accessible via `builder.Host`.

### `IHostedService`

```csharp
public interface IHostedService
{
    Task StartAsync(CancellationToken cancellationToken);
    Task StopAsync(CancellationToken cancellationToken);
}
```

When the host starts, it calls `StartAsync` on all registered hosted services **in registration order**. When shutting down (SIGTERM, Ctrl+C, or `IHostApplicationLifetime.StopApplication()`), it calls `StopAsync` in **reverse registration order** and waits up to `HostOptions.ShutdownTimeout` (default: 30 s).

### `BackgroundService`

`BackgroundService` implements `IHostedService` and:

1. Starts a `Task` that calls your `ExecuteAsync(CancellationToken stoppingToken)`.
2. When the host stops, cancels `stoppingToken` and awaits the task.
3. Surfacing exceptions: **if `ExecuteAsync` throws, the host logs the error but by default does NOT stop the process** (changed in .NET 6+ with `BackgroundServiceExceptionBehavior.StopHost`).

```
IHostedService
    └── BackgroundService (abstract)
            └── YourWorker (concrete)
```

### Exception behavior (important .NET 6 change)

| Setting | Behavior on exception from `ExecuteAsync` |
|---|---|
| `Ignore` (pre-.NET 6 default) | Log error, keep host running |
| `StopHost` (.NET 6+ default) | Log error, trigger graceful shutdown |

Configure via:
```csharp
builder.Services.Configure<HostOptions>(opts =>
    opts.BackgroundServiceExceptionBehavior = BackgroundServiceExceptionBehavior.Ignore);
```

### Registration order and startup sequencing

Hosted services start in the order they are registered. Use `IHostedServiceShutdownCompletionToken` or explicit `IHostApplicationLifetime` events if you need sequencing guarantees.

### `IHostedLifecycleService` (.NET 8+)

Adds `StartingAsync` / `StartedAsync` / `StoppingAsync` / `StoppedAsync` hooks for finer lifecycle control, useful when one service must fully start before another.

## Code Example

```csharp
// Worker.cs — concrete BackgroundService
namespace MyApp;

public sealed class QueueProcessorWorker(
    ILogger<QueueProcessorWorker> logger,
    IServiceScopeFactory scopeFactory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Worker started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                // Create a scope for scoped services (e.g., DbContext)
                await using var scope = scopeFactory.CreateAsyncScope();
                var processor = scope.ServiceProvider.GetRequiredService<IMessageProcessor>();
                await processor.ProcessNextAsync(stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break; // graceful shutdown requested
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unhandled exception in worker");
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken); // back-off
            }
        }

        logger.LogInformation("Worker stopping");
    }
}
```

```csharp
// Program.cs — registration
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHostedService<QueueProcessorWorker>();

// Configure shutdown timeout
builder.Services.Configure<HostOptions>(opts =>
    opts.ShutdownTimeout = TimeSpan.FromSeconds(15));

var app = builder.Build();
app.MapControllers();
app.Run();
```

```csharp
// Pure worker (no HTTP) — Worker Service template
var host = Host.CreateDefaultBuilder(args)
    .ConfigureServices(services =>
    {
        services.AddHostedService<QueueProcessorWorker>();
    })
    .Build();

await host.RunAsync();
```

## Common Follow-up Questions

- How do you use a **scoped** service (e.g., `DbContext`) inside a `BackgroundService` without a captive dependency issue?
- What happens to in-flight work in `ExecuteAsync` when SIGTERM is received?
- How do you start multiple `BackgroundService` instances of the same type with different configurations?
- What is `IHostedLifecycleService` and when would you use it over `IHostedService`?
- How do you unit-test a `BackgroundService` without starting a full host?

## Common Mistakes / Pitfalls

- **Injecting a `Scoped` service directly into `BackgroundService`** — `BackgroundService` is registered as a Singleton; injecting Scoped services causes a captive dependency. Use `IServiceScopeFactory` instead. See [di-with-hosted-services.md](di-with-hosted-services.md).
- **Not awaiting `ExecuteAsync` properly** — `BackgroundService.StartAsync` fires `ExecuteAsync` without awaiting it (the returned Task is stored). If you `await` a never-ending task inside `StartAsync`, the host start hangs.
- **Swallowing `OperationCanceledException`** — when `stoppingToken` is cancelled you should exit the loop, not retry indefinitely.
- **Assuming `StopAsync` has unlimited time** — by default the host waits 30 seconds then forcefully exits. Long teardown work must complete within this window or increase `ShutdownTimeout`.
- **Pre-.NET 6 exception behavior** — in older apps, exceptions silently disappear; add explicit error handling and alerting.

## References

- [Microsoft Learn — Background tasks with hosted services](https://learn.microsoft.com/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-8.0)
- [Microsoft Learn — Generic Host](https://learn.microsoft.com/aspnet/core/fundamentals/host/generic-host?view=aspnetcore-8.0)
- [Andrew Lock — Series on BackgroundService](https://andrewlock.net/tag/background-tasks/) (verify URL)
- [Microsoft — BackgroundService source code](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.Hosting.Abstractions/src/BackgroundService.cs)
- [Microsoft Learn — IHostedLifecycleService (.NET 8)](https://learn.microsoft.com/dotnet/api/microsoft.extensions.hosting.ihostedlifecycleservice?view=dotnet-plat-ext-8.0)
