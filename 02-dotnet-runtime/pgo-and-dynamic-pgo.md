# What Are PGO and Dynamic PGO in .NET?

**Category:** .NET Runtime / JIT & AOT
**Difficulty:** 🔴 Senior
**Tags:** `pgo`, `dynamic pgo`, `tiered compilation`, `guarded devirtualization`, `r2r`

## Question

> What is Profile-Guided Optimization in .NET, and how does dynamic PGO differ from static PGO?

Also asked as:
> How does .NET collect runtime profile data and use it to produce better Tier 1 code?
> What is guarded devirtualization, and why is it tied to dynamic PGO?

## Short Answer

Profile-Guided Optimization uses execution data to help the JIT make better optimization decisions. Static PGO uses profiles collected ahead of time, while dynamic PGO, introduced in modern .NET releases, instruments Tier 0 code at runtime and feeds the observed behavior back into Tier 1 recompilation. That enables optimizations such as guarded devirtualization, where hot virtual or interface calls are specialized for the most common runtime type while still keeping a correct fallback path.

## Detailed Explanation

### Static PGO vs Dynamic PGO

PGO is the idea that optimization is better when the compiler knows what the program actually does instead of guessing from static code shape alone. Historically, that meant collecting a profile from representative runs, then feeding it into compilation later. That is the static PGO model: profile first, compile later.

Dynamic PGO changes the timing. In .NET 6 and later, the runtime can instrument Tier 0 code while the application is running. It observes things such as hot basic blocks, likely branches, and the concrete types seen at virtual and interface call sites. When the method is promoted to Tier 1, the JIT can use that live profile to make much more informed decisions.

| Mode | Where profile comes from | When it is applied | Trade-off |
|---|---|---|---|
| Static PGO | Representative training runs | Before deployment or publish | Stable, but only as good as the training data |
| Dynamic PGO | The application's current execution | During runtime tiering | Adaptive, but needs warm-up and instrumentation |

### How Dynamic PGO Fits Into Tiered Compilation

Dynamic PGO is closely tied to [tiered-compilation.md](./tiered-compilation.md). Tier 0 code is designed to start quickly, so it favors low compilation cost. But while that Tier 0 code runs, the runtime can collect profile data. Once enough call counting and instrumentation data exists, the method is re-JITed into Tier 1 using the observed behavior.

That is why settings such as `DOTNET_TC_CallCountingDelayMs=0` are useful during experiments: they force profiling and promotion to happen immediately, making it easier to observe the effect without waiting for the normal delay.

### Guarded Devirtualization

A classic win enabled by dynamic PGO is guarded devirtualization. Suppose the source code calls an interface method, and at runtime 97% of calls target the same concrete implementation. Without profile data, the JIT may keep the call virtual because many implementations are *possible*. With PGO, the JIT can generate a fast path:

1. Check whether the receiver is the common type.
2. If yes, call the concrete target directly, which opens the door to inlining and further optimization.
3. If not, fall back to the original virtual dispatch path.

This is called “guarded” because the optimization is protected by a runtime type check. It preserves correctness while making the hot case cheaper.

> Warning: dynamic PGO helps workloads that stay alive long enough to collect meaningful data. If you only measure process startup or one cold request, you may miss most of its benefits.

### R2R + PGO Is a Useful Combination

ReadyToRun and dynamic PGO are complementary, not competing, features. R2R gives you fast startup by precompiling much of the code so the process can begin with little JIT work. Dynamic PGO then improves hot paths later by guiding Tier 1 recompilation with real execution data.

A useful interview summary is: R2R accelerates the first execution, dynamic PGO improves the important repeated executions.

### Practical Interpretation

Dynamic PGO is valuable because it narrows the gap between “fast startup code” and “high-quality optimized code.” Instead of optimizing blindly, the JIT can optimize based on what the application actually did in production-like execution.

For services, that often means better steady-state throughput. For microbenchmarks, it means warm-up policy matters: if the benchmark never reaches the profiled Tier 1 state, you are not measuring the feature fairly.

## Code Example

```csharp
using System;
using System.Runtime.CompilerServices;

namespace RuntimeSamples.DynamicPgo;

internal interface IMessageFormatter
{
    string Format(int value);
}

internal sealed class JsonFormatter : IMessageFormatter
{
    public string Format(int value) => $"{{\"value\":{value}}}";
}

internal sealed class XmlFormatter : IMessageFormatter
{
    public string Format(int value) => $"<value>{value}</value>";
}

internal static class Program
{
    private static readonly IMessageFormatter[] Formatters =
    [
        new JsonFormatter(),
        new JsonFormatter(),
        new JsonFormatter(), // Hot path usually sees JsonFormatter.
        new XmlFormatter()
    ];

    private static void Main()
    {
        // Useful when experimenting:
        // DOTNET_TieredPGO=1
        // DOTNET_TC_CallCountingDelayMs=0
        Console.WriteLine(RunHotLoop(2_000_000));
    }

    [MethodImpl(MethodImplOptions.NoInlining)]
    private static int RunHotLoop(int iterations)
    {
        int totalLength = 0;

        for (int i = 0; i < iterations; i++)
        {
            IMessageFormatter formatter = Formatters[i & 3];
            totalLength += formatter.Format(i).Length;
        }

        return totalLength;
    }
}
```

## Common Follow-up Questions

- What data does dynamic PGO collect from Tier 0 code?
- Why is guarded devirtualization useful for interface-heavy code?
- How does dynamic PGO interact with ReadyToRun publishing?
- Why do warm-up and call-counting delays matter when benchmarking .NET?
- Can static and dynamic PGO both exist in the same overall optimization strategy?

## Common Mistakes / Pitfalls

- Describing dynamic PGO as a separate compiler instead of a feedback input into Tier 1 JIT compilation.
- Assuming devirtualization becomes unconditional; guarded devirtualization still needs a fallback path.
- Measuring only cold start and concluding dynamic PGO has no value.
- Forgetting that R2R and dynamic PGO complement each other.
- Turning on profiling knobs in tests, then assuming production behavior will match exactly without similar warm-up.

## References

- [Compilation config settings — Microsoft Learn](https://learn.microsoft.com/dotnet/core/runtime-config/compilation)
- [ReadyToRun compilation — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/ready-to-run)
- [Performance Improvements in .NET 6 — .NET Blog](https://devblogs.microsoft.com/dotnet/performance-improvements-in-net-6/)
- [Performance Improvements in .NET 7 — .NET Blog](https://devblogs.microsoft.com/dotnet/performance_improvements_in_net_7/)
