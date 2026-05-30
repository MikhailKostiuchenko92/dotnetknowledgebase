# Aggressive Inlining and Related Attributes

**Category:** C# / Memory & Performance
**Difficulty:** Senior
**Tags:** `MethodImpl`, `AggressiveInlining`, `NoInlining`, `SkipLocalsInit`, `JIT`, `performance`

## Question

> What do `[MethodImpl(MethodImplOptions.AggressiveInlining)]`, `NoInlining`, and `[SkipLocalsInit]` actually do in C#, and when should you use them?

Also asked as:
- "Can I force the JIT to inline a method with `AggressiveInlining`?"
- "When is `NoInlining` useful for diagnostics or correctness?"
- "What are the risks of `SkipLocalsInit` in hot-path code?"

## Short Answer

These attributes are low-level hints that influence JIT and code generation behavior, but they are not magic performance switches. `AggressiveInlining` asks the JIT to inline more eagerly, `NoInlining` prevents inlining, and `SkipLocalsInit` suppresses automatic zero-initialization of locals for the annotated scope. In .NET 8/9, they are best reserved for measured hot paths, diagnostics, interop-heavy code, or carefully designed low-level libraries—not everyday business logic.

## Detailed Explanation

### What each attribute changes

`MethodImplOptions.AggressiveInlining` is a hint on a specific method. The JIT still decides whether inlining is legal and profitable. It may ignore the hint if the method is too large, contains unsupported constructs, or inlining would be harmful.

`MethodImplOptions.NoInlining` does the opposite: it tells the runtime not to inline the method. That is useful when you want a stable stack frame for diagnostics, want to isolate cold throwing code, or do not want a helper folded into a caller.

`SkipLocalsInit` applies to a method, type, or module and tells the compiler not to emit `.locals init` for that scope. That can avoid zeroing some local storage, which occasionally matters in extremely hot low-level code. The trade-off is safety: every local must be definitely assigned before use.

| Attribute / option | Scope | Main effect | Typical use |
|---|---|---|---|
| `AggressiveInlining` | Method | Requests earlier/more eager inlining | Tiny hot-path helpers |
| `NoInlining` | Method | Prevents inlining | Diagnostics, exception helpers, benchmarking |
| `SkipLocalsInit` | Method / type / module | Skips automatic local zeroing | Carefully reviewed perf-sensitive code |

### JIT heuristics still matter

The JIT makes inlining decisions using its own heuristics: method size, IL shape, generic expansion, exception handling, tiered compilation, and whether the method becomes hotter over time. In .NET 8/9, tiered compilation and profile-guided optimization mean the runtime can make better decisions after observing real execution.

That is why interview answers should emphasize: **`AggressiveInlining` is a hint, not a command.** If the JIT sees a bad candidate, it can still refuse.

> **Warning:** Do not spray `AggressiveInlining` across a codebase. Too much inlining can increase code size, hurt instruction-cache locality, and even reduce performance.

### When these attributes are worth using

Good use cases for `AggressiveInlining`:
- tiny helper methods on hot paths
- thin wrappers over intrinsics or span-based parsing helpers
- performance-critical code already validated with benchmarks

Good use cases for `NoInlining`:
- separating rare throw paths from hot paths
- preserving a cleaner stack frame during debugging or profiling
- preventing benchmark distortion when comparing call overhead

Good use cases for `SkipLocalsInit`:
- low-level buffer code using `Span<T>`, `stackalloc`, or interop
- code that assigns every element explicitly before reading
- library code reviewed with extra care for correctness

### When not to use them

Most application code should let the runtime decide. The JIT is already good at inlining obvious tiny methods, and zero-initialization is usually a valuable safety guarantee. If a method is not on a proven hot path, these attributes add complexity without meaningful benefit.

This topic connects closely to [stackalloc.md](./stackalloc.md), [span-of-t.md](./span-of-t.md), and [unsafe-and-pointers.md](./unsafe-and-pointers.md).

## Code Example

```csharp
using System;
using System.Runtime.CompilerServices;

namespace Demo;

Console.WriteLine(MathHelpers.Add(10, 20));
Console.WriteLine(Parser.ParsePositiveInt("42"));
Console.WriteLine(BufferHelpers.SumTwoBytes());

static class MathHelpers
{
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static int Add(int left, int right)
        => left + right; // Small hot-path helper that is a reasonable inlining candidate.
}

static class Parser
{
    [MethodImpl(MethodImplOptions.NoInlining)]
    public static int ParsePositiveInt(string text)
    {
        if (!int.TryParse(text, out var value) || value < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(text));
        }

        return value;
    }
}

[SkipLocalsInit] // Never rely on uninitialized data; assign every local before reading it.
static class BufferHelpers
{
    public static int SumTwoBytes()
    {
        Span<byte> buffer = stackalloc byte[2];
        buffer[0] = 10; // Explicit initialization keeps the method safe.
        buffer[1] = 20;
        return buffer[0] + buffer[1];
    }
}
```

## Common Follow-up Questions

- Why is `AggressiveInlining` only a hint and not a guarantee?
- How can too much inlining make performance worse instead of better?
- Why is `NoInlining` useful in benchmarking or exception-helper methods?
- What extra risk does `SkipLocalsInit` introduce compared with default codegen?
- How do tiered compilation and profile-guided optimization affect inlining decisions?

## Common Mistakes / Pitfalls

- Assuming `AggressiveInlining` always improves performance without measuring.
- Using `SkipLocalsInit` and then reading locals before they are definitely assigned.
- Forgetting that larger inlined code can hurt instruction-cache behavior.
- Marking normal business methods with low-level attributes just because they are called often.
- Treating `NoInlining` as a performance optimization instead of a diagnostic or code-shaping tool.

## References

- [MethodImplAttribute Class](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.methodimplattribute)
- [MethodImplOptions Enum](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.methodimploptions)
- [SkipLocalsInitAttribute Class](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.skiplocalsinitattribute)
- [See: stackalloc.md](./stackalloc.md)
- [See: span-of-t.md](./span-of-t.md)
