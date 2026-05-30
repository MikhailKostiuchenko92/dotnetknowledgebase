# Native Memory Management in .NET

**Category:** .NET Runtime / Interop
**Difficulty:** 🔴 Senior
**Tags:** `NativeMemory`, `AllocHGlobal`, `AllocCoTaskMem`, `MemoryMarshal`, `SafeHandle`, `IDisposable`

## Question
> How do you allocate and free native memory from .NET?

> What is the difference between `NativeMemory`, `AllocHGlobal`, and `AllocCoTaskMem`?

> How should you manage the lifetime of unmanaged buffers safely in modern .NET?

## Short Answer
Modern .NET exposes `NativeMemory` for low-level native allocation APIs such as `Alloc`, `Free`, and aligned allocation, which roughly map to C-style allocation patterns. Older APIs like `Marshal.AllocHGlobal`/`FreeHGlobal` and `Marshal.AllocCoTaskMem`/`FreeCoTaskMem` still matter for Win32 and COM-specific interop contracts. Whatever allocator you use, lifetime must be explicit—ideally wrapped in `SafeHandle` or `IDisposable`—because the GC does not automatically free unmanaged memory.

## Detailed Explanation
### Why Native Allocation Exists
Most .NET code should stay in managed memory, but interop sometimes requires native ownership, stable pointers, special alignment, or allocator compatibility with an external API. In those cases, you allocate memory outside the GC heap and pass raw pointers or handles across the boundary.

### The Main Allocation APIs
| API | Typical use | Notes |
|---|---|---|
| `NativeMemory.Alloc/Free` | Modern low-level native buffers | Cross-platform, closer to `malloc/free` |
| `NativeMemory.AlignedAlloc` | SIMD or native APIs needing alignment | Must free with the matching aligned free API |
| `Marshal.AllocHGlobal/FreeHGlobal` | Older Win32-style interop | Legacy but still common |
| `Marshal.AllocCoTaskMem/FreeCoTaskMem` | COM allocator compatibility | Required when COM expects task allocator memory |

The allocator must match the deallocator. Mixing them is a bug.

### `NativeMemory` vs Older `Marshal` APIs
`NativeMemory` is the modern low-level choice introduced in .NET 6. It is explicit, portable, and closer to the C mental model. `AllocHGlobal` is older and historically tied to Win32 global/local allocation patterns. `AllocCoTaskMem` matters when COM APIs document that returned or accepted memory must use the COM task allocator.

### Reinterpreting Managed Spans Safely
Not all low-level work requires unsafe pointer arithmetic. `MemoryMarshal.AsBytes<T>(Span<T>)` lets you reinterpret a span of structs or primitives as a byte span without copying. That is useful for serialization, hashing, or interop staging while staying inside safe span-based APIs.

> **Warning:** `MemoryMarshal.AsBytes` does not pin memory or change ownership. It only reinterprets the same managed memory. If native code needs a stable pointer beyond the current operation, you still need pinning or a native allocation.

### Lifetime Management Is the Real Hard Part
Allocation is easy; ownership is the real design problem. If you return a raw `IntPtr`, every caller must remember how to free it and with which allocator. That is why wrapping native memory in `SafeHandle` or an `IDisposable` type is usually better. The type becomes the contract for ownership and cleanup.

### Native Memory Bypasses GC Safety Nets
Because unmanaged allocations live outside the managed heap, the GC does not automatically reclaim them and may not feel their full pressure immediately. A service can look healthy from managed allocation metrics while still exhausting process memory through native buffers. That is another reason to keep native allocations deliberate, measured, and wrapped in abstractions that make ownership obvious.

### Practical Guidance
Use `NativeMemory` for new low-level cross-platform native buffers. Use `AllocCoTaskMem` when the COM contract requires it. Keep allocations short-lived, free them in `finally`, and prefer higher-level abstractions such as spans or safe handles whenever possible.

Related: [Unsafe Code & Pointers](./unsafe-code-and-pointers.md) and [SafeHandle](./safehandle.md).

## Code Example
```csharp
using System.Runtime.InteropServices;

namespace DotNetRuntimeExamples;

public static unsafe class NativeMemoryDemo
{
    public static void Run()
    {
        var values = new int[] { 1, 2, 3, 4 };
        var bytes = MemoryMarshal.AsBytes(values.AsSpan()); // Reinterpret managed ints as bytes without copying.
        Console.WriteLine($"Managed byte length = {bytes.Length}");

        var size = (nuint)256;
        var ptr = (byte*)NativeMemory.AlignedAlloc(size, alignment: 16); // Native aligned allocation.

        try
        {
            new Span<byte>(ptr, (int)size).Clear(); // Work with the unmanaged buffer via Span.
            Console.WriteLine($"Native buffer allocated at 0x{((nint)ptr).ToInt64():X}");
        }
        finally
        {
            NativeMemory.AlignedFree(ptr); // Free with the matching API.
        }
    }

    public static IntPtr AllocateForCom(int bytes)
    {
        return Marshal.AllocCoTaskMem(bytes); // Use when a COM contract requires CoTaskMem ownership.
    }
}
```

## Common Follow-up Questions
- When should I prefer `NativeMemory` over `AllocHGlobal`?
- Why must allocator and deallocator always match?
- What is `AllocCoTaskMem` for specifically?
- Does `MemoryMarshal.AsBytes` pin memory or copy it?
- Why should unmanaged buffers usually be wrapped in `IDisposable` or `SafeHandle`?

## Common Mistakes / Pitfalls
- Freeing memory with a different API than the one that allocated it.
- Returning raw pointers with unclear ownership rules.
- Assuming unmanaged memory is tracked by the GC.
- Using `MemoryMarshal.AsBytes` as if it created a native buffer.
- Forgetting that long-lived unmanaged allocations can bypass GC pressure signals and still exhaust process memory.

## References
- [NativeMemory class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.nativememory)
- [Marshal.AllocHGlobal](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.marshal.allochglobal)
- [Marshal.AllocCoTaskMem](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.marshal.alloccotaskmem)
- [MemoryMarshal.AsBytes](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.memorymarshal.asbytes)
