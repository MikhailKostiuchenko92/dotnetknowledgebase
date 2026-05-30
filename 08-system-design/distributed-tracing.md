# Distributed Tracing

**Category:** System Design / Microservices
**Difficulty:** Senior
**Tags:** `distributed-tracing`, `opentelemetry`, `sampling`, `trace-context`, `jaeger`, `zipkin`

## Question

> Explain distributed tracing in a microservices system. How does trace context propagate across service boundaries? What is sampling and why is it important? How do you implement distributed tracing in a .NET application with OpenTelemetry?

- What is the difference between a trace, span, and baggage?
- How do you correlate logs with traces?

## Short Answer

Distributed tracing records the path of a single request as it traverses multiple services. Each service creates a **span** (a named, timed operation); spans are grouped into a **trace** by a shared `traceId` propagated in HTTP headers (`traceparent` per W3C TraceContext). A root span at the entry point starts the trace; downstream services create child spans linked by `parentSpanId`. **Sampling** controls what fraction of traces are recorded — head-based sampling (decide at the root span) is simplest; tail-based sampling (decide after seeing the full trace) captures all errors and slow traces. In .NET, OpenTelemetry SDK integrates with `ActivitySource` (the native tracing API) and auto-instruments HttpClient, ASP.NET Core, EF Core, gRPC.

## Detailed Explanation

### Core Concepts

| Concept | Definition |
|---------|-----------|
| **Trace** | The end-to-end record of a single request across all services |
| **Span** | A single timed operation within a trace (e.g., "HTTP GET /orders", "SQL SELECT") |
| **TraceId** | 128-bit ID shared by all spans in a trace |
| **SpanId** | 64-bit ID unique to each span |
| **ParentSpanId** | Links a child span to its parent |
| **Baggage** | Key-value metadata propagated with the trace (e.g., `userId`, `tenantId`) |

### W3C TraceContext — Propagation Headers

The `traceparent` HTTP header carries the trace context between services:

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
              ^  ^---------- traceId (32 hex) ----------^ ^spanId^ ^flags^
              version                                              sampled=1
```

Every outgoing HTTP call propagates this header; every incoming request checks for it to determine if this is a continuation of an existing trace or the start of a new one.

ASP.NET Core reads `traceparent` automatically when OpenTelemetry is configured; `HttpClient` propagates it on outgoing calls. No manual header copying is needed.

### Sampling Strategies

Recording every span for every request at high QPS is expensive (storage, ingestion cost). Sampling controls the trade-off:

| Strategy | How it Works | Trade-off |
|----------|-------------|-----------|
| **Always-on** | Record everything | High cost; good for dev/test |
| **Head-based (probabilistic)** | Decide at root span (e.g., 5%); propagate decision downstream | Simple; may miss errors in the 95% |
| **Rate-limited** | Record up to N traces/s regardless of total QPS | Predictable cost |
| **Tail-based** | Buffer full trace; record if error, slow, or sampled | Best coverage; more complex; requires buffer |
| **Parent-based** | Honour parent's sampling decision | Consistent — span either fully recorded or not |

**Production recommendation**: head-based at 5–10% for baseline coverage + always record traces containing errors or high latency (via `ActivityStatusCode.Error`).

### Span Attributes and Events

Spans carry structured metadata:

```
Span: "HTTP POST /orders"
  traceId:  4bf92f3577b34da6a3ce929d0e0e4736
  spanId:   a3ce929d0e0e4736
  start:    2026-05-30T12:00:00.000Z
  end:      2026-05-30T12:00:00.452Z
  status:   OK
  attributes:
    http.method: POST
    http.url: https://orders-service/orders
    http.status_code: 201
    order.id: ord_abc123
  events:
    - {name: "inventory.reserved", timestamp: ...}
    - {name: "payment.charged",    timestamp: ...}
  child spans:
    - "EF Core: INSERT orders" (12 ms)
    - "HTTP POST /inventory/reserve" (80 ms)
      └── "EF Core: UPDATE inventory" (8 ms)
```

### Correlating Logs with Traces

Log entries become vastly more useful when they include the `traceId` and `spanId`:

```
[2026-05-30 12:00:00.234] INFO  Order placed successfully
  traceId=4bf92f3577b34da6a3ce929d0e0e4736
  spanId=a3ce929d0e0e4736
  orderId=ord_abc123
  userId=usr_789
```

OpenTelemetry automatically injects `TraceId` and `SpanId` into the Serilog log context when both are configured.

### OpenTelemetry in .NET

```csharp
// Program.cs — full OpenTelemetry setup
using OpenTelemetry;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);

var resourceBuilder = ResourceBuilder.CreateDefault()
    .AddService("orders-service", serviceVersion: "1.4.0")
    .AddTelemetrySdk();

// Tracing
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .SetResourceBuilder(resourceBuilder)
        .AddAspNetCoreInstrumentation()   // auto-trace all incoming requests
        .AddHttpClientInstrumentation()   // auto-trace all outgoing HttpClient calls
        .AddEntityFrameworkCoreInstrumentation()  // SQL queries
        .AddGrpcClientInstrumentation()
        .AddSource("Orders.Application")  // custom spans from our ActivitySource
        .SetSampler(new ParentBasedSampler(
            new TraceIdRatioBasedSampler(0.05))) // 5% head-based; parent decision honoured
        .AddOtlpExporter(options =>       // export to Jaeger / Grafana Tempo / Datadog
            options.Endpoint = new Uri("http://otel-collector:4317")))
    .WithMetrics(metrics => metrics
        .SetResourceBuilder(resourceBuilder)
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter())
    .WithLogging(logs => logs
        .SetResourceBuilder(resourceBuilder)
        .AddOtlpExporter());

// Serilog: enrich logs with trace context
builder.Host.UseSerilog((ctx, cfg) => cfg
    .ReadFrom.Configuration(ctx.Configuration)
    .Enrich.WithProperty("Service", "orders-service")
    .Enrich.FromLogContext()           // picks up TraceId/SpanId added by OpenTelemetry
    .WriteTo.Console(new JsonFormatter()));
```

```csharp
// Custom span — manual instrumentation for business operations
using System.Diagnostics;

namespace Orders.Application;

public sealed class OrderService(IOrderRepository orders)
{
    // Register ActivitySource once (static) — low allocation
    private static readonly ActivitySource _source = new("Orders.Application");

    public async Task<Order> PlaceOrderAsync(PlaceOrderCommand cmd, CancellationToken ct)
    {
        // Create a child span under the current trace
        using var activity = _source.StartActivity("PlaceOrder");
        activity?.SetTag("order.customer_id", cmd.CustomerId.ToString());
        activity?.SetTag("order.item_count",  cmd.Items.Count);

        var order = Order.Place(cmd.CustomerId, cmd.Items);

        try
        {
            await orders.SaveAsync(order, ct);
            activity?.AddEvent(new ActivityEvent("OrderPersisted",
                tags: new ActivityTagsCollection { ["order.id"] = order.Id.ToString() }));

            activity?.SetStatus(ActivityStatusCode.Ok);
            return order;
        }
        catch (Exception ex)
        {
            // Mark span as error — tail-based sampler will always capture this
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.RecordException(ex);
            throw;
        }
    }
}
```

### Baggage: Cross-Service Context

Baggage travels with the trace but is application-level metadata (not trace infrastructure). Useful for tenant ID, feature flags, or A/B test group — propagate once, available everywhere:

```csharp
// Set baggage at API gateway / entry point
Baggage.SetBaggage("tenant.id", tenantId);
Baggage.SetBaggage("ab.variant", "B");

// Read anywhere downstream (including in worker services)
var tenantId = Baggage.GetBaggage("tenant.id");
```

> **Warning:** Baggage is propagated in HTTP headers to all downstream services and is visible to anyone who can inspect traffic. Never put sensitive data (tokens, PII, internal IPs) in baggage.

## Common Follow-up Questions

- Your traces show a 200 ms gap between two spans. How do you diagnose what's happening in that gap?
- How do you implement tail-based sampling without losing data during the buffering window?
- What is the difference between OpenTelemetry `Activity` and the older `DiagnosticSource` in .NET?
- How do you trace async message processing — a Kafka consumer that processes a message minutes after it was published?
- How do you prevent cardinality explosion in span attributes (e.g., using `orderId` as a tag)?

## Common Mistakes / Pitfalls

- **Not setting a timeout or sampling**: without sampling at high QPS, tracing can generate GBs of data per hour and dominate storage costs.
- **Using `traceId` as a correlation ID in logs but not linking to the trace backend**: log the full `traceId` as a clickable link to your Jaeger/Grafana dashboard.
- **Creating too many spans**: a span per loop iteration creates millions of spans; create spans for meaningful units of work (one per DB call, one per HTTP request, one per business operation).
- **Not propagating `traceparent` through message queues**: when a Kafka consumer starts processing, extract the `traceparent` from the message headers to link the consumer span back to the producer's trace.
- **Putting high-cardinality values (orderId, userId) as metric labels**: this is fine for trace span tags but will cause cardinality explosion in Prometheus metrics — use histograms for distributions, not per-entity labels.
- **Forgetting to dispose `Activity`**: always wrap `_source.StartActivity(...)` in a `using` statement; un-disposed activities are never sent to the exporter.

## References

- [OpenTelemetry .NET — GitHub](https://github.com/open-telemetry/opentelemetry-dotnet)
- [W3C TraceContext Specification](https://www.w3.org/TR/trace-context/)
- [OpenTelemetry .NET Instrumentation Libraries](https://opentelemetry.io/docs/instrumentation/net/)
- [Distributed Tracing with .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/distributed-tracing)
- [See: observability-three-pillars.md](./observability-three-pillars.md)
- [See: structured-logging-patterns.md](./structured-logging-patterns.md)
