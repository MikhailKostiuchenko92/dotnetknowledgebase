# How Do You Profile Memory Allocations in a Benchmark?

**Category:** Testing / Performance & Load Testing
**Difficulty:** 🔴 Senior
**Tags:** `BenchmarkDotNet`, `memory`, `allocations`, `MemoryDiagnoser`, `Span`, `GC`, `profiling`

## Question
> How do you profile memory allocations in a benchmark to detect excessive allocations?

## Short Answer
Add `[MemoryDiagnoser]` to your BenchmarkDotNet class to report bytes allocated per operation and Gen 0/1/2 GC collection counts. For deeper analysis — allocation call stacks and object lifetime — use dotnet-trace, JetBrains dotMemory, or Visual Studio Diagnostic Tools against a running process or a test.

## Detailed Explanation

### `[MemoryDiagnoser]` — In-Benchmark Allocation Profiling
```csharp
[MemoryDiagnoser]
public class AllocBenchmark
{
    [Benchmark]
    public string WithStringBuilder()
    {
        var sb = new StringBuilder();
        for (int i = 0; i < 10; i++) sb.Append("x");
        return sb.ToString();
    }

    [Benchmark]
    public string WithStringCreate() =>
        string.Create(10, 0, (span, _) => span.Fill('x'));
}
```

Output:
```
| Method            | Mean   | Gen0  | Allocated |
|-------------------|--------|-------|-----------|
| WithStringBuilder | 52 ns  | 0.023 | 192 B     |
| WithStringCreate  | 12 ns  | 0.011 | 48 B      |
```

**Gen0/1/2 columns** show GC collection frequency per 1000 operations.

### Identifying Allocation Sources
Zero-allocation targets can be verified:
```csharp
[Benchmark]
[AssertionCondition(AssertionConditionType.IS_NULL)]  // ensure no allocation
public void SpanOperation()
{
    Span<byte> buffer = stackalloc byte[64];
    buffer.Fill(0);
}
```

With `[MemoryDiagnoser]`, `Allocated: 0 B` confirms stackalloc-only code.

### dotnet-trace for Allocation Call Stacks
```shell
dotnet-trace collect --process-id <PID> \
  --profile gc-verbose --output trace.nettrace
```
Open in PerfView or SpeedScope to see which call sites allocate the most.

### dotnet-counters for Live Monitoring
```shell
dotnet-counters monitor --process-id <PID> \
  System.Runtime[gc-heap-size,gen-0-gc-count,gen-1-gc-count,alloc-rate]
```

### Common Allocation Anti-Patterns to Look For

| Anti-pattern | Fix |
|---|---|
| Boxing value types | Use generics or `Span<T>` |
| LINQ on hot paths | Rewrite as `foreach` / array |
| String concatenation in loops | `StringBuilder` / `string.Create` |
| `params` allocates an array | Use overloads or `ReadOnlySpan<T>` |
| Closure captures in lambdas | Extract to a static method |
| `ToList()` / `ToArray()` unnecessarily | Operate on the source enumerable |

### Zero-Allocation Techniques
```csharp
// Stackalloc for small fixed buffers
Span<byte> buffer = stackalloc byte[256];

// ArrayPool for larger reusable buffers
var arr = ArrayPool<byte>.Shared.Rent(1024);
try { /* use arr */ }
finally { ArrayPool<byte>.Shared.Return(arr); }

// Avoid boxing
void Method<T>(T value) where T : struct { } // no boxing
```

## Code Example
```csharp
[MemoryDiagnoser]
public class ParsingBenchmarks
{
    private readonly string _csv = "1,2,3,4,5,6,7,8,9,10";

    [Benchmark(Baseline = true)]
    public int[] ParseWithSplit()
        => _csv.Split(',').Select(int.Parse).ToArray();

    [Benchmark]
    public int[] ParseWithSpan()
    {
        var results = new int[10];
        int index = 0;
        var span = _csv.AsSpan();
        while (!span.IsEmpty)
        {
            int comma = span.IndexOf(',');
            var token = comma >= 0 ? span[..comma] : span;
            results[index++] = int.Parse(token);
            if (comma < 0) break;
            span = span[(comma + 1)..];
        }
        return results;
    }
}

// Expected:
// ParseWithSplit: high allocation (string[], string[10] intermediate)
// ParseWithSpan:  low allocation (Span<char> is stack-based)
```

## Common Follow-up Questions
- What is `ArrayPool<T>` and when should you use it instead of `new`?
- What is the LOH (Large Object Heap) and what triggers allocation there?
- How do `Span<T>` and `Memory<T>` help reduce allocations?
- What is `SkipLocalsInit` and does it matter for performance?
- How do you use the `[EventPipeProfiler]` in BenchmarkDotNet for GC events?

## Common Mistakes / Pitfalls
- **Not adding `[MemoryDiagnoser]`** — `[Benchmark]` alone does not report allocations.
- **Ignoring Gen0 count** — frequent Gen0 GCs indicate allocations even when total bytes look low.
- **Benchmarking with large stackalloc** — `stackalloc` > ~1 KB risks `StackOverflowException` in production; benchmark realistic sizes.
- **Returning `ArrayPool` arrays as method returns** — callers can't return them safely; document ownership.

## References
- [BenchmarkDotNet — MemoryDiagnoser](https://benchmarkdotnet.org/articles/configs/diagnosers.html#memory-diagnoser)
- [Microsoft Learn — Span<T> and Memory<T>](https://learn.microsoft.com/en-us/dotnet/standard/memory-and-spans/)
- [Microsoft Learn — ArrayPool<T>](https://learn.microsoft.com/en-us/dotnet/api/system.buffers.arraypool-1)
- [dotnet-trace documentation](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-trace)
