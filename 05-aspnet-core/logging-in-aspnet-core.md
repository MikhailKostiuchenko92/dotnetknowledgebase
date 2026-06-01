# Logging in ASP.NET Core

**Category:** ASP.NET Core / Performance & Diagnostics
**Difficulty:** 🟢 Junior
**Tags:** `ILogger`, `ILoggerFactory`, `log-levels`, `structured-logging`, `Serilog`, `NLog`, `OpenTelemetry`

## Question

> How does the `ILogger<T>` abstraction work in ASP.NET Core? What is structured logging, and how do you wire in Serilog or NLog?

## Short Answer

`ILogger<T>` is the built-in logging abstraction injected via DI. Log messages are filtered by **category** (the generic type parameter) and **minimum log level** configured per category in `appsettings.json`. **Structured logging** preserves message template parameters as named properties (not just string substitution), enabling rich querying in log stores (Seq, Elastic, Datadog). Serilog and NLog are popular third-party providers that integrate with `ILogger<T>` via the `Microsoft.Extensions.Logging` provider system and add sinks, enrichers, and formatting.

## Detailed Explanation

### `ILogger<T>` basics

```csharp
public class OrderService(ILogger<OrderService> logger)
{
    public async Task<Order> CreateAsync(CreateOrderRequest req)
    {
        // Structured message — {OrderId} becomes a named property in log stores
        logger.LogInformation("Creating order {OrderId} for customer {CustomerId}",
            Guid.NewGuid(), req.CustomerId);

        try
        {
            // ...
            logger.LogDebug("Order created successfully. Items: {@Items}", req.Items);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to create order for customer {CustomerId}", req.CustomerId);
            throw;
        }
    }
}
```

### Log levels

| Level | Numeric | Use |
|---|---|---|
| `Trace` | 0 | Most verbose — execution flow |
| `Debug` | 1 | Development diagnostics |
| `Information` | 2 | Normal operational events |
| `Warning` | 3 | Unexpected, but recoverable |
| `Error` | 4 | Error requiring attention |
| `Critical` | 5 | Failure, app may not continue |
| `None` | 6 | Disable logging |

### Category filtering in `appsettings.json`

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore.Database.Command": "Information",
      "MyApp.Services": "Debug"
    }
  }
}
```

### Structured logging: `@` destructuring operator

```csharp
// With @ prefix: serializes the entire object as a JSON property
logger.LogInformation("Order placed: {@Order}", order);

// Without @: calls ToString()
logger.LogInformation("Order placed: {Order}", order.ToString());
```

### High-performance logging with source generators (.NET 6+)

`LoggerMessage.Define` and `[LoggerMessage]` attribute generate cached delegates, avoiding boxing/string allocation on hot paths:

```csharp
public static partial class LogEvents
{
    [LoggerMessage(EventId = 1001, Level = LogLevel.Information, Message = "Order {OrderId} created")]
    public static partial void OrderCreated(this ILogger logger, Guid orderId);

    [LoggerMessage(EventId = 1002, Level = LogLevel.Error, Message = "Order {OrderId} failed")]
    public static partial void OrderFailed(this ILogger logger, Exception ex, Guid orderId);
}

// Usage
logger.OrderCreated(order.Id);
logger.OrderFailed(ex, order.Id);
```

### Serilog integration

```bash
dotnet add package Serilog.AspNetCore
dotnet add package Serilog.Sinks.Console
dotnet add package Serilog.Sinks.Seq
```

```csharp
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithMachineName()
    .Enrich.WithEnvironmentName()
    .WriteTo.Console(new JsonFormatter())
    .WriteTo.Seq("http://seq-server:5341")
    .CreateLogger();

builder.Host.UseSerilog(); // replaces default ILogger providers
```

### NLog integration

```bash
dotnet add package NLog.Web.AspNetCore
```

```csharp
builder.Host.UseNLog();
```

## Code Example

```csharp
// Structured logging with scopes
public class PaymentService(ILogger<PaymentService> logger)
{
    public async Task ProcessAsync(Payment payment)
    {
        // Scope adds properties to all log statements within the block
        using var scope = logger.BeginScope(new Dictionary<string, object>
        {
            ["PaymentId"] = payment.Id,
            ["Amount"] = payment.Amount,
            ["Currency"] = payment.Currency
        });

        logger.LogInformation("Processing payment");

        if (payment.Amount > 10_000)
            logger.LogWarning("Large payment detected: {Amount} {Currency}",
                payment.Amount, payment.Currency);

        await Task.Delay(10); // simulate processing

        logger.LogInformation("Payment processed successfully. CorrelationId: {CorrelationId}",
            payment.CorrelationId);
    }
}
```

```csharp
// appsettings.json for production
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft.AspNetCore": "Warning",
        "System.Net.Http.HttpClient": "Warning"
      }
    },
    "WriteTo": [
      { "Name": "Console", "Args": { "formatter": "Serilog.Formatting.Json.JsonFormatter, Serilog.Formatting.Json" } }
    ],
    "Enrich": ["FromLogContext", "WithMachineName", "WithThreadId"]
  }
}
```

## Common Follow-up Questions

- What is the performance difference between `LogInformation("Value: " + value)` and `LogInformation("Value: {Value}", value)`?
- How does `ILogger` scope work with OpenTelemetry trace context?
- What is `ILoggerFactory` and when would you use it instead of `ILogger<T>`?
- How do you unit-test code that uses `ILogger<T>`?
- How do you configure different minimum levels for different environments?

## Common Mistakes / Pitfalls

- **String interpolation in log messages** — `$"Value is {x}"` allocates a string even when the log level is filtered out; use message templates `"Value is {X}", x` so allocation only happens when the event is actually emitted.
- **Not checking `logger.IsEnabled(LogLevel.Debug)`** — for expensive debug-only operations, guard with `IsEnabled()` to avoid building the message object unnecessarily.
- **Logging sensitive data (passwords, PII, tokens)** — structured logging persists properties to external systems; never log secrets. Use `{@User}` only for non-sensitive objects.
- **Calling `Log.CloseAndFlush()` (Serilog) at application shutdown** — without this, async sinks may lose the last batch of log events on graceful shutdown. Register in `IHostApplicationLifetime.ApplicationStopped` or as a final `builder.Build().Run()` cleanup.
- **Using `ILogger` (non-generic) in DI** — `ILogger<T>` creates a category from the type name; plain `ILogger` requires the category to be set manually. Prefer `ILogger<T>`.

## References

- [Microsoft Learn — Logging in .NET](https://learn.microsoft.com/aspnet/core/fundamentals/logging/?view=aspnetcore-8.0)
- [Microsoft Learn — High-performance logging](https://learn.microsoft.com/dotnet/core/extensions/high-performance-logging)
- [Serilog — ASP.NET Core integration](https://github.com/serilog/serilog-aspnetcore)
- [NLog — Getting started with ASP.NET Core](https://nlog-project.org/documentation/v5.2.0/tutorial-aspnet.html) (verify URL)
