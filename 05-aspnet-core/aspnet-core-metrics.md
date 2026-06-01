# ASP.NET Core Metrics (.NET 8+)

**Category:** ASP.NET Core / Performance & Diagnostics
**Difficulty:** 🔴 Senior
**Tags:** `metrics`, `IMeterFactory`, `OpenTelemetry`, `Prometheus`, `kestrel`, `http-metrics`, `OTEL`

## Question

> What built-in meters does ASP.NET Core expose in .NET 8+? How do you export them to Prometheus or OpenTelemetry?

## Short Answer

ASP.NET Core .NET 8 ships built-in `System.Diagnostics.Metrics` meters covering Kestrel connections, HTTP request duration/rate/error, routing, and SignalR. Access them via `IMeterFactory` (for custom meters) or the built-in meter names (e.g., `Microsoft.AspNetCore.Hosting`). Export to Prometheus using `OpenTelemetry.Exporter.Prometheus.AspNetCore` or to any OTEL-compatible backend using `OpenTelemetry.Extensions.Hosting`. The key benefit over `EventCounters` is that `System.Diagnostics.Metrics` is the new canonical .NET metrics API with first-class OTEL integration.

## Detailed Explanation

### Built-in ASP.NET Core meters (.NET 8)

| Meter name | Key instruments |
|---|---|
| `Microsoft.AspNetCore.Hosting` | `http.server.request.duration` (histogram), `http.server.active_requests` (updown counter) |
| `Microsoft.AspNetCore.Routing` | `aspnetcore.routing.match_attempts` (counter) |
| `Microsoft.AspNetCore.Diagnostics` | `aspnetcore.diagnostics.exceptions` (counter) |
| `Microsoft.AspNetCore.RateLimiting` | `aspnetcore.rate_limiting.requests` (counter, with `policy` dimension) |
| `System.Net.Http` (client) | `http.client.request.duration`, `http.client.active_requests` |
| `Microsoft.AspNetCore.Server.Kestrel` | `kestrel.active_connections`, `kestrel.queued_connections`, `kestrel.tls_handshake.duration` |

### Creating custom metrics with `IMeterFactory`

```csharp
public sealed class OrderMetrics(IMeterFactory meterFactory) : IDisposable
{
    private readonly Meter _meter = meterFactory.Create("MyApp.Orders");
    private readonly Counter<int> _created;
    private readonly Histogram<double> _processingTime;

    public OrderMetrics(IMeterFactory factory)
    {
        _meter = factory.Create("MyApp.Orders", version: "1.0");
        _created = _meter.CreateCounter<int>(
            "myapp.orders.created",
            unit: "{order}",
            description: "Number of orders created");
        _processingTime = _meter.CreateHistogram<double>(
            "myapp.orders.processing_duration",
            unit: "ms",
            description: "Order processing time in ms");
    }

    public void RecordOrderCreated(string region) =>
        _created.Add(1, new TagList { { "region", region } });

    public void RecordProcessingTime(double ms, string status) =>
        _processingTime.Record(ms, new TagList { { "status", status } });

    public void Dispose() => _meter.Dispose();
}

// Registration
builder.Services.AddSingleton<OrderMetrics>();
```

### Exporting to Prometheus

```bash
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Exporter.Prometheus.AspNetCore  # preview
```

```csharp
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics =>
    {
        metrics
            .AddAspNetCoreInstrumentation()   // adds HTTP request metrics
            .AddHttpClientInstrumentation()   // adds HttpClient metrics
            .AddMeter("MyApp.Orders")         // custom meter
            .AddPrometheusExporter();         // exports /metrics endpoint
    });

var app = builder.Build();
app.MapPrometheusScrapingEndpoint(); // /metrics — scraped by Prometheus
```

### Exporting to OTLP (Grafana, Datadog, Jaeger)

```bash
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
```

```csharp
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics =>
    {
        metrics
            .AddAspNetCoreInstrumentation()
            .AddOtlpExporter(opts =>
            {
                opts.Endpoint = new Uri(builder.Configuration["Otel:Endpoint"]!);
                opts.Protocol = OtlpExportProtocol.Grpc;
            });
    });
```

### Combined observability setup (Metrics + Traces + Logs)

```csharp
builder.Services.AddOpenTelemetry()
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddMeter("MyApp.*")
        .AddOtlpExporter())
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter())
    .WithLogging(l => l
        .AddOtlpExporter());
```

### Accessing metrics programmatically

```csharp
// Listen for metric measurements (testing / local processing)
using var meterListener = new MeterListener();
meterListener.InstrumentPublished = (instrument, listener) =>
{
    if (instrument.Meter.Name == "Microsoft.AspNetCore.Hosting")
        listener.EnableMeasurementEvents(instrument);
};
meterListener.SetMeasurementEventCallback<double>(
    (instrument, value, tags, state) =>
        Console.WriteLine($"{instrument.Name} = {value}"));
meterListener.Start();
```

## Code Example

```csharp
// Service with instrumentation
public sealed class ProductService(
    IProductRepository repo,
    OrderMetrics metrics,
    ILogger<ProductService> logger)
{
    public async Task<Product> CreateAsync(CreateProductRequest req, CancellationToken ct)
    {
        var sw = Stopwatch.StartNew();
        try
        {
            var product = await repo.InsertAsync(req, ct);
            metrics.RecordOrderCreated(req.Region);
            metrics.RecordProcessingTime(sw.Elapsed.TotalMilliseconds, "success");
            return product;
        }
        catch (Exception ex)
        {
            metrics.RecordProcessingTime(sw.Elapsed.TotalMilliseconds, "error");
            logger.LogError(ex, "Product creation failed");
            throw;
        }
    }
}
```

## Common Follow-up Questions

- What is the difference between `System.Diagnostics.Metrics` and `EventCounters`?
- How do you add dimension tags (labels) to a metric counter?
- How do you test custom metrics in unit tests without a real OTEL exporter?
- What is the `IMeterFactory` interface and why use it instead of `new Meter()`?
- How does the `MetricsOptions` configuration in `appsettings.json` enable/disable built-in meters?

## Common Mistakes / Pitfalls

- **Using `new Meter(...)` directly instead of `IMeterFactory`** — direct construction bypasses DI lifetime management and prevents clean shutdown in test scenarios. Prefer `IMeterFactory` in production code.
- **Not calling `meterListener.Start()` after setting up callbacks** — the listener collects no data until `Start()` is called.
- **Exposing `/metrics` without authentication in production** — Prometheus scrape endpoints reveal operational details; protect with network policies or bearer token validation.
- **Adding all meters with `.AddMeter("*")`** — this collects from third-party libraries too; be selective or use prefix patterns (`"MyApp.*"`) to control cardinality.
- **High-cardinality tags** — using user IDs or request paths as tag values creates an unbounded number of time series, overwhelming Prometheus storage and increasing costs.

## References

- [Microsoft Learn — ASP.NET Core metrics (.NET 8)](https://learn.microsoft.com/aspnet/core/log-mon/metrics/metrics?view=aspnetcore-8.0)
- [Microsoft Learn — IMeterFactory](https://learn.microsoft.com/dotnet/api/system.diagnostics.metrics.imeterfactory)
- [OpenTelemetry .NET SDK](https://github.com/open-telemetry/opentelemetry-dotnet)
- [Microsoft Blog — .NET 8 metrics](https://devblogs.microsoft.com/dotnet/new-performance-improvements-in-net-8/) (verify URL)
