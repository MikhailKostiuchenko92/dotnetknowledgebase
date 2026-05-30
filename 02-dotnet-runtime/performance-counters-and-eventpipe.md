# What Are Performance Counters, EventPipe, and DiagnosticsClient in .NET?

**Category:** .NET Runtime / Diagnostics
**Difficulty:** 🔴 Senior
**Tags:** `EventPipe`, `DiagnosticsClient`, `EventPipeProvider`, `profiling`, `runtime-providers`

## Question

> What is EventPipe in .NET, and how is it different from old Windows performance counters or ETW-only diagnostics?

Also asked as:
> How do you collect runtime events programmatically with `DiagnosticsClient`?
> What are runtime providers, and how do profilers attach to a .NET process in production?

## Short Answer

EventPipe is the cross-platform diagnostics transport built into modern .NET. It carries runtime events, counters, and traces on Windows, Linux, and macOS, and tools such as `dotnet-trace` or `dotnet-counters` use it under the hood. Programmatically, you can attach with `DiagnosticsClient`, configure `EventPipeProvider` instances, and stream events from providers like `Microsoft-Windows-DotNETRuntime` or `System.Runtime`; separate profiler-based products can also attach through `CORECLR_PROFILER`, but that is a different integration path with its own overhead profile.

## Detailed Explanation

### Why EventPipe Matters

Classic Windows performance counters and ETW solved diagnostics well on Windows, but they were platform-specific. Modern .NET needed a built-in transport that worked consistently across operating systems and containers. EventPipe is that transport.

It lets the runtime publish structured events, sampling data, and counters inside the process and stream them to an external listener without requiring a debugger. That is why current diagnostics tooling feels similar across Linux, macOS, and Windows.

| Mechanism | Scope | Typical use |
|---|---|---|
| Windows perf counters | Windows only | Legacy machine-level counters |
| ETW | Windows only | High-volume event tracing |
| EventPipe | Cross-platform | Runtime traces, counters, programmatic sessions |
| CLR profiler API | In-process profiler hook | Continuous APM/profiling products |

### Providers and Sessions

EventPipe itself is just the pipeline. To collect anything useful, you choose providers. `EventPipeProvider` specifies provider name, level, and keywords. Provider names such as `Microsoft-Windows-DotNETRuntime` or `System.Runtime` determine which event families are emitted.

This model mirrors ETW concepts, but it works cross-platform. A session can subscribe to several providers at once, which is how one trace can include GC, thread-pool, exception, and application events together.

### Programmatic Collection with `DiagnosticsClient`

The `Microsoft.Diagnostics.NETCore.Client` package exposes `DiagnosticsClient`, which can attach to a process ID and start an EventPipe session programmatically. This is useful for custom support tools, test harnesses, or automated capture triggered by a health monitor.

The key point in interviews is that `DiagnosticsClient` is not a profiler. It is an out-of-process client that talks to the runtime diagnostics server. That usually makes it safer and easier to deploy than rewriting your service to include custom trace exporters.

> Warning: attaching diagnostics sessions or profilers to production processes always has cost. Keep provider sets tight, collect for short windows, and validate overhead under load before standardizing the workflow.

### Continuous Profiling and `CORECLR_PROFILER`

Some commercial profilers and APM agents use the CLR profiler API rather than EventPipe. They attach by setting environment variables such as `CORECLR_ENABLE_PROFILING`, `CORECLR_PROFILER`, and provider-specific paths or CLSIDs. That approach gives deeper instrumentation options, but it is fundamentally different from EventPipe collection and can have broader behavioral impact.

### Runtime Providers in Practice

The built-in providers matter because they define the language of the trace. `System.Runtime` is often the first stop for counters and high-level runtime signals, while `Microsoft-Windows-DotNETRuntime` exposes lower-level runtime events such as GC, loader, exception, and threading activity. Adding your own `EventSource` providers lets you correlate application phases with runtime behavior in the same collection. That combination is usually more powerful than either source alone because you can finally answer not only that the GC paused, but which request or operation led to the allocation spike.

A solid senior-level answer is: EventPipe is the runtime's cross-platform diagnostics stream; the profiler API is an instrumentation extension point for always-on agents. For CLI workflows, also see [dotnet-diagnostics-tools.md](./dotnet-diagnostics-tools.md). For JIT-focused tracing, see [jit-diagnostics.md](./jit-diagnostics.md).

## Code Example

```csharp
using Microsoft.Diagnostics.NETCore.Client;
using Microsoft.Diagnostics.Tracing;
using Microsoft.Diagnostics.Tracing.Parsers;

namespace DotNetRuntimeSamples.EventPipe;

internal static class Program
{
    private static void Main(string[] args)
    {
        int processId = int.Parse(args[0]); // Target PID supplied by the caller.

        var client = new DiagnosticsClient(processId);
        var providers = new List<EventPipeProvider>
        {
            new("System.Runtime", EventLevel.Informational), // Runtime counters and events.
            new("Microsoft-Windows-DotNETRuntime", EventLevel.Informational, keywords: 0x1) // Example keyword mask.
        };

        using var session = client.StartEventPipeSession(providers, requestRundown: false);
        using var source = new EventPipeEventSource(session.EventStream);

        source.Dynamic.All += traceEvent =>
            Console.WriteLine($"{traceEvent.ProviderName}::{traceEvent.EventName}"); // Stream events as they arrive.

        source.Process();
    }
}
```

## Common Follow-up Questions

- How is EventPipe different from ETW conceptually and operationally?
- Why would you use `DiagnosticsClient` instead of embedding custom tracing logic in the app?
- What do provider level and keyword masks control?
- When is a profiler attached via `CORECLR_PROFILER` more appropriate than an EventPipe session?
- Which built-in providers are most useful for runtime investigations?

## Common Mistakes / Pitfalls

- Confusing EventPipe with the profiler API; they are related to diagnostics but not the same mechanism.
- Enabling overly broad provider sets and collecting far more data than needed.
- Assuming old Windows performance counters are the primary diagnostics story in modern cross-platform .NET.
- Forgetting that continuous profilers can change startup, memory, and runtime overhead characteristics.
- Starting long-running collection sessions in production without validating cost.

## References

- [EventPipe — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/eventpipe)
- [Microsoft.Diagnostics.NETCore.Client package](https://www.nuget.org/packages/Microsoft.Diagnostics.NETCore.Client)
- [Well-known Event Providers — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/well-known-event-providers)
- [dotnet-trace — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-trace)
- [CLR Profiling overview (verify URL)](https://learn.microsoft.com/dotnet/framework/unmanaged-api/profiling/profiling-overview)
