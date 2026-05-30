# JIT Compilation Basics

**Category:** .NET Runtime / JIT & AOT
**Difficulty:** 🟢 Middle
**Tags:** `JIT`, `RyuJIT`, `IL`, `Tier 0`, `Tier 1`, `startup`, `throughput`, `ReadyToRun`

## Question

> How does JIT compilation work in .NET?

Also asked as:
> What is RyuJIT, and when does the CLR compile IL into native code?
> How do Tier 0 and Tier 1 fit into the startup-versus-throughput trade-off?

## Short Answer

Most .NET code is compiled twice: first from C# into IL at build time, then from IL into native machine code by the JIT at runtime. The default JIT on modern .NET is RyuJIT, and it usually compiles methods lazily the first time they are needed rather than compiling the whole application up front. Modern runtimes also use tiered compilation, starting with fast Tier 0 code for startup and promoting hot methods to more optimized Tier 1 code for throughput.

## Detailed Explanation

### From C# to IL to Native Code

When you build a .NET application, the C# compiler does **not** usually emit final CPU-specific instructions. Instead, it emits **Common Intermediate Language (IL)** plus metadata. At runtime, the CLR loads assemblies, verifies metadata, and asks the JIT compiler to translate IL into native code for the current architecture.

That second stage is what “JIT compilation” means. The JIT can tailor code generation to the actual CPU, OS, pointer size, and runtime features present on the machine.

### RyuJIT in Modern .NET

The production JIT in modern .NET is **RyuJIT**. It handles x64, Arm64, and other mainstream targets and is responsible for optimizations such as inlining, devirtualization, bounds-check elimination, and register allocation.

A key point for interviews: .NET is not generally running your application through a bytecode interpreter first. For most normal code paths, methods execute as **native code produced by the JIT**. There are a few specialized exceptions inside the runtime, but the everyday model is IL-to-native JIT compilation, not interpretation.

### Per-Method Lazy Compilation

The CLR does not normally compile the whole program at startup. Instead, it compiles methods **on demand** as they are first invoked. That keeps startup costs lower because unused methods never need native code at all.

| Approach | Benefit | Cost |
|---|---|---|
| Lazy per-method JIT | Faster startup, less wasted work | First call to a method pays compilation cost |
| Eager precompilation | Better warm startup | Larger binaries and less runtime adaptability |

This is why the first request to an ASP.NET Core endpoint or the first execution of a code path can feel slightly slower than subsequent executions.

### Tier 0 and Tier 1

Modern .NET uses **tiered compilation**. The first version of a method is often Tier 0: generated quickly, with limited optimization, so the app becomes responsive sooner. If the runtime observes that the method is hot, it recompiles it as Tier 1 with better optimizations.

That design solves a classic trade-off:

- **Startup:** compile quickly, do less optimization initially
- **Throughput:** spend more time optimizing code that runs a lot

This is why “the JIT” is no longer a single event. The same method may be compiled more than once at different quality levels. See [tiered-compilation.md](./tiered-compilation.md).

### JIT vs Precompiled Options

JIT gives excellent adaptability, but it is not the only deployment model. .NET also supports precompiled options such as ReadyToRun and NativeAOT.

| Model | Main idea |
|---|---|
| Normal JIT | Compile methods lazily at runtime |
| ReadyToRun | Ship assemblies with precompiled native code plus IL fallback |
| NativeAOT | Publish a native executable with no normal JIT dependency at runtime |

ReadyToRun can reduce startup time while keeping some JIT flexibility. NativeAOT pushes further toward ahead-of-time compilation but imposes stronger constraints. See [ready-to-run-overview.md](./ready-to-run-overview.md).

> **Warning:** JIT behavior is full of heuristics. Do not memorize every optimization threshold as a language guarantee; understand the trade-offs and the big picture.

### Interview Takeaway

A strong concise answer is: the C# compiler emits IL, RyuJIT turns that IL into native code per method at runtime, tiered compilation balances startup and throughput, and precompiled options exist when startup or deployment constraints matter more than JIT flexibility.

## Code Example

```csharp
using System.Diagnostics;
using System.Runtime.CompilerServices;

namespace RuntimeSamples;

public static class JitBasicsDemo
{
    public static void Main()
    {
        Measure("first call", 200_000);
        Measure("second call", 200_000); // Usually avoids the initial JIT cost.
    }

    private static void Measure(string label, int iterations)
    {
        Stopwatch sw = Stopwatch.StartNew();

        long sum = 0;
        for (int i = 0; i < iterations; i++)
        {
            sum += Compute(i);
        }

        sw.Stop();
        Console.WriteLine($"{label,-11}: {sw.ElapsedMilliseconds,4} ms, sum={sum}");
    }

    [MethodImpl(MethodImplOptions.NoInlining)] // Makes the demo easier to observe.
    private static int Compute(int value) => (value * 31) ^ (value >> 3);
}
```

## Common Follow-up Questions

- Why does the CLR JIT methods lazily instead of compiling the whole program at startup?
- What is the practical difference between Tier 0 and Tier 1 code?
- Why is .NET usually described as JIT-compiled rather than interpreted?
- How do ReadyToRun and NativeAOT change the startup story?
- Can the same method be compiled more than once during a process lifetime?

## Common Mistakes / Pitfalls

- Saying .NET is “interpreted” in the same sense as classic scripting runtimes.
- Assuming every method is fully optimized before the application starts executing.
- Forgetting that first-use latency can come from JIT compilation.
- Treating Tier 0 and Tier 1 thresholds as stable language-level contracts.
- Assuming precompiled deployments completely eliminate all runtime code generation scenarios.

## References

- [Compilation runtime configuration options for .NET](https://learn.microsoft.com/dotnet/core/runtime-config/compilation)
- [ReadyToRun deployment overview](https://learn.microsoft.com/dotnet/core/deploying/ready-to-run)
- [Native AOT deployment](https://learn.microsoft.com/dotnet/core/deploying/native-aot/)
- [RyuJIT Overview (dotnet/runtime)](https://github.com/dotnet/runtime/blob/main/docs/design/coreclr/botr/ryujit-overview.md)
- [MethodImplOptions Enum](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.methodimploptions)
