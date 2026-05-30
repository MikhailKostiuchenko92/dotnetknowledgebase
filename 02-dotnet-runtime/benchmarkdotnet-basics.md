# How Do You Benchmark .NET Code with BenchmarkDotNet?

**Category:** .NET Runtime / Diagnostics
**Difficulty:** 🔴 Senior
**Tags:** `BenchmarkDotNet`, `microbenchmark`, `MemoryDiagnoser`, `DisassemblyDiagnoser`, `performance`

## Question

> How do you benchmark .NET code correctly with BenchmarkDotNet?

Also asked as:
> What do `[Benchmark]`, `[Params]`, and `[MemoryDiagnoser]` do in BenchmarkDotNet?
> How do you avoid misleading benchmark results from warm-up bias or dead-code elimination?

## Short Answer

BenchmarkDotNet is the standard .NET microbenchmark framework because it handles warm-up, pilot runs, iteration control, statistics, environment reporting, and result export for you. You mark benchmark methods with `[Benchmark]`, optionally parameterize them with `[Params]`, and add diagnosers such as `[MemoryDiagnoser]` or `[DisassemblyDiagnoser]` to inspect allocations and generated assembly. Good benchmarks return or consume results, isolate the code under test, and compare baselines rather than timing arbitrary console apps with `Stopwatch`.

## Detailed Explanation

### Why BenchmarkDotNet Beats Ad-Hoc Timing

A raw `Stopwatch` around a loop looks simple, but it hides most of the variables that make performance numbers unreliable: JIT warm-up, tiered compilation, dead-code elimination, GC noise, outliers, and environment drift. BenchmarkDotNet was built to control those variables and report statistically meaningful results.

It generates a dedicated benchmark host, performs warm-up and measurement phases, and records the runtime, architecture, JIT, GC mode, and other environment details alongside the numbers. That makes results far easier to trust and compare.

### Key Attributes and Concepts

| Feature | Purpose |
|---|---|
| `[Benchmark]` | Marks a method to measure |
| `[Params]` | Runs the benchmark with multiple input values |
| `[GlobalSetup]` / `[GlobalCleanup]` | One-time setup and teardown outside the timed path |
| `[MemoryDiagnoser]` | Reports allocations and Gen0/1/2 activity |
| `[DisassemblyDiagnoser]` | Shows generated machine code for JIT analysis |
| Baseline comparison | Lets you compare variants side by side |

`[MemoryDiagnoser]` is especially valuable for .NET because many “fast” implementations are only fast until allocation pressure creates GC cost. `[DisassemblyDiagnoser]` is the bridge into JIT reasoning, which pairs well with [jit-diagnostics.md](./jit-diagnostics.md).

### Avoiding Bad Benchmarks

The biggest pitfall is benchmarking code the optimizer can eliminate. If the result is unused, the JIT may fold or remove parts of the work. The usual fix is to return the value, consume it through a blackhole-style sink, or store it in state that BenchmarkDotNet cannot treat as dead.

Another pitfall is accidentally benchmarking setup. If you allocate the test data inside the benchmark method when the real question is algorithm speed, you are measuring the wrong thing. Move fixed preparation into `[GlobalSetup]`.

> Warning: microbenchmarks answer narrow questions. A benchmark can prove one method is faster in isolation and still tell you nothing about database latency, lock contention, request fan-out, or real production throughput.

### Reporting and Interpretation

BenchmarkDotNet can export results to HTML, CSV, JSON, and Markdown, which makes regression tracking and PR discussion much easier. Baseline columns are helpful because the absolute number may vary by machine, but the relative improvement is often the decision-making signal.

### What Good Comparisons Look Like

The most useful benchmarks compare two or three clear alternatives under the same conditions: for-loop vs LINQ, pooled buffer vs fresh allocation, source-generated serializer vs reflection-based serializer. They should state the question being answered and isolate that question from unrelated work such as logging or network I/O. If the benchmark includes a baseline and one optimized variant, reviewers can understand not just the absolute number but the trade-off in readability, allocations, and complexity. That is much more persuasive than presenting one fast-looking number with no context.

A mature answer also mentions scope: use BenchmarkDotNet for CPU and allocation-sensitive microbenchmarks, not for entire system performance tests. For runtime counters and GC behavior in a live service, see [gc-notifications-and-monitoring.md](./gc-notifications-and-monitoring.md).

## Code Example

```csharp
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;

namespace DotNetRuntimeSamples.Benchmarks;

[MemoryDiagnoser]
[DisassemblyDiagnoser]
public class SumBenchmarks
{
    private int[] _numbers = [];

    [Params(100, 10_000)]
    public int Count { get; set; }

    [GlobalSetup]
    public void Setup()
    {
        _numbers = Enumerable.Range(1, Count).ToArray(); // Setup is excluded from benchmark timing.
    }

    [Benchmark(Baseline = true)]
    public int ForLoop()
    {
        int sum = 0;
        for (int i = 0; i < _numbers.Length; i++)
        {
            sum += _numbers[i];
        }

        return sum; // Return the value so the JIT cannot drop the work.
    }

    [Benchmark]
    public int LinqSum() => _numbers.Sum();
}

internal static class Program
{
    private static void Main() => BenchmarkRunner.Run<SumBenchmarks>();
}
```

## Common Follow-up Questions

- Why is BenchmarkDotNet more trustworthy than `Stopwatch` in a loop?
- What problems does `[MemoryDiagnoser]` reveal that raw timing misses?
- Why do benchmark methods usually return a value?
- When would you use `[DisassemblyDiagnoser]` during performance work?
- Why should setup and cleanup be separated from the measured method?

## Common Mistakes / Pitfalls

- Benchmarking code that the JIT optimizes away because the result is unused.
- Including input generation or I/O in the measured path when the question is algorithm cost.
- Reading one benchmark number without comparing a baseline or variance.
- Treating microbenchmark results as proof of end-to-end system performance.
- Running informal debug-build timings and calling them benchmarks.

## References

- [BenchmarkDotNet documentation](https://benchmarkdotnet.org/)
- [BenchmarkDotNet getting started](https://benchmarkdotnet.org/articles/guides/getting-started.html)
- [BenchmarkDotNet diagnosers](https://benchmarkdotnet.org/articles/configs/diagnosers.html)
- [ReadyToRun overview — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/ready-to-run)
- [Performance improvements in .NET — Microsoft Learn](https://learn.microsoft.com/dotnet/core/performance/)
