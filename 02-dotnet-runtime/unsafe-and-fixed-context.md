# Unsafe Code and the `fixed` Context

**Category:** .NET Runtime / Interop
**Difficulty:** 🟡 Middle
**Tags:** `unsafe`, `fixed`, `pinning`, `GCHandle`, `pointers`, `interop`

## Question
> What does the `fixed` statement do in C#?

> How is `fixed` different from `GCHandle.Alloc(..., Pinned)`?

> When should you pin managed memory before passing it to native code?

## Short Answer
The `fixed` statement temporarily pins a managed object so the GC cannot relocate it while you take a raw pointer into its memory. It is block-scoped and ideal for short-lived interop or low-level operations on arrays, strings, or fields. If native code must keep the pointer beyond the current scope, `fixed` is not enough—you need a longer-lived pin such as `GCHandle.Alloc(..., GCHandleType.Pinned)` or, better, unmanaged memory with explicit ownership.

## Detailed Explanation
### Why Pinning Exists
The GC moves objects during compaction so it can reduce fragmentation. That is normally invisible and beneficial. The problem appears when unmanaged code or unsafe code needs a stable memory address. If the GC moves the object while native code still uses its pointer, the pointer becomes invalid.

`fixed` solves that by pinning the target object for a limited scope.

### What `fixed` Does
Within a `fixed` block, the runtime guarantees that the pinned object stays at the same address. You can then obtain a pointer to:
- an array’s first element
- a string’s first UTF-16 character
- a fixed buffer or pinnable reference
- certain fields in managed objects

| Mechanism | Lifetime | Best use case |
|---|---|---|
| `fixed` | Current block only | Short native call or local pointer work |
| `GCHandle.Alloc(..., Pinned)` | Until explicitly freed | Longer-lived pinning across callbacks or stored pointers |
| Unmanaged allocation | Until explicitly freed | Native ownership or very long-lived buffers |

### Arrays and Strings
`fixed` on an array gives a pointer to its first element. `fixed` on a string gives a pointer to the first UTF-16 `char`. That is convenient for interop, but remember that strings are immutable and null-terminated expectations on the native side still matter.

### `fixed` vs `GCHandle`
`fixed` is safer when possible because the scope is obvious and short. `GCHandle.Alloc(Pinned)` is more flexible, but it is also easier to leak or forget to free. Long-lived pins can hurt GC efficiency because pinned objects reduce compaction freedom and can increase fragmentation pressure.

### Important Lifetime Caveat
Sometimes interview prompts say “pin the object if the native side stores the pointer.” That is only partly true. A `fixed` block protects the address only until the block ends. If native code stores the pointer for later use, you need a pin that lasts that long—or better yet, a copied unmanaged buffer whose lifetime you control explicitly.

### Pinning Has a GC Cost
Pinned objects limit the GC’s ability to compact memory efficiently. Short pins are usually fine, but many long-lived pins can create fragmentation pressure and leave holes in the heap. That is why modern .NET also has specialized tools such as the pinned object heap for some scenarios, and why a small unmanaged copy can sometimes be healthier for the GC than keeping a managed object pinned for a long time.

> **Warning:** Never let a native component keep a pointer obtained from `fixed` after the block ends. That is a classic use-after-move bug.

### Practical Guidance
Use `fixed` for tiny, local windows. Use `GCHandle` only when you truly need a longer-lived pin. For larger or longer-lived native ownership scenarios, prefer `SafeHandle` or native allocations over pinning managed objects indefinitely.

Related: [Object Pinning](./object-pinning.md) and [GC Handles](./gc-handles.md).

## Code Example
```csharp
using System.Runtime.InteropServices;

namespace DotNetRuntimeExamples;

public static class FixedDemo
{
    public static unsafe void PinArray(byte[] buffer)
    {
        fixed (byte* ptr = buffer) // Pin the array for this block only.
        {
            ptr[0] = 42; // Raw pointer access while the GC cannot move the array.
            Console.WriteLine($"First byte via pointer: {ptr[0]}");
        }
    }

    public static unsafe void PinString(string text)
    {
        fixed (char* ptr = text) // Managed string stays at a stable UTF-16 address temporarily.
        {
            Console.WriteLine($"First char: {ptr[0]}");
        }
    }

    public static GCHandle PinForLonger(byte[] buffer)
    {
        return GCHandle.Alloc(buffer, GCHandleType.Pinned); // Caller must Free() later.
    }
}
```

## Common Follow-up Questions
- Why can the GC move objects in the first place?
- When is `fixed` preferable to `GCHandle.Alloc(Pinned)`?
- What happens to GC performance when many objects stay pinned?
- Can I use a pointer from `fixed` after the block ends?
- When should I copy data into unmanaged memory instead of pinning managed memory?

## Common Mistakes / Pitfalls
- Assuming `fixed` keeps memory stable after the block exits.
- Using long-lived pinned handles unnecessarily and hurting GC compaction.
- Forgetting to free a `GCHandle` created with `Pinned`.
- Passing a pinned string to native code that expects a different encoding.
- Pinning managed memory when the native side really needs its own owned buffer.

## References
- [The `fixed` statement](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/fixed)
- [unsafe code and pointers](https://learn.microsoft.com/dotnet/csharp/language-reference/unsafe-code)
- [GCHandle class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.gchandle)
- [Blittable and non-blittable types (verify URL)](https://learn.microsoft.com/dotnet/framework/interop/blittable-and-non-blittable-types)
