# Pinning and GCHandles

**Category:** C# / Memory & Interop
**Difficulty:** Senior
**Tags:** `pinning`, `gchandle`, `fixed`, `interop`, `gc`

## Question
> What does it mean to pin a managed object in .NET, and why can pinning hurt GC performance?
>
> How do `fixed` and `GCHandleType.Pinned` differ, and when should each be used?
>
> Why are `SafeHandle` and `MemoryHandle` often preferable to long-lived pinning patterns?

## Short Answer
Pinning tells the GC that a managed object must stay at a stable memory address for some period of time, which is necessary when native code or pointer-based code needs that address. The cost is that pinned objects cannot be moved during compaction, so excessive or long-lived pinning can increase heap fragmentation and hurt GC efficiency. In practice, prefer short `fixed` scopes for brief access, use `GCHandle` only when a pin must outlive a statement block, and favor higher-level lifetime helpers like `SafeHandle` or owner-based memory APIs when possible.

## Detailed Explanation
### Why pinning exists
The .NET GC normally moves managed objects during compaction to keep the heap dense and efficient. Native code, however, often needs a stable pointer. Pinning temporarily blocks object movement so that pointer remains valid.

| Technique | Typical lifetime | Best use |
| --- | --- | --- |
| `fixed` | Very short lexical scope | Temporary pointer access |
| `GCHandle.Alloc(..., Pinned)` | Manual lifetime | Interop callbacks or longer pin windows |
| `SafeHandle` | Native handle lifetime | OS/native resource ownership |
| `MemoryHandle` | Owner-defined | Pinned access over memory abstractions |

### Why pinning hurts the GC
Pinning does not necessarily make the GC slower because the object is “special”; it hurts because compaction has fewer choices. If the GC must leave pinned objects in place, it can create holes around them. Enough holes mean more fragmentation and worse locality.

This is especially painful when small, young objects are pinned frequently or for too long. Short-lived pins on older objects are often less damaging than repeated pinning of ephemeral objects.

| Pattern | GC impact |
| --- | --- |
| Brief `fixed` around a P/Invoke call | Usually acceptable |
| Long-lived pinned byte arrays on the small object heap | Risky |
| Repeated pinning of many temporary objects | Often harmful |
| Stable native handle wrapped in `SafeHandle` | Better than pinning managed objects |

> Tip: when discussing pinning, mention fragmentation. That is the key reason interviewers ask why pinning is expensive.

### Choosing the right abstraction
Use `fixed` for brief, obvious scopes. Use `GCHandle` when the pin must survive beyond a single statement block or be associated with a native callback. But if the real need is ownership of a native resource, `SafeHandle` is usually the better abstraction because it manages release correctly and integrates with [finalizer-and-dispose-pattern.md](./finalizer-and-dispose-pattern.md).

If you already work with memory abstractions, owner-based APIs can be more expressive than manual pins. This topic connects closely to [unsafe-and-pointers.md](./unsafe-and-pointers.md), [memory-of-t.md](./memory-of-t.md), and [span-of-t.md](./span-of-t.md).

> Warning: never pin managed objects for “general performance.” Pin only when a stable address is required, and keep the pin window as short as possible.

## Code Example
```csharp
using System;
using System.Runtime.InteropServices;

byte[] bytes = { 10, 20, 30, 40 };

unsafe
{
    fixed (byte* pointer = bytes)
    {
        // `fixed` pins for this lexical scope only.
        Console.WriteLine($"First byte via pointer: {*pointer}");
    }
}

GCHandle handle = GCHandle.Alloc(bytes, GCHandleType.Pinned);
try
{
    IntPtr address = handle.AddrOfPinnedObject();
    Console.WriteLine($"Pinned address: 0x{address.ToString("X")}");
}
finally
{
    handle.Free(); // Always free manually allocated handles.
}
```

## Common Follow-up Questions
- Why does pinning increase heap fragmentation?
- When is `fixed` preferable to `GCHandleType.Pinned`?
- When should `SafeHandle` be used instead of pinning a managed object?
- Why is long-lived pinning on young objects especially problematic?
- How does pinning relate to unsafe pointer access and P/Invoke?

## Common Mistakes / Pitfalls
- Pinning objects longer than necessary.
- Forgetting to free a `GCHandle`, causing a permanent pin and resource leak.
- Pinning for performance reasons when no stable address is actually required.
- Confusing native handle lifetime management with object pinning.
- Assuming pinned buffers are automatically safe to share after the pin is released.

## References
- [Microsoft Docs: `fixed` statement](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/fixed)
- [Microsoft Docs: GCHandle](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.gchandle)
- [Microsoft Docs: SafeHandle](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.safehandle)
- [See: Unsafe and Pointers](./unsafe-and-pointers.md)
- [See: Finalizer and Dispose Pattern](./finalizer-and-dispose-pattern.md)
