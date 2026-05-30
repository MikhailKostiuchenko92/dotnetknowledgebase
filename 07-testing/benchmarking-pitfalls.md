# Common Sources of Benchmark Inaccuracy

**Category:** Testing / Performance & Load Testing
**Difficulty:** 🟡 Middle
**Tags:** `BenchmarkDotNet`, `JIT`, `GC`, `benchmarking`, `performance`, `accuracy`

## Question
> What are common sources of benchmark inaccuracy (JIT warmup, GC pressure, CPU caching)?

## Short Answer
The main sources are: JIT compilation on first run (skewed by warmup), GC pauses between iterations, CPU instruction and data cache effects, frequency scaling (Turbo Boost), branch prediction, and dead code elimination by the JIT. BenchmarkDotNet mitigates most of these automatically, but you must still structure your benchmarks correctly.

## Detailed Explanation

### 1. JIT Compilation (Warmup)
On the first call, the .NET JIT compiles the method. This takes microseconds to milliseconds — orders of magnitude longer than the actual operation.

**Mitigation**: BenchmarkDotNet performs multiple warmup iterations before measuring. Never use `Stopwatch` for benchmarks.

### 2. GC Pressure
If your benchmark allocates heap memory, the GC may kick in mid-measurement, introducing spikes.

**Detection**: Use `[MemoryDiagnoser]` to see bytes allocated per operation.
**Mitigation**: Zero-allocation code paths produce stable results; high-allocation paths show more variance.

```csharp
[MemoryDiagnoser]
public class MyBenchmark
{
    [Benchmark]
    public string Build() => new StringBuilder().Append("a").Append("b").ToString();
    // High allocation → more GC variance
}
```

### 3. CPU Caching (Cache Miss Effects)
Modern CPUs have L1/L2/L3 caches. If your benchmark data fits in L1 cache, measured latency is artificially low. Real workloads may be cache-cold.

**Example**: Benchmarking array lookup with 1000 elements fits in L1. With 10M elements, you measure memory access latency instead.

**Mitigation**: Use `[Params(100, 10_000, 1_000_000)]` to benchmark at multiple data sizes.

### 4. CPU Frequency Scaling (Turbo Boost)
Modern CPUs increase clock frequency under burst load. Short benchmarks benefit disproportionately from Turbo; sustained load runs at base clock.

**Mitigation**: BenchmarkDotNet runs long enough to average across thermal states. Disable Turbo on benchmark machines for maximum reproducibility (not practical on cloud CI).

### 5. Branch Prediction
Sorted vs. unsorted data can produce dramatically different results because the CPU branch predictor succeeds or fails differently.

```csharp
// Fast: sorted data — predictor is right 99% of the time
// Slow: random data — predictor fails 50% of the time
```

### 6. Dead Code Elimination
The JIT may eliminate a method that has no observable side effects.

```csharp
// ❌ JIT may eliminate — result is unused
[Benchmark]
public void NotReturned() { var x = Compute(); }

// ✅ Return the result
[Benchmark]
public int Returned() => Compute();
```

### 7. Measurement Overhead
Measuring very fast operations (< 1 ns) introduces measurement overhead that dominates the result.

**Mitigation**: Wrap the operation in a loop inside the benchmark method, then divide externally — or use `[OperationsPerInvoke(N)]`.

## Code Example
```csharp
[MemoryDiagnoser]
[Orderer(SummaryOrderPolicy.FastestToSlowest)]
public class CacheEffectsDemo
{
    [Params(100, 10_000, 1_000_000)]
    public int Size { get; set; }

    private int[] _array = Array.Empty<int>();

    [GlobalSetup]
    public void Setup() => _array = Enumerable.Range(0, Size).ToArray();

    [Benchmark(Baseline = true)]
    public int SequentialSum()
    {
        int sum = 0;
        foreach (var x in _array) sum += x; // cache-friendly
        return sum;
    }

    [Benchmark]
    public int RandomAccessSum()
    {
        int sum = 0;
        var indices = Enumerable.Range(0, Size).OrderBy(_ => Random.Shared.Next()).ToArray();
        foreach (var i in indices) sum += _array[i]; // cache-unfriendly
        return sum;
    }
}
// Expected: SequentialSum >> RandomAccessSum at large sizes due to cache misses
```

## Common Follow-up Questions
- What is `[OperationsPerInvoke]` and when do you use it?
- How do you benchmark operations that involve I/O?
- What is Tiered JIT and how does it affect benchmark warmup?
- How do you benchmark on different OSs and hardware to ensure portability?
- What is ReadyToRun (R2R) and does it affect benchmark results?

## Common Mistakes / Pitfalls
- **Calling `GC.Collect()` manually in benchmarks** — distorts GC pressure measurements.
- **Using `Random` inside `[Benchmark]`** — add randomness in `[GlobalSetup]` to avoid it being measured.
- **Benchmarking with Debug symbols** — use `dotnet run -c Release`.
- **Too-small data sets** — always benchmark with data sizes representative of production load.

## References
- [BenchmarkDotNet — diagnosers](https://benchmarkdotnet.org/articles/configs/diagnosers.html)
- [Andrey Akinshin — Performance of Microbenchmarks](https://aakinshin.net/tags/benchmarking/) (verify URL)
- [See also: benchmarkdotnet-overview.md](benchmarkdotnet-overview.md)
