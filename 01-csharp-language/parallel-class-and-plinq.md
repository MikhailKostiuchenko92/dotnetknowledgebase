# `Parallel` Class and PLINQ

**Category:** C# / Threading / Concurrency
**Difficulty:** Middle
**Tags:** `Parallel`, `PLINQ`, `AsParallel`, `partitioning`, `cpu-bound`, `parallelism`

## Question
> What are the `Parallel` APIs and PLINQ in .NET, how do they partition work, and when do they help or hurt performance?

Also asked as:
- "When should I use `Parallel.For` or `Parallel.ForEach` instead of ordinary loops?"
- "Why can `AsParallel()` make code slower even on a multi-core machine?"

## Short Answer
`Parallel.For` and `Parallel.ForEach` split CPU-bound work across multiple thread pool threads, while PLINQ (`AsParallel`) parallelizes LINQ query execution. They help when each item has enough CPU work to amortize scheduling, partitioning, and merge overhead. They hurt when the work is tiny, heavily contended, order-dependent, blocking on I/O, or when the cost of combining results outweighs the parallel speedup.

## Detailed Explanation

### What these APIs are for
The `Parallel` class and PLINQ are data-parallel tools. They are designed for collections or ranges where many items can be processed independently. The runtime partitions the source into chunks and schedules them across thread pool workers.

These tools target **CPU-bound** workloads. If each iteration spends most of its time waiting on network or disk I/O, async APIs and `Task.WhenAll` are usually a better fit.

### `Parallel.For` / `Parallel.ForEach`
These APIs are imperative. You provide a loop body and let the runtime distribute iterations. They are often a good fit for:

- numeric or simulation work
- image or text transformations
- batch calculations over large arrays

### PLINQ with `AsParallel`
PLINQ is the declarative version. You write a LINQ pipeline, add `AsParallel()`, and the query engine partitions the source, executes parts concurrently, and merges the results.

That is convenient, but convenience can hide costs such as partitioning, ordering, and merging.

| Tool | Style | Best for | Common cost |
|---|---|---|---|
| `Parallel.For` | Imperative | Tight loops over ranges | Coordination and shared-state contention |
| `Parallel.ForEach` | Imperative | Independent work per item | Enumerator/partition overhead |
| PLINQ | Declarative | Parallel query pipelines | Partition + merge + ordering overhead |

### Partitioning and why it matters
The runtime does not usually assign one item per thread. It partitions the data into chunks so each worker processes batches. That reduces scheduling overhead and improves cache locality.

Performance depends heavily on partition quality:

- if work is evenly distributed, parallelism scales better
- if some items are much slower than others, one worker may become a straggler
- if all workers constantly update shared state, contention can erase the benefit

### Why PLINQ sometimes hurts
`AsParallel()` is not magic. It can be slower when:

- the dataset is small
- each element's work is trivial
- the query requires preserving order with `AsOrdered`
- the query uses side effects or shared mutable state
- the source is already materialized in a way that merges poorly

For example, parallelizing `numbers.AsParallel().Select(x => x + 1).ToArray()` may be slower than sequential LINQ because the work per item is too tiny.

> **Warning:** never assume parallel means faster. Measure with realistic input sizes and realistic contention.

### Good usage patterns
A good rule is: the more independent and CPU-heavy each item is, the better these APIs tend to work.

They are poor choices for most I/O-bound loops. For I/O, see [parallel-foreach-vs-task-whenall.md](./parallel-foreach-vs-task-whenall.md) and [cpu-bound-vs-io-bound-async.md](./cpu-bound-vs-io-bound-async.md).

### Tuning knobs
You can use `ParallelOptions.MaxDegreeOfParallelism` or PLINQ's `WithDegreeOfParallelism` to cap concurrency. That matters when:

- the machine already has other heavy work
- the algorithm saturates memory bandwidth before all cores
- an external dependency should not be hit too hard

### Ordering, merging, and exceptions
Parallel work eventually has to be merged back into one result. That merge step is where a lot of hidden cost lives, especially in PLINQ. Preserving source order, materializing arrays, or reducing into a shared collection can all eat into the speedup.

Exception behavior also matters. `Parallel` loops and PLINQ can aggregate failures from several workers, which is useful, but it means you should think in terms of whole-query failure rather than one neat sequential stack trace.

### A simple decision rule
Reach for `Parallel` or PLINQ when the operation is CPU-heavy, independent per item, and large enough to amortize overhead. Stay sequential when the work is tiny, ordered by nature, or dominated by coordination. Parallelism is a performance tool, not a readability default.

### Choosing between imperative and declarative forms
`Parallel.ForEach` is often easier when you naturally think in terms of a work loop and local accumulators. PLINQ is attractive when the code is already a LINQ pipeline and the transformations are pure. If the query starts filling up with side effects, shared mutable state, or order-sensitive behavior, that is a sign the imperative `Parallel` APIs may be the clearer choice.

> **Tip:** if your parallel loop updates shared counters or collections on every iteration, consider thread-local accumulation and a final reduction instead.

## Code Example
```csharp
using System;
using System.Linq;
using System.Threading.Tasks;

int[] numbers = Enumerable.Range(1, 200_000).ToArray();

// 1. Parallel.For: explicit data-parallel CPU loop.
long parallelSum = 0;
object gate = new();

Parallel.For<long>(
    fromInclusive: 0,
    toExclusive: numbers.Length,
    localInit: () => 0,
    body: (index, _, localTotal) =>
    {
        // Simulate CPU work per item.
        int value = numbers[index];
        return localTotal + (long)value * value;
    },
    localFinally: localTotal =>
    {
        // Merge once per worker instead of locking on every iteration.
        lock (gate)
        {
            parallelSum += localTotal;
        }
    });

Console.WriteLine($"Parallel.For sum: {parallelSum}");

// 2. PLINQ: declarative parallel query.
long plinqSum = numbers
    .AsParallel()
    .WithDegreeOfParallelism(Environment.ProcessorCount)
    .Select(n => (long)n * n)
    .Sum();

Console.WriteLine($"PLINQ sum: {plinqSum}");

// 3. Example of when parallelism can be overkill.
int[] tiny = [1, 2, 3, 4, 5];
int[] maybeSlower = tiny
    .AsParallel() // Likely slower than sequential for such tiny work.
    .Select(n => n + 1)
    .ToArray();

Console.WriteLine(string.Join(", ", maybeSlower));
```

## Common Follow-up Questions
- How does partitioning differ for arrays versus enumerables in PLINQ?
- When should you use thread-local state in `Parallel.For`?
- Why is PLINQ usually a bad choice for I/O-bound work?
- What does `AsOrdered()` do, and why can it reduce performance?
- How does this compare with [parallel-foreach-vs-task-whenall.md](./parallel-foreach-vs-task-whenall.md)?

## Common Mistakes / Pitfalls
- Parallelizing tiny per-item work where overhead dominates.
- Doing blocking I/O inside `Parallel.ForEach`, which ties up worker threads.
- Mutating shared state on every iteration, causing lock contention.
- Assuming PLINQ preserves order by default; it usually does not unless you ask for it.
- Using side effects in PLINQ queries, which makes correctness and performance harder to reason about.

## References
- [Parallel Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.parallel)
- [Potential pitfalls in data and task parallelism — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/parallel-programming/potential-pitfalls-in-data-and-task-parallelism)
- [Introduction to PLINQ — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/parallel-programming/introduction-to-plinq)
- [See: cpu-bound-vs-io-bound-async.md](./cpu-bound-vs-io-bound-async.md)
- [See: parallel-foreach-vs-task-whenall.md](./parallel-foreach-vs-task-whenall.md)
- [See: task-vs-thread.md](./task-vs-thread.md)
