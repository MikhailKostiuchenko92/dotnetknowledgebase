# BackgroundService — Long-Running Work in ASP.NET Core

**Category:** ASP.NET Core / Hosting
**Difficulty:** 🟡 Middle
**Tags:** `BackgroundService`, `IHostedService`, `background-tasks`, `cancellation`, `scoped-di`

## Question

> How do you implement long-running background work in ASP.NET Core using `BackgroundService`, and how do you handle graceful shutdown?

## Short Answer

You subclass `BackgroundService`, override `ExecuteAsync(CancellationToken stoppingToken)`, and implement your loop there. When the host receives a shutdown signal (SIGTERM, Ctrl+C, `StopApplication()`), the framework cancels `stoppingToken` — your loop should watch for this and exit cleanly. Scoped services (like `DbContext`) cannot be injected directly; use `IServiceScopeFactory` to create a scope per unit of work.

## Detailed Explanation

### The `BackgroundService` lifecycle

```
Host.StartAsync()
  └── IHostedService.StartAsync(CancellationToken hostStart)
        └── _executingTask = ExecuteAsync(stoppingToken)  // fired, not awaited

Host.StopAsync()
  └── IHostedService.StopAsync(CancellationToken hostStop)
        └── _stoppingCts.Cancel()              // cancels stoppingToken
            await _executingTask               // wait up to ShutdownTimeout
```

Key point: `StartAsync` stores the `Task` returned by `ExecuteAsync` but does **not** await it, so the host can continue starting other services. The task is awaited in `StopAsync`.

### Graceful shutdown — the correct pattern

```csharp
protected override async Task ExecuteAsync(CancellationToken stoppingToken)
{
    while (!stoppingToken.IsCancellationRequested)
    {
        await DoWorkAsync(stoppingToken);                       // pass token everywhere
        await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken); // interruptible sleep
    }
}
```

Passing `stoppingToken` to every awaitable (including `Task.Delay`) allows the OS-level signal to cancel all pending I/O immediately, rather than waiting for the next loop iteration.

### `IHostOptions.ShutdownTimeout`

The host waits this long (default: **30 seconds**) for all hosted services to finish their `StopAsync`. If the timeout elapses, the process is terminated forcefully.

```csharp
builder.Services.Configure<HostOptions>(o =>
    o.ShutdownTimeout = TimeSpan.FromSeconds(20));
```

### Exception behavior (.NET 6+)

By default in .NET 6+, if `ExecuteAsync` throws an unhandled exception, the host triggers a graceful shutdown (`StopHost` behavior). In older versions the exception was silently logged and the host continued.

```csharp
builder.Services.Configure<HostOptions>(o =>
    o.BackgroundServiceExceptionBehavior = BackgroundServiceExceptionBehavior.Ignore);
```

### Scoped services inside `BackgroundService`

`BackgroundService` is a **Singleton** (registered via `AddHostedService`). Injecting `DbContext` or any Scoped service directly causes a **captive dependency** error (with scope validation enabled) or a silent scope violation.

**Correct pattern** — create a scope per unit of work:

```csharp
public class ReportGenerator(IServiceScopeFactory scopeFactory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await using var scope = scopeFactory.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            // use db here; scope disposes DbContext at end of using block
            await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }
}
```

### Queued background work — `Channel<T>`

For producer–consumer patterns, inject a `Channel<T>` as a Singleton and have the background service drain it:

```csharp
// Enqueue work from a controller
channel.Writer.TryWrite(new SendEmailRequest(...));

// Background service processes the queue
while (await channel.Reader.WaitToReadAsync(stoppingToken))
    while (channel.Reader.TryRead(out var item))
        await ProcessAsync(item, stoppingToken);
```

## Code Example

```csharp
// EmailDispatchWorker.cs
namespace MyApp.Workers;

public sealed class EmailDispatchWorker(
    ILogger<EmailDispatchWorker> logger,
    IServiceScopeFactory scopeFactory,
    Channel<EmailRequest> queue) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Email dispatch worker started");

        await foreach (var request in queue.Reader.ReadAllAsync(stoppingToken))
        {
            try
            {
                await using var scope = scopeFactory.CreateAsyncScope();
                var sender = scope.ServiceProvider.GetRequiredService<IEmailSender>();
                await sender.SendAsync(request, stoppingToken);
                logger.LogInformation("Email sent to {Recipient}", request.To);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to send email to {Recipient}", request.To);
                // continue processing next item — don't crash the worker
            }
        }

        logger.LogInformation("Email dispatch worker stopping");
    }
}
```

```csharp
// Program.cs
builder.Services.AddSingleton(Channel.CreateUnbounded<EmailRequest>());
builder.Services.AddHostedService<EmailDispatchWorker>();

builder.Services.Configure<HostOptions>(o =>
    o.ShutdownTimeout = TimeSpan.FromSeconds(10));
```

## Common Follow-up Questions

- How would you implement a scheduled background task (cron-style) without a third-party library?
- How do you run multiple instances of the same `BackgroundService` type (e.g., per tenant)?
- How do you expose health information about a background service's state?
- What is `IHostedLifecycleService` and when does it matter over plain `IHostedService`?
- How would you unit-test a `BackgroundService` that uses a `Channel<T>`?

## Common Mistakes / Pitfalls

- **Not passing `stoppingToken` to inner awaitable calls** — the service keeps running after shutdown is requested until the current `await` finishes naturally.
- **Injecting Scoped services directly** — use `IServiceScopeFactory`. See [scoped-in-singleton-pitfall.md](scoped-in-singleton-pitfall.md).
- **Using `Task.Run(...)` inside `ExecuteAsync` without forwarding cancellation** — creates orphaned tasks that outlive the host.
- **Swallowing all exceptions silently** — at minimum log them; in .NET 6+ an uncaught exception will trigger host shutdown.
- **Blocking inside `ExecuteAsync`** — calling `.Result` or `.Wait()` on Tasks blocks a thread pool thread unnecessarily. Always `await`.

## References

- [Microsoft Learn — Background tasks with hosted services](https://learn.microsoft.com/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-8.0)
- [Microsoft Learn — Worker services in .NET](https://learn.microsoft.com/dotnet/core/extensions/workers)
- [Andrew Lock — Running async tasks on app startup in ASP.NET Core](https://andrewlock.net/running-async-tasks-on-app-startup-in-asp-net-core-part-1/) (verify URL)
- [Stephen Cleary — BackgroundService](https://blog.stephencleary.com/2020/05/backgroundservice-gotcha-startup.html) (verify URL)
- [Microsoft — BackgroundService source](https://github.com/dotnet/runtime/blob/main/src/libraries/Microsoft.Extensions.Hosting.Abstractions/src/BackgroundService.cs)
