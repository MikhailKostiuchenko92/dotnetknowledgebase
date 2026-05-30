# JIT Optimizations

**Category:** .NET Runtime / JIT & AOT
**Difficulty:** 🟡 Middle-Senior
**Tags:** `inlining`, `devirtualization`, `SIMD`, `range-check elimination`, `constant folding`, `dead code elimination`, `loop hoisting`

## Question

> What kinds of optimizations does the .NET JIT perform?

Also asked as:
> How do inlining, devirtualization, and bounds-check elimination improve performance in .NET?
> Which coding patterns help RyuJIT generate better machine code without writing unsafe code?

## Short Answer

RyuJIT performs many classic compiler optimizations: method inlining, constant folding, dead-code elimination, loop hoisting, range-check elimination, devirtualization, and some loop/vector optimizations. The exact set depends on architecture, runtime version, tier, and profile data, so you should think in terms of heuristics rather than guarantees. Good code structure helps the JIT: simple hot methods, predictable types, tight loops over spans/arrays, and benchmark-guided validation.

## Detailed Explanation

### Inlining: Removing Call Overhead

Inlining replaces a method call with the callee body. That removes call overhead, exposes constants, and unlocks further optimizations.

| Benefit of inlining | Why it matters |
|---|---|
| Removes call/return overhead | Helps tiny hot methods |
| Exposes constants | Enables constant folding |
| Exposes control flow | Allows more dead-code elimination |

The JIT inlines aggressively for small, simple methods. `[MethodImpl(MethodImplOptions.AggressiveInlining)]` can increase the chance, but it is only a hint, not a command.

### Devirtualization

Virtual and interface dispatch normally require runtime indirection. If the JIT can prove the concrete target, it can turn that indirect call into a direct call and sometimes inline it too.

Common cases include:

- sealed classes
- methods on exact known types
- profile-guided guarded devirtualization for interface calls

That is why “make everything virtual just in case” can hurt performance on hot paths, while sealed or obviously concrete types are easier for the JIT to optimize.

### Loop Optimizations and SIMD

Loops dominate many hot workloads, so the JIT looks for opportunities such as:

- loop-invariant code motion (hoisting)
- loop unrolling in some cases
- auto-vectorization for certain patterns
- recognition of APIs that map cleanly to SIMD-friendly machine code

For example, a repeated property or length read that does not change inside the loop can be moved outside it. Some arithmetic loops can also become vectorized using CPU SIMD instructions. This is not as broad as hand-written intrinsics, but it often gives meaningful speedups for idiomatic numeric code.

### Range-Check Elimination

Array and span indexing is normally bounds-checked for safety. In predictable loops, the JIT can prove the index stays within range and remove redundant checks.

```csharp
for (int i = 0; i < array.Length; i++)
{
    sum += array[i];
}
```

This pattern is easy to reason about, so the JIT can often eliminate repeated checks. If the code uses obscure index math, aliasing, or helper calls that hide the pattern, fewer checks may be removable.

### Constant Folding and Dead-Code Elimination

If an expression can be computed at compile time for the current method body, the JIT folds it into a constant. If a branch or computation becomes irrelevant after that, it may disappear entirely.

| Optimization | Example |
|---|---|
| Constant folding | `3 * 1024` becomes `3072` |
| Dead-code elimination | Branch on a known-false condition disappears |

These optimizations are often unlocked by inlining, which exposes more constants to the optimizer.

### Why Tiering and PGO Matter

Optimization quality depends on whether the method is still in Tier 0 or has been promoted to Tier 1. Tier 1 gets more expensive analysis. Modern runtimes also use profile-guided data, enabling better guarded devirtualization and layout decisions in hot code.

> **Warning:** JIT optimization is heuristic and version-dependent. Never assume a specific optimization will always happen because it did in one benchmark or one runtime build.

### Interview Takeaway

A strong interview answer names the main optimizations, explains that inlining often unlocks others, and emphasizes that the best way to “help the JIT” is writing straightforward hot-path code and measuring the result. See [tiered-compilation.md](./tiered-compilation.md) and [code-generation-attributes.md](./code-generation-attributes.md).

## Code Example

```csharp
using System.Runtime.CompilerServices;

namespace RuntimeSamples;

public interface IDiscount
{
    int Apply(int value);
}

public sealed class FlatDiscount : IDiscount
{
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public int Apply(int value) => value - 5;
}

public static class JitOptimizationsDemo
{
    public static void Main()
    {
        int[] data = [1, 2, 3, 4, 5, 6, 7, 8];
        IDiscount discount = new FlatDiscount();

        int sum = Sum(data); // Straight loop helps range-check elimination.
        int discounted = discount.Apply(sum); // Sealed implementation helps devirtualization.

        const int blockSize = 4 * 1024; // Constant folded by the JIT.
        Console.WriteLine($"Sum={sum}, discounted={discounted}, blockSize={blockSize}");
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static int Transform(int value) => value * 2;

    private static int Sum(int[] data)
    {
        int sum = 0;
        for (int i = 0; i < data.Length; i++)
        {
            sum += Transform(data[i]);
        }

        return sum;
    }
}
```

## Common Follow-up Questions

- Why does inlining often enable constant folding and dead-code elimination?
- What makes a call site easier to devirtualize?
- Why do simple counted loops help with bounds-check elimination?
- When does the JIT auto-vectorize, and when do you need explicit intrinsics?
- Why can Tier 1 produce noticeably better code than Tier 0?
- How do profile-guided optimizations improve interface-call performance?

## Common Mistakes / Pitfalls

- Assuming `[AggressiveInlining]` forces the JIT to inline every call.
- Writing complex hot-path abstractions and expecting the JIT to always optimize them away.
- Treating one benchmark on one runtime version as proof of a permanent optimization rule.
- Ignoring tiered compilation and measuring only cold startup code.
- Expecting auto-vectorization to replace all manual SIMD scenarios.

## References

- [RyuJIT Overview (dotnet/runtime)](https://github.com/dotnet/runtime/blob/main/docs/design/coreclr/botr/ryujit-overview.md)
- [MethodImplOptions Enum](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.methodimploptions)
- [Performance Improvements in .NET 8](https://devblogs.microsoft.com/dotnet/performance-improvements-in-net-8/)
- [Vector<T> Class](https://learn.microsoft.com/dotnet/api/system.numerics.vector-1)
- [BenchmarkDotNet overview](https://benchmarkdotnet.org/)
