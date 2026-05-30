# GC Finalization and the Finalizer Queue

**Category:** .NET Runtime / GC
**Difficulty:** 🟡 Middle
**Tags:** `finalization`, `finalizer`, `F-reachable`, `Dispose`, `GC.SuppressFinalize`, `resurrection`

## Question

> How does object finalization work in .NET, and why do finalizable objects usually survive an extra GC cycle?

Also asked as:
> What are the finalization queue and the F-reachable queue?
> Why does the Dispose pattern call `GC.SuppressFinalize(this)`?

## Short Answer

A finalizer is a last-chance cleanup mechanism that runs on a dedicated finalizer thread when the GC discovers an unreachable object with a finalizer. The object is not freed immediately: on the first collection it is moved from the finalization queue to the F-reachable queue so the finalizer can run, and only a later collection can actually reclaim it. That extra work makes finalization expensive, which is why the normal pattern is `Dispose()` plus `GC.SuppressFinalize(this)`.

## Detailed Explanation

### The Queues Involved

When an object type defines a finalizer (`~TypeName()` in C#), each instance is registered with the runtime’s **finalization queue** when it is allocated. That does not mean the finalizer runs immediately; it means the GC must treat the object specially when it later becomes unreachable.

When the GC finds such an unreachable object, it does **not** reclaim it in the same pass. Instead, the runtime moves it to the **F-reachable queue** (“finalizer-reachable”). A dedicated **finalizer thread** dequeues objects from that queue and invokes their finalizers.

| Stage | What happens |
|---|---|
| Allocation | Object with a finalizer is registered for finalization |
| First GC after becoming unreachable | Object is discovered as dead, then moved to F-reachable queue |
| Finalizer thread | Runs the finalizer method |
| Later GC | Object can finally be reclaimed if nothing resurrected it |

### Why Finalization Is a Two-Phase Process

This produces a **two-phase collection cycle**:

1. **First pass:** the GC determines the object is unreachable, but because it has a finalizer, it is queued for finalization instead of being freed.
2. **Second pass:** after the finalizer thread has run, the object becomes collectible in a later GC.

That is why finalizable objects are more expensive than ordinary objects. They survive at least one more GC, often get promoted to an older generation, and require coordination with another runtime thread.

> **Warning:** A finalizer is non-deterministic. You do not know when it will run, and it might run much later than the last managed reference disappeared.

### What the Finalizer Thread Can and Cannot Do

The finalizer runs on a dedicated CLR thread, not on the thread that created the object. It must avoid blocking for a long time, avoid throwing exceptions, and avoid touching other managed objects unless absolutely necessary. By the time the finalizer runs, other related managed objects may already be finalized or otherwise unavailable.

That is why the recommended Dispose pattern separates cleanup into managed and unmanaged phases. In `Dispose(true)` you may touch managed members; in finalizer-driven cleanup you should release only unmanaged state.

### Object Resurrection

A finalizer can make the object reachable again by storing `this` into a static field or another GC root. That is called **resurrection**.

```csharp
_resurrected = this;
```

If that happens, the object survives the current cleanup path. However, the runtime does **not** automatically register it for another finalization pass. If you truly need that behavior, you must call `GC.ReRegisterForFinalize`, which is rarely a good idea.

Resurrection is legal but dangerous. It creates confusing lifetime rules, can leak memory, and often breaks reasoning about invariants.

### Why `Dispose` + `GC.SuppressFinalize` Matters

If a consumer disposes an object deterministically, there is no reason to keep it on the finalization path. Calling `GC.SuppressFinalize(this)` tells the runtime that the finalizer no longer needs to run. That saves finalizer-thread work and often prevents the object from surviving an unnecessary extra GC.

This is one reason the standard pattern exists:
- `Dispose()` releases resources now
- `GC.SuppressFinalize(this)` skips finalization overhead
- the finalizer remains only as a safety net when the caller forgets to dispose

Modern .NET code usually prefers `SafeHandle` over handwritten finalizers because `SafeHandle` centralizes this reliability logic.

Related: [IDisposable and using](./idisposable-and-using.md) and [SuppressFinalize](./suppress-finalize.md).

## Code Example

```csharp
using System.Runtime.InteropServices;

namespace DotNetRuntimeExamples;

internal sealed class NativeBuffer : IDisposable
{
    private static NativeBuffer? _resurrected;
    private IntPtr _pointer;
    private bool _disposed;

    public NativeBuffer(int bytes)
    {
        _pointer = Marshal.AllocHGlobal(bytes); // Unmanaged allocation.
    }

    ~NativeBuffer()
    {
        Console.WriteLine("Finalizer running on finalizer thread.");

        // Demo only: resurrection is usually a bad idea.
        // _resurrected = this;

        ReleaseUnmanaged();
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        ReleaseUnmanaged();
        _disposed = true;
        GC.SuppressFinalize(this); // Skip finalizer because cleanup already happened.
    }

    private void ReleaseUnmanaged()
    {
        if (_pointer == IntPtr.Zero)
        {
            return;
        }

        Marshal.FreeHGlobal(_pointer); // Free native memory.
        _pointer = IntPtr.Zero;
    }
}

internal static class Program
{
    private static void Main()
    {
        using var buffer = new NativeBuffer(4096);
        Console.WriteLine("Buffer created and disposed deterministically.");
    }
}
```

## Common Follow-up Questions

- What is the difference between the finalization queue and the F-reachable queue?
- Why do finalizable objects often get promoted to Gen1 or Gen2?
- What is object resurrection, and why is it dangerous?
- When should you use `GC.ReRegisterForFinalize`?
- Why is `SafeHandle` preferred over writing a finalizer manually?
- Can a finalizer access other managed objects safely?

## Common Mistakes / Pitfalls

- Assuming a finalizer runs immediately after an object becomes unreachable.
- Putting expensive I/O or locks inside a finalizer, which can stall the finalizer thread.
- Accessing already-finalized managed state from the finalizer path.
- Forgetting that finalizable objects usually survive one extra collection cycle.
- Using resurrection as a normal lifecycle mechanism instead of a rare advanced technique.

## References

- [Fundamentals of garbage collection](https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals)
- [Implement a Dispose method](https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-dispose)
- [GC.SuppressFinalize](https://learn.microsoft.com/dotnet/api/system.gc.suppressfinalize)
- [Cleaning up unmanaged resources](https://learn.microsoft.com/dotnet/standard/garbage-collection/unmanaged)
