# `SemaphoreSlim` and `Mutex`

**Category:** C# / Threading / Concurrency
**Difficulty:** Middle
**Tags:** `SemaphoreSlim`, `Mutex`, `WaitAsync`, `synchronization`, `cross-process`

## Question
> What is the difference between `SemaphoreSlim` and `Mutex` in .NET, and when should you use each one?

Also asked as:
- "Why is `SemaphoreSlim` usually preferred in async code?"
- "When do you need a named `Mutex` instead of an in-process synchronization primitive?"

## Short Answer
`SemaphoreSlim` is an in-process synchronization primitive that can allow one or many concurrent entrants and supports `WaitAsync`, which makes it a strong fit for throttling and async coordination. `Mutex` is an OS-backed synchronization primitive that can be named and shared across processes, but it is heavier and only supports single ownership. Use `SemaphoreSlim` for most application-level async or in-process coordination; use `Mutex` only when you truly need cross-process exclusion.

## Detailed Explanation

### What problem each primitive solves
A semaphore controls how many callers may enter a critical region at once. `SemaphoreSlim` is the lightweight managed version intended for in-process usage. If you initialize it with a count of `1`, it behaves like an async-friendly gate. If you initialize it with `N`, it becomes a throttler that allows `N` concurrent callers.

A mutex is different. It represents exclusive ownership by exactly one thread at a time, and the underlying OS object can be named so that separate processes coordinate through the same mutex.

| Feature | `SemaphoreSlim` | `Mutex` |
|---|---|---|
| In-process coordination | Excellent | Works, but heavier |
| Cross-process coordination | No | Yes, via named mutex |
| Async waiting | Yes with `WaitAsync` | No |
| Multiple simultaneous entrants | Yes | No |
| Typical use | Throttling, async gate | Single-instance app, file/process-wide exclusion |

### Why `SemaphoreSlim` is common in modern .NET
`SemaphoreSlim` works well with `async` because `WaitAsync` returns a task instead of blocking a thread. That makes it ideal for:

- limiting concurrent HTTP requests
- protecting a shared async resource
- implementing a lightweight async lock
- controlling fan-out in background pipelines

Because it is in-process only, it is also cheaper than a kernel-backed primitive.

### When `Mutex` is the right choice
Use `Mutex` when the coordination boundary is broader than one process. Common examples:

- preventing two instances of a desktop app from running at once
- serializing access to a shared resource across processes
- integrating with OS- or interop-level synchronization requirements

`Mutex` is not naturally async-friendly. Waiting on it blocks a thread, which is usually the wrong thing inside an async workflow.

> **Warning:** if your only goal is to guard shared state inside one process, a `Mutex` is usually overkill and slower than needed.

### Ownership model and release rules
A mutex has thread ownership semantics: the thread that acquires it should release it. `SemaphoreSlim` instead manages counts. Each successful wait must eventually be balanced by a `Release`, but it is not tied to the same thread in the same way.

That difference matters operationally. With `SemaphoreSlim`, the most common bug is forgetting to release in a `finally` block. With `Mutex`, one common bug is accidentally using it in async code, which blocks worker threads and harms scalability.

### Practical choices
- **Need async coordination or throttling?** `SemaphoreSlim`.
- **Need exactly one process-wide owner?** named `Mutex`.
- **Need a simple synchronous in-process critical section?** often `lock` is even simpler than either.

### Throttling patterns with `SemaphoreSlim`
One of the most common modern uses is limiting concurrency rather than guarding a single critical section. For example, you might allow only 8 outbound HTTP requests at a time or only 2 expensive file conversions in parallel. That is a different mental model from a mutex: you are not protecting ownership of one thing, you are budgeting a finite number of slots.

That makes `SemaphoreSlim` especially useful in background workers, data ingestion pipelines, and APIs that call rate-limited dependencies.

### Operational edge cases with `Mutex`
Because `Mutex` is OS-backed and cross-process, it also comes with OS-level behaviors. For example, if a thread exits while owning a mutex, another waiter can observe an abandoned mutex condition. That can be valuable as a signal that something went wrong, but it is another reminder that `Mutex` is a heavier primitive intended for broader coordination scenarios.

### Choosing by ownership model
A final way to think about the decision is ownership. `Mutex` models exclusive ownership of one resource. `SemaphoreSlim` models access to a pool of permits. If you are reasoning about capacity, throttling, or concurrency limits, `SemaphoreSlim` usually matches the problem better.

> **Tip:** a `SemaphoreSlim(1, 1)` is often described as an "async lock," but semantically it is still a semaphore. Be disciplined about `try/finally` release patterns.

## Code Example
```csharp
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

// 1. Async throttling with SemaphoreSlim.
var throttler = new SemaphoreSlim(initialCount: 2, maxCount: 2);

var tasks = Enumerable.Range(1, 5).Select(async id =>
{
    await throttler.WaitAsync(); // Does not block a thread while waiting.
    try
    {
        Console.WriteLine($"Job {id} entered on thread {Environment.CurrentManagedThreadId}");
        await Task.Delay(300); // Simulate async I/O while holding one permit.
        Console.WriteLine($"Job {id} leaving");
    }
    finally
    {
        throttler.Release(); // Always release in finally.
    }
});

await Task.WhenAll(tasks);

// 2. Cross-process coordination with a named Mutex.
const string mutexName = "Global\\DotNetKnowledgeBaseDemoMutex";
using var mutex = new Mutex(initiallyOwned: false, name: mutexName);

bool entered = false;
try
{
    entered = mutex.WaitOne(TimeSpan.FromSeconds(1)); // Synchronous, blocks the thread.
    if (entered)
    {
        Console.WriteLine("Acquired named mutex. Another process using the same name would be excluded.");
    }
    else
    {
        Console.WriteLine("Could not acquire named mutex within the timeout.");
    }
}
finally
{
    if (entered)
    {
        mutex.ReleaseMutex();
    }
}
```

## Common Follow-up Questions
- When is `SemaphoreSlim(1, 1)` a better choice than `lock`?
- How would you limit outbound HTTP requests to avoid overwhelming another service?
- Why is `Mutex` a poor fit for async request handlers or high-throughput services?
- What is the difference between `Semaphore` and `SemaphoreSlim`?
- How does this relate to [cancellation-tokens.md](./cancellation-tokens.md) and [producer-consumer-with-channel.md](./producer-consumer-with-channel.md)?

## Common Mistakes / Pitfalls
- Using `Mutex` for ordinary in-process locking where `lock` or `SemaphoreSlim` would be simpler and cheaper.
- Calling `Wait()` on `SemaphoreSlim` inside async code instead of `WaitAsync`, which blocks a thread unnecessarily.
- Forgetting to release a semaphore in a `finally` block, leading to hidden deadlocks.
- Treating `SemaphoreSlim` as cross-process safe; it is not.
- Holding either primitive across long or unnecessary work, which increases contention.

## References
- [SemaphoreSlim Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.semaphoreslim)
- [Mutex Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.mutex)
- [Overview of synchronization primitives — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/threading/overview-of-synchronization-primitives)
- [See: cancellation-tokens.md](./cancellation-tokens.md)
- [See: lock-and-monitor.md](./lock-and-monitor.md)
- [See: producer-consumer-with-channel.md](./producer-consumer-with-channel.md)
