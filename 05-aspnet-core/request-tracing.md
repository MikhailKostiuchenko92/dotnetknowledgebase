# Request Tracing and Distributed Tracing in ASP.NET Core

**Category:** ASP.NET Core / Performance & Diagnostics
**Difficulty:** 🔴 Senior
**Tags:** `Activity`, `DiagnosticSource`, `OpenTelemetry`, `W3C-TraceContext`, `correlation-id`, `baggage`, `OTEL`

## Question

> How does distributed tracing work in ASP.NET Core? What is `Activity`, the W3C TraceContext header, and how do you integrate OpenTelemetry tracing?

## Short Answer

ASP.NET Core uses `System.Diagnostics.Activity` as the core tracing primitive. Every incoming HTTP request automatically starts an `Activity` using the `W3C TraceContext` format (`traceparent`, `tracestate` headers) — propagating `TraceId` and `SpanId` across service boundaries. OpenTelemetry instruments this activity, enriches it with HTTP metadata, and exports spans to backends (Jaeger, Zipkin, OTLP/Grafana Tempo). Use `Activity.Current` to access the current span; add tags/baggage to enrich context across services.

## Detailed Explanation

### W3C TraceContext propagation

```
Client → Service A → Service B → Database

Request headers:
  traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
               └── version─┘└──────────── TraceId ──────────────┘└──SpanId──┘└─flags┘
  tracestate: vendor1=value1, vendor2=value2
```

ASP.NET Core sets `traceparent` outgoing headers when using `IHttpClientFactory` + OTEL instrumentation, automatically linking spans across service calls.

### `Activity` API

```csharp
// ASP.NET Core automatically starts an Activity per request
// Access the current activity anywhere in the request
var activity = Activity.Current;
if (activity is not null)
{
    activity.SetTag("order.id", orderId.ToString());
    activity.SetTag("order.customer", customerId);
    activity.AddEvent(new ActivityEvent("PaymentProcessed",
        tags: new ActivityTagsCollection { ["paymentId"] = paymentId }));
}
```

### Creating child spans

```csharp
private static readonly ActivitySource _activitySource = new("MyApp.Orders");

public async Task ProcessOrderAsync(Order order)
{
    using var activity = _activitySource.StartActivity("ProcessOrder",
        ActivityKind.Internal,
        parentContext: Activity.Current?.Context ?? default);

    activity?.SetTag("order.id", order.Id);

    try
    {
        await _repo.SaveAsync(order);
        activity?.SetStatus(ActivityStatusCode.Ok);
    }
    catch (Exception ex)
    {
        activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
        activity?.RecordException(ex);
        throw;
    }
}
```

### OpenTelemetry tracing setup

```bash
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.Http
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
```

```csharp
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing =>
    {
        tracing
            .SetResourceBuilder(ResourceBuilder.CreateDefault()
                .AddService(serviceName: "MyApp.OrderService", serviceVersion: "1.0.0"))
            .AddAspNetCoreInstrumentation(opts =>
            {
                opts.RecordException = true;
                opts.Filter = ctx => !ctx.Request.Path.StartsWithSegments("/health");
            })
            .AddHttpClientInstrumentation()
            .AddSource("MyApp.*") // include custom ActivitySource spans
            .AddOtlpExporter(opts =>
            {
                opts.Endpoint = new Uri("http://otel-collector:4317");
                opts.Protocol = OtlpExportProtocol.Grpc;
            });

        if (builder.Environment.IsDevelopment())
            tracing.AddConsoleExporter();
    });
```

### Correlation IDs vs TraceId

- `TraceId` (W3C TraceContext): 16-byte hex, distributed-tracing standard, propagated via `traceparent` header.
- `CorrelationId`: application-level string, often carried in `X-Correlation-ID` header. Can be set to `TraceId` for consistency:

```csharp
app.Use((ctx, next) =>
{
    var traceId = Activity.Current?.TraceId.ToString()
        ?? ctx.Request.Headers["X-Correlation-ID"].FirstOrDefault()
        ?? Guid.NewGuid().ToString("N");

    ctx.Response.Headers["X-Correlation-ID"] = traceId;
    ctx.TraceIdentifier = traceId; // used by ILogger and exception pages
    return next(ctx);
});
```

### Baggage — cross-service context propagation

```csharp
// Set baggage (propagated in W3C baggage header)
Activity.Current?.SetBaggage("tenant.id", tenantId);

// Read in a downstream service
var tenantId = Activity.Current?.GetBaggageItem("tenant.id");
```

## Code Example

```csharp
// Custom ActivitySource for domain operations
public static class AppActivities
{
    public static readonly ActivitySource Orders = new("MyApp.Orders", "1.0");

    public static Activity? StartOrderProcessing(int orderId) =>
        Orders.StartActivity("order.process",
            tags: new ActivityTagsCollection { ["order.id"] = orderId });
}

// In service
public async Task FulfillAsync(Order order)
{
    using var span = AppActivities.StartOrderProcessing(order.Id);
    span?.SetTag("order.customerId", order.CustomerId);

    var sw = Stopwatch.StartNew();
    try
    {
        await _payment.ChargeAsync(order);
        await _warehouse.ReserveAsync(order);
        span?.AddEvent(new ActivityEvent("InventoryReserved"));
        span?.SetStatus(ActivityStatusCode.Ok);
    }
    catch (Exception ex)
    {
        span?.SetStatus(ActivityStatusCode.Error, ex.Message);
        span?.RecordException(ex);
        throw;
    }
    finally
    {
        span?.SetTag("duration_ms", sw.ElapsedMilliseconds);
    }
}
```

## Common Follow-up Questions

- What is the difference between `Activity.TraceId`, `Activity.SpanId`, and `Activity.ParentSpanId`?
- How does baggage propagation differ from `Activity.Tags`?
- How do you sample traces (e.g., only 10% of requests) in OpenTelemetry?
- How does `DiagnosticSource` relate to `ActivitySource`?
- How do you correlate log entries with trace spans using Serilog or Microsoft.Extensions.Logging?

## Common Mistakes / Pitfalls

- **Not registering the `ActivitySource` with `AddSource()`** — spans created by a source not registered with OpenTelemetry are silently discarded; always call `.AddSource("MyApp.*")`.
- **Creating `ActivitySource` as `static readonly` but not disposing** — `ActivitySource` implements `IDisposable`; static instances are fine (app lifetime), but created-per-scope instances must be disposed.
- **Setting baggage for request-scoped data** — baggage is propagated to ALL downstream services; only put data in baggage that is genuinely needed cross-service (e.g., tenant ID, correlation ID).
- **Not filtering health check endpoints** — without filtering, `/health` and `/metrics` endpoints generate traces that pollute the trace backend. Use `opts.Filter` in `AddAspNetCoreInstrumentation`.
- **Using `Activity.TraceId` as a user-facing correlation ID before OTEL is configured** — `Activity.TraceId` is empty until an `ActivityListener` (like OTEL) subscribes; fallback to `HttpContext.TraceIdentifier` for the correlation header.

## References

- [Microsoft Learn — Distributed tracing in .NET](https://learn.microsoft.com/dotnet/core/diagnostics/distributed-tracing)
- [W3C TraceContext specification](https://www.w3.org/TR/trace-context/)
- [OpenTelemetry .NET — ASP.NET Core instrumentation](https://github.com/open-telemetry/opentelemetry-dotnet/tree/main/src/OpenTelemetry.Instrumentation.AspNetCore)
- [Microsoft — Activity source](https://github.com/dotnet/runtime/blob/main/src/libraries/System.Diagnostics.DiagnosticSource/src/System/Diagnostics/ActivitySource.cs)
