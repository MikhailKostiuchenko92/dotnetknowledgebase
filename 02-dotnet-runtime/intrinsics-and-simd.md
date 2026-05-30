# How Do Hardware Intrinsics and SIMD Work in .NET?

**Category:** .NET Runtime / JIT & AOT
**Difficulty:** 🔴 Senior
**Tags:** `simd`, `intrinsics`, `vector`, `avx2`, `advsimd`

## Question

> What is the difference between `Vector<T>` and `System.Runtime.Intrinsics` in .NET?

Also asked as:
> When would you use `Vector128<T>` or `Avx2` directly instead of relying on auto-vectorization?
> How does .NET write SIMD code that works on both x86 and ARM?

## Short Answer

.NET exposes SIMD in two layers. `Vector<T>` is a portable, adaptive abstraction that uses the best available vector width on the current machine, while `System.Runtime.Intrinsics` gives explicit access to instruction-set-specific types such as `Vector128<T>`, `Vector256<T>`, `Vector512<T>`, `Sse41`, `Avx2`, and `AdvSimd`. RyuJIT can auto-vectorize some loops, but explicit intrinsics are used when you need precise control over instructions, data layout, and hot-path performance.

## Detailed Explanation

### The Two SIMD Programming Models

At a high level, SIMD means processing multiple values with one instruction. .NET supports that in two main ways:

| API | Best for | Portability | Control |
|---|---|---|---|
| `Vector<T>` | Portable data-parallel loops | High | Medium |
| `System.Runtime.Intrinsics` | Hot paths tuned to a specific ISA | Medium to low | High |

`Vector<T>` is attractive because the JIT chooses the hardware width at runtime. On one machine it may map to 128-bit vectors, on another 256-bit or wider. That makes it a good default for cross-platform numeric code.

Intrinsics are different. With them, you express the exact instruction families you want to use: `Sse41` or `Avx2` on x86/x64, `AdvSimd` on ARM64, and increasingly wider vector forms such as `Vector512<T>` on newer CPUs.

### Why the `IsSupported` Guards Matter

Instruction sets are optional hardware capabilities, so intrinsic code must be guarded:

```csharp
if (Avx2.IsSupported)
{
    // Use AVX2 path.
}
else
{
    // Fallback implementation.
}
```

That guard is not just defensive coding; it is how you write one binary that can adapt at runtime. The JIT understands these checks and can eliminate unreachable branches for the current machine.

### Auto-Vectorization vs Explicit Intrinsics

RyuJIT can auto-vectorize some simple loops, especially when the loop shape is obvious, bounds checks can be removed, and the operations map cleanly to SIMD. But auto-vectorization is conservative. It may decline when aliasing, branching, mixed types, irregular access patterns, or unsupported operations make the transformation unsafe or unprofitable.

Explicit intrinsics are used when you want to force a specific strategy: compare 32 bytes at once, shuffle lanes, widen/narrow values, or exploit a CPU instruction the JIT would not introduce automatically.

> Warning: intrinsics can produce excellent performance, but they also increase maintenance cost. If `Vector<T>` or simple scalar code is already fast enough, the lower-level route may not be worth the complexity.

### Cross-Platform Reality

Good .NET SIMD code usually has three layers:

1. A specialized x86/x64 path (`Sse41`, `Avx2`, maybe `Avx512`).
2. A specialized ARM64 path (`AdvSimd` / NEON).
3. A portable fallback (`Vector<T>` or scalar code).

That pattern is common in image processing, hashing, Base64, UTF-8 validation, and text scanning libraries. The framework itself uses these techniques heavily in places like span helpers and encoding routines.

### When to Reach for Intrinsics

Use explicit intrinsics when all of these are true:

- The path is proven hot by measurement.
- The algorithm naturally maps to vector instructions.
- You need ISA-specific behavior the JIT will not reliably synthesize.
- You can afford a fallback path and test multiple architectures.

This topic pairs naturally with [jit-optimizations.md](./jit-optimizations.md): the JIT can help a lot automatically, but the highest-performance libraries often still guide it with carefully chosen intrinsics.

## Code Example

```csharp
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Intrinsics;
using System.Runtime.Intrinsics.X86;

namespace RuntimeSamples.Intrinsics;

internal static class ByteSearch
{
    public static bool ContainsZero(ReadOnlySpan<byte> data)
    {
        if (Avx2.IsSupported && data.Length >= Vector256<byte>.Count)
        {
            ref byte start = ref MemoryMarshal.GetReference(data);
            Vector256<byte> zero = Vector256<byte>.Zero;

            for (int i = 0; i <= data.Length - Vector256<byte>.Count; i += Vector256<byte>.Count)
            {
                Vector256<byte> block = Vector256.LoadUnsafe(ref Unsafe.Add(ref start, i));
                Vector256<byte> compare = Avx2.CompareEqual(block, zero);

                if (Avx2.MoveMask(compare) != 0)
                {
                    return true; // At least one byte in the 32-byte block is zero.
                }
            }
        }

        // Portable fallback for machines without AVX2 or for the tail.
        foreach (byte value in data)
        {
            if (value == 0)
            {
                return true;
            }
        }

        return false;
    }
}

internal static class Program
{
    private static void Main()
    {
        byte[] payload = [1, 2, 3, 4, 0, 6, 7, 8, 9];
        Console.WriteLine(ByteSearch.ContainsZero(payload));
    }
}
```

## Common Follow-up Questions

- When is `Vector<T>` preferable to hardware-specific intrinsics?
- Why do intrinsic APIs require `IsSupported` guards?
- What kinds of loops can RyuJIT auto-vectorize on its own?
- How would you write a portable SIMD path for both x64 and ARM64?
- What workloads benefit most from explicit intrinsics?

## Common Mistakes / Pitfalls

- Writing ISA-specific code without a fallback path.
- Assuming auto-vectorization will always happen for a loop that “looks vectorizable”.
- Using intrinsics before proving the code path is hot enough to justify the complexity.
- Confusing `Vector<T>`'s adaptive width with fixed-width types like `Vector256<T>`.
- Optimizing x86 only and forgetting ARM64 is important on modern servers and mobile devices.

## References

- [SIMD-enabled numeric types — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/simd)
- [Vector128<T> API — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.intrinsics.vector128-1)
- [Vector<T> API — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.numerics.vector-1)
- [Avx2 API — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.intrinsics.x86.avx2)
- [AdvSimd API — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.intrinsics.arm.advsimd)
