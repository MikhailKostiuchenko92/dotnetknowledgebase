# GC Notifications and Monitoring

**Category:** .NET Runtime / GC
**Difficulty:** 🔴 Senior
**Tags:** `GC notifications`, `GCMemoryInfo`, `ETW`, `dotnet-counters`, `monitoring`, `diagnostics`

## Question

> How can you monitor garbage collection behavior in production .NET applications?

Also asked as:
> What does `GC.RegisterForFullGCNotification` do, and when is it useful?
> How do `GC.GetGCMemoryInfo`, ETW events, and `dotnet-counters` complement each other?

## Short Answer

.NET offers both in-process and out-of-process GC monitoring. In-process APIs such as `GC.RegisterForFullGCNotification` and `GC.GetGCMemoryInfo` let applications react to or inspect GC behavior, while external tools such as ETW/EventPipe, `dotnet-counters`, `dotnet-trace`, and PerfView provide richer operational visibility. In practice, you use counters for live trend monitoring, event traces for deep diagnosis, and `GCMemoryInfo` for application-level decisions or health endpoints.

## Detailed Explanation

### `GC.RegisterForFullGCNotification`

`GC.RegisterForFullGCNotification` lets a process ask the runtime for notifications before and after a **full blocking GC**. The typical use case is load shedding or throttling: if the process learns a full GC is imminent, it can delay accepting work, flush queues, or reduce allocation spikes.

This is an advanced API and not universally applicable. It is most relevant in long-running server processes where the application can actually change behavior in response.

### `GC.GetGCMemoryInfo`

`GC.GetGCMemoryInfo()` provides a snapshot of current GC state such as heap size, fragmented bytes, committed memory, high-memory-load thresholds, and pause-related information. There is also an overload that takes `GCKind`, allowing you to query the most recent **full**, **ephemeral**, or **background** collection details.

A particularly useful part is `GenerationInfo`, which reports per-generation information from **Gen0 through the LOH**. That helps distinguish “many short-lived allocations” from “Gen2 or LOH retention problems”.

| API/tool | Best for |
|---|---|
| `GC.GetGCMemoryInfo` | In-process snapshot |
| `RegisterForFullGCNotification` | Advanced load balancing or throttling |
| `dotnet-counters monitor` | Live operational metrics |
| ETW / EventPipe | Deep root-cause analysis |

### ETW / EventPipe GC Events

For production diagnostics, GC events are among the most important runtime signals. Events such as **GCStart**, **GCEnd**, and **GCHeapStats** show when collections happen, what kind they were, and how the heap changed. On Windows, ETW has long been the gold standard; cross-platform, EventPipe powers tools like `dotnet-trace` and `dotnet-counters`.

These events answer questions like:
- Are Gen2 collections too frequent?
- Is LOH growth driving pauses?
- Is fragmentation increasing over time?
- Are background GCs overlapping with foreground pressure?

> **Warning:** Metrics alone rarely explain *why* memory is high. Counters tell you that something is happening; heap dumps and traces explain what is being retained.

### `dotnet-counters monitor`

`dotnet-counters monitor` is the fastest way to watch live GC health. Common counters include allocation rate, GC count, and heap sizes by generation. For example, watching Gen2 heap size and allocation rate together often reveals whether the problem is retention or just healthy temporary churn.

Typical counters to watch:
- allocation rate
- gc heap size
- gen-0/1/2 gc count
- time in GC
- LOH size if surfaced via runtime metrics tooling

### Putting It Together

A practical production workflow often looks like this:
1. Use `dotnet-counters` or your telemetry stack to detect abnormal allocation rate or heap growth.
2. Capture a trace with GC events if the issue persists.
3. Capture a heap dump if you suspect retention, cache leaks, or static roots.
4. Use `GC.GetGCMemoryInfo` in health endpoints or debug logs for app-aware snapshots.

Related: [GC modes](./gc-modes.md) and [dotnet diagnostics tools](./dotnet-diagnostics-tools.md).

## Code Example

```csharp
using System.Runtime;

namespace DotNetRuntimeExamples;

internal static class Program
{
    private static void Main()
    {
        GC.RegisterForFullGCNotification(maxGenerationThreshold: 10, largeObjectHeapThreshold: 10);

        GCMemoryInfo overall = GC.GetGCMemoryInfo();
        GCMemoryInfo lastFull = GC.GetGCMemoryInfo(GCKind.FullBlocking);

        Console.WriteLine($"Heap size: {overall.HeapSizeBytes / 1024 / 1024} MB");
        Console.WriteLine($"Fragmented bytes: {overall.FragmentedBytes / 1024 / 1024} MB");
        Console.WriteLine($"Last full GC pause time %: {lastFull.PauseTimePercentage}");

        foreach (var generation in overall.GenerationInfo)
        {
            Console.WriteLine($"Size before: {generation.SizeBeforeBytes}, after: {generation.SizeAfterBytes}");
        }

        // Out-of-process examples:
        // dotnet-counters monitor --process-id <pid> System.Runtime
        // dotnet-trace collect --process-id <pid>
    }
}
```

## Common Follow-up Questions

- When does `RegisterForFullGCNotification` help in real systems?
- What kinds of `GCKind` can you query with `GC.GetGCMemoryInfo`?
- Which ETW/EventPipe GC events are most useful first: `GCStart`, `GCEnd`, or `GCHeapStats`?
- How do you tell allocation churn from memory retention?
- What counters should you put on a production dashboard for GC?
- When should you take a heap dump instead of just reading counters?

## Common Mistakes / Pitfalls

- Expecting `RegisterForFullGCNotification` to be a universal autoscaling solution.
- Looking only at total process memory instead of generation-specific GC metrics.
- Treating a rising heap size as automatically bad without checking allocation rate and pause behavior.
- Using counters alone to diagnose leaks when a dump or trace is required.
- Ignoring LOH and fragmentation while focusing only on Gen0 counts.

## References

- [GC.RegisterForFullGCNotification](https://learn.microsoft.com/dotnet/api/system.gc.registerforfullgcnotification)
- [GC.GetGCMemoryInfo](https://learn.microsoft.com/dotnet/api/system.gc.getgcmemoryinfo)
- [dotnet-counters](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-counters)
- [Logging and tracing .NET runtime events](https://learn.microsoft.com/dotnet/core/diagnostics/runtime-garbage-collection-events)
- [dotnet diagnostics overview](https://learn.microsoft.com/dotnet/core/diagnostics/)
