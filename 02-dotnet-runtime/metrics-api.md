# What Is the .NET Metrics API?

**Category:** .NET Runtime / Diagnostics
**Difficulty:** 🟡 Middle
**Tags:** `Meter`, `Counter`, `Histogram`, `ObservableGauge`, `IMeterFactory`

## Question

> What is `System.Diagnostics.Metrics`, and how do you expose metrics from a .NET application?

Also asked as:
> What are `Meter`, `Counter<T>`, `Histogram<T>`, and `ObservableGauge<T>` used for?
> How do custom .NET metrics integrate with OpenTelemetry and `dotnet-counters`?

## Short Answer

`System.Diagnostics.Metrics` is the built-in .NET metrics API introduced in .NET 6. You create a `Meter`, define instruments such as `Counter<T>`, `Histogram<T>`, and `ObservableGauge<T>`, and record measurements with optional tags for dimensions like route or tenant. In .NET 8, `IMeterFactory` makes meters easier to obtain through DI, and OpenTelemetry or `dotnet-counters` can subscribe to those instruments without application-specific wiring.

## Detailed Explanation

### The Role of `Meter`

A `Meter` is the metrics equivalent of an `ActivitySource` for tracing: it names the component that publishes measurements. Instruments created from that meter define the shape of the metrics stream, and listeners decide whether to subscribe, aggregate, and export.

The main instrument types solve different questions:

| Instrument | Best for |
|---|---|
| `Counter<T>` | Monotonically increasing counts such as requests or failures |
| `Histogram<T>` | Value distributions such as latency or payload size |
| `ObservableGauge<T>` | Point-in-time measurements sampled on demand |
| `UpDownCounter<T>` | Values that can increase or decrease, such as active jobs |

That separation matters because a histogram answers a different question from a counter. “How many?” is not the same as “what is the distribution?”

### Tags and Dimensions

Metrics become much more valuable when you attach tags, sometimes called dimensions. A request counter tagged by route, status code, or tenant lets your backend aggregate multiple slices from one instrument instead of needing a separate instrument per case.

The trade-off is cardinality. Tags should represent bounded sets such as `route=/orders/{id}` or `status_code=500`, not unbounded values like user email or raw order ID.

> Warning: high-cardinality tags can make metrics backends expensive, slow, or nearly unusable. Design metric dimensions as carefully as database indexes.

### `IMeterFactory` and Testability

Creating global static meters works, but in larger apps it can make ownership and testing awkward. .NET 8 introduced `IMeterFactory`, which integrates with DI. Instead of each service owning ad-hoc static meters, a service can request a factory and create a meter scoped to the application's hosting model.

That improves composition and testability. In unit or integration tests, you can substitute listeners or verify measurements more cleanly than when all metrics are buried in global statics.

### How Tooling Subscribes

The API is producer-side only; consumers attach through listeners. OpenTelemetry's .NET SDK uses listeners under the hood and activates specific meters with `AddMeter("MyApp")`. That is why your code does not need to know whether the downstream consumer is OTLP, Prometheus, or another exporter.

The same design also explains why `dotnet-counters` can show custom meters. Once your process exposes metrics, the runtime diagnostics infrastructure can subscribe and display them, especially for simple counters and rates during local debugging.

### Names, Units, and Instrument Stability

Good metrics are boringly consistent. Instrument names should be stable, dot-separated, and domain-oriented, while units should be explicit so dashboards do not guess whether a number is bytes, milliseconds, or items. You should also avoid renaming instruments casually, because dashboards, alerts, and SLO queries depend on those names. In interviews, it is strong to mention that changing a metric contract is an observability breaking change in the same way changing an API contract can be.

Metrics pair naturally with tracing. Metrics tell you there is a latency spike; tracing tells you which requests and spans caused it. See [activity-and-opentelemetry.md](./activity-and-opentelemetry.md).

## Code Example

```csharp
using System.Diagnostics.Metrics;

namespace DotNetRuntimeSamples.Metrics;

internal static class Program
{
    private static readonly Meter Meter = new("Samples.Orders", "1.0.0");
    private static readonly Counter<long> OrdersCreated = Meter.CreateCounter<long>("orders.created");
    private static readonly Histogram<double> CheckoutLatencyMs = Meter.CreateHistogram<double>("checkout.latency.ms");
    private static int _activeWorkers = 2;

    private static readonly ObservableGauge<int> ActiveWorkers = Meter.CreateObservableGauge(
        "workers.active",
        () => _activeWorkers,
        unit: "workers",
        description: "Current number of active background workers");

    private static void Main()
    {
        OrdersCreated.Add(1, new KeyValuePair<string, object?>("region", "eu")); // Add a tagged measurement.
        CheckoutLatencyMs.Record(42.7, new KeyValuePair<string, object?>("route", "/checkout"));
        _activeWorkers++;

        Console.WriteLine("Custom metrics recorded.");
        Console.WriteLine("Use: dotnet-counters monitor --process-id <pid> --counters Samples.Orders");

        // In ASP.NET Core on .NET 8+, prefer injecting IMeterFactory into services.
        // OpenTelemetry wiring: builder.Services.AddOpenTelemetry().WithMetrics(m => m.AddMeter("Samples.Orders"));
        _ = ActiveWorkers; // Keep the observable instrument referenced for the sample.
    }
}
```

## Common Follow-up Questions

- When should you choose a histogram instead of a counter?
- Why can bad metric tags create operational problems?
- What does `IMeterFactory` improve compared to static meters?
- How does OpenTelemetry subscribe to metrics from a `Meter`?
- Can `dotnet-counters` display custom metrics or only built-in runtime ones?

## Common Mistakes / Pitfalls

- Encoding every dimension in the metric name instead of using tags.
- Adding unbounded tag values such as user IDs or GUIDs.
- Using a counter to model a value distribution that should be a histogram.
- Assuming metrics export themselves without registering the meter name in the listener or OpenTelemetry configuration.
- Hiding meter creation in static state everywhere, which makes ownership and tests harder.

## References

- [Metrics instrumentation in .NET — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/metrics-instrumentation)
- [Meter Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.diagnostics.metrics.meter)
- [IMeterFactory Interface — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.diagnostics.metrics.imeterfactory)
- [OpenTelemetry .NET metrics](https://opentelemetry.io/docs/languages/dotnet/metrics/)
- [dotnet-counters — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-counters)
