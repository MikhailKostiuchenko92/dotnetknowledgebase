# What Is BenchmarkDotNet and What Kind of Questions Does It Answer?

**Category:** Testing / Performance & Load Testing
**Difficulty:** 🟡 Middle
**Tags:** `BenchmarkDotNet`, `performance`, `benchmarking`, `micro-benchmarks`, `.NET`

## Question
> What is BenchmarkDotNet and what kind of questions does it answer?

## Short Answer
BenchmarkDotNet is the de-facto standard library for writing micro-benchmarks in .NET. It handles JIT warmup, GC pressure, statistical analysis, and result presentation. It answers questions like "Is `Span<T>` faster than `string` here?", "Does this LINQ query allocate more than the manual loop?", and "Did my optimization actually improve throughput?"

## Detailed Explanation

### What BenchmarkDotNet Solves
Naïve benchmarking with `Stopwatch` is unreliable due to:
- JIT compilation on first call
- GC pauses between runs
- CPU frequency scaling
- OS task scheduling noise

BenchmarkDotNet runs your benchmark **thousands of times**, discards warmup, collects statistics, and reports mean, standard deviation, and memory allocations.

### Installing
```shell
dotnet add package BenchmarkDotNet
```

### Basic Benchmark
```csharp
[MemoryDiagnoser]
public class StringBenchmarks
{
    private const string Template = "Hello, {0}!";
    private const string Name = "World";

    [Benchmark(Baseline = true)]
    public string StringFormat() => string.Format(Template, Name);

    [Benchmark]
    public string StringInterpolation() => $"Hello, {Name}!";

    [Benchmark]
    public string StringConcat() => "Hello, " + Name + "!";
}
```

### Running
```csharp
// Program.cs
BenchmarkRunner.Run<StringBenchmarks>();
```
```shell
dotnet run -c Release
```
> ⚠️ Always run in Release configuration — Debug adds overhead that distorts results.

### Sample Output
```
| Method              | Mean     | Allocated |
|---------------------|----------|-----------|
| StringFormat        | 63.4 ns  | 48 B      |
| StringInterpolation | 12.1 ns  | 32 B      |
| StringConcat        | 11.8 ns  | 32 B      |
```

### Diagnosers
| Attribute | What it measures |
|---|---|
| `[MemoryDiagnoser]` | Allocations per operation |
| `[EventPipeProfiler(EventPipeProfile.CpuSampling)]` | CPU hot paths |
| `[ThreadingDiagnoser]` | Thread contention |
| `[DisassemblyDiagnoser]` | JIT output |

### Parameterised Benchmarks
```csharp
[Params(10, 100, 1000)]
public int N { get; set; }

[Benchmark]
public int[] CreateArray() => new int[N];
```

## Code Example
```csharp
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;

[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class ListVsArrayBenchmarks
{
    private int[] _source = Enumerable.Range(0, 1000).ToArray();

    [Benchmark(Baseline = true)]
    public int SumArray()
    {
        int sum = 0;
        foreach (var x in _source) sum += x;
        return sum;
    }

    [Benchmark]
    public int SumLinq() => _source.Sum();

    [Benchmark]
    public int SumSpan()
    {
        int sum = 0;
        foreach (var x in _source.AsSpan()) sum += x;
        return sum;
    }
}

// Entry point
BenchmarkRunner.Run<ListVsArrayBenchmarks>();
```

## Common Follow-up Questions
- What is the difference between BenchmarkDotNet and profiling (dotnet-trace, JetBrains dotMemory)?
- How do you prevent BenchmarkDotNet from deadcode-eliminating your method?
- What is the `[GlobalSetup]` attribute in BenchmarkDotNet?
- How do you compare performance across different .NET runtimes?
- What should you do when benchmark results have high variance?

## Common Mistakes / Pitfalls
- **Running in Debug mode** — always use `dotnet run -c Release`; Debug results are meaningless.
- **Benchmarking I/O (network, disk)** — BenchmarkDotNet is designed for CPU-bound micro-benchmarks; I/O variance drowns the signal.
- **Not using `[GlobalSetup]`** — data preparation inside `[Benchmark]` skews results; set up once in `[GlobalSetup]`.
- **Not checking `[MemoryDiagnoser]`** — a fast method that allocates heavily may still cause GC pressure at scale.

## References
- [BenchmarkDotNet official site](https://benchmarkdotnet.org/)
- [BenchmarkDotNet GitHub](https://github.com/dotnet/BenchmarkDotNet)
- [Microsoft Learn — Performance testing with BenchmarkDotNet](https://learn.microsoft.com/en-us/dotnet/performance/benchmarks-overview) (verify URL)
