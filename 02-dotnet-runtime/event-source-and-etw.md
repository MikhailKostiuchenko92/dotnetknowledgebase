# What Are EventSource and ETW in .NET?

**Category:** .NET Runtime / Diagnostics
**Difficulty:** 🟡 Middle
**Tags:** `EventSource`, `ETW`, `EventPipe`, `EventListener`, `DiagnosticSource`

## Question

> What is `EventSource` in .NET, and how does it relate to ETW or EventPipe?

Also asked as:
> How do you define high-performance diagnostic events with `[Event]` methods?
> When would you use `EventSource` instead of `DiagnosticSource`?

## Short Answer

`EventSource` is .NET's structured eventing API for emitting strongly typed diagnostic events. On Windows those events can flow to ETW, and cross-platform they flow through EventPipe, which is what tools like `dotnet-trace` consume. It is designed for low-overhead, out-of-process diagnostics, while `DiagnosticSource` is better for rich in-process instrumentation with object payloads.

## Detailed Explanation

### Why `EventSource` Exists

`EventSource` gives libraries and applications a stable schema for diagnostics events: event IDs, levels, keywords, opcodes, and payload fields. That matters because external tooling needs events that are cheap to emit and predictable to parse. A profiler, trace collector, or production support engineer cannot subscribe to arbitrary in-memory objects; it needs serialized event records.

In .NET Framework on Windows, the main transport was ETW. In modern .NET, the same `EventSource` instrumentation can also flow through EventPipe on Linux, macOS, and Windows, which is why the API still matters even if you are not ETW-specific.

### Defining Events Correctly

A typical pattern is to derive from `EventSource`, expose a singleton instance, and declare event methods with `[Event(id, Level = ...)]`. The event method should stay simple and forward primitive payloads to `WriteEvent` or `Write`. That keeps the event contract stable and fast.

| Concept | Purpose |
|---|---|
| Event ID | Stable numeric identity for tooling and compatibility |
| Level | Severity such as Informational, Warning, or Error |
| Keywords | Bit flags for selective filtering |
| Channel | ETW-oriented routing classification on Windows |
| Payload fields | Serialized data visible out of process |

Keywords are especially useful because collectors can subscribe only to event families they care about. Channels matter more in ETW-centric Windows setups; EventPipe primarily filters by provider, level, and keywords.

### Performance Considerations

`EventSource` is designed for hot paths, but only if you use it carefully. The classic rule is to guard expensive work with `IsEnabled()` before creating formatted strings or serializing large payloads. Without that check, you can pay the allocation cost even when no listener is attached.

> Warning: do not pass large object graphs or already-formatted JSON into `EventSource` as if it were normal application logging. It is a diagnostics pipeline, not a replacement for every logging scenario.

The best payloads are small, primitive, and versionable: IDs, durations, sizes, counts, and short strings.

### `EventListener` vs `DiagnosticSource`

`EventListener` is an in-process subscriber for `EventSource`. It is useful in tests, integration with another logging system, or local debugging when you want to inspect events without attaching an external tool. You can turn providers on, filter levels and keywords, and inspect the payloads synchronously inside the process.

`DiagnosticSource` solves a different problem. It is intended for richer in-process observability where publishers may attach object payloads, HTTP request models, or custom context. That makes it ideal for ASP.NET Core and OpenTelemetry bridges, but those payloads are not naturally suited to low-level out-of-process trace tools. A good interview summary is: `DiagnosticSource` is richer and more flexible inside the process; `EventSource` is more stable and tooling-friendly outside the process.

For tooling that captures providers externally, see [dotnet-diagnostics-tools.md](./dotnet-diagnostics-tools.md).

## Code Example

```csharp
using System.Diagnostics.Tracing;

namespace DotNetRuntimeSamples.EventSources;

[EventSource(Name = "Samples-Checkout")]
internal sealed class CheckoutEventSource : EventSource
{
    public static readonly CheckoutEventSource Log = new();

    public static class Keywords
    {
        public const EventKeywords Requests = (EventKeywords)1;
        public const EventKeywords Payments = (EventKeywords)2;
    }

    [Event(1, Level = EventLevel.Informational, Keywords = Keywords.Requests)]
    public void RequestStarted(string route) => WriteEvent(1, route);

    [Event(2, Level = EventLevel.Error, Keywords = Keywords.Payments)]
    public void PaymentFailed(string orderId, string reason) => WriteEvent(2, orderId, reason);

    public void RequestCompleted(string route, long elapsedMs)
    {
        if (!IsEnabled())
        {
            return; // Avoid payload work when no listener is enabled.
        }

        Write("RequestCompleted", new EventSourceOptions { Level = EventLevel.Informational }, new { route, elapsedMs });
    }
}

internal sealed class ConsoleEventListener : EventListener
{
    protected override void OnEventSourceCreated(EventSource eventSource)
    {
        if (eventSource.Name == "Samples-Checkout")
        {
            EnableEvents(eventSource, EventLevel.Informational, EventKeywords.All); // Subscribe in-process.
        }
    }

    protected override void OnEventWritten(EventWrittenEventArgs eventData)
    {
        Console.WriteLine($"[{eventData.Level}] {eventData.EventName}: {string.Join(", ", eventData.Payload ?? [])}");
    }
}
```

## Common Follow-up Questions

- Why are keywords useful when collecting traces from production?
- What is the difference between ETW and EventPipe in modern .NET?
- When should you use `EventListener` instead of an external collector?
- Why is `IsEnabled()` important on hot paths?
- How is `DiagnosticSource` different from `EventSource` for payload design?

## Common Mistakes / Pitfalls

- Building expensive strings before checking `IsEnabled()`.
- Treating `EventSource` like general-purpose business logging instead of structured diagnostics.
- Changing event IDs or payload shape casually and breaking downstream tooling.
- Assuming channels matter equally on every platform; they are mostly an ETW concept.
- Emitting complex object payloads when simple scalar fields would be more stable and cheaper.

## References

- [EventSource Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.diagnostics.tracing.eventsource)
- [EventListener Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.diagnostics.tracing.eventlistener)
- [Tracing with EventSource — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/eventsource-instrumentation)
- [dotnet-trace — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-trace)
- [DiagnosticSource User Guide](https://github.com/dotnet/runtime/blob/main/src/libraries/System.Diagnostics.DiagnosticSource/src/DiagnosticSourceUsersGuide.md)
