# Thread vs ThreadPool

**Category:** C# / Threading / Concurrency
**Difficulty:** Middle
**Tags:** `Thread`, `ThreadPool`, `Task.Run`, `QueueUserWorkItem`, `threading`

## Question
> What is the difference between creating a raw `Thread` and queuing work to the .NET thread pool, and when should you choose one over the other?

Also asked as:
- "Why is creating lots of threads expensive compared to `Task.Run` or `ThreadPool.QueueUserWorkItem`?"
- "What is the practical difference between `ThreadPool.QueueUserWorkItem` and `Task.Run`?"

## Short Answer
A raw `Thread` is a dedicated OS thread with its own stack and lifetime, so creating one is relatively expensive and should be reserved for special cases such as STA threads, long-running dedicated loops, or custom thread settings. The thread pool reuses a shared set of worker threads, making `Task.Run` or `ThreadPool.QueueUserWorkItem` the right default for short-lived background work. `Task.Run` is usually preferable because it composes with `await`, results, exceptions, and cancellation more naturally than the low-level pool APIs.

## Detailed Explanation

### What a raw `Thread` gives you
`new Thread(...)` creates a real OS thread. That means a separate stack, kernel scheduling, and explicit lifetime management. It is useful when you need something the pool does not expose well:

- apartment state such as STA for COM or certain UI interop
- a dedicated long-lived worker that should not compete with pool heuristics
- explicit thread properties such as `IsBackground`, name, or custom stack size

The trade-off is cost. Threads consume more memory and startup time than simply queueing work to the pool.

### What the thread pool gives you
The .NET thread pool is a shared worker pool managed by the runtime. Instead of constantly creating and destroying threads, the runtime reuses worker threads for many tasks over time. That is why the pool is the default for most server and application background work.

| Option | Startup cost | Reuse | Return value support | Typical use |
|---|---|---|---|---|
| `new Thread(...)` | Highest | No | Manual | Dedicated special-case worker |
| `ThreadPool.QueueUserWorkItem` | Low | Yes | No direct result | Simple fire-and-forget work |
| `Task.Run` | Low | Yes | Yes via `Task` | Most app-level background work |

### `ThreadPool.QueueUserWorkItem` vs `Task.Run`
Both typically execute on thread pool threads, but they target different abstraction levels.

`ThreadPool.QueueUserWorkItem` is the older low-level API. It is fine when you only want to queue a delegate and you do not care about awaiting completion or getting a result.

`Task.Run` builds on the task infrastructure. It gives you:

- a `Task` to await
- built-in result propagation with `Task<T>`
- exception capture
- natural composition with `Task.WhenAll`, `await`, and cancellation tokens passed into your delegate

Because modern .NET code is task-based, `Task.Run` is usually the better application-facing choice.

### When to create a dedicated thread
A dedicated thread can still be correct when the work is effectively permanent or has special requirements. Examples include:

- a hardware polling loop that blocks for the life of the process
- a single-threaded apartment requirement
- a custom message pump
- an isolated background thread where you explicitly do not want pool contention

> **Warning:** do not create threads just because some work is "important." Important short-lived work still usually belongs on the thread pool.

### When not to use raw threads
Avoid raw threads for routine request handling, short background jobs, or async workflows. If you spin up many dedicated threads, you pay unnecessary memory and scheduling cost, and you bypass the runtime's ability to balance concurrency across the process.

### Practical guidance
Prefer this order:

1. Use naturally async APIs for I/O.
2. Use `Task.Run` for short CPU-bound offloading.
3. Use `ThreadPool.QueueUserWorkItem` only when you intentionally want the low-level fire-and-forget form.
4. Use `new Thread` only when you need dedicated-thread behavior the pool cannot provide.

### Pool heuristics and blocking
The thread pool is optimized for many short work items, not for permanently blocked ones. If you queue work that spends most of its time in `Thread.Sleep`, synchronous I/O, or waiting on external locks, the pool may eventually compensate by adding more workers, but that adjustment is reactive rather than free. During that window, unrelated work can experience extra latency.

That is why dedicated threads and long-running task options exist: not because they are generally superior, but because some workloads do not fit the thread pool's reuse model.

### Choosing between the two pool APIs
If you are writing application code, `Task.Run` usually communicates intent more clearly because the caller can observe completion. `ThreadPool.QueueUserWorkItem` is still useful in lower-level infrastructure or performance-sensitive code paths where you explicitly want the minimal queueing primitive and do not need a returned `Task`.

> **Tip:** if you think you need a dedicated thread because the work is long-running, also consider `TaskCreationOptions.LongRunning`, which hints that the task should get a dedicated thread-like execution model.

## Code Example
```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

// 1. Raw thread: useful when you need special thread configuration.
var dedicatedThread = new Thread(() =>
{
    Console.WriteLine($"Dedicated thread id: {Environment.CurrentManagedThreadId}");
    Thread.Sleep(200); // Simulate a blocking dedicated loop.
});
dedicatedThread.Name = "SpecialWorker";
dedicatedThread.IsBackground = true;
dedicatedThread.Start();

// 2. Thread pool low-level API: fire-and-forget work item.
using var workItemDone = new ManualResetEventSlim();
ThreadPool.QueueUserWorkItem(_ =>
{
    Console.WriteLine($"ThreadPool work item on thread: {Environment.CurrentManagedThreadId}");
    workItemDone.Set();
});

// 3. Task.Run: preferred modern option because it is awaitable.
int sum = await Task.Run(() =>
{
    Console.WriteLine($"Task.Run on thread: {Environment.CurrentManagedThreadId}");
    int total = 0;
    for (int i = 1; i <= 1_000; i++)
    {
        total += i;
    }

    return total;
});

workItemDone.Wait();
dedicatedThread.Join();
Console.WriteLine($"Sum from Task.Run: {sum}");
```

## Common Follow-up Questions
- What does `TaskCreationOptions.LongRunning` do, and when is it useful?
- How does thread pool starvation differ from simply having a lot of queued work?
- Why is `Task.Run` usually a better fit than `ThreadPool.QueueUserWorkItem` in modern code?
- Can `ThreadPool.QueueUserWorkItem` or `Task.Run` be used for async I/O work?
- How does this compare with [task-vs-thread.md](./task-vs-thread.md)?

## Common Mistakes / Pitfalls
- Creating many dedicated threads for short work items that would be cheaper on the pool.
- Using `ThreadPool.QueueUserWorkItem` when you really need completion tracking, results, or exception handling.
- Assuming `Task.Run` creates a new thread every time; it usually uses an existing pool thread.
- Putting permanently blocking loops on normal pool workers, which can reduce throughput for unrelated work.
- Forgetting that raw thread exceptions are not captured into a `Task` for easy propagation.

## References
- [Thread Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.thread)
- [The managed thread pool — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/threading/the-managed-thread-pool)
- [ThreadPool.QueueUserWorkItem Method — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.threadpool.queueuserworkitem)
- [Task.Run Method — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.task.run)
- [See: task-vs-thread.md](./task-vs-thread.md)
- [See: cpu-bound-vs-io-bound-async.md](./cpu-bound-vs-io-bound-async.md)
