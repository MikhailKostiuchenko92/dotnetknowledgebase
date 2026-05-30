# How Do the .NET Diagnostics CLI Tools Work?

**Category:** .NET Runtime / Diagnostics
**Difficulty:** 🟢 Junior
**Tags:** `dotnet-counters`, `dotnet-trace`, `dotnet-dump`, `dotnet-gcdump`, `eventpipe`

## Question

> What are the main `dotnet-*` diagnostics tools, and when would you use each one?

Also asked as:
> How do `dotnet-counters`, `dotnet-trace`, `dotnet-dump`, and `dotnet-gcdump` differ in a production incident?
> If a .NET process is slow or leaking memory, which diagnostics CLI tool would you reach for first?

## Short Answer

The `dotnet-*` diagnostics tools solve different investigation levels. `dotnet-counters` shows live runtime metrics, `dotnet-trace` records EventPipe traces, `dotnet-dump` captures and analyzes full managed dumps, `dotnet-gcdump` captures a lightweight heap snapshot, and `dotnet-stack` prints thread stacks immediately. In practice, you start with counters for symptoms, traces for timing, and dumps or GC dumps for retention and memory-root analysis.

## Detailed Explanation

### The Core Idea

The .NET runtime exposes diagnostics data through EventPipe, runtime counters, and dump infrastructure. The command-line tools in the `dotnet/diagnostics` family package those capabilities into workflows that are safe enough for production, especially when you need answers without restarting the process.

You usually install them as global tools:

- `dotnet tool install -g dotnet-counters`
- `dotnet tool install -g dotnet-trace`
- `dotnet tool install -g dotnet-dump`
- `dotnet tool install -g dotnet-gcdump`
- `dotnet tool install -g dotnet-stack`

### What Each Tool Is Best At

| Tool | Best use case | Typical output |
|---|---|---|
| `dotnet-counters` | Live health check | Allocation rate, GC, thread pool, exceptions, requests/sec |
| `dotnet-trace` | Time-based performance investigation | EventPipe trace for PerfView, SpeedScope, or other viewers |
| `dotnet-dump` | Memory leak or crash investigation | Full managed dump plus SOS analysis |
| `dotnet-gcdump` | Heap-size and type-retention snapshot | Lightweight GC heap summary |
| `dotnet-stack` | Fast thread-state inspection | Snapshot of all managed thread stacks |

`dotnet-counters monitor` is often the best first step because it tells you whether the issue smells like allocation pressure, thread-pool starvation, exception storms, or request throughput collapse. If counters show abnormal behavior over time, `dotnet-trace collect` lets you capture the timeline behind it.

### Trace vs Dump vs GC Dump

A trace is about **what happened over time**. With `dotnet-trace`, you capture runtime providers and later inspect them in PerfView or SpeedScope to understand CPU usage, GC pauses, JIT activity, or request latency. This connects directly to [jit-diagnostics.md](./jit-diagnostics.md).

A dump is about **what the process looked like at one moment**. `dotnet-dump collect` captures a managed core dump, and `dotnet-dump analyze` gives you SOS-style commands such as `dumpheap -stat`, `gcroot`, and `clrstack`. That is the right tool when you need to know which objects are alive, why they are rooted, or what a stuck thread is doing.

`dotnet-gcdump` sits between counters and a full dump. It is much lighter than a full dump and focuses on managed heap shape rather than every address space detail. It is ideal when production policy allows a heap snapshot but not a full dump. Open the result in Visual Studio or a heap viewer to compare type growth over time. It also complements [gc-notifications-and-monitoring.md](./gc-notifications-and-monitoring.md).

> Warning: none of these tools are completely free. Even “lightweight” collection adds some pause or overhead, so capture the smallest artifact that answers the question.

### A Practical Incident Workflow

A strong interview answer is to describe an escalation ladder:

1. Use `dotnet-counters` to confirm symptoms live.
2. If timing matters, capture `dotnet-trace` and inspect hot paths and pauses.
3. If memory retention matters, capture `dotnet-gcdump` first.
4. If you need object roots or stack-by-stack state, escalate to `dotnet-dump`.
5. If threads appear hung right now, run `dotnet-stack` immediately.

That sequence avoids grabbing heavyweight artifacts before you know the failure mode.

## Code Example

```csharp
using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace DotNetRuntimeSamples.DiagnosticsTools;

internal static class Program
{
    private static readonly Meter Meter = new("RuntimeSamples.Diagnostics", "1.0.0");
    private static readonly Counter<int> Requests = Meter.CreateCounter<int>("sample.requests");

    private static void Main()
    {
        Console.WriteLine($"PID: {Environment.ProcessId}");
        Console.WriteLine("Press Ctrl+C after attaching a diagnostics tool.");

        for (int i = 0; i < 20; i++)
        {
            Requests.Add(1, new KeyValuePair<string, object?>("route", "/health")); // Visible to counters/metrics tooling.
            _ = Enumerable.Range(1, 10_000).Select(x => x * 2).ToArray(); // Create some allocations.
            Thread.Sleep(500);
        }

        // Example commands to run from another terminal:
        // dotnet-counters monitor --process-id <pid> System.Runtime
        // dotnet-trace collect --process-id <pid>
        // dotnet-gcdump collect --process-id <pid>
        // dotnet-dump collect --process-id <pid>
        // dotnet-stack --process-id <pid>
    }
}
```

## Common Follow-up Questions

- When would you choose `dotnet-gcdump` over `dotnet-dump`?
- What runtime providers would you enable in `dotnet-trace` for GC or JIT analysis?
- Which counters are the best first ones to watch in an ASP.NET Core service?
- How do `gcroot` and `dumpheap -stat` help with memory leaks?
- When is `dotnet-stack` enough without taking a dump?

## Common Mistakes / Pitfalls

- Treating `dotnet-counters` as a root-cause tool when it mainly shows symptoms and trends.
- Taking a full dump first when a lighter `dotnet-gcdump` or trace would have answered the question.
- Forgetting to analyze traces with the right viewer such as PerfView or SpeedScope.
- Capturing too much data in production instead of using the smallest useful artifact.
- Assuming GC dumps replace full dumps; they help with heap shape, not full stack and native-state analysis.

## References

- [Diagnostics tools overview — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/)
- [dotnet-counters — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-counters)
- [dotnet-trace — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-trace)
- [dotnet-dump — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-dump)
- [dotnet-gcdump — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-gcdump)
