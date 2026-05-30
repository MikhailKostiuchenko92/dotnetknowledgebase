# How Do Activity and OpenTelemetry Work in .NET?

**Category:** .NET Runtime / Diagnostics
**Difficulty:** 🟡 Middle
**Tags:** `Activity`, `ActivitySource`, `OpenTelemetry`, `TraceContext`, `baggage`

## Question

> What is `System.Diagnostics.Activity`, and how does it support distributed tracing in .NET?

Also asked as:
> How do `ActivitySource.StartActivity()` and W3C trace context propagation work across services?
> How does OpenTelemetry use `ActivitySource` and baggage in ASP.NET Core applications?

## Short Answer

`Activity` is the core distributed tracing primitive in modern .NET. An `ActivitySource` creates spans, preserves parent-child relationships, and carries W3C trace context through headers such as `traceparent` and `tracestate`. OpenTelemetry subscribes to those sources with `AddSource("MyApp")`, exports the resulting spans, and can propagate baggage across service boundaries for correlated metadata.

## Detailed Explanation

### `Activity` as the Span Model in .NET

Before OpenTelemetry became common, .NET already had `Activity` as a diagnostics abstraction. In .NET 5 and later, it effectively became the built-in span model for distributed tracing. Each `Activity` represents a timed operation with a trace ID, span ID, optional parent span, tags, events, and baggage.

`ActivitySource` is the factory for these spans. Calling `StartActivity("name")` creates a new child of `Activity.Current` when a parent exists. That automatic parenting is what makes nested calls, HTTP handlers, database work, and downstream service calls show up as one end-to-end trace rather than unrelated logs.

### Context Propagation

Distributed tracing only works if the parent context crosses process boundaries. In HTTP scenarios, the W3C TraceContext standard uses the `traceparent` and `tracestate` headers. ASP.NET Core, `HttpClient`, and OpenTelemetry instrumentation can read and write these headers automatically, so an incoming request span becomes the parent for internal operations and outgoing calls.

| Concept | What it carries |
|---|---|
| `traceparent` | Trace ID, parent span ID, and trace flags |
| `tracestate` | Vendor-specific trace system state |
| `Baggage` | Key-value pairs propagated end to end |
| Tags | Attributes on one span only |

That distinction matters in interviews: baggage flows across service boundaries, while tags describe only the current span.

### OpenTelemetry Integration

The OpenTelemetry .NET SDK does not replace `Activity`; it subscribes to it. In code you usually register tracing with `AddOpenTelemetry().WithTracing(...)` and then specify `AddSource("MyApp")`. From that point on, any `ActivitySource` with that name can create spans that exporters send to Jaeger, OTLP collectors, Application Insights, or another backend.

This division of responsibility is elegant: the runtime and libraries produce `Activity` data, while the OpenTelemetry SDK handles sampling, processors, and export.

> Warning: avoid stuffing high-cardinality or sensitive data into tags or baggage. User IDs, raw SQL, or full request bodies can explode storage cost and create privacy issues.

### Tags, Baggage, and Good Span Design

For per-span attributes, prefer `SetTag` or `AddTag` semantics over manually building an `ActivityTagsCollection` unless you already have a batch of values. `SetTag` is clearer for the common case and maps directly to span attributes in OpenTelemetry.

Baggage should be used sparingly because every downstream service receives it. Good examples are tenant ID or correlation scope values needed across services. Bad examples are huge payloads or internal implementation details.

### Sampling and Boundary Design

A mature tracing design also thinks about sampling and service boundaries. Not every span needs to be exported forever, especially in high-volume systems. OpenTelemetry samplers can decide which traces to keep, but the instrumentation should still create meaningful span boundaries: request in, business operation, downstream call, cache call, database call. When span names and tags are stable, traces stay queryable even when only a subset is sampled. That is another reason to avoid putting random IDs in span names and instead store them in carefully chosen attributes.

If you need lower-level serialized events rather than trace spans, see [event-source-and-etw.md](./event-source-and-etw.md).

## Code Example

```csharp
using System.Diagnostics;

namespace DotNetRuntimeSamples.ActivityTracing;

internal static class Program
{
    private static readonly ActivitySource Source = new("Samples.Checkout", "1.0.0");

    private static void Main()
    {
        Activity.DefaultIdFormat = ActivityIdFormat.W3C;
        Baggage.SetBaggage("tenant.id", "contoso"); // Propagates across service boundaries.

        using Activity? request = Source.StartActivity("checkout.request", ActivityKind.Server);
        request?.SetTag("http.request.method", "POST");
        request?.SetTag("user.authenticated", true); // Prefer SetTag for normal span attributes.

        using Activity? payment = Source.StartActivity("payment.authorize", ActivityKind.Client);
        payment?.SetTag("payment.provider", "stripe");
        payment?.SetTag("cart.item_count", 3);

        Console.WriteLine($"TraceId: {Activity.Current?.TraceId}");
        Console.WriteLine($"ParentSpanId: {Activity.Current?.ParentSpanId}");
        Console.WriteLine($"Baggage tenant: {Baggage.Current.GetBaggage("tenant.id")}");

        // OpenTelemetry wiring usually looks like:
        // services.AddOpenTelemetry().WithTracing(builder => builder.AddSource("Samples.Checkout"));
    }
}
```

## Common Follow-up Questions

- What is the difference between tags and baggage?
- How does `Activity.Current` determine parent-child relationships?
- What do `traceparent` and `tracestate` contain?
- Why does OpenTelemetry subscribe to `ActivitySource` instead of inventing a separate span model?
- When would you prefer `EventSource` over `Activity`?

## Common Mistakes / Pitfalls

- Assuming baggage is local to one service when it actually propagates downstream.
- Using tags for sensitive or extremely high-cardinality values.
- Creating activities without registering the matching source name in OpenTelemetry.
- Manually breaking parent context instead of allowing `Activity.Current` and propagation middleware to flow it.
- Treating `Activity` as a logging API rather than a tracing API.

## References

- [Distributed tracing concepts — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/distributed-tracing-concepts)
- [Instrumentation walkthroughs — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/distributed-tracing-instrumentation-walkthroughs)
- [ActivitySource Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.diagnostics.activitysource)
- [W3C Trace Context Recommendation](https://www.w3.org/TR/trace-context/)
- [OpenTelemetry .NET tracing](https://opentelemetry.io/docs/languages/dotnet/traces/)
