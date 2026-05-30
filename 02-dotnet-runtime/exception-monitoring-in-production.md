# How Do You Monitor Exceptions in Production .NET Apps?

**Category:** .NET Runtime / Diagnostics
**Difficulty:** 🟡 Middle
**Tags:** `exceptions`, `ILogger`, `AppDomain`, `TaskScheduler`, `DiagnosticSource`

## Question

> How do you monitor unhandled exceptions and background task failures in a production .NET service?

Also asked as:
> What do `AppDomain.UnhandledException` and `TaskScheduler.UnobservedTaskException` actually tell you?
> How would you wire exception telemetry into a hosted ASP.NET Core application?

## Short Answer

Production exception monitoring has layers. `AppDomain.UnhandledException` is a last-chance notification before the process typically terminates, `TaskScheduler.UnobservedTaskException` surfaces faulted tasks that were never awaited, and application logging plus telemetry SDKs provide the main operational signal. In real systems you combine structured `ILogger` logging, correlation IDs or trace IDs, graceful shutdown hooks through `IHostApplicationLifetime.ApplicationStopping`, and an exporter such as Application Insights, Sentry, Datadog, or Seq.

## Detailed Explanation

### Start with Normal Logging, Not Only Last-Chance Hooks

The most important idea is that last-chance exception events are **not** your primary monitoring strategy. Your primary strategy should be structured logging at the point where the exception is handled or where the request pipeline captures it. That gives you stack trace, route, tenant, trace ID, and other context while the application is still in a known state.

| Mechanism | What it is good for |
|---|---|
| `ILogger` + middleware | Normal request and background exception telemetry |
| `AppDomain.UnhandledException` | Final signal before crash or forced termination |
| `TaskScheduler.UnobservedTaskException` | Faulted tasks that were abandoned |
| `ApplicationStopping` | Cleanup and final flush during graceful shutdown |
| Telemetry SDKs | Centralized storage, alerting, correlation, dashboards |

### Understanding the Runtime Hooks

`AppDomain.UnhandledException` runs when an exception escapes all handling and reaches the runtime boundary. In a server process that usually means the process is about to die, so the handler should do as little as possible: emit minimal telemetry, flush what can be flushed, and avoid complex recovery logic.

`TaskScheduler.UnobservedTaskException` is often misunderstood. It does **not** fire for every task failure. It fires for tasks that faulted and were never observed through `await`, `Wait`, `Result`, or equivalent handling. That means it is a code-smell detector for fire-and-forget mistakes, not a replacement for proper async exception handling.

### Correlation and Observability Backends

In production, exception events are most useful when correlated with requests, spans, and logs. That is why `ILogger` plus Serilog/Seq, Application Insights, Sentry, or Datadog is so common. The log record should include route, operation name, user-safe identifiers, and trace/span IDs if distributed tracing is enabled.

ASP.NET Core and many libraries also publish diagnostics through `DiagnosticSource`, including the `Microsoft.AspNetCore` sources. Telemetry libraries can listen to those sources to attach request and exception context automatically.

> Warning: never rely on `AppDomain.UnhandledException` to “recover” a corrupted process. Treat it as a final reporting hook, not as a resiliency mechanism.

### Graceful Shutdown

`IHostApplicationLifetime.ApplicationStopping` is not an exception event, but it belongs in the same conversation. If Kubernetes, systemd, or IIS is stopping the app, this hook lets you stop accepting work, drain background queues, and flush telemetry cleanly. That matters because otherwise your exception pipeline may drop the most important events during shutdown.

### A Sensible Production Playbook

In practice, teams should alert on exception rate, not only on single crash events. A sudden spike in handled exceptions can be just as operationally important as an app-domain crash because it often signals a dependency outage, schema drift, or bad rollout. Good production setups therefore combine logs, traces, and metrics: structured error records for detail, trace correlation for request context, and dashboards for rate-based alerting. The runtime hooks are the safety net at the edge of failure, but day-to-day monitoring should happen much earlier in the flow.

For exception design itself, see [exception-design-guidelines.md](./exception-design-guidelines.md). For low-level diagnostics pipelines, see [event-source-and-etw.md](./event-source-and-etw.md).

## Code Example

```csharp
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace DotNetRuntimeSamples.ExceptionMonitoring;

internal static class Program
{
    private static async Task Main()
    {
        using IHost host = Host.CreateDefaultBuilder()
            .ConfigureServices(services => services.AddHostedService<Worker>())
            .Build();

        var logger = host.Services.GetRequiredService<ILoggerFactory>().CreateLogger("Startup");
        var lifetime = host.Services.GetRequiredService<IHostApplicationLifetime>();

        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
            logger.LogCritical(args.ExceptionObject as Exception, "Unhandled exception reached AppDomain.");

        TaskScheduler.UnobservedTaskException += (_, args) =>
        {
            logger.LogError(args.Exception, "Observed abandoned task failure.");
            args.SetObserved(); // Prevent escalation when appropriate.
        };

        lifetime.ApplicationStopping.Register(() => logger.LogInformation("Application stopping; flushing telemetry."));

        await host.RunAsync();
    }
}

internal sealed class Worker(ILogger<Worker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            throw new InvalidOperationException("Sample background failure.");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Background worker failed with TraceId={TraceId}", System.Diagnostics.Activity.Current?.TraceId);
        }

        await Task.Delay(Timeout.Infinite, stoppingToken);
    }
}
```

## Common Follow-up Questions

- Why is `TaskScheduler.UnobservedTaskException` not a substitute for awaiting tasks?
- What data should be included in structured exception logs?
- Why should last-chance handlers do very little work?
- How do tracing IDs improve exception investigations?
- How do Application Insights, Sentry, or Datadog typically integrate with ASP.NET Core?

## Common Mistakes / Pitfalls

- Treating `AppDomain.UnhandledException` as a recovery mechanism.
- Assuming every background task failure will automatically appear in `UnobservedTaskException`.
- Logging exceptions as plain strings instead of structured exception objects.
- Losing telemetry during shutdown because nothing flushes on `ApplicationStopping`.
- Using fire-and-forget tasks in request handlers without explicit observation and error handling.

## References

- [AppDomain.UnhandledException Event — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.appdomain.unhandledexception)
- [TaskScheduler.UnobservedTaskException Event — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.taskscheduler.unobservedtaskexception)
- [Logging in .NET — Microsoft Learn](https://learn.microsoft.com/dotnet/core/extensions/logging)
- [Generic Host in .NET — Microsoft Learn](https://learn.microsoft.com/dotnet/core/extensions/generic-host)
- [Distributed tracing concepts — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/distributed-tracing-concepts)
