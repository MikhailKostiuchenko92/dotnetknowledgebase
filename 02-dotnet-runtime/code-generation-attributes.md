# Code Generation Attributes

**Category:** .NET Runtime / JIT & AOT
**Difficulty:** 🟡 Middle-Senior
**Tags:** `MethodImplOptions`, `AggressiveInlining`, `NoInlining`, `NoOptimization`, `AggressiveOptimization`, `SkipLocalsInit`, `JIT hints`

## Question

> Which attributes can influence .NET code generation, and what do they actually do?

Also asked as:
> What is the difference between `AggressiveInlining`, `NoInlining`, `NoOptimization`, and `AggressiveOptimization`?
> What does `[SkipLocalsInit]` change, and why is it considered a dangerous optimization?

## Short Answer

The main code-generation hints in everyday .NET code are method-level `MethodImplOptions` flags and `[SkipLocalsInit]`. `AggressiveInlining` and `AggressiveOptimization` ask the JIT to spend more effort on hot code, while `NoInlining` and `NoOptimization` tell it to keep code easier to observe or debug. `[SkipLocalsInit]` disables automatic zero-initialization of locals and `stackalloc` buffers where allowed, which can reduce overhead but must only be used when every value is definitely written before it is read.

## Detailed Explanation

### Attributes Here Are Mostly Hints

Interviewers often ask about these attributes to see whether you understand an important nuance: most of them are **hints, not guarantees**. The CLR and JIT still decide what is safe and worthwhile.

| Attribute / option | Intent |
|---|---|
| `AggressiveInlining` | Strongly suggest inlining |
| `NoInlining` | Prevent inlining |
| `NoOptimization` | Disable JIT optimizations for that method |
| `AggressiveOptimization` | Ask for a more optimized codegen path |
| `SkipLocalsInit` | Skip zeroing locals/stackalloc memory |

### `AggressiveInlining` and `NoInlining`

Inlining removes call overhead and can expose more optimization opportunities. `AggressiveInlining` tells the JIT that the method is likely on a hot path and worth considering for inline expansion.

`NoInlining` does the opposite. It is useful when you want stable stack traces, clear benchmark boundaries, or a guaranteed method frame for diagnostics. It can also help keep cold paths from bloating hot callers.

A strong answer here is: **use `AggressiveInlining` sparingly, and prefer measurement over guesswork.**

### `NoOptimization`

`NoOptimization` is mostly a debugging tool. It tells the JIT not to apply normal optimizations for that method, making stepping and variable inspection easier.

That comes with a clear performance cost, so it is not something you should leave on production hot paths. It is also not a substitute for proper profiling.

### `AggressiveOptimization`

`AggressiveOptimization` tells the runtime this method is performance-critical and worth compiling with a more expensive optimization strategy. Conceptually, it is a way of saying, “treat this as hot code.”

That can help in carefully chosen performance-sensitive code, but overusing it may increase startup cost and compile time with little benefit.

> **Warning:** `AggressiveOptimization` is not a magic “make this fast” switch. If the algorithm or memory access pattern is poor, the attribute will not rescue it.

### `[SkipLocalsInit]`

Normally the runtime/compiler zero-initializes locals and `stackalloc` buffers. This improves safety because reading an uninitialized local cannot expose old stack data.

`[SkipLocalsInit]` tells the compiler to skip that initialization where supported. You can apply it to a method, type, or module. At module scope it looks like:

```csharp
[module: SkipLocalsInit]
```

That can reduce overhead in very tight low-level code, especially when buffers are immediately and fully overwritten. But it is risky because any missed write turns into undefined-looking garbage data being observed.

### Assembly-Level and Module-Level Scope

Developers sometimes say “assembly-level `SkipLocalsInit`,” but the actual syntax is module-level. In practice, applying it at module scope affects all eligible methods in that module, which is powerful and therefore dangerous.

Use narrow scope whenever possible. A method-level attribute communicates intent better and limits blast radius.

### Interview Takeaway

A good concise answer is: code-generation attributes influence the JIT, but mostly as hints; `NoInlining` and `NoOptimization` are often diagnostics-oriented; `AggressiveInlining` and `AggressiveOptimization` should be used only on measured hot paths; and `SkipLocalsInit` trades safety for tiny performance gains in expert-only scenarios. See [jit-optimizations.md](./jit-optimizations.md) and [unsafe-code-and-pointers.md](./unsafe-code-and-pointers.md).

## Code Example

```csharp
using System.Runtime.CompilerServices;

namespace RuntimeSamples;

public static class CodeGenerationAttributesDemo
{
    public static void Main()
    {
        Console.WriteLine($"Fast path: {FastAdd(20, 22)}");
        Console.WriteLine($"Cold path: {BuildMessage(5)}");
        Console.WriteLine($"Debug path: {DebugFriendly(10)}");
    }

    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static int FastAdd(int left, int right) => left + right;

    [MethodImpl(MethodImplOptions.NoInlining)]
    private static string BuildMessage(int value) => $"Value={value}";

    [MethodImpl(MethodImplOptions.NoOptimization)]
    private static int DebugFriendly(int value)
    {
        int local = value * 2;
        return local + 1;
    }

    [SkipLocalsInit]
    [MethodImpl(MethodImplOptions.AggressiveOptimization)]
    private static void FillBuffer(Span<byte> destination)
    {
        for (int i = 0; i < destination.Length; i++)
        {
            destination[i] = (byte)i; // Safe because every element is written before any read.
        }
    }
}
```

## Common Follow-up Questions

- Why is `AggressiveInlining` only a hint rather than a guarantee?
- When would `NoInlining` be preferable on purpose?
- Why is `NoOptimization` mostly useful for debugging and diagnostics?
- What is the risk of applying `[module: SkipLocalsInit]` too broadly?
- How does `AggressiveOptimization` interact with tiered compilation and startup cost?

## Common Mistakes / Pitfalls

- Decorating many methods with `AggressiveInlining` without evidence that it helps.
- Leaving `NoOptimization` on production hot paths.
- Thinking `AggressiveOptimization` fixes algorithmic inefficiency.
- Applying `[module: SkipLocalsInit]` broadly and then reading partially initialized locals.
- Confusing module-level `SkipLocalsInit` syntax with ordinary method attributes.

## References

- [MethodImplAttribute](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.methodimplattribute)
- [MethodImplOptions Enum](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.methodimploptions)
- [SkipLocalsInitAttribute](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.skiplocalsinitattribute)
- [Compilation runtime configuration options for .NET](https://learn.microsoft.com/dotnet/core/runtime-config/compilation)
- [Performance Improvements in .NET 6](https://devblogs.microsoft.com/dotnet/performance-improvements-in-net-6/)
