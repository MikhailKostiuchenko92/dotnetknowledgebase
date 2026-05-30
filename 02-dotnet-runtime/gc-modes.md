# GC Modes: Workstation vs Server, Concurrent vs Background

**Category:** .NET Runtime / GC
**Difficulty:** 🟡 Middle
**Tags:** `GC modes`, `workstation GC`, `server GC`, `background GC`, `concurrent GC`, `latency`

## Question

> What are the different GC modes in .NET, and which should you choose for an ASP.NET Core application vs a desktop app?

Also asked as:
> What is the difference between workstation and server GC?
> What is background garbage collection and how does it reduce pause times?

## Short Answer

.NET GC has two primary modes: **Workstation GC** (optimised for low latency and UI responsiveness — single heap, background collection on a dedicated thread) and **Server GC** (optimised for throughput — one heap per logical CPU core, one dedicated GC thread per core). For ASP.NET Core / server apps, Server GC dramatically increases throughput by parallelising GC work. Both modes support **background GC** (Gen2 collected concurrently) by default, which minimises application pauses.

## Detailed Explanation

### Workstation GC

- **Single managed heap** (one Gen0/Gen1/Gen2 + LOH)
- **Single GC thread** for collections
- Optimised for **responsiveness**: Gen0 pauses are very short (< 1 ms typical)
- Default for console apps, desktop apps, unit test runners

```
Workstation GC heap:
┌──────────────────────────────────────┐
│  Single heap (Gen0/Gen1/Gen2/LOH)    │
│  One GC thread                       │
└──────────────────────────────────────┘
```

### Server GC

- **One heap per logical CPU core** (e.g., 8 heaps on 8-core machine)
- **One dedicated GC thread per heap**, running in parallel
- Allocation pointer per heap → threads allocate to their local heap (cache-friendly)
- Much higher throughput but uses more memory (proportional to heap count)
- Default for ASP.NET Core in .NET 6+ (automatically detected from environment)

```
Server GC (8-core machine):
┌──────────────────────────────────────┐
│  Heap 0 (GC thread 0)  Gen0/1/2/LOH │
│  Heap 1 (GC thread 1)  Gen0/1/2/LOH │
│  ...                                  │
│  Heap 7 (GC thread 7)  Gen0/1/2/LOH │
└──────────────────────────────────────┘
```

| Metric | Workstation | Server |
|--------|-------------|--------|
| Default memory overhead | Low | High (per-CPU heap) |
| Gen0/1 collection pauses | Short | Very short (parallel) |
| Gen2 collection pauses | Moderate | Low (parallel) |
| Best for | Desktop, single-user | Web servers, services |
| Allocation throughput | Moderate | Very high |

### Background GC (Concurrent Gen2)

Both workstation and server GC support **background GC** (enabled by default) for Gen2 collections:

- A dedicated background GC thread scans and marks Gen2 concurrently while app threads run
- App threads can still do Gen0/Gen1 "foreground" collections during a background Gen2 sweep
- Dramatically reduces Gen2 pause times compared to "blocking" Gen2 collections

```
Timeline with background GC:
App:        ──────────────────────────────────────────▶
Bg GC:            [Gen2 scan concurrently─────────────]
Fg pauses:                [G0]    [G0]    [G0]
```

Without background GC ("concurrent GC" disabled), Gen2 pauses the entire application for its full duration.

### Concurrent GC (Legacy Term)

In .NET Framework, "Concurrent GC" meant the Gen2 collection ran concurrently for workstation only. .NET Core extended this to "background GC" for both modes. "Concurrent GC" and "background GC" are now used interchangeably in most documentation.

### Configuration

```json
// runtimeconfig.json
{
  "configProperties": {
    "System.GC.Server": true,        // Server GC
    "System.GC.Concurrent": true,    // Background GC (default true)
    "System.GC.HeapCount": 4         // Override per-CPU heap count (advanced)
  }
}
```

```bash
# Environment variable
DOTNET_GCServer=1
DOTNET_GCConserveMemory=5   # 0-9, higher = more aggressive memory conservation
```

### Auto-Detection in Containers

.NET 6+ automatically enables Server GC when `System.GC.Server` is not explicitly set and the process detects it's running on a multi-CPU host with > 1 core. In containers, it respects CPU affinity set by Docker/Kubernetes cgroups.

> **Container best practice:** If your container is limited to 1 or 2 CPUs, set `System.GC.Server=false` or `System.GC.HeapCount=1`. Server GC with 8 heaps on a 2-CPU container wastes memory.

## Code Example

```csharp
using System.Runtime;

// Check current GC mode
Console.WriteLine($"Server GC:       {GCSettings.IsServerGC}");
Console.WriteLine($"Latency mode:    {GCSettings.LatencyMode}");
Console.WriteLine($"Concurrent GC:   enabled by default in .NET Core");

// GC memory info
GCMemoryInfo info = GC.GetGCMemoryInfo();
Console.WriteLine($"Available memory: {info.TotalAvailableMemoryBytes / 1024 / 1024} MB");
Console.WriteLine($"Heap size:        {info.HeapSizeBytes / 1024 / 1024} MB");

// Collection counts (server GC with 8 heaps → counts are per heap in some APIs)
int gen0 = GC.CollectionCount(0);
int gen1 = GC.CollectionCount(1);
int gen2 = GC.CollectionCount(2);
Console.WriteLine($"Collections: Gen0={gen0}, Gen1={gen1}, Gen2={gen2}");

// Temporarily switch to low-latency mode (avoid Gen2 blocking pauses)
var previous = GCSettings.LatencyMode;
GCSettings.LatencyMode = GCLatencyMode.SustainedLowLatency;
try
{
    // Time-critical section (e.g., real-time processing)
    ProcessRealTimeData();
}
finally
{
    GCSettings.LatencyMode = previous; // always restore!
}

void ProcessRealTimeData() { /* ... */ }
```

```json
// runtimeconfig.template.json — recommended for ASP.NET Core in containers
{
  "configProperties": {
    "System.GC.Server": true,
    "System.GC.HeapHardLimitPercent": 75
  }
}
```

## Common Follow-up Questions

- How does Server GC affect memory usage in a microservice with many small containers?
- What does `System.GC.HeapCount` do and when would you override the default?
- How does `GCSettings.LatencyMode = SustainedLowLatency` interact with Server GC?
- Is background GC always enabled in .NET Core, and can you turn it off?
- How does .NET GC compare to JVM's G1GC or ZGC in terms of pause times?
- What is the No GC Region feature and when is it appropriate?

## Common Mistakes / Pitfalls

- **Using Server GC in a 1-CPU / single-core container** — Server GC allocates per-core heaps; a 1-core container with Server GC is functionally identical to Workstation GC but wastes memory. Set `System.GC.HeapCount=1` or disable Server GC.
- **Disabling background GC (`System.GC.Concurrent=false`)** — disabling forces all Gen2 collections to be stop-the-world. Very rarely needed; only considered for server workloads with predictable allocation patterns where you control collection timing.
- **Not restoring `GCSettings.LatencyMode`** — failing to restore after a latency-sensitive section causes heap growth and eventual OOM because Gen2 collections are suppressed indefinitely.
- **Assuming Server GC always = better** — on memory-constrained machines, Server GC can double or triple the baseline heap size. Benchmark both modes for your workload.
- **Confusing `GCSettings.IsServerGC` with thread pool threads** — Server GC threads are separate from thread pool threads. `IsServerGC` returning `true` doesn't mean your code runs on more threads.

## References

- [Workstation and server garbage collection — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/workstation-server-gc)
- [Background garbage collection — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/background-gc)
- [GCSettings class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.gcsettings)
- [Configure GC for containers — Microsoft Learn](https://learn.microsoft.com/dotnet/core/runtime-config/garbage-collector)
- [See also: gc-generations.md](./gc-generations.md) | [gc-server-vs-workstation.md](./gc-server-vs-workstation.md)
