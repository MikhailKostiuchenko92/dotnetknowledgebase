# StackOverflowException and OutOfMemoryException

**Category:** .NET Runtime / Process-Fatal Failures
**Difficulty:** 🔴 Senior
**Tags:** `StackOverflowException`, `OutOfMemoryException`, `stack-size`, `ArrayPool`, `memory-pressure`, `GC`

## Question
> Why is `StackOverflowException` effectively non-catchable in .NET?

> Can you recover from `OutOfMemoryException`, and should you try?

> What practical mitigations reduce the risk of stack overflow and OOM in production systems?

## Short Answer
`StackOverflowException` is process-fatal in modern .NET because once a thread exhausts its stack, the runtime cannot rely on having enough space to run arbitrary recovery code safely. `OutOfMemoryException` can technically be caught, but the process may already be in a badly degraded state, so the safest production response is usually to log minimal diagnostics and terminate or shed work. Prevention matters more than recovery: avoid deep recursion, reduce large contiguous allocations, pool buffers, and monitor memory pressure proactively.

## Detailed Explanation
### Why Stack Overflow Is Fatal
Each thread gets a finite stack, commonly about 1 MB by default on Windows for managed threads, though the exact value can vary by platform and host. Every method call consumes some stack space for parameters, locals, return addresses, and bookkeeping. Infinite recursion or extremely deep call chains eventually hit the guard page and trigger `StackOverflowException`.

The CLR treats this as non-recoverable. Even if you could enter a catch block, that code itself would need stack space, and the runtime cannot guarantee safe execution. The standard outcome is process termination.

### Custom Stack Size
The `Thread(ThreadStart, int maxStackSize)` overload allows a custom stack size for explicitly created threads, but that is a niche tool. It can buy room for specialized workloads, yet it is not a substitute for fixing recursion depth or large stack allocations.

### `OutOfMemoryException` Is Different but Still Dangerous
OOM is not automatically process-fatal in the same way. The runtime may throw it when the GC cannot free or compact enough memory, when a large contiguous allocation fails, or when address space is exhausted. This can happen even when total machine memory is not fully consumed—for example, fragmentation may prevent a sufficiently large contiguous block.

| Exception | Catchable? | Recommended strategy |
|---|---|---|
| `StackOverflowException` | No, effectively process-fatal | Prevent it; avoid recursion; terminate |
| `OutOfMemoryException` | Technically yes | Minimal logging, fail fast or shed load safely |

### Why Catching OOM Is Not True Recovery
After an OOM, the process may still be able to execute some code, but there is no guarantee that the system can continue reliably. Logging frameworks may allocate. Error pages may allocate. Retrying the same work often makes things worse. Recovery is realistic only in narrow, carefully engineered scenarios with reserved memory or strict allocation discipline.

> **Warning:** A blanket `catch (OutOfMemoryException)` that tries to continue normal request processing is usually a reliability bug, not resilience.

### Practical Mitigations
For stack pressure:
- replace deep recursion with iterative algorithms where possible
- avoid large `stackalloc` buffers in deep call chains
- keep synchronous call depth reasonable

For heap pressure:
- use `ArrayPool<T>` and object pooling for reusable buffers
- prefer streaming over loading huge payloads entirely into memory
- avoid unnecessary copies of large arrays or strings
- watch `GC.GetGCMemoryInfo()` for memory load, fragmentation hints, and high-memory conditions

Large allocations are especially sensitive because they may require contiguous space. That is why pooling and chunked processing help even when total memory looks sufficient.

See also [Large Object Heap](./large-object-heap.md) and [ArrayPool & MemoryPool](./arraypool-and-memorypool.md).

## Code Example
```csharp
using System.Buffers;

namespace DotNetRuntimeExamples;

public static class MemoryPressureDemo
{
    public static void ProcessLargePayload(Stream source)
    {
        var buffer = ArrayPool<byte>.Shared.Rent(64 * 1024); // Reuse a buffer instead of allocating repeatedly.

        try
        {
            while (source.Read(buffer, 0, buffer.Length) > 0)
            {
                // Process the current chunk here without buffering the whole file in memory.
            }

            var info = GC.GetGCMemoryInfo();
            Console.WriteLine($"High memory load threshold: {info.HighMemoryLoadThresholdBytes:n0}");
        }
        finally
        {
            ArrayPool<byte>.Shared.Return(buffer, clearArray: true); // Return pooled memory deterministically.
        }
    }

    public static long FactorialIterative(int value)
    {
        long result = 1;
        for (var i = 2; i <= value; i++)
        {
            result *= i; // Iterative code avoids recursion-driven stack growth.
        }

        return result;
    }
}
```

## Common Follow-up Questions
- Why does the CLR terminate on `StackOverflowException` instead of allowing a catch block?
- What conditions trigger `OutOfMemoryException` besides total RAM exhaustion?
- When would a custom thread stack size be justified?
- How do `ArrayPool<T>` and streaming reduce OOM risk?
- What signals can `GC.GetGCMemoryInfo()` provide during memory pressure?

## Common Mistakes / Pitfalls
- Assuming more RAM alone eliminates `OutOfMemoryException` risk.
- Catching OOM and continuing normal business logic as if nothing happened.
- Using recursion for arbitrarily deep inputs without bounds.
- Creating large temporary arrays or strings when chunked processing would work.
- Forgetting that large contiguous allocations can fail because of fragmentation, not only raw memory exhaustion.

## References
- [StackOverflowException class](https://learn.microsoft.com/dotnet/api/system.stackoverflowexception)
- [OutOfMemoryException class](https://learn.microsoft.com/dotnet/api/system.outofmemoryexception)
- [GC.GetGCMemoryInfo](https://learn.microsoft.com/dotnet/api/system.gc.getgcmemoryinfo)
- [ArrayPool<T> class](https://learn.microsoft.com/dotnet/api/system.buffers.arraypool-1)
