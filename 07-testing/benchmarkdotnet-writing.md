# How Do You Write a Simple Benchmark With BenchmarkDotNet?

**Category:** Testing / Performance & Load Testing
**Difficulty:** 🟡 Middle
**Tags:** `BenchmarkDotNet`, `benchmark`, `performance`, `.NET`, `profiling`

## Question
> How do you write a simple benchmark with BenchmarkDotNet?

## Short Answer
Create a class with `[Benchmark]`-attributed methods, add optional configuration attributes like `[MemoryDiagnoser]`, and call `BenchmarkRunner.Run<T>()` from `Program.cs`. Always run with `dotnet run -c Release`. BenchmarkDotNet handles warmup, iteration count, and statistical analysis automatically.

## Detailed Explanation

### Step-by-Step Setup

**1. Install the NuGet package:**
```shell
dotnet add package BenchmarkDotNet
```

**2. Create a benchmark class:**
```csharp
[MemoryDiagnoser]
public class HashingBenchmarks
{
    private readonly byte[] _data = new byte[1024];

    [GlobalSetup]
    public void Setup() => Random.Shared.NextBytes(_data);

    [Benchmark(Baseline = true)]
    public byte[] MD5Hash() =>
        System.Security.Cryptography.MD5.HashData(_data);

    [Benchmark]
    public byte[] SHA256Hash() =>
        System.Security.Cryptography.SHA256.HashData(_data);
}
```

**3. Run from Program.cs:**
```csharp
using BenchmarkDotNet.Running;
BenchmarkRunner.Run<HashingBenchmarks>();
```

**4. Execute:**
```shell
dotnet run -c Release
```

### Key Attributes

| Attribute | Purpose |
|---|---|
| `[Benchmark]` | Marks a method for measurement |
| `[Benchmark(Baseline = true)]` | Sets the comparison baseline |
| `[GlobalSetup]` | Runs once before all iterations (not measured) |
| `[IterationSetup]` | Runs before each iteration (use sparingly) |
| `[Params(1, 10, 100)]` | Runs benchmark with different parameter values |
| `[MemoryDiagnoser]` | Reports allocations |
| `[SimpleJob(RuntimeMoniker.Net90)]` | Specifies runtime target |

### Preventing Dead Code Elimination
The JIT may optimize away a method that returns unused results. Use the return value:
```csharp
[Benchmark]
public int ComputeSum()
{
    int sum = 0;
    for (int i = 0; i < 1000; i++) sum += i;
    return sum; // return prevents elimination
}
```

Or use `[DoNotOptimize]` / `[ConsumeAttribute]` from the Consume helper.

### Reading the Results
```
| Method     | Mean      | Error    | StdDev   | Allocated |
|------------|-----------|----------|----------|-----------|
| MD5Hash    | 421.3 ns  | 3.2 ns   | 3.0 ns   | 64 B      |
| SHA256Hash | 1,234.1 ns| 9.4 ns   | 8.8 ns   | 64 B      |

Legend: Mean = average; Error = half-confidence interval; StdDev = standard deviation
```

## Code Example
```csharp
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;

[MemoryDiagnoser]
public class DictionaryBenchmarks
{
    private Dictionary<int, string> _dict = new();
    private List<int> _keys = new();

    [Params(100, 1000, 10_000)]
    public int Count { get; set; }

    [GlobalSetup]
    public void Setup()
    {
        _dict = new Dictionary<int, string>(Count);
        _keys = new List<int>(Count);
        for (int i = 0; i < Count; i++)
        {
            _dict[i] = $"value_{i}";
            _keys.Add(i);
        }
    }

    [Benchmark(Baseline = true)]
    public string? LookupByKey()
    {
        string? result = null;
        foreach (var key in _keys) _dict.TryGetValue(key, out result);
        return result;
    }

    [Benchmark]
    public string? LinqFirstOrDefault()
    {
        string? result = null;
        foreach (var key in _keys)
            result = _dict.FirstOrDefault(kv => kv.Key == key).Value;
        return result;
    }
}

// Program.cs
BenchmarkRunner.Run<DictionaryBenchmarks>();
```

## Common Follow-up Questions
- How do you benchmark async methods with BenchmarkDotNet?
- What is the difference between `[IterationSetup]` and `[GlobalSetup]`?
- How do you export benchmark results to a file or CI artifact?
- How do you run benchmarks for multiple runtimes in one run?
- What is `[DryJob]` and when is it useful during development?

## Common Mistakes / Pitfalls
- **Running in Debug** — adds overhead of 2–10x; results are useless.
- **Side-effect-free methods getting eliminated** — always return a value or use `Consume`.
- **Putting allocations in `[Benchmark]`** — allocations in setup contaminate measurement; use `[GlobalSetup]`.
- **Benchmarking at too small a scale** — operations that take < 1ns have too much noise; use larger inputs.

## References
- [BenchmarkDotNet Getting Started](https://benchmarkdotnet.org/articles/guides/getting-started.html)
- [BenchmarkDotNet configuration](https://benchmarkdotnet.org/articles/configs/configs.html)
- [See also: benchmarkdotnet-overview.md](benchmarkdotnet-overview.md)
