# Metrics and Alerting

**Category:** System Design / Observability
**Difficulty:** Middle
**Tags:** `metrics`, `prometheus`, `grafana`, `alerting`, `RED`, `USE`, `histogram`

## Question

> How do you design a metrics and alerting strategy for a production .NET service? What is the RED method? How do you configure Prometheus with .NET and write meaningful alert rules?

- What is the difference between a counter, gauge, and histogram?
- How do you avoid alert fatigue?

## Short Answer

The RED method defines the three metrics every request-serving service needs: **Rate** (req/s), **Errors** (error rate), and **Duration** (latency distribution). In .NET, `System.Diagnostics.Metrics` (the native API) or the `prometheus-net` library exposes these; Prometheus scrapes them; Grafana visualises and alerts. Histograms (not averages) are essential for latency — p99 is far more actionable than mean. Alert on **symptoms** (SLO breach, error rate spike) rather than causes (CPU%, disk), and use multi-window burn rate alerts to distinguish transient from sustained problems.

## Detailed Explanation

### Metric Types

| Type | Description | Example | .NET API |
|------|-------------|---------|---------|
| **Counter** | Monotonically increasing; reset on restart | Total HTTP requests, total errors | `CreateCounter<long>` |
| **Gauge** | Current value, can go up/down | Active connections, queue depth | `CreateGauge<int>` |
| **Histogram** | Distribution of values across configurable buckets | Request duration, payload size | `CreateHistogram<double>` |
| **UpDownCounter** | Like counter but can decrease | Items in a pool | `CreateUpDownCounter<int>` |

> **Warning:** Never use averages for latency SLOs. An average of 200 ms can hide that 1% of requests take 30 s. Use histograms and alert on percentiles (p95, p99).

### The RED Method

For every service that handles requests:

| Signal | Prometheus Query | Alert Threshold |
|--------|-----------------|-----------------|
| **Rate** (req/s) | `rate(http_requests_total[5m])` | Informational (traffic baseline) |
| **Errors** (%) | `rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])` | Alert if >1% for 5 min |
| **Duration** (p99) | `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))` | Alert if >1 s for 5 min |

### The USE Method (Infrastructure)

For every resource (CPU, memory, disk, network):

| Signal | Example |
|--------|---------|
| **Utilization** | CPU % used |
| **Saturation** | CPU run queue length (are tasks waiting?) |
| **Errors** | Memory allocation failures, NIC errors |

**Practical rule**: RED alerts page you when users are affected; USE alerts help diagnose root cause after.

### .NET Metrics Setup

**Option A — System.Diagnostics.Metrics (built-in, .NET 8)**:

```csharp
using System.Diagnostics.Metrics;

public sealed class OrderMetrics : IDisposable
{
    private readonly Meter _meter = new("Orders.Application", "1.0");
    private readonly Counter<long>     _ordersPlaced;
    private readonly Counter<long>     _ordersFailed;
    private readonly Histogram<double> _orderDurationMs;

    public OrderMetrics()
    {
        _ordersPlaced    = _meter.CreateCounter<long>  ("orders.placed",        "orders");
        _ordersFailed    = _meter.CreateCounter<long>  ("orders.failed",        "orders");
        _orderDurationMs = _meter.CreateHistogram<double>("orders.duration",    "ms");
    }

    public void RecordSuccess(double durationMs, string region)
    {
        _ordersPlaced.Add(1, new TagList { { "region", region } });
        _orderDurationMs.Record(durationMs, new TagList { { "region", region } });
    }

    public void RecordFailure(string reason, string region) =>
        _ordersFailed.Add(1, new TagList { { "reason", reason }, { "region", region } });

    public void Dispose() => _meter.Dispose();
}
```

**Export to Prometheus via OpenTelemetry**:

```csharp
builder.Services.AddOpenTelemetry()
    .WithMetrics(m => m
        .AddMeter("Orders.Application")
        .AddAspNetCoreInstrumentation()    // http_server_request_duration (OTLP histogram)
        .AddHttpClientInstrumentation()
        .AddPrometheusExporter());         // scrape endpoint: /metrics

app.MapPrometheusScrapingEndpoint();       // exposes GET /metrics
```

### Prometheus Alert Rules

```yaml
# prometheus/rules/orders.yml
groups:
  - name: orders-service
    rules:
      # High error rate
      - alert: OrdersHighErrorRate
        expr: |
          rate(http_server_request_duration_count{
            job="orders-api", http_response_status_code=~"5.."
          }[5m])
          /
          rate(http_server_request_duration_count{job="orders-api"}[5m])
          > 0.01
        for: 5m
        labels:
          severity: page
        annotations:
          summary: "Orders API error rate > 1% for 5 minutes"
          runbook: "https://wiki/runbooks/orders-high-error-rate"

      # High p99 latency
      - alert: OrdersHighLatency
        expr: |
          histogram_quantile(0.99,
            rate(http_server_request_duration_seconds_bucket{job="orders-api"}[5m])
          ) > 1.0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Orders API p99 latency > 1s"

      # Service completely down (no requests for 2 min)
      - alert: OrdersServiceDown
        expr: absent(rate(http_server_request_duration_count{job="orders-api"}[2m]))
        for: 2m
        labels:
          severity: critical
```

### Avoiding Alert Fatigue

Alert fatigue happens when on-call engineers receive too many non-actionable alerts and start ignoring them.

**Rules**:
1. **Alert on symptoms, not causes**: "error rate > 1%" is a symptom; "CPU > 80%" is a cause. Page on symptoms; use cause metrics for dashboards only.
2. **Every alert needs a runbook**: if you can't write a runbook (what to do when this fires), it shouldn't be an alert.
3. **Use multi-window burn rates**: instead of "error rate > 1% for 5 min" (noisy for transient spikes), use SLO burn rates — "you will exhaust your 30-day error budget in 1 h" (Google SRE approach).
4. **Tune thresholds with historical data**: set `for: 5m` on most alerts to avoid paging for spikes that resolve in seconds.
5. **Distinguish page vs warning vs info**: page → wake someone up; warning → Slack channel; info → dashboard only.

### SLO-Based Burn Rate Alerting

```yaml
# Multi-burn-rate alert (Google SRE Book approach)
# Fires if errors are consuming the monthly error budget too fast
- alert: OrdersErrorBudgetBurning
  expr: |
    (
      rate(http_server_request_duration_count{job="orders-api",http_response_status_code=~"5.."}[1h])
      / rate(http_server_request_duration_count{job="orders-api"}[1h])
    ) > 14.4 * 0.001   # 14.4× the hourly budget rate (1h window burn rate)
    and
    (
      rate(http_server_request_duration_count{job="orders-api",http_response_status_code=~"5.."}[5m])
      / rate(http_server_request_duration_count{job="orders-api"}[5m])
    ) > 14.4 * 0.001   # also elevated in short window (reduces false positives)
  for: 2m
  labels:
    severity: page
  annotations:
    summary: "Orders API burning error budget at 14.4× rate (SLO at risk)"
```

## Common Follow-up Questions

- What is the Prometheus data model and why does high cardinality hurt it?
- How do you use Grafana templating to create reusable dashboards across multiple services?
- Your histogram bucket resolution is too coarse — how do you change it without restarting Prometheus?
- How does Azure Monitor / Application Insights differ from Prometheus + Grafana?
- What is exemplars support in Prometheus, and how does it link metrics to traces?

## Common Mistakes / Pitfalls

- **Using averages for latency SLOs**: `avg(http_request_duration_seconds)` hides the tail; always use `histogram_quantile(0.99, ...)`.
- **High-cardinality label values**: adding `userId` or `orderId` as a Prometheus label creates one time series per user — Prometheus cannot handle millions of series.
- **Alerting on CPU and memory without user-facing symptoms**: a service can be at 90% CPU but responding fine; page only on symptoms users feel.
- **No `for:` duration on alerts**: without a `for: 5m` clause, a single bad scrape fires and immediately resolves, creating noise.
- **Not exposing histograms — only counters**: without histograms you cannot compute percentiles; retrofitting histograms later requires changes to every instrumented service.
- **Missing the `/metrics` endpoint in load balancer health check**: if the load balancer scrapes `/metrics` and it returns 404, the pod is marked unhealthy.

## References

- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)
- [The RED Method — Tom Wilkie, Grafana Labs](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/) (verify URL)
- [Google SRE Book — Alerting on SLOs (Chapter 5)](https://sre.google/workbook/alerting-on-slos/)
- [.NET Metrics — System.Diagnostics.Metrics](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/metrics-instrumentation)
- [See: observability-three-pillars.md](./observability-three-pillars.md)
- [See: slos-slas-error-budgets.md](./slos-slas-error-budgets.md)
