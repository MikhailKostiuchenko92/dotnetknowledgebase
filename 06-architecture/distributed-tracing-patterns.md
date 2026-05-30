# Distributed Tracing Patterns

**Category:** Architecture / Microservices
**Difficulty:** 🔴 Senior
**Tags:** `distributed-tracing`, `OpenTelemetry`, `W3C-trace-context`, `correlation-ID`, `Jaeger`, `Zipkin`, `observability`

## Question

> How does distributed tracing work in microservices? Describe the W3C Trace Context standard, how correlation IDs propagate across services, OpenTelemetry setup in .NET, and how Jaeger or Zipkin visualize trace data.

## Short Answer

Distributed tracing assigns a **trace ID** to a request at the entry point (API gateway or first service) and propagates it to every downstream call as an HTTP header (`traceparent` in W3C Trace Context). Each service creates **spans** — timed segments of work — linked to the trace ID. A trace aggregator (Jaeger, Zipkin, Azure Application Insights) collects all spans and reconstructs the full distributed call tree. In .NET, **OpenTelemetry** is the standard SDK: it auto-instruments `HttpClient`, EF Core, and ASP.NET Core, and exports spans to any OTLP-compatible backend.

## Detailed Explanation

### W3C Trace Context Headers

```
GET /api/orders HTTP/1.1
traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
             ^  ^                               ^               ^
             |  trace-id (128-bit)             span-id        flags
             version (always 00)
tracestate: rojo=00f067aa0ba902b7  ← vendor-specific state

The traceparent is propagated automatically by OpenTelemetry instrumentation.
Each service creates a child span linked to the trace-id from the incoming header.
```

### OpenTelemetry Setup in .NET

```bash
dotnet add package OpenTelemetry.Sdk
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.Http
dotnet add package OpenTelemetry.Instrumentation.EntityFrameworkCore
dotnet add package OpenTelemetry.Exporter.Otlp
```

```csharp
// Program.cs — complete OpenTelemetry setup
builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r
        .AddService("order-service", serviceVersion: "1.0.0")
        .AddAttributes([new("deployment.environment", "production")]))
    .WithTracing(tracing =>
    {
        tracing
            .AddAspNetCoreInstrumentation(options =>
            {
                options.RecordException = true;
                options.Filter = ctx => !ctx.Request.Path.StartsWithSegments("/health");
            })
            .AddHttpClientInstrumentation()  // ← traces all outgoing HttpClient calls
            .AddEntityFrameworkCoreInstrumentation(options =>
                options.SetDbStatementForText = true)  // ← traces EF Core queries
            .AddSource("order-service.*")  // ← custom activity sources
            .AddOtlpExporter(options =>
                options.Endpoint = new Uri("http://jaeger:4317"));  // ← OTLP gRPC
    })
    .WithMetrics(metrics =>
    {
        metrics
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddOtlpExporter();
    });
```

### Custom Spans and Enrichment

```csharp
// Custom ActivitySource for domain-specific spans
public class OrderApplicationService(ActivitySource activitySource)
{
    private static readonly ActivitySource _activitySource = new("order-service.application");

    public async Task<int> PlaceOrderAsync(PlaceOrderCommand cmd, CancellationToken ct)
    {
        using var activity = _activitySource.StartActivity("PlaceOrder");
        activity?.SetTag("order.customer_id", cmd.CustomerId);
        activity?.SetTag("order.line_count", cmd.Lines.Count);

        try
        {
            var orderId = await /* ... */ Task.FromResult(42);
            activity?.SetTag("order.id", orderId);
            activity?.SetStatus(ActivityStatusCode.Ok);
            return orderId;
        }
        catch (Exception ex)
        {
            activity?.RecordException(ex);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            throw;
        }
    }
}

// Register ActivitySource
builder.Services.AddSingleton(new ActivitySource("order-service.application"));
```

### Correlation ID vs Trace ID

```
Correlation ID: application-level concept, often manually managed
  Header: X-Correlation-ID: abc-123
  Used by: logging (serilog enricher), error emails, support tickets

Trace ID: observability-level concept, managed by OpenTelemetry
  Header: traceparent: 00-<trace-id>-<span-id>-01
  Used by: Jaeger/Zipkin, distributed tracing UI, span correlation

Best practice: log the trace ID as a structured property
  log.Information("Order placed {OrderId} traceId={TraceId}",
      orderId, Activity.Current?.TraceId.ToString());
```

### Jaeger: Trace Visualization

```yaml
# Docker Compose: Jaeger all-in-one
services:
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"  # ← Jaeger UI
      - "4317:4317"    # ← OTLP gRPC (OpenTelemetry ingest)
      - "4318:4318"    # ← OTLP HTTP

# Access Jaeger UI: http://localhost:16686
# Search by service: order-service
# Search by trace ID: directly paste trace ID from logs
```

## Code Example

```csharp
// Complete tracing for an order flow
// Trace shows: HTTP POST /orders → PlaceOrder span → EF Core INSERT → HTTP call to InventoryService

// The trace in Jaeger will look like:
// order-service: POST /api/orders (150ms)
//   └─ PlaceOrder (140ms)
//       ├─ EF Core: INSERT Order (5ms)
//       └─ HTTP GET http://inventory-svc/api/stock/42 (100ms)
//           └─ inventory-service: GET /api/stock/42 (95ms)  ← same trace ID!
//               └─ EF Core: SELECT Stock (10ms)

// All of this captured automatically by OpenTelemetry — no manual span creation for HTTP/EF
```

## Common Follow-up Questions

- How do you correlate traces with logs — what is the best approach for structured logging?
- What is sampling in distributed tracing, and when should you sample less than 100%?
- How do you propagate trace context through a message queue (RabbitMQ, Azure Service Bus)?
- What is OpenTelemetry's semantic conventions for HTTP attributes?
- How do you set up distributed tracing in a local development environment?

## Common Mistakes / Pitfalls

- **Not propagating trace context through message queues**: OpenTelemetry auto-instruments HTTP but NOT all message bus SDKs. For RabbitMQ/Service Bus, you must manually inject `traceparent` into message headers.
- **Sampling 100% in production at high throughput**: 10,000 rps × full trace = massive storage cost. Use tail-based sampling (sample failed/slow requests at 100%, success at 1–5%).
- **Logging vs tracing confusion**: trace IDs belong in both logs AND spans. Enrich your Serilog/NLog output with the current trace ID so you can correlate log lines with traces.
- **Not setting service names**: all services showing as "unknown_service" in Jaeger defeats the purpose. Always set `AddService("your-service-name")` in resource configuration.

## References

- [OpenTelemetry .NET documentation](https://opentelemetry.io/docs/languages/net/)
- [W3C Trace Context specification](https://www.w3.org/TR/trace-context/)
- [Jaeger documentation](https://www.jaegertracing.io/docs/)
- [See: sidecar-and-ambassador-patterns.md](./sidecar-and-ambassador-patterns.md)
