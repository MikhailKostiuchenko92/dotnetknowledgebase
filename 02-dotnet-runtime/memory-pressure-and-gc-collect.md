# Memory Pressure, `GC.Collect()`, and Low-Latency GC Modes

**Category:** .NET Runtime / GC
**Difficulty:** 🟡 Middle
**Tags:** `GC.AddMemoryPressure`, `GC.Collect`, `LatencyMode`, `NoGCRegion`, `unmanaged memory`, `performance`

## Question

> When should you use `GC.AddMemoryPressure`, `GC.Collect()`, or low-latency GC settings in .NET?

Also asked as:
> Why is calling `GC.Collect()` usually a bad idea?
> What are `GCLatencyMode` and `GC.TryStartNoGCRegion`, and when are they justified?

## Short Answer

`GC.AddMemoryPressure` and `GC.RemoveMemoryPressure` are niche APIs for types that allocate significant unmanaged memory the GC cannot otherwise “see”. `GC.Collect()` is usually harmful because it breaks the generational heuristics that make the GC efficient and often forces expensive Gen2 work. Low-latency settings such as `LowLatency`, `SustainedLowLatency`, and `NoGCRegion` are specialized tools for short real-time windows where pauses matter more than memory growth.

## Detailed Explanation

### Why the GC Usually Knows Better Than You

The .NET GC is generational and adaptive. It decides when to collect based on allocation budgets, promotion rates, fragmentation, and memory pressure. A manual `GC.Collect()` call bypasses those heuristics and often forces a more expensive collection than the runtime would have chosen.

That is why “I created garbage, so I should collect now” is usually wrong. Short-lived garbage is exactly what Gen0 is designed to handle efficiently.

### `GC.AddMemoryPressure` and `RemoveMemoryPressure`

These APIs exist for wrappers around **large unmanaged allocations**. If your object allocates 500 MB through native code but only stores an `IntPtr` on the managed heap, the GC sees a tiny managed object and may delay collection too long. `GC.AddMemoryPressure` tells the runtime that your managed object is associated with significant external memory.

Use it only when:
- the unmanaged allocation is substantial
- the wrapper’s lifetime maps closely to that allocation
- you reliably call `RemoveMemoryPressure` when the unmanaged memory is released

> **Warning:** Over-reporting memory pressure can cause the GC to collect too aggressively and hurt throughput.

### Why `GC.Collect()` Is Usually a Pitfall

A forced collection can:
- trigger a full blocking Gen2 collection
- promote objects that would otherwise die naturally later
- increase pause time
- reduce throughput by interrupting useful work

In effect, you are telling the GC to stop trusting its generational model. That is why explicit collection is rarely justified in request-processing code, UI code, or library code.

Justified cases do exist, but they are rare: after unloading a large plugin, after a one-time bulk import right before an idle period, or in diagnostics/test scenarios where you intentionally want a collection boundary.

### `GCSettings.LatencyMode`

`GCLatencyMode` lets you bias the runtime toward responsiveness:

| Mode | Typical meaning |
|---|---|
| `Interactive` | Default balanced mode |
| `Batch` | Favor throughput over responsiveness |
| `LowLatency` | Avoid Gen2 as much as possible for a short critical section |
| `SustainedLowLatency` | Longer-running low-pause mode, still not free |
| `NoGCRegion` | Try to prevent GC entirely during a bounded interval |

`LowLatency` is meant for **short windows**. `SustainedLowLatency` is safer for longer periods but can still increase heap growth and fragmentation.

### `GC.TryStartNoGCRegion`

`TryStartNoGCRegion` asks the runtime to reserve enough budget so a section can run without triggering GC. If the runtime cannot guarantee that budget, the call returns `false`. If it succeeds, you must later call `GC.EndNoGCRegion()`.

This is useful only for tightly controlled real-time segments such as audio processing, market-data handling, or device control loops where even a brief GC pause is unacceptable.

The burden is on you to avoid excessive allocation during the region. If you exceed the promised budget, the runtime may be forced to break the no-GC contract.

### Practical Guidance

Use these APIs only when you can explain exactly what problem they solve and measure the result. In most applications, better wins come from reducing allocations, pooling buffers, avoiding pinning, and disposing unmanaged resources promptly.

## Code Example

```csharp
using System.Runtime;
using System.Runtime.InteropServices;

namespace DotNetRuntimeExamples;

internal sealed class NativeImage : IDisposable
{
    private readonly nint _pixels;
    private readonly long _bytes;
    private bool _disposed;

    public NativeImage(long bytes)
    {
        _bytes = bytes;
        _pixels = Marshal.AllocHGlobal((nint)bytes);
        GC.AddMemoryPressure(bytes); // Tell the GC about large unmanaged memory.
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        Marshal.FreeHGlobal(_pixels);
        GC.RemoveMemoryPressure(_bytes); // Must match AddMemoryPressure.
        _disposed = true;
    }
}

internal static class Program
{
    private static void Main()
    {
        GCLatencyMode previous = GCSettings.LatencyMode;
        GCSettings.LatencyMode = GCLatencyMode.SustainedLowLatency; // Short performance-sensitive period.

        try
        {
            if (GC.TryStartNoGCRegion(16 * 1024 * 1024)) // Ask for 16 MB without GC.
            {
                try
                {
                    byte[] buffer = GC.AllocateUninitializedArray<byte>(1_000_000);
                    Console.WriteLine(buffer.Length);
                }
                finally
                {
                    GC.EndNoGCRegion();
                }
            }
        }
        finally
        {
            GCSettings.LatencyMode = previous; // Always restore the old mode.
        }

        // Rarely justified: explicit collection after a known large temporary workload.
        GC.Collect();
        GC.WaitForPendingFinalizers();
        GC.Collect();
    }
}
```

## Common Follow-up Questions

- When is `GC.AddMemoryPressure` appropriate versus just implementing `Dispose()`?
- Why can `GC.Collect()` accidentally make performance worse?
- What is the difference between `LowLatency` and `SustainedLowLatency`?
- When should `GC.TryStartNoGCRegion` be preferred over simply reducing allocations?
- Can `NoGCRegion` be used safely in ASP.NET Core request handlers?
- Why is the common pattern `Collect` + `WaitForPendingFinalizers` + `Collect` used in tests?

## Common Mistakes / Pitfalls

- Calling `GC.Collect()` on every request or on a timer “to keep memory low”.
- Using `AddMemoryPressure` for tiny unmanaged allocations, which distorts GC heuristics.
- Forgetting to call `RemoveMemoryPressure`, causing the runtime to think external memory is still in use.
- Leaving `LowLatency` or `SustainedLowLatency` enabled too long and causing heap growth.
- Starting a no-GC region without a realistic allocation budget or without calling `EndNoGCRegion()`.

## References

- [GC.AddMemoryPressure](https://learn.microsoft.com/dotnet/api/system.gc.addmemorypressure)
- [GC.Collect](https://learn.microsoft.com/dotnet/api/system.gc.collect)
- [GCSettings.LatencyMode](https://learn.microsoft.com/dotnet/api/system.runtime.gcsettings.latencymode)
- [GC.TryStartNoGCRegion](https://learn.microsoft.com/dotnet/api/system.gc.trystartnogcregion)
- [Induced collections](https://learn.microsoft.com/dotnet/standard/garbage-collection/induced)
