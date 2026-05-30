# How Do volatile, Volatile, and Memory Barriers Work in .NET?

**Category:** .NET Runtime / Threading Model  
**Difficulty:** Senior  
**Tags:** `volatile`, `memory-barrier`, `interlocked`, `cpu-memory-model`, `reordering`

## Question
> What does the `volatile` keyword actually guarantee in C#, and what does it not guarantee?
>
> Why do memory barriers matter on modern CPUs even when code “looks” ordered in source?
>
> When should you use `volatile`, `Volatile.Read/Write`, `Thread.MemoryBarrier()`, or `Interlocked`?

## Short Answer
Modern CPUs and JIT compilers may reorder memory operations for performance, so one thread cannot safely assume another thread observes reads and writes in source-code order unless synchronization establishes ordering. In C#, `volatile` and `Volatile.Read/Write` add acquire/release semantics for individual accesses, which improves visibility but does not make compound operations like `x++` atomic. `Interlocked` operations are both atomic and full-fence, while `Thread.MemoryBarrier()` is a blunt full fence used rarely in application code and mostly in low-level synchronization logic.

## Detailed Explanation
### Why ordering and visibility are separate problems
Concurrency bugs are not only about two threads updating the same variable simultaneously. They are also about one thread seeing stale data, because CPUs use caches and store buffers, and both CPUs and the JIT can reorder instructions when that does not change single-threaded behavior.

So there are two questions:

1. Is the operation atomic?
2. If another thread reads afterward, is the write guaranteed to be visible in the right order?

A plain field access may fail the second question even if the first is irrelevant.

### What `volatile` means in C#
Marking a field `volatile` changes the memory-ordering semantics of reads and writes to that field. A volatile read behaves like an acquire read: later reads/writes cannot move before it. A volatile write behaves like a release write: earlier reads/writes cannot move after it.

This is enough for common publication patterns such as “write data, then set ready flag” when the data itself is otherwise safely published.

> `volatile` improves visibility and ordering for that field. It does **not** make compound actions atomic. `count++`, “check then act,” and multi-field invariants still need a lock or `Interlocked`.

### `Volatile.Read` and `Volatile.Write`
The `Volatile` class provides the same acquire/release semantics without requiring the field itself to be declared `volatile`. That is useful when you only need the semantics at specific access sites or when generic code cannot use the field modifier conveniently.

### `Thread.MemoryBarrier()`
`Thread.MemoryBarrier()` is a full fence: memory operations before the barrier cannot move after it, and operations after it cannot move before it. It is stronger and lower-level than most application code needs.

In practice, if you are tempted to call it directly, you should first ask whether `lock`, `Interlocked`, `volatile`, or `Volatile.Read/Write` expresses the intent more clearly.

### `Interlocked` and full-fence semantics
`Interlocked` methods do two jobs at once:

| API | Atomic? | Ordering |
| --- | --- | --- |
| `volatile` field / `Volatile.Read/Write` | No for compound ops | Acquire/release |
| `Thread.MemoryBarrier()` | No by itself | Full fence |
| `Interlocked.*` | Yes | Full fence |

That is why `Interlocked.CompareExchange` is the foundation of many lock-free algorithms: it both atomically updates state and establishes strong memory ordering.

### Practical usage patterns
Use `volatile` or `Volatile.Read/Write` for simple signal flags and publication patterns. Use `Interlocked` for counters, one-word state machines, and compare-and-swap loops. Use `lock` when correctness depends on multiple variables changing together.

### Common misconception
A lot of candidates say, “volatile makes access thread-safe.” That is incomplete. It only addresses visibility/ordering on the marked access. If two threads both do `if (!initialized) initialized = true;`, `volatile` does not prevent both from entering.

For related atomic operations, see [SpinLock and Interlocked](./spinlock-and-interlocked.md).

## Code Example
```csharp
namespace RuntimeSamples.VolatileAndBarriers;

internal static class Program
{
    private static DataSnapshot? _snapshot;
    private static bool _ready;
    private static int _processedCount;

    public static void Main()
    {
        var producer = Task.Run(() =>
        {
            var snapshot = new DataSnapshot("eu-west-1", 3);
            _snapshot = snapshot;                // Publish the fully built object first.
            Volatile.Write(ref _ready, true);   // Release-store: readers seeing true also see prior writes.
        });

        var consumer = Task.Run(() =>
        {
            while (!Volatile.Read(ref _ready))  // Acquire-load: do not move later reads before this.
            {
                Thread.SpinWait(50);
            }

            Console.WriteLine($"Config: {_snapshot!.Region}, Retries: {_snapshot.MaxRetries}");
            Interlocked.Increment(ref _processedCount); // Atomic increment + full fence semantics.
        });

        Task.WaitAll(producer, consumer);
        Console.WriteLine($"Processed count: {_processedCount}");
    }
}

internal sealed record DataSnapshot(string Region, int MaxRetries);
```

## Common Follow-up Questions
- Why doesn't `volatile` make `x++` safe?
- What is the difference between visibility and atomicity?
- When is `Volatile.Read/Write` preferable to a `volatile` field modifier?
- Why do `Interlocked` methods imply stronger guarantees than `volatile`?
- When should you use a full lock instead of low-level memory-ordering primitives?

## Common Mistakes / Pitfalls
- Using `volatile` to protect compound read-modify-write logic.
- Assuming source-code order is automatically the order observed by other threads.
- Calling `Thread.MemoryBarrier()` when a clearer higher-level primitive would do.
- Publishing mutable shared objects with a volatile flag but then mutating them afterward.
- Forgetting that ordering guarantees must match the actual access pattern on both writer and reader sides.

## References
- https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/volatile
- https://learn.microsoft.com/dotnet/api/system.threading.volatile
- https://learn.microsoft.com/dotnet/api/system.threading.thread.memorybarrier
- https://learn.microsoft.com/dotnet/api/system.threading.interlocked
