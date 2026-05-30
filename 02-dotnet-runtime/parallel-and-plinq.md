# When Should You Use Parallel APIs and PLINQ?

**Category:** .NET Runtime / Threading Model  
**Difficulty:** Senior  
**Tags:** `parallel`, `plinq`, `parallelforeachasync`, `aggregateexception`, `cpu-bound`

## Question
> What is the difference between `Parallel.For`, `Parallel.ForEachAsync`, and PLINQ in .NET?
>
> When does PLINQ help, and when does it actually make performance worse?
>
> How do degree of parallelism and exception handling work in the parallel APIs?

## Short Answer
`Parallel.For` and `Parallel.ForEach` parallelize synchronous CPU-bound loops on the ThreadPool and wait until all iterations finish. `Parallel.ForEachAsync` extends the model to async delegates, letting you process items concurrently without blocking threads during awaits. PLINQ (`AsParallel()`) parallelizes LINQ-style query operators, which helps on large CPU-bound datasets but often hurts for I/O-bound or small workloads because coordination overhead can exceed the saved time.

## Detailed Explanation
### `Parallel.For` and `Parallel.ForEach`
The classic `Parallel` APIs partition work across ThreadPool threads, execute iterations concurrently, and only return when all iterations complete. They are ideal for independent CPU-bound iterations such as image processing, numeric transforms, or expensive pure computations over large collections.

They are not magic. The runtime still pays costs for partitioning, scheduling, synchronization, and cache effects. If each iteration is tiny, the overhead can outweigh the benefit.

### `Parallel.ForEachAsync`
`.NET 6+` added `Parallel.ForEachAsync`, which accepts an async delegate. That matters because the classic `Parallel.ForEach` expects synchronous work. If you try to force asynchronous I/O into the older API, you often end up blocking threads or accidentally fire-and-forgetting tasks.

`Parallel.ForEachAsync` limits concurrency using `ParallelOptions.MaxDegreeOfParallelism` and awaits the per-item delegate correctly.

### PLINQ
PLINQ is LINQ executed in parallel. You opt in with `AsParallel()`, and then familiar operators like `Where`, `Select`, and `GroupBy` can run across partitions. Important modifiers include:

- `WithDegreeOfParallelism(...)`
- `AsOrdered()` to preserve source order
- `AsSequential()` to switch back to sequential execution mid-query

PLINQ shines when the work per element is CPU-heavy and the dataset is large enough to amortize partitioning overhead. It often disappoints when the dataset is small, when the computation is trivial, or when the bottleneck is I/O rather than CPU.

> Do not use PLINQ as a default replacement for LINQ. Measure it on realistic workloads.

### Degree of parallelism
`ParallelOptions.MaxDegreeOfParallelism` controls the upper bound of concurrency. A value of `-1` means unlimited from the API's perspective, but the actual scheduler still decides how much work runs at once. In practice, for CPU-bound work, a good starting point is `Environment.ProcessorCount`.

For I/O-bound async work, the right number depends on external bottlenecks such as sockets, rate limits, and service latency.

### Ordering and exceptions
Parallel loops and PLINQ do not automatically preserve the same ordering guarantees as sequential code. PLINQ requires `AsOrdered()` if ordering matters, and ordering usually reduces performance.

When multiple parallel operations fail, the TPL typically reports them through `AggregateException`. That is important in interviews because the failure model is different from a normal sequential `foreach`, where only the first thrown exception is visible.

### Choosing between them

| API | Best for | Async delegate? | Notes |
| --- | --- | --- | --- |
| `Parallel.For` / `Parallel.ForEach` | Synchronous CPU-bound loops | No | Blocks until all iterations finish |
| `Parallel.ForEachAsync` | Mixed or async per-item work | Yes | Great for bounded concurrent async processing |
| PLINQ | Query-shaped CPU-bound transformations | No async query operators | Expressive LINQ-style parallelism |

For deeper scheduling behavior, see [Task Parallel Library Internals](./task-parallel-library-internals.md) and exception aggregation in [AggregateException](./aggregate-exception.md).

## Code Example
```csharp
namespace RuntimeSamples.ParallelAndPlinq;

internal static class Program
{
    public static async Task Main()
    {
        var numbers = Enumerable.Range(1, 50_000).ToArray();

        var primeCount = 0;
        Parallel.ForEach(
            numbers,
            new ParallelOptions { MaxDegreeOfParallelism = Environment.ProcessorCount },
            number =>
            {
                if (IsPrime(number))
                {
                    Interlocked.Increment(ref primeCount); // Aggregate shared results safely.
                }
            });

        Console.WriteLine($"Parallel.ForEach prime count: {primeCount}");

        await Parallel.ForEachAsync(
            Enumerable.Range(1, 5),
            new ParallelOptions { MaxDegreeOfParallelism = 2 },
            async (item, cancellationToken) =>
            {
                await Task.Delay(100, cancellationToken); // Async I/O-style work.
                Console.WriteLine($"Processed async item {item}");
            });

        var firstOrderedSquares = numbers
            .AsParallel()
            .WithDegreeOfParallelism(Environment.ProcessorCount)
            .AsOrdered() // Preserve input ordering when materializing the query.
            .Where(IsPrime)
            .Select(n => n * n)
            .Take(5)
            .ToArray();

        Console.WriteLine($"PLINQ sample: {string.Join(", ", firstOrderedSquares)}");
    }

    private static bool IsPrime(int value)
    {
        if (value < 2)
        {
            return false;
        }

        for (var i = 2; i * i <= value; i++)
        {
            if (value % i == 0)
            {
                return false;
            }
        }

        return true;
    }
}
```

## Common Follow-up Questions
- Why is `Parallel.ForEach` a poor fit for naturally async I/O operations?
- What does `AsOrdered()` cost in PLINQ?
- Why can small datasets get slower after parallelization?
- How should you choose `MaxDegreeOfParallelism` for CPU-bound work?
- Why do parallel APIs often surface `AggregateException`?

## Common Mistakes / Pitfalls
- Parallelizing tiny or trivial loops where overhead dominates.
- Using `Parallel.ForEach` with async lambdas and expecting correct awaiting behavior.
- Assuming PLINQ preserves ordering by default.
- Setting `MaxDegreeOfParallelism` far above useful levels for CPU-bound work.
- Forgetting that shared result aggregation still needs thread-safe coordination.

## References
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.parallel.for
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.parallel.foreachasync
- https://learn.microsoft.com/dotnet/standard/parallel-programming/introduction-to-plinq
- https://learn.microsoft.com/dotnet/standard/parallel-programming/how-to-specify-the-execution-mode-in-plinq
- https://learn.microsoft.com/dotnet/api/system.aggregateexception
