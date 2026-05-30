# Observability: Three Pillars

**Category:** System Design / Observability
**Difficulty:** Junior
**Tags:** `observability`, `logs`, `metrics`, `traces`, `opentelemetry`, `monitoring`

## Question

> What are the three pillars of observability? What question does each one answer, and when do you need each one?

- What is the difference between monitoring and observability?
- How does OpenTelemetry unify the three pillars?

## Short Answer

The three pillars are **logs** (what happened), **metrics** (how much / how fast), and **traces** (where time was spent across services). Monitoring tells you *when* something is wrong by alerting on known failure modes (threshold breaches). Observability lets you ask arbitrary questions about system behaviour — including failures you didn't predict — by combining all three data types. OpenTelemetry provides a single vendor-neutral SDK and wire protocol (OTLP) that instruments all three pillars from one codebase and exports to any backend (Grafana, Datadog, Azure Monitor, Jaeger).

## Detailed Explanation

### Monitoring vs Observability

| | Monitoring | Observability |
|--|-----------|--------------|
| Approach | Watch predefined metrics, alert on known failures | Instrument everything, explore unknown failures |
| Question answered | "Is the system healthy?" | "Why is the system behaving this way?" |
| Failure coverage | Known failure modes | Unknown unknowns |
| Tools | Prometheus alerts, CloudWatch alarms | Logs + metrics + traces together |
| Value | Detect; page on-call | Diagnose; understand causality |

The term "observability" comes from control theory: a system is observable if its internal state can be inferred from its outputs. A system with only health checks and CPU metrics is monitored, not truly observable.

### Pillar 1 — Logs (What Happened)

Logs are **discrete, timestamped records** of events. Structured logs (JSON) are machine-queryable; unstructured logs (plain text) are human-readable but difficult to aggregate.

**What logs answer**: "What exactly happened at 14:32:11 for request X?" — they are the most detailed, event-by-event record.

**When to use**: debugging specific incidents, audit trails, security events, error messages with context.

**Tools**: Serilog, NLog (producers); Elasticsearch / Kibana, Loki / Grafana, Azure Log Analytics (aggregators).

**Best practice**: include `traceId`, `spanId`, `userId`, `correlationId` in every log entry.

### Pillar 2 — Metrics (How Much / How Fast)

Metrics are **numerical measurements aggregated over time**. They are low-cardinality, cheap to store, and ideal for dashboards and alerting.

**What metrics answer**: "How many requests/s? What is the p99 latency? What is the error rate?"

**Metric types**:

| Type | Example | .NET |
|------|---------|------|
| Counter | Total HTTP requests | `Meter.CreateCounter<long>` |
| Gauge | Current active connections | `Meter.CreateGauge<int>` |
| Histogram | Request latency distribution | `Meter.CreateHistogram<double>` |

**RED method** (for request-driven services):
- **R**ate: requests per second
- **E**rrors: error rate (% or count)
- **D**uration: response time (histogram, p50/p95/p99)

**USE method** (for infrastructure resources):
- **U**tilization: % of time resource is busy
- **S**aturation: how much work is queued
- **E**rrors: error count

**Tools**: Prometheus (pull-based collection), Grafana (visualisation), Azure Monitor, Datadog.

### Pillar 3 — Traces (Where Time Was Spent)

Traces are **causal chains of operations** across service boundaries. Each span records a unit of work with its parent relationship, forming a tree.

**What traces answer**: "Which service is causing the latency? What was the call path for this slow request?"

**Tools**: Jaeger, Zipkin, Grafana Tempo, Azure Application Insights, Datadog APM.

See [distributed-tracing.md](./distributed-tracing.md) for deep dive.

### How They Work Together

A complete diagnosis typically uses all three:

```
1. Metric alert fires: error rate > 1% (Prometheus → PagerDuty)
   ↓
2. Dashboard shows spike started at 14:32 (Grafana)
   ↓
3. Find a failed trace in Jaeger: 14:32:11, traceId=abc123
   ↓
4. Trace shows: Orders service → 450 ms → Inventory service → SQL timeout
   ↓
5. Jump to logs filtered by traceId=abc123:
   "ERROR: Command timeout after 30s — index missing on inventory.product_id"
   ↓
6. Root cause: missing index on Inventory DB
```

Without all three, step 5 (finding the exact SQL query that timed out) would require guessing.

### OpenTelemetry: Unifying the Three Pillars

OpenTelemetry (OTel) is the CNCF standard for instrumentation. It provides:

- **API**: interfaces (`ActivitySource`, `Meter`, `ILogger`) — no vendor lock-in
- **SDK**: implementation with batching, sampling, export
- **OTLP**: OpenTelemetry Protocol — single wire format for all three signals
- **Instrumentation libraries**: auto-instrument ASP.NET Core, HttpClient, EF Core, gRPC, Redis

```
Your .NET App
  ├── Traces   → ActivitySource   ─┐
  ├── Metrics  → System.Diagnostics.Metrics ─┤ → OTLP exporter → OpenTelemetry Collector
  └── Logs     → ILogger + OTel   ─┘                                ↓
                                                  ┌─────────────────────────────┐
                                                  │ Grafana Tempo (traces)       │
                                                  │ Prometheus (metrics)         │
                                                  │ Loki (logs)                  │
                                                  └─────────────────────────────┘
```

The **OpenTelemetry Collector** is a vendor-neutral proxy that receives OTLP, processes (batch, filter, enrich), and fans out to multiple backends simultaneously.

## Code Example

```csharp
// Program.cs — three-pillars setup with OpenTelemetry
using OpenTelemetry;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;
using OpenTelemetry.Resources;
using System.Diagnostics;
using System.Diagnostics.Metrics;

var builder = WebApplication.CreateBuilder(args);

var resource = ResourceBuilder.CreateDefault()
    .AddService("orders-api", serviceVersion: "2.0.0");

builder.Services.AddOpenTelemetry()
    .WithTracing(t => t
        .SetResourceBuilder(resource)
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddOtlpExporter())      // → OTel Collector → Jaeger/Tempo
    .WithMetrics(m => m
        .SetResourceBuilder(resource)
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddMeter("Orders.Application")  // custom business metrics
        .AddOtlpExporter())      // → OTel Collector → Prometheus
    .WithLogging(l => l
        .SetResourceBuilder(resource)
        .AddOtlpExporter());     // → OTel Collector → Loki

// Serilog for structured logs (enriched with trace context automatically)
builder.Host.UseSerilog((ctx, cfg) => cfg
    .WriteTo.OpenTelemetry()     // Serilog.Sinks.OpenTelemetry
    .Enrich.FromLogContext());

var app = builder.Build();

// Custom business metrics (RED pattern)
var meter   = new Meter("Orders.Application");
var counter = meter.CreateCounter<long>("orders.placed.total", "orders", "Total orders placed");
var latency = meter.CreateHistogram<double>("orders.latency.ms", "ms", "Order placement latency");

app.MapPost("/orders", async (CreateOrderRequest req, ILogger<Program> log) =>
{
    var sw = Stopwatch.StartNew();
    log.LogInformation("Placing order for customer {CustomerId}", req.CustomerId);

    // ... process order

    counter.Add(1, new TagList { { "region", "eu-west" }, { "tier", req.CustomerTier } });
    latency.Record(sw.ElapsedMilliseconds);

    return Results.Created("/orders/123", null);
});

app.Run();
```

## Common Follow-up Questions

- What is the difference between a push-based metrics system (StatsD, OTLP) and a pull-based one (Prometheus)?
- How do you decide what cardinality is acceptable for metric labels?
- What is the "cardinality explosion" problem and how does it affect Prometheus performance?
- How do you correlate a log entry from one service with the trace from a different service?
- What is an OpenTelemetry Collector and why would you use it instead of exporting directly from the application?

## Common Mistakes / Pitfalls

- **Logs only ("log-driven debugging")**: without metrics, you won't know a problem is happening until a customer reports it; without traces, you can't find which service is slow.
- **Not including `traceId` in logs**: logs without a trace correlation ID are nearly useless in a distributed system — you can't connect them to the trace.
- **Metric label explosion**: adding `userId` or `orderId` as metric labels creates millions of time series and kills Prometheus performance. Use trace span tags for high-cardinality data.
- **Sampling traces aggressively without always-recording errors**: if you sample at 1%, you may never capture the trace for the error that happens at 0.5% rate.
- **Two different observability stacks**: teams that "add Datadog for metrics but use ELK for logs" create a correlation nightmare; standardise on one platform or use OTel to export to both.
- **Ignoring the OpenTelemetry Collector**: exporting OTLP directly from the app to a backend ties you to that vendor; the Collector adds buffering, retry, and multi-backend fan-out for free.

## References

- [OpenTelemetry .NET — GitHub](https://github.com/open-telemetry/opentelemetry-dotnet)
- [Observability Engineering — Charity Majors (book)](https://www.oreilly.com/library/view/observability-engineering/9781492076438/)
- [The RED Method — Tom Wilkie](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/) (verify URL)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [See: distributed-tracing.md](./distributed-tracing.md)
- [See: structured-logging-patterns.md](./structured-logging-patterns.md)
