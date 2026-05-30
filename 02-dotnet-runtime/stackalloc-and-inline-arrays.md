# stackalloc and Inline Arrays

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🔴 Senior
**Tags:** `stackalloc`, `Span<T>`, `InlineArray`, `SkipLocalsInit`, `stack overflow`, `ArrayPool<T>`, `buffering`

## Question

> When should you use `stackalloc` in .NET, and what are the risks?

Also asked as:
> How do `stackalloc` and inline arrays differ from heap arrays or `ArrayPool<T>`?
> What does `[SkipLocalsInit]` do, and why should you be careful with stack-allocated buffers?

## Short Answer

`stackalloc` allocates a small buffer on the current thread’s stack frame, so allocation and cleanup are extremely cheap and usually create zero GC pressure. In safe code it commonly returns a `Span<T>`, while in unsafe code it can produce a raw pointer. It is best for very small, short-lived buffers; for larger or reusable buffers, prefer heap allocation or `ArrayPool<T>` because thread stacks are limited and large `stackalloc` calls can cause `StackOverflowException`.

## Detailed Explanation

### What `stackalloc` Actually Does

`stackalloc T[n]` reserves space inside the current stack frame instead of the managed heap. The memory disappears automatically when the method returns, so there is no GC involvement for the buffer itself. Modern C# makes this practical because the expression can initialize a `Span<T>` or `ReadOnlySpan<T>` in safe code, not just a `T*` in unsafe code.

| Form | Typical use |
|---|---|
| `Span<byte> buffer = stackalloc byte[64];` | Safe temporary scratch buffer |
| `int* p = stackalloc int[16];` | Unsafe pointer-oriented code |

That makes `stackalloc` a great fit for parsing, encoding, formatting, or small temporary work buffers in hot paths.

### The Real Risk: Stack Size Is Small

Heap memory can grow substantially; a thread stack is intentionally much smaller. On many .NET processes, the default stack reserve is around **1 MB per thread**, though exact behavior depends on OS, host, and runtime configuration. That means a few large recursive calls or one overly large `stackalloc` can crash the process with `StackOverflowException`.

> **Warning:** `StackOverflowException` is process-fatal in normal .NET applications. Do not treat `stackalloc` as a general-purpose replacement for arrays.

Because of this, a common safe pattern is to stack-allocate only below a small threshold and fall back to the heap otherwise.

### Safe Threshold Pattern

A robust pattern is:

```csharp
Span<byte> buffer = stackalloc byte[length <= threshold ? length : 0];
if (buffer.IsEmpty)
{
    buffer = new byte[length];
}
```

This keeps the hot small case allocation-free while safely handling larger inputs. Many teams prefer this over a ternary returning either `stackalloc` or `new[]` because the zero-length span pattern is explicit and easy to read.

### Inline Arrays in C# 12

`[InlineArray(N)]` lets you define a struct that stores **N elements inline** with zero object header per element and without a separate managed array allocation.

| Feature | `stackalloc` | Inline array |
|---|---|---|
| Storage location | Current stack frame | Inline inside a struct |
| Lifetime | Current method/frame | Lifetime of the containing value |
| Size known at | Runtime | Compile time |
| Typical use | Scratch buffer | Small fixed-size embedded buffer |

Inline arrays are useful when a type always needs a tiny fixed-capacity buffer, such as a small key, vector, or token scratch area. They are conceptually the safe modern replacement for many old fixed-buffer scenarios.

### `SkipLocalsInit`

Normally, .NET zero-initializes locals and `stackalloc` memory to avoid accidental reads of uninitialized data. `[SkipLocalsInit]` tells the compiler to omit that initialization where allowed, which can save a little time in extremely hot code.

That optimization is advanced and risky. If you skip initialization, every byte must be written before it is read.

> **Warning:** `SkipLocalsInit` improves performance only in niche cases. Using it carelessly creates correctness and security bugs because old stack data may be observed before you overwrite it.

### When to Use `stackalloc` vs `ArrayPool<T>`

Use `stackalloc` when the buffer is:

- small
- short-lived
- used synchronously
- not stored anywhere
- ideally bounded or known at compile time

Use `ArrayPool<T>` when the buffer can be larger, crosses method boundaries, or would put too much pressure on thread stacks. See [arraypool-and-memorypool.md](./arraypool-and-memorypool.md). For span lifetime rules, see [span-t-and-memory-t.md](./span-t-and-memory-t.md).

### Interview Takeaway

The key answer is: `stackalloc` is for tiny temporary buffers where heap allocation would be wasteful; inline arrays are for fixed-capacity inline storage inside a type; and both features require discipline around lifetime, initialization, and size limits.

## Code Example

```csharp
using System.Runtime.CompilerServices;

namespace RuntimeSamples;

[InlineArray(16)]
public struct HexBuffer
{
    private char _element0;
}

public static class StackAllocDemo
{
    [SkipLocalsInit] // Safe only because every slot is written before being read.
    public static void Main()
    {
        int length = 24;
        const int threshold = 32;

        Span<byte> buffer = stackalloc byte[length <= threshold ? length : 0];
        if (buffer.IsEmpty)
        {
            buffer = new byte[length]; // Heap fallback for larger requests.
        }

        for (int i = 0; i < buffer.Length; i++)
        {
            buffer[i] = (byte)(i + 1);
        }

        HexBuffer hex = default;
        for (int i = 0; i < 16; i++)
        {
            hex[i] = i < 10 ? (char)('0' + i) : (char)('A' + (i - 10));
        }

        Console.WriteLine($"Buffer length: {buffer.Length}");
        Console.WriteLine($"Inline array first/last: {hex[0]} ... {hex[15]}");
    }
}
```

## Common Follow-up Questions

- Why is `stackalloc` usually paired with `Span<T>` instead of raw pointers in modern C#?
- What kinds of bugs can `[SkipLocalsInit]` introduce?
- How do inline arrays differ from `fixed` buffers and normal arrays?
- Why is `ArrayPool<T>` safer for larger temporary buffers?
- What happens if you `stackalloc` too much memory on a thread?

## Common Mistakes / Pitfalls

- Using `stackalloc` for large or attacker-controlled sizes and risking stack overflow.
- Assuming stack memory is automatically safe to read when `[SkipLocalsInit]` is in play.
- Returning data that depends on a `stackalloc` buffer after the stack frame ends.
- Using inline arrays where a resizable collection is actually required.
- Treating `stackalloc` as always faster than pooled arrays regardless of size.

## References

- [stackalloc expression - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/stackalloc)
- [InlineArrayAttribute](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.inlinearrayattribute)
- [SkipLocalsInitAttribute](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.skiplocalsinitattribute)
- [Span<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.span-1)
- [ArrayPool<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.buffers.arraypool-1)
