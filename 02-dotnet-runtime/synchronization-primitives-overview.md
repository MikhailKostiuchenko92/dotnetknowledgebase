# What Synchronization Primitives Should You Know in .NET?

**Category:** .NET Runtime / Threading Model
**Difficulty:** 🟢 Junior
**Tags:** `lock`, `monitor`, `mutex`, `semaphoreslim`, `manualreseteventslim`

## Question

> What synchronization primitives are most important in .NET, and when would you use each one?

Also asked as:
> What is the difference between `lock`, `Mutex`, `SemaphoreSlim`, and reset events?
> Why is `SemaphoreSlim` usually preferred over older event-based primitives for async code?

## Short Answer

Use `lock`/`Monitor` for fast in-process mutual exclusion around small critical sections. Use `Mutex` when you specifically need an OS-backed, cross-process lock. Use `SemaphoreSlim` when you need lightweight throttling or async-compatible waiting with `WaitAsync`, and use reset events when one thread must signal one or many waiters to continue. The right primitive depends on scope, contention pattern, and whether the code must support async.

## Detailed Explanation

### `lock` Is the Default In-Process Mutual Exclusion Tool

In C#, `lock (obj)` is syntactic sugar over `Monitor.Enter` and `Monitor.Exit`, wrapped in a `try/finally` so the lock is released even if an exception occurs. It is fast, process-local, and ideal for protecting short critical sections over shared memory.

If your problem is “only one thread at a time may update this in-memory state,” `lock` is usually the first tool to consider.

### `Mutex` Is Heavier but Cross-Process

A `Mutex` is an OS-level synchronization object. Because it can be named and shared across processes, it is appropriate when multiple processes must coordinate access to a resource such as a file, single-instance app marker, or machine-wide gate.

That extra capability makes it slower than `Monitor`. If you do not need cross-process coordination, `Mutex` is often unnecessary overhead.

### `SemaphoreSlim` Controls Concurrency, Not Just Exclusion

A semaphore allows a limited number of concurrent entrants rather than exactly one. `SemaphoreSlim` is the lightweight managed version designed for in-process use. It is especially important because it supports `WaitAsync`, making it suitable for throttling async operations such as outbound HTTP calls or background jobs.

That makes it much more natural in modern .NET applications than blocking on classic wait handles.

### Reset Events Coordinate Progress Between Threads

Reset events are about signaling rather than ownership. `ManualResetEventSlim` stays signaled until manually reset, so all current and future waiters proceed while it remains open. `AutoResetEvent` releases a single waiter and then automatically returns to the non-signaled state.

| Primitive | Best use | Cross-process | Async-friendly |
|---|---|---|---|
| `lock` / `Monitor` | Protect short in-memory critical sections | No | No |
| `Mutex` | Named OS-level exclusion | Yes | No |
| `SemaphoreSlim` | Limit concurrent operations | No | Yes (`WaitAsync`) |
| `ManualResetEventSlim` | Release many waiters after a signal | No | No |

> Warning: `lock` and most wait-handle-based primitives do not mix well with `await`. If the code path is asynchronous, prefer async-aware primitives such as `SemaphoreSlim`.

### Choosing Quickly in Interviews

A good fast decision rule is:

- Need one-at-a-time access in one process -> `lock`.
- Need one-at-a-time access across processes -> `Mutex`.
- Need N-at-a-time throttling or async waiting -> `SemaphoreSlim`.
- Need signaling/gate behavior -> reset events.

For deeper examples, see [semaphoreslim-and-manualresetevent.md](./semaphoreslim-and-manualresetevent.md).

## Code Example

```csharp
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace RuntimeSamples.SyncPrimitives;

internal static class Program
{
    private static readonly object Gate = new();
    private static readonly SemaphoreSlim Throttle = new(initialCount: 2, maxCount: 2);
    private static readonly ManualResetEventSlim StartSignal = new(initialState: false);
    private static int _completed;

    private static async Task Main()
    {
        Task[] jobs = Enumerable.Range(1, 4).Select(RunAsync).ToArray();

        Console.WriteLine("Releasing all workers...");
        StartSignal.Set(); // Manual reset: all waiting workers may continue.

        await Task.WhenAll(jobs);
        Console.WriteLine($"Completed jobs: {_completed}");
    }

    private static async Task RunAsync(int jobId)
    {
        StartSignal.Wait();
        await Throttle.WaitAsync(); // Only two workers can enter at once.

        try
        {
            await Task.Delay(100);

            lock (Gate) // Compiles to Monitor.Enter/Exit with try/finally semantics.
            {
                _completed++;
                Console.WriteLine($"Job {jobId} completed on thread {Environment.CurrentManagedThreadId}");
            }
        }
        finally
        {
            Throttle.Release();
        }
    }
}
```

## Common Follow-up Questions

- What does `lock` compile to under the hood?
- Why is `Mutex` slower than `Monitor`?
- When should you prefer `SemaphoreSlim` over `lock`?
- What is the behavioral difference between `ManualResetEventSlim` and `AutoResetEvent`?
- Why should you avoid `await` inside a `lock` block?

## Common Mistakes / Pitfalls

- Using `Mutex` for ordinary in-process locking where `lock` is simpler and faster.
- Treating `SemaphoreSlim` as a mutex instead of a concurrency limiter.
- Forgetting to release a semaphore in a `finally` block.
- Using blocking primitives in async-heavy code when async-compatible coordination is needed.
- Confusing manual-reset behavior (“release all waiters until reset”) with auto-reset behavior (“release one waiter”).

## References

- [The `lock` statement — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/lock)
- [Monitor API — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.monitor)
- [Mutex API — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.mutex)
- [SemaphoreSlim API — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.semaphoreslim)
- [ManualResetEventSlim API — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.manualreseteventslim)
