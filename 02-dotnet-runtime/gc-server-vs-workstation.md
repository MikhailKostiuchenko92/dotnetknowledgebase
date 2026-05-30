# Server GC vs Workstation GC

**Category:** .NET Runtime / GC
**Difficulty:** 🟡 Middle
**Tags:** `server GC`, `workstation GC`, `heap count`, `throughput`, `latency`, `containers`

## Question

> What is the difference between Server GC and Workstation GC in .NET?

Also asked as:
> Why does Server GC create one heap per logical processor, and when is that better than Workstation GC?
> How do ASP.NET Core, containers, and `System.GC.HeapCount` affect the choice between Server and Workstation GC?

## Short Answer

Workstation GC is optimized for responsiveness and lower memory overhead, so it is usually better for desktop apps, command-line tools, and smaller services. Server GC is optimized for throughput: it creates one managed heap per logical processor and runs GC work in parallel, which usually improves request throughput on multicore web servers at the cost of higher memory usage. In modern ASP.NET Core deployments, Server GC is commonly the right default, but container CPU limits and heap-count overrides can change that trade-off.

## Detailed Explanation

### What Actually Changes Between the Modes

The biggest architectural difference is the heap model. **Workstation GC** uses a single managed heap and is designed to keep pause times small and memory overhead modest. **Server GC** creates **one heap per logical processor** and assigns dedicated GC worker threads so collection work can run in parallel.

| Aspect | Workstation GC | Server GC |
|---|---|---|
| Heap layout | Single managed heap | One heap per logical processor |
| Primary goal | Low latency / responsiveness | High throughput |
| GC threads | Fewer | One or more dedicated GC threads per heap |
| Memory overhead | Lower | Higher |
| Best fit | Desktop/UI, small jobs, low-core containers | ASP.NET Core, APIs, background services on multicore hosts |

With Server GC on an 8 logical CPU machine, the runtime typically creates **8 heaps**. Each heap has its own Gen0/Gen1 allocation context, which reduces contention during allocation. During collection, the GC can scan and compact those heaps in parallel, so total work scales much better under heavy load.

### Throughput vs Latency

Server GC usually wins when the process is allocation-heavy and can keep multiple cores busy. In web workloads, benchmarks often show **1.3x to 2x higher throughput** than Workstation GC on 8–16 core machines, but memory usage is often **20% to 50% higher** because each heap carries its own segments, card tables, and allocation budget. The exact number depends on allocation rate, object lifetime, LOH usage, and CPU count.

Workstation GC usually has smaller working-set growth and is friendlier to interactive apps because it avoids the per-CPU heap model. A WPF or WinForms app often prefers predictable responsiveness over peak requests-per-second.

> **Warning:** Server GC is not automatically “faster” for every app. On a 1 vCPU or 2 vCPU container, extra GC infrastructure can add memory cost without delivering meaningful parallelism.

### ASP.NET Core and Automatic Selection

ASP.NET Core applications are commonly configured to use Server GC by default in real server deployments because the hosting model assumes a throughput-oriented workload. The runtime also respects **container CPU limits and processor affinity**, so if Kubernetes or Docker limits the process to fewer CPUs, the GC sees fewer logical processors and reduces heap count accordingly.

That matters because heap count follows the processor view the runtime can use, not necessarily the host machine’s physical core count. If the container is pinned to 2 CPUs, Server GC usually creates 2 heaps, not 32.

### `System.GC.HeapCount` and Advanced Overrides

You can override the default heap count with `System.GC.HeapCount` in runtime configuration. This is an advanced knob used when you want Server GC but do not want one heap per visible logical CPU.

```json
{
  "configProperties": {
    "System.GC.Server": true,
    "System.GC.HeapCount": 4
  }
}
```

This is useful for dense multi-tenant hosts, NUMA experiments, or containers where visible CPUs exceed what the service should actually use for GC. It is a tuning parameter, not a first-choice setting.

### When Each Mode Is Better

Choose **Workstation GC** when:
- UI responsiveness matters more than raw throughput
- the process is small or short-lived
- memory headroom is tight
- the service runs on very small CPU limits

Choose **Server GC** when:
- request throughput matters
- the host has several logical processors
- allocation rate is high
- the app is an ASP.NET Core API, queue worker, or other long-running service

Related: [GC Modes](./gc-modes.md).

## Code Example

```csharp
using System.Runtime;

namespace DotNetRuntimeExamples;

internal static class Program
{
    private static void Main()
    {
        Console.WriteLine($"Server GC: {GCSettings.IsServerGC}");
        Console.WriteLine($"Latency mode: {GCSettings.LatencyMode}");
        Console.WriteLine($"Processor count visible to runtime: {Environment.ProcessorCount}");

        // Allocate some temporary objects so we can observe collection counters.
        for (int i = 0; i < 100_000; i++)
        {
            _ = new byte[256]; // Short-lived allocation.
        }

        Console.WriteLine($"Gen0 collections: {GC.CollectionCount(0)}");
        Console.WriteLine($"Gen1 collections: {GC.CollectionCount(1)}");
        Console.WriteLine($"Gen2 collections: {GC.CollectionCount(2)}");

        GCMemoryInfo info = GC.GetGCMemoryInfo();
        Console.WriteLine($"Heap size: {info.HeapSizeBytes / 1024 / 1024} MB");
        Console.WriteLine($"Fragmented bytes: {info.FragmentedBytes / 1024 / 1024} MB");
    }
}

// Example runtimeconfig.template.json settings:
// {
//   "configProperties": {
//     "System.GC.Server": true,
//     "System.GC.HeapCount": 4
//   }
// }
```

## Common Follow-up Questions

- Why does Server GC usually increase memory usage?
- How does Server GC interact with background GC?
- What happens on NUMA machines with Server GC?
- When would you override `System.GC.HeapCount` manually?
- How do container CPU quotas affect heap count and GC behavior?
- How can you verify the current mode in production?

## Common Mistakes / Pitfalls

- Assuming Server GC is always the best choice, even for desktop apps or tiny containers.
- Forgetting that heap count normally follows **visible logical processors**, not marketing core counts.
- Overriding `System.GC.HeapCount` without benchmarking, which can reduce throughput instead of improving it.
- Evaluating only pause time and ignoring higher steady-state memory usage under Server GC.
- Treating ASP.NET Core defaults as universal truth instead of verifying with `GCSettings.IsServerGC` and real measurements.

## References

- [Workstation and server garbage collection](https://learn.microsoft.com/dotnet/standard/garbage-collection/workstation-server-gc)
- [Runtime configuration options for garbage collection](https://learn.microsoft.com/dotnet/core/runtime-config/garbage-collector)
- [GCSettings.IsServerGC](https://learn.microsoft.com/dotnet/api/system.runtime.gcsettings.isservergc)
- [Background garbage collection](https://learn.microsoft.com/dotnet/standard/garbage-collection/background-gc)
