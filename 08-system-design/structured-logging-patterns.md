# Structured Logging Patterns

**Category:** System Design / Observability
**Difficulty:** Middle
**Tags:** `logging`, `serilog`, `structured-logging`, `correlation-id`, `pii`, `log-aggregation`

## Question

> What is structured logging and why does it matter in a distributed system? How do you implement it in a .NET application? How do you handle correlation IDs, PII scrubbing, and log aggregation?

- What is the difference between `ILogger` and Serilog — why would you use Serilog?
- How do you prevent sensitive data from appearing in logs?

## Short Answer

Structured logging emits log entries as machine-parseable key-value records (JSON) rather than free-form strings. This enables filtering (`level=ERROR AND service=orders`), aggregation (count errors by `customerId`), and correlation (join all logs for `traceId=X` across services). In .NET, `Microsoft.Extensions.Logging` (`ILogger<T>`) provides the abstraction; Serilog or NLog are popular sinks that format and ship logs. Always log `traceId`, `spanId`, and a `correlationId` on every entry. Scrub PII at the sink level using destructuring policies, not at the call site — this prevents accidental leaks in catch blocks and framework-level logs.

## Detailed Explanation

### Structured vs Unstructured

```csharp
// ❌ Unstructured — queryable only by regex
_logger.LogInformation($"Order {orderId} placed by {userId} for £{amount}");
// Log: "Order ord_123 placed by usr_456 for £49.99"

// ✅ Structured — queryable by field
_logger.LogInformation("Order {OrderId} placed by {UserId} for {Amount}",
    orderId, userId, amount);
// JSON: {"level":"info","message":"Order placed","OrderId":"ord_123","UserId":"usr_456","Amount":49.99}
```

In the structured version, you can query: `OrderId = "ord_123"` or `Amount > 100` without regex.

### Microsoft.Extensions.Logging vs Serilog

`Microsoft.Extensions.Logging` (MEL) is the standard .NET abstraction. `ILogger<T>` is what you inject; the underlying provider (Console, Serilog, NLog) is configured at startup.

**Serilog advantages over built-in MEL providers**:
- **Destructuring**: `{@Order}` serialises complex objects as nested JSON, not `.ToString()`
- **Enrichers**: automatic properties on every log event (machine name, thread ID, trace ID)
- **Sinks ecosystem**: 60+ sinks (Elasticsearch, Loki, Seq, Application Insights, Azure Log Analytics)
- **Log context**: `LogContext.PushProperty` adds properties to all logs in a scope
- **Sub-logger routing**: route `Error` to PagerDuty, `Warning` to Slack, `Info` to Loki

### Log Levels — Use Them Correctly

| Level | When to Use |
|-------|-------------|
| `Trace` | Very detailed — loop iterations, raw bytes. Disabled in production. |
| `Debug` | Diagnostic — function entry/exit, intermediate values. Disabled in production. |
| `Information` | Business events — "Order placed", "User logged in". |
| `Warning` | Unexpected but handled — retry attempt, degraded mode, fallback used. |
| `Error` | Something failed that shouldn't have — exception, data corruption. |
| `Critical` | System is down or data is at risk — process must restart. |

> **Warning:** Log at `Information` for business events, not `Debug`. Developers often log everything at `Debug` and nothing at `Information`, making production logs useless. At prod, `Debug` is typically disabled.

### Correlation IDs

A correlation ID ties together all log entries for a single user request across all services. Without it, you're searching by time range and hoping.

```csharp
// Middleware: ensure every request has a correlation ID
app.Use(async (ctx, next) =>
{
    var correlationId = ctx.Request.Headers["X-Correlation-Id"].FirstOrDefault()
        ?? Guid.NewGuid().ToString("N");

    ctx.Response.Headers["X-Correlation-Id"] = correlationId;

    // Add to Serilog's log context — appears on EVERY log entry in this request
    using (LogContext.PushProperty("CorrelationId", correlationId))
    using (LogContext.PushProperty("UserId", ctx.User?.FindFirst("sub")?.Value))
    {
        await next();
    }
});
```

When calling downstream services, propagate the header:
```csharp
httpClient.DefaultRequestHeaders.Add("X-Correlation-Id",
    Activity.Current?.TraceId.ToString() ?? Guid.NewGuid().ToString("N"));
```

Prefer using W3C `traceparent` (OpenTelemetry) as the correlation ID — it's standardised and integrates with tracing backends.

### PII Scrubbing

**Strategy**: define what is PII, then scrub it at the infrastructure level (sink/enricher), not at every call site. Scrubbing at the call site is error-prone — one forgotten `catch (ex) { _logger.LogError(ex, "Failed for {User}", user); }` leaks the data.

```csharp
// Serilog destructuring policy — mask Email on any object
public sealed class PiiDestructuringPolicy : IDestructuringPolicy
{
    private static readonly HashSet<string> _piiFields =
        new(StringComparer.OrdinalIgnoreCase)
        { "email", "password", "creditcard", "ssn", "phonenumber", "token" };

    public bool TryDestructure(object value, ILogEventPropertyValueFactory factory,
        out LogEventPropertyValue result)
    {
        if (value is not IEnumerable<KeyValuePair<string, object>> dict)
        {
            result = null!;
            return false;
        }

        var properties = dict
            .Select(kv => new LogEventProperty(kv.Key,
                _piiFields.Contains(kv.Key)
                    ? new ScalarValue("***REDACTED***")
                    : factory.CreatePropertyValue(kv.Value, true)))
            .ToList();

        result = new StructureValue(properties);
        return true;
    }
}

// Register in Serilog
Log.Logger = new LoggerConfiguration()
    .Destructure.With<PiiDestructuringPolicy>()
    .WriteTo.Console(new JsonFormatter())
    .CreateLogger();
```

Alternatively, mark DTO properties with `[LogMasked]` (Serilog.Enrichers.Sensitive) or use regex sink filters.

### Log Aggregation Architecture

```
Service A (Serilog → stdout JSON)
Service B (Serilog → stdout JSON)   → [Log Shipper: Fluent Bit / Promtail]
Service C (Serilog → stdout JSON)
                                          ↓
                                   [Aggregation Backend]
                                   Loki + Grafana     ← log queries by label
                                   Elasticsearch + Kibana ← full-text + analytics
                                   Azure Log Analytics ← Azure-native
```

In Kubernetes, the standard pattern is: containers write to stdout → Fluent Bit DaemonSet ships to Loki/ES → engineers query via Grafana/Kibana.

### Serilog Setup in .NET 8

```csharp
// Program.cs
using Serilog;
using Serilog.Events;
using Serilog.Formatting.Json;

// Bootstrap logger (before host build — captures startup errors)
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .MinimumLevel.Override("System", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithMachineName()
    .Enrich.WithEnvironmentName()
    .WriteTo.Console(new JsonFormatter()) // JSON to stdout for log shipper
    .CreateBootstrapLogger();

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, services, cfg) => cfg
    .ReadFrom.Configuration(ctx.Configuration)
    .ReadFrom.Services(services)         // inject IHttpContextAccessor etc.
    .Enrich.FromLogContext()
    .Enrich.WithProperty("Application", "orders-api")
    .WriteTo.Console(new JsonFormatter())
    .WriteTo.OpenTelemetry());           // also ship logs via OTLP to OTel Collector

var app = builder.Build();

app.UseSerilogRequestLogging(options =>
{
    options.MessageTemplate =
        "HTTP {RequestMethod} {RequestPath} → {StatusCode} in {Elapsed:0.0}ms";
    options.EnrichDiagnosticContext = (dc, ctx) =>
    {
        dc.Set("UserId", ctx.User?.FindFirst("sub")?.Value);
        dc.Set("RequestHost", ctx.Request.Host.Value);
    };
});
```

## Common Follow-up Questions

- How do you implement log sampling in production (e.g., log only 10% of `Information` events but always log `Error`)?
- What is the difference between log enrichers and log sinks in Serilog?
- How do you correlate a log from a background job (no HTTP context) with the user request that triggered it?
- How do you handle log volume at 100K req/s — what is the risk of synchronous logging?
- What is the difference between Serilog's `{Property}` and `{@Property}` syntax?

## Common Mistakes / Pitfalls

- **String interpolation in log messages**: `_logger.LogInformation($"Order {id}")` loses the structured property `id`; the message template becomes a literal string with no queryable fields.
- **Logging at `Debug` in production**: `Debug` logs in production-level traffic generate GBs/hour; disable below `Information` in production config.
- **Logging sensitive data in exception messages**: `throw new Exception($"Failed to authenticate {password}")` → the exception message ends up in Error logs verbatim.
- **No log level filtering per namespace**: logging `Microsoft.*` at `Verbose` in production generates massive framework noise; set `MinimumLevel.Override("Microsoft", Warning)`.
- **Using `Console.WriteLine` for app logs**: bypasses MEL/Serilog, loses structured format, and doesn't respect log level configuration.
- **Forgetting async sinks**: Serilog sinks can be synchronous (slow write) or async (`WriteTo.Async(...)`). In high-throughput services, always wrap sinks in `WriteTo.Async` to avoid blocking request threads.

## References

- [Serilog — serilog.net](https://serilog.net/)
- [Structured Logging with Serilog and Seq — Nicholas Blumhardt](https://nblumhardt.com/2016/06/structured-logging-concepts-in-net-series-1/) (verify URL)
- [Logging in .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging)
- [Serilog.Sinks.OpenTelemetry](https://github.com/serilog/serilog-sinks-opentelemetry)
- [See: observability-three-pillars.md](./observability-three-pillars.md)
- [See: distributed-tracing.md](./distributed-tracing.md)
