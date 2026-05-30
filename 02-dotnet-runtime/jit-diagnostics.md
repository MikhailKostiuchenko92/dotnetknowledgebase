# How Do You Diagnose JIT Behavior in .NET?

**Category:** .NET Runtime / JIT & AOT
**Difficulty:** 🔴 Senior
**Tags:** `jit`, `disassembly`, `perfview`, `dotnet-trace`, `benchmarkdotnet`

## Question

> How do you inspect what the .NET JIT actually generated for a method?

Also asked as:
> What tools would you use to see JIT assembly, IR dumps, or inlining decisions?
> How can you tell whether a method was inlined or re-JITed under tiered compilation?

## Short Answer

The lowest-level JIT diagnostics start with environment variables such as `DOTNET_JitDisasm=MethodName` for native assembly output and `DOTNET_JitDump=*` for detailed JIT IR and decision logging. For repeatable benchmarking, BenchmarkDotNet's `[DisassemblyDiagnoser]` gives cleaner disassembly output around the exact method under test. For runtime-wide observation, PerfView and `dotnet-trace` can capture JIT events such as method start and end, letting you correlate tiering, rejits, and method compilation with application execution.

## Detailed Explanation

### Start with the Smallest Useful Tool

If you only care about one method, environment-variable-based diagnostics are often the fastest route. `DOTNET_JitDisasm=Namespace.Type:Method` tells the runtime to print the generated machine code for matching methods to standard output. `DOTNET_JitDump=*` goes deeper and emits the JIT's intermediate reasoning: IR, transformations, inlining attempts, and optimization phases.

These are extremely powerful, but also noisy. `JitDisasm` is usually the better first step because it answers a concrete question: “What code did the JIT finally emit?”

### When to Use BenchmarkDotNet

For serious microbenchmark work, BenchmarkDotNet is often the cleanest option. The `[DisassemblyDiagnoser]` attribute integrates warm-up, iteration control, and stable output formatting, so you can compare code generation across methods or runtime versions without manually managing environment variables.

That makes it a better fit than raw console output when you want reproducible evidence in a performance investigation.

| Tool | Best for | Output style |
|---|---|---|
| `DOTNET_JitDisasm` | Quick inspection of one method | Assembly on stdout |
| `DOTNET_JitDump` | Deep internal JIT reasoning | Very verbose IR + phase logs |
| BenchmarkDotNet | Repeatable disassembly in benchmarks | Structured reports |
| PerfView / `dotnet-trace` | Runtime-wide JIT event analysis | ETW/EventPipe traces |

### Runtime Tracing: PerfView and `dotnet-trace`

When you need to answer broader questions — which methods were compiled, when Tier 1 kicked in, whether a re-JIT happened during load — use tracing tools instead of raw dumps.

PerfView is especially useful on Windows because it consumes ETW events from the .NET runtime. JIT-related events such as `MethodJittingStarted`, `JitMethodStart`, and `JitMethodEnd` help correlate compilation activity with the rest of the process.

Cross-platform, `dotnet-trace collect --providers Microsoft-Windows-DotNETRuntime:0x10` captures the JIT keyword over EventPipe. That gives you a lightweight way to see compilation activity without instrumenting the app.

> Warning: disassembly and dump output are sensitive to tiered compilation, PGO, OSR, and benchmark warm-up. Always note whether you are looking at Tier 0, Tier 1, or an R2R stub before drawing conclusions.

### How to Check Inlining

Inlining is one of the most common questions in JIT diagnostics. The simplest way to verify it is:

- If the caller disassembly contains a `call` to the callee, the callee was not inlined at that site.
- If the callee's logic appears directly in the caller body and there is no call instruction, it likely was inlined.
- `DOTNET_JitDump` can also explicitly report inline attempts and the reasons an inline was accepted or rejected.

This connects directly to [tiered-compilation.md](./tiered-compilation.md) and [pgo-and-dynamic-pgo.md](./pgo-and-dynamic-pgo.md), because inlining decisions often improve after profiling and Tier 1 recompilation.

### A Practical Workflow

A good interview-quality workflow is:

1. Reproduce the hot path in a minimal program or benchmark.
2. Use `JitDisasm` for a targeted assembly view.
3. Escalate to `JitDump` only if you need reasoning.
4. Use BenchmarkDotNet for durable comparisons.
5. Use PerfView or `dotnet-trace` when the question is process-wide rather than method-local.

That sequence avoids drowning in data too early.

## Code Example

```csharp
using System;
using System.Linq;
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;

namespace RuntimeSamples.JitDiagnostics;

[DisassemblyDiagnoser(printSource: true, maxDepth: 2)]
public class InliningBenchmarks
{
    private readonly int[] _values = Enumerable.Range(1, 1_000).ToArray();

    [Benchmark]
    public int SumSquares()
    {
        int sum = 0;

        foreach (int value in _values)
        {
            sum += Square(value); // Check disassembly to see whether this call was inlined.
        }

        return sum;
    }

    private static int Square(int value) => value * value;
}

internal static class Program
{
    private static void Main()
    {
        BenchmarkRunner.Run<InliningBenchmarks>();
    }
}
```

## Common Follow-up Questions

- What is the difference between `DOTNET_JitDisasm` and `DOTNET_JitDump`?
- How do tiered compilation and PGO change what disassembly you see?
- How can you verify whether a method was inlined?
- Why is BenchmarkDotNet usually better than ad-hoc loops for disassembly work?
- When would you prefer PerfView or `dotnet-trace` over method-local diagnostics?

## Common Mistakes / Pitfalls

- Looking at Tier 0 code and assuming it represents the final optimized state.
- Using `JitDump` first and getting buried in output that is too noisy to interpret.
- Forgetting that R2R images, tiered compilation, and OSR can all change what code is active.
- Concluding a method was not inlined just because the callee still exists as a separately compiled body elsewhere.
- Running benchmarks without warm-up, then comparing disassembly from different optimization tiers.

## References

- [dotnet-trace — Microsoft Learn](https://learn.microsoft.com/dotnet/core/diagnostics/dotnet-trace)
- [BenchmarkDotNet diagnosers](https://benchmarkdotnet.org/articles/configs/diagnosers.html)
- [PerfView repository](https://github.com/microsoft/perfview)
- [Compilation config settings — Microsoft Learn](https://learn.microsoft.com/dotnet/core/runtime-config/compilation)
