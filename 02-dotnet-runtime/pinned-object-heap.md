# The Pinned Object Heap (POH)

**Category:** .NET Runtime / GC
**Difficulty:** 🔴 Senior
**Tags:** `POH`, `pinned object heap`, `GC.AllocateArray`, `pinning`, `GCHandle`, `fixed`

## Question

> What is the Pinned Object Heap in .NET, and when should you allocate objects there?

Also asked as:
> How is the POH different from the small object heap and large object heap?
> When should you use `GC.AllocateArray(..., pinned: true)` instead of pinning a normal array?

## Short Answer

The Pinned Object Heap, introduced in .NET 5, is a dedicated managed heap for objects that are intentionally allocated as permanently pinned. Because the GC already assumes those objects will not move, they no longer disrupt compaction of the normal small object heap and large object heap the same way ordinary pinned objects do. The POH is best for long-lived pinned buffers such as socket, file, or device I/O buffers—not for general application objects.

## Detailed Explanation

### What Problem the POH Solves

Before .NET 5, a pinned object lived in the normal managed heaps. If you pinned an array on the small object heap, the GC had to compact around it, leaving holes and increasing fragmentation pressure. Long-lived pinned buffers were especially problematic because they stayed put while many surrounding objects died and moved.

The **Pinned Object Heap (POH)** was added as a third logical managed heap beside the normal small object heap and the large object heap. It is specifically for pinned objects that are expected to remain pinned for a meaningful portion of their lifetime.

### Key POH Behavior

| Heap | Typical purpose | Compacted? |
|---|---|---|
| Small object heap | Most normal allocations | Yes |
| Large object heap | Large objects, usually 85 KB+ | Usually not compacted often |
| Pinned object heap | Objects allocated as pinned | No |

The GC does not compact the POH. That sounds like a downside, but for pinned objects it is exactly the point: they would not be movable anyway. By isolating them, the runtime avoids letting pinned buffers punch holes through the compacting heaps.

### How to Allocate on the POH

The main APIs are:
- `GC.AllocateArray<T>(length, pinned: true)`
- `GC.AllocateUninitializedArray<T>(length, pinned: true)`

These allocate arrays directly onto the POH when the runtime supports it.

### When the POH Is a Good Fit

Use it for **long-lived pinned buffers** whose address must stay stable across many operations:
- reusable socket receive/send buffers
- file I/O staging buffers
- hardware communication buffers
- native library workspaces held for the life of a component

If the pin lasts only for one synchronous call, `fixed` is usually still the simplest tool. If the data is not managed or lifetime is fully native, unmanaged memory may be cleaner.

> **Warning:** The POH is not a free performance boost. It is a specialized heap for pinned arrays. Do not move ordinary application objects there just because the API exists.

### Comparison with Other Pinning Techniques

| Approach | Best for | Main trade-off |
|---|---|---|
| `fixed` | Very short synchronous pin | Scope-limited, simplest |
| `GCHandleType.Pinned` | Flexible manual pinning | Easy to leak or overextend |
| POH allocation | Long-lived pinned arrays | Specialized, array-focused |

A good mental model is: pin late, unpin early, and if a buffer will be pinned almost all the time anyway, consider allocating it on the POH from the start.

### Practical Limits

POH allocation is primarily for arrays, not arbitrary object graphs. Also, the POH still participates in collection; it is not immortal memory. If the array becomes unreachable, it can be reclaimed. What changes is that the heap itself is designed around the assumption that its objects do not move.

Related: [Object pinning](./object-pinning.md) and [GC handles](./gc-handles.md).

## Code Example

```csharp
namespace DotNetRuntimeExamples;

internal static class Program
{
    private static void Main()
    {
        // Allocate a reusable pinned buffer directly on the POH.
        byte[] pinnedBuffer = GC.AllocateArray<byte>(64 * 1024, pinned: true);

        // Allocate without zeroing when you know you'll overwrite the contents.
        byte[] scratch = GC.AllocateUninitializedArray<byte>(64 * 1024, pinned: true);

        pinnedBuffer[0] = 1;
        scratch[0] = 2;

        Console.WriteLine($"Pinned buffer length: {pinnedBuffer.Length}");
        Console.WriteLine($"Scratch buffer length: {scratch.Length}");

        // These buffers are still collectible when no strong references remain.
        // The benefit is that they do not interfere with normal heap compaction.
    }
}
```

## Common Follow-up Questions

- Does the POH replace `fixed` or pinned `GCHandle` completely?
- Why is the POH described as a third heap next to SOH and LOH?
- What kinds of objects can be allocated on the POH?
- Is a POH object still garbage-collected if nothing references it?
- When is unmanaged memory still better than POH allocation?
- How can you observe POH usage in diagnostics tools?

## Common Mistakes / Pitfalls

- Using POH allocation for short-lived pins that would be simpler with `fixed`.
- Assuming POH objects are never collected; they are pinned, not immortal.
- Allocating general-purpose object graphs there instead of pinned buffers.
- Ignoring buffer lifetime and continuing to hold large POH arrays long after they are needed.
- Treating POH as a cure-all instead of first minimizing unnecessary pinning.

## References

- [GC.AllocateArray<T>](https://learn.microsoft.com/dotnet/api/system.gc.allocatearray)
- [GC.AllocateUninitializedArray<T>](https://learn.microsoft.com/dotnet/api/system.gc.allocateuninitializedarray)
- [Fundamentals of garbage collection](https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals)
- [Performance improvements in .NET 5](https://devblogs.microsoft.com/dotnet/performance-improvements-in-net-5/) 
