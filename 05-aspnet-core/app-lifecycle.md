# App Lifecycle — IHostApplicationLifetime

**Category:** ASP.NET Core / Hosting
**Difficulty:** 🟡 Middle
**Tags:** `IHostApplicationLifetime`, `lifetime`, `graceful-shutdown`, `startup`, `cancellation`

## Question

> What is `IHostApplicationLifetime`, and how do you hook into application startup, stopping, and stopped events?

## Short Answer

`IHostApplicationLifetime` exposes three `CancellationToken` properties — `ApplicationStarted`, `ApplicationStopping`, and `ApplicationStopped` — that are cancelled when those lifecycle moments occur. You register callbacks via `Register(...)` on those tokens to run logic at each phase, such as warming up caches on start or draining connections on stop.

## Detailed Explanation

### The three lifecycle tokens

| Token | Triggered when... | Typical use |
|---|---|---|
| `ApplicationStarted` | Host is fully started; all `IHostedService.StartAsync` calls completed | Warm up caches, emit a "ready" log, start probes |
| `ApplicationStopping` | Shutdown initiated; `StopAsync` calls beginning but not finished | Close connections, stop accepting new work |
| `ApplicationStopped` | All `IHostedService.StopAsync` calls completed; process about to exit | Final cleanup, flush logs, release handles |

### Registering callbacks

```csharp
lifetime.ApplicationStarted.Register(() => logger.LogInformation("App started"));
lifetime.ApplicationStopping.Register(() => logger.LogWarning("App stopping"));
lifetime.ApplicationStopped.Register(() => logger.LogInformation("App stopped"));
```

Callbacks are invoked synchronously on the thread that triggers the cancellation. Avoid long-blocking operations — use fire-and-forget with proper error handling if needed.

### Triggering shutdown programmatically

```csharp
lifetime.StopApplication(); // equivalent to sending SIGTERM
```

This is useful in hosted services that detect an unrecoverable error and want to bring the whole process down gracefully.

### `IHostLifetime` vs `IHostApplicationLifetime`

- **`IHostApplicationLifetime`** — application-level events (Started/Stopping/Stopped).
- **`IHostLifetime`** — infrastructure-level; handles OS signals (`ConsoleLifetime` listens to SIGTERM/Ctrl+C). You rarely implement this yourself.

### Shutdown sequence (complete picture)

```
1. OS sends SIGTERM / IHostApplicationLifetime.StopApplication() called
2. ConsoleLifetime (or platform lifetime) triggers host StopAsync
3. ApplicationStopping cancellation token is cancelled (callbacks invoked)
4. All IHostedService.StopAsync() called in reverse registration order
5. ApplicationStopped cancellation token is cancelled (callbacks invoked)
6. DI container disposed (IDisposable singletons cleaned up)
7. Process exits
```

Steps 4 through 6 must complete within `HostOptions.ShutdownTimeout` (default 30 s).

### Using lifetime in `Program.cs`

```csharp
var app = builder.Build();

var lifetime = app.Services.GetRequiredService<IHostApplicationLifetime>();
lifetime.ApplicationStarted.Register(() =>
    app.Logger.LogInformation("🚀 Application started on {Env}", app.Environment.EnvironmentName));

app.Run();
```

## Code Example

```csharp
// CacheWarmupService.cs — uses lifetime tokens for sequenced startup/shutdown
namespace MyApp.Services;

public sealed class CacheWarmupService(
    IHostApplicationLifetime lifetime,
    ILogger<CacheWarmupService> logger,
    ICacheStore cache) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        // Register on ApplicationStarted so the HTTP server is ready before warming
        lifetime.ApplicationStarted.Register(async () =>
        {
            try
            {
                logger.LogInformation("Pre-warming cache...");
                await cache.WarmUpAsync();
                logger.LogInformation("Cache warm-up complete");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Cache warm-up failed");
                // Optionally force shutdown if warm-up is critical:
                // lifetime.StopApplication();
            }
        });

        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        logger.LogInformation("CacheWarmupService stopping");
        return Task.CompletedTask;
    }
}
```

```csharp
// Program.cs
builder.Services.AddHostedService<CacheWarmupService>();
builder.Services.AddSingleton<ICacheStore, InMemoryCacheStore>();

var app = builder.Build();

// Direct registration in Program.cs (alternative pattern)
var appLifetime = app.Services.GetRequiredService<IHostApplicationLifetime>();
appLifetime.ApplicationStopping.Register(() =>
    app.Logger.LogWarning("Shutdown in progress — stopping accepting new work"));

app.MapControllers();
app.Run();
```

### Async callbacks (pattern — Register only accepts synchronous delegates)

```csharp
// Register does not accept async delegates; use this pattern
lifetime.ApplicationStopping.Register(() =>
{
    // Fire-and-forget with a bounded timeout
    Task.Run(async () =>
    {
        await FlushTelemetryAsync();
    }).GetAwaiter().GetResult(); // block briefly; respect ShutdownTimeout
});
```

> **Warning:** `Register(Action)` is synchronous. If you need async cleanup, implement a proper `IHostedService` with `StopAsync` instead of relying on lifetime callbacks for async work.

## Common Follow-up Questions

- What is the difference between `ApplicationStopping` and `ApplicationStopped`? When would you use each?
- How do you ensure that database connections are fully flushed before the process exits?
- What happens if a `Register` callback throws an exception?
- How does `IHostApplicationLifetime.StopApplication()` interact with `IHostedService.StopAsync` cancellation tokens?
- How would you implement a "drain" pattern where an API stops accepting new requests while finishing in-flight ones?

## Common Mistakes / Pitfalls

- **Using `ApplicationStopped` for cleanup that needs the DI container** — at `ApplicationStopped` the container may already be partially disposed. Do cleanup in `IHostedService.StopAsync` or `ApplicationStopping` instead.
- **Registering async lambdas with `Register()`** — `Register(async () => ...)` creates an `async void` delegate, which hides exceptions. Use synchronous delegates or a proper `IHostedService`.
- **Not honoring `ShutdownTimeout`** — if a callback blocks longer than the remaining shutdown window, the process is killed, losing cleanup work.
- **Calling `StopApplication()` in `StartAsync`** — if called before startup completes, it races with the startup sequence and can leave the app in a partially started state.
- **Forgetting that callbacks are invoked on the cancellation thread** — don't do expensive synchronous work there; it can delay the shutdown of other services.

## References

- [Microsoft Learn — IHostApplicationLifetime](https://learn.microsoft.com/dotnet/api/microsoft.extensions.hosting.ihostapplicationlifetime?view=dotnet-plat-ext-8.0)
- [Microsoft Learn — Generic Host in .NET](https://learn.microsoft.com/aspnet/core/fundamentals/host/generic-host?view=aspnetcore-8.0)
- [Andrew Lock — Running async startup tasks in ASP.NET Core](https://andrewlock.net/running-async-tasks-on-app-startup-in-asp-net-core-part-1/) (verify URL)
- [Microsoft Learn — App shutdown with Graceful Shutdown](https://learn.microsoft.com/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-8.0#graceful-shutdown)
