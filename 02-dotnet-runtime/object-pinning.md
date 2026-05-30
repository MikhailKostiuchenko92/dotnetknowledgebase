# Object Pinning in .NET

**Category:** .NET Runtime / GC
**Difficulty:** 🔴 Senior
**Tags:** `pinning`, `fixed`, `GCHandle`, `fragmentation`, `POH`, `interop`

## Question

> What is object pinning in .NET, and why can it hurt garbage collector performance?

Also asked as:
> What is the difference between the `fixed` keyword and a pinned `GCHandle`?
> When is pinning necessary, and when should you avoid it?

## Short Answer

Pinning tells the GC that an object’s address must stay stable, usually because unmanaged code needs a raw pointer into managed memory. You can pin with the `fixed` keyword for short lexical scopes or with `GCHandleType.Pinned` for more flexible interop scenarios. Pinning is necessary for some P/Invoke, DMA, and native buffer APIs, but it disrupts compaction and can create holes in the managed heap, especially when many pinned objects sit in Gen0 or Gen1.

## Detailed Explanation

### Why Pinning Exists

The .NET GC is a moving collector: during compaction it relocates objects to remove fragmentation and improve locality. That breaks any raw native pointer that was taken to a managed object. Pinning solves this by telling the GC that a specific object may not move.

That is essential when:
- passing a pointer to native code that will dereference it
- working with hardware or OS APIs that require a stable buffer address
- interacting with DMA-style operations or overlapped I/O buffers

### `fixed` vs `GCHandleType.Pinned`

Both create a pin, but they are used differently.

| Technique | Lifetime | Best use |
|---|---|---|
| `fixed` | Limited to one lexical scope | Short synchronous interop call |
| `GCHandle.Alloc(..., Pinned)` | Manual, until `Free()` | Callback-heavy or stateful interop |

`fixed` is usually safer because the compiler constrains its lifetime. A pinned `GCHandle` is more flexible, but also easier to leak or hold too long.

### Why Pinning Hurts the GC

During compaction, the GC wants to pack live objects tightly. A pinned object becomes an obstacle the collector cannot move. If small objects around it die, the GC may be forced to leave **holes** in the heap. Over time, many pinned objects can increase fragmentation and reduce allocation efficiency.

This is especially problematic in **Gen0 and Gen1**, where the GC expects rapid movement and compaction. Long-lived pinned objects in the ephemeral generations can make short-lived allocation patterns more expensive.

> **Warning:** Pinning short-lived arrays repeatedly in hot paths can be worse than copying data into a dedicated interop buffer.

### When Pinning Is Necessary

Pinning is justified when native code truly needs a stable pointer. Examples include:
- `ReadFile`/`WriteFile` style OS calls
- sockets or file APIs that operate on in-memory buffers
- GPU or device APIs that read directly from process memory
- native libraries that keep a pointer only for the duration of a synchronous call

If the native side copies the data immediately, short-lived `fixed` is often enough. If the native side retains the pointer after the call returns, a pinned handle or unmanaged allocation may be needed.

### Alternatives and Modern Guidance

If you only want efficient element access in managed code, do **not** pin. APIs like `MemoryMarshal.GetArrayDataReference` give zero-overhead by-ref access to array data without pinning. That is useful for unsafe or high-performance managed code, but the reference is still only safe while normal managed rules hold; it is not a promise to native code that the array address will stay fixed.

For long-lived pinned managed buffers, .NET 5 introduced the **Pinned Object Heap (POH)**, which isolates permanently pinned objects so they no longer disrupt normal heap compaction as much.

Related: [GC handles](./gc-handles.md) and [Pinned Object Heap](./pinned-object-heap.md).

## Code Example

```csharp
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace DotNetRuntimeExamples;

internal static class Program
{
    private static unsafe void Main()
    {
        byte[] buffer = new byte[1024];

        // Short-lived pin for a synchronous native call.
        fixed (byte* pointer = buffer)
        {
            NativeConsume(pointer, buffer.Length);
        }

        // Longer-lived pin for stateful interop. Must be freed manually.
        GCHandle handle = GCHandle.Alloc(buffer, GCHandleType.Pinned);
        try
        {
            nint address = handle.AddrOfPinnedObject();
            Console.WriteLine($"Pinned address: 0x{address:X}");
        }
        finally
        {
            handle.Free();
        }

        // Zero-overhead managed access without pinning.
        ref byte first = ref MemoryMarshal.GetArrayDataReference(buffer);
        first = 42; // Fast managed mutation, but not a native pin.
    }

    private static unsafe void NativeConsume(byte* data, int length)
    {
        Console.WriteLine($"Native call received {length} bytes.");
    }
}
```

## Common Follow-up Questions

- Why are pinned objects especially harmful in Gen0 and Gen1?
- When should you prefer copying over pinning?
- What does `MemoryMarshal.GetArrayDataReference` provide, and what does it not guarantee?
- How does the Pinned Object Heap reduce compaction disruption?
- Can `stackalloc` replace pinning for some interop scenarios?
- When is unmanaged memory better than a pinned managed array?

## Common Mistakes / Pitfalls

- Keeping pinned handles alive far longer than the native call actually requires.
- Assuming `ref` access or `MemoryMarshal.GetArrayDataReference` means the array is pinned.
- Pinning many small frequently allocated objects and then blaming the GC for fragmentation.
- Using `GCHandleType.Pinned` where a short `fixed` block would be simpler and safer.
- Forgetting that long-lived interop buffers may be better allocated on the POH or unmanaged heap.

## References

- [fixed statement](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/fixed)
- [GCHandle](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.gchandle)
- [MemoryMarshal.GetArrayDataReference](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.memorymarshal.getarraydatareference)
- [Fundamentals of garbage collection](https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals)
