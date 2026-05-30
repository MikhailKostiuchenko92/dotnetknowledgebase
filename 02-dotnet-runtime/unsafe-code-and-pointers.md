# Unsafe Code and Pointers

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🔴 Senior
**Tags:** `unsafe`, `pointers`, `fixed`, `delegate*`, `Unsafe`, `NativeMemory`, `MemoryMarshal`, `interop`

## Question

> When do you use unsafe code in .NET, and what does it enable that safe code does not?

Also asked as:
> What are `fixed`, raw pointers, and the `Unsafe` helper APIs used for?
> How do you work with unmanaged memory in modern .NET without writing your own P/Invoke declarations?

## Short Answer

Unsafe code lets C# work directly with memory addresses, pointer arithmetic, function pointers, and unmanaged buffers, but it requires an `unsafe` context and the `/unsafe` compiler setting. You use it only in focused low-level areas such as interop, high-performance parsing, vectorized libraries, or runtime-like infrastructure. Modern .NET complements raw pointers with APIs like `Unsafe`, `MemoryMarshal`, and `NativeMemory`, which expose low-level capabilities while keeping the rest of the application safe.

## Detailed Explanation

### What “unsafe” Means in C#

C# is normally memory-safe: the runtime tracks object references, the GC can move objects, and array bounds are checked. An `unsafe` block opts out of some of those guarantees so you can work with pointers directly.

To compile such code, the project must allow unsafe blocks, usually via `<AllowUnsafeBlocks>true</AllowUnsafeBlocks>` or the `/unsafe` compiler flag. Inside an unsafe context, you can declare pointer types such as `int*`, `byte*`, `void*`, and function pointers like `delegate* managed<int, int>`.

| Pointer form | Purpose |
|---|---|
| `int*`, `byte*` | Typed pointer arithmetic |
| `void*` | Untyped raw address |
| `delegate*` | Low-overhead function pointer call |

### Why Pinning Matters

Managed objects can move during garbage collection, so taking a pointer to array or string data is dangerous unless the object is pinned. That is what the `fixed` statement does: it temporarily tells the GC not to relocate the target.

```csharp
fixed (byte* p = array)
{
    // Safe to use p for the duration of this block.
}
```

Pinning is essential for pointer arithmetic over managed memory, but excessive long-lived pinning can hurt GC performance by fragmenting the heap.

> **Warning:** A pointer into managed memory is only valid while the object is pinned. Storing it and using it after the `fixed` block is a memory corruption bug.

### `Unsafe` and `MemoryMarshal`

Many performance-sensitive libraries avoid raw pointers where possible and instead use **byrefs** and spans.

- `Unsafe.As<TFrom, TTo>` reinterprets one type as another without copying.
- `Unsafe.Add<T>` performs element-wise pointer-like offsetting on a byref.
- `Unsafe.NullRef<T>` creates a null byref sentinel.
- `MemoryMarshal.GetReference<T>` gives a byref to the first element of a span with essentially zero overhead.

The important nuance is that `MemoryMarshal.GetReference<T>` does **not** pin managed memory. It is perfect when you stay in byref-based code, but if you convert that byref to a pointer and a GC can occur, you still need pinning.

### Working with Unmanaged Memory

Modern .NET includes `System.Runtime.InteropServices.NativeMemory`, so you no longer need custom P/Invoke declarations just to allocate native buffers.

| API | Use |
|---|---|
| `NativeMemory.Alloc` | Allocate unmanaged memory |
| `NativeMemory.Free` | Free unmanaged memory |
| `NativeMemory.AlignedAlloc` | Allocate aligned memory |
| `NativeMemory.AlignedFree` | Free aligned allocation |

This is useful for interop buffers, custom allocators, or specialized algorithms. But unlike managed arrays, the GC will not free this memory for you, so leaks and double frees are your responsibility.

### When Unsafe Code Is Worth It

Good use cases include:

- binary parsing with minimal bounds overhead
- span internals and zero-copy transformations
- P/Invoke and native library wrappers
- custom serializers, codecs, or parsers in hot loops
- runtime-like infrastructure and specialized collections

Poor use cases include “micro-optimizing” ordinary business code. Unsafe code increases maintenance cost, testing burden, and bug severity.

### Interview Takeaway

The strongest answer is that unsafe code is a controlled escape hatch. Use it only at well-contained boundaries, pin managed memory when taking pointers into it, prefer span/byref helpers when possible, and treat `NativeMemory` allocations like manual memory management in C or C++.

## Code Example

```csharp
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace RuntimeSamples;

public static unsafe class UnsafeDemo
{
    private static int Square(int value) => value * value;

    public static void Main()
    {
        int[] numbers = [10, 20, 30, 40];

        fixed (int* pNumbers = numbers) // Pin managed array before pointer arithmetic.
        {
            int third = *(pNumbers + 2);
            Console.WriteLine($"Third item via pointer: {third}");
        }

        Span<int> span = numbers;
        ref int first = ref MemoryMarshal.GetReference(span); // Fast byref access, no pinning by itself.
        ref int second = ref Unsafe.Add(ref first, 1);
        Console.WriteLine($"Second item via Unsafe.Add: {second}");

        delegate* managed<int, int> squarePtr = &Square;
        Console.WriteLine($"Function pointer result: {squarePtr(12)}");

        nuint bytes = (nuint)(4 * sizeof(int));
        int* native = (int*)NativeMemory.Alloc(bytes);
        try
        {
            for (int i = 0; i < 4; i++)
            {
                native[i] = i * 100;
            }

            Console.WriteLine($"Native buffer last item: {native[3]}");
        }
        finally
        {
            NativeMemory.Free(native);
        }
    }
}
```

## Common Follow-up Questions

- Why do you need `fixed` before taking a pointer to an array element?
- What is the difference between raw pointers and byref-based APIs like `MemoryMarshal`?
- When would `delegate*` be preferable to a delegate instance?
- Why can long-lived pinning hurt GC performance?
- When is `NativeMemory` a better fit than a managed array?
- What kinds of libraries in the BCL rely on unsafe code internally?

## Common Mistakes / Pitfalls

- Forgetting to enable `/unsafe` or `<AllowUnsafeBlocks>true</AllowUnsafeBlocks>`.
- Using a pointer to managed memory after leaving the `fixed` block.
- Assuming `MemoryMarshal.GetReference<T>` pins memory when it does not.
- Allocating unmanaged memory with `NativeMemory.Alloc` and never freeing it.
- Sprinkling unsafe code through business logic instead of isolating it to low-level modules.

## References

- [Unsafe code, pointer types, and function pointers](https://learn.microsoft.com/dotnet/csharp/language-reference/unsafe-code)
- [System.Runtime.CompilerServices.Unsafe](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.unsafe)
- [NativeMemory Class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.nativememory)
- [MemoryMarshal.GetReference<T>(Span<T>)](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.memorymarshal.getreference)
- [fixed statement - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/fixed)
