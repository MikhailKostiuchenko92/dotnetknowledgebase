# TaskCompletionSource

**Category:** C# / Async / Tasks
**Difficulty:** Senior
**Tags:** `TaskCompletionSource`, `TCS`, `async`, `bridge`, `callback`, `RunContinuationsAsynchronously`

## Question

> What is `TaskCompletionSource<T>` and when do you use it? What is the `RunContinuationsAsynchronously` flag and why does it matter?

Also asked as:
- "How do you bridge a callback-based or event-based API into the `async`/`await` world?"
- "What is the risk of completing a `TaskCompletionSource` while holding a lock?"

## Short Answer

`TaskCompletionSource<T>` is a manually-controlled `Task<T>` factory. You call `SetResult`, `SetException`, or `SetCanceled` from any thread or callback to complete the task, and callers can `await` it normally. It is the bridge pattern for converting legacy callback APIs, event-driven code, or hardware interrupts into `Task`-based async. The `RunContinuationsAsynchronously` flag prevents the completing thread from synchronously executing awaiting continuations — omitting it can cause unexpected re-entrancy, deadlocks, or stack overflows.

## Detailed Explanation

### The Problem It Solves

`async`/`await` works naturally with APIs that return `Task`. But older or low-level APIs use callbacks, `ManualResetEvent`, `IAsyncResult`, or hardware interrupt handlers. `TaskCompletionSource<T>` lets you create a `Task<T>` whose completion is driven externally:

```
external event/callback fires → TCS.SetResult(value) → awaiting Task<T> completes
```

### Basic Pattern

```csharp
var tcs = new TaskCompletionSource<string>();

// Pass tcs to the callback API:
socket.OnMessageReceived = msg => tcs.SetResult(msg);
socket.OnError = ex  => tcs.SetException(ex);
socket.Connect();

// Await the result as if it were a normal async method:
string message = await tcs.Task;
```

### `TrySet*` vs `Set*`

| Method | Behaviour if already completed |
|---|---|
| `SetResult(v)` | Throws `InvalidOperationException` |
| `TrySetResult(v)` | Returns `false` silently |
| `SetException(ex)` | Throws if already completed |
| `TrySetException(ex)` | Returns `false` silently |
| `SetCanceled()` | Throws if already completed |
| `TrySetCanceled(ct)` | Returns `false` silently |

Use `Try*` variants whenever multiple code paths may complete the TCS (race conditions, timeouts, user cancellation).

### `RunContinuationsAsynchronously` — The Critical Flag

By default (`TaskCreationOptions.None`), when `SetResult` is called, **continuations registered on the task run synchronously on the thread that calls `SetResult`**. This is an optimisation — but it has dangerous side effects:

```
Thread A: holds lock → calls tcs.SetResult(value)
  → synchronously executes Task continuation
  → continuation tries to acquire the same lock → DEADLOCK
```

Or a deep call stack:

```
SetResult → continuation1 → continuation2 → ... → StackOverflowException
```

The fix:

```csharp
var tcs = new TaskCompletionSource<string>(
    TaskCreationOptions.RunContinuationsAsynchronously);   // ← continuations queued to thread pool
```

With this flag, `SetResult` queues continuations to the thread pool and returns immediately. The calling thread is never blocked.

> **Rule:** Always use `RunContinuationsAsynchronously` unless you have a specific and documented reason not to. The performance gain from synchronous continuation execution is rarely worth the re-entrancy risk.

### Cancellation Support

```csharp
var tcs = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);

using var reg = ct.Register(() => tcs.TrySetCanceled(ct));
// ... set up work ...
await tcs.Task;
```

The `Register` callback fires when the token is cancelled, completing the task as cancelled. The `using` ensures the registration is disposed when we're done — preventing the callback from firing after the TCS is no longer in use.

### Converting Event-Based Asynchronous Pattern (EAP)

```csharp
static Task<byte[]> ReadFileAsync(string path)
{
    var tcs = new TaskCompletionSource<byte[]>(
        TaskCreationOptions.RunContinuationsAsynchronously);

    var reader = new BackgroundWorker();
    reader.DoWork += (_, _) => tcs.SetResult(File.ReadAllBytes(path));
    reader.RunWorkerCompleted += (_, e) =>
    {
        if (e.Error != null) tcs.TrySetException(e.Error);
    };
    reader.RunWorkerAsync();
    return tcs.Task;
}
```

### `ValueTask` Counterpart: `ManualResetValueTaskSourceCore<T>`

For high-performance scenarios where you want to avoid a `Task` allocation and the TCS can be reused, implement `IValueTaskSource<T>` using `ManualResetValueTaskSourceCore<T>`. This is advanced infrastructure code (used inside `Channel<T>`, `SocketAsyncEventArgs`, etc.) and is not needed in typical application code.

### Real-World Applications

| Use case | Pattern |
|---|---|
| Convert callback API | `SetResult` in the callback |
| Implement async `ManualResetEvent` | `TCS.Task` as the wait handle; `SetResult` to release |
| Add timeout to any async op | `TrySetCanceled` from `Task.Delay` continuation |
| Async test synchronization | `TCS` to signal test completion from another thread |
| Bridge `IAsyncResult` (APM) | `FromAsync` or manual TCS |

## Code Example

```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

// --- 1. Basic bridge: callback → Task ---
static Task<int> SimulateHardwareCallbackAsync(CancellationToken ct)
{
    var tcs = new TaskCompletionSource<int>(
        TaskCreationOptions.RunContinuationsAsynchronously);   // ← always use this

    // Simulate hardware interrupt on a pool thread:
    ThreadPool.QueueUserWorkItem(_ =>
    {
        Thread.Sleep(50);   // simulate latency
        tcs.TrySetResult(42);
    });

    using var reg = ct.Register(() => tcs.TrySetCanceled(ct));
    return tcs.Task;
}

int result = await SimulateHardwareCallbackAsync(CancellationToken.None);
Console.WriteLine(result);   // 42

// --- 2. Async ManualResetEvent ---
public class AsyncGate
{
    private volatile TaskCompletionSource _tcs =
        new(TaskCreationOptions.RunContinuationsAsynchronously);

    public Task WaitAsync() => _tcs.Task;

    public void Open()  => _tcs.TrySetResult();

    public void Reset() =>
        Interlocked.Exchange(
            ref _tcs,
            new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously));
}

var gate = new AsyncGate();
var waiter = Task.Run(async () =>
{
    await gate.WaitAsync();
    Console.WriteLine("Gate opened!");
});

await Task.Delay(30);
gate.Open();
await waiter;   // Gate opened!

// --- 3. Timeout on any Task ---
static async Task<T> WithTimeoutAsync<T>(Task<T> task, TimeSpan timeout)
{
    var tcs = new TaskCompletionSource<T>(TaskCreationOptions.RunContinuationsAsynchronously);
    using var cts = new CancellationTokenSource(timeout);
    using var reg = cts.Token.Register(() => tcs.TrySetCanceled(cts.Token));

    // Race the original task against the timeout TCS:
    var completed = await Task.WhenAny(task, tcs.Task);
    if (completed == tcs.Task)
        throw new TimeoutException($"Operation timed out after {timeout}");
    return await task;
}

var fast = Task.Delay(50).ContinueWith(_ => "ok");
Console.WriteLine(await WithTimeoutAsync(fast, TimeSpan.FromSeconds(1)));   // ok
```

## Common Follow-up Questions

- What is the difference between `TaskCompletionSource<T>` and `TaskCompletionSource` (non-generic, .NET 5+)?
- How does `ManualResetValueTaskSourceCore<T>` compare to `TaskCompletionSource<T>` for high-throughput infrastructure?
- How do you safely complete a TCS from multiple concurrent threads — which `Try*` method is atomic?
- Why does Kestrel (ASP.NET Core's HTTP server) use `IValueTaskSource` internally instead of `TaskCompletionSource`?
- How does `TaskCompletionSource` interact with `Task.WhenAll` — does `WhenAll` see exceptions from all TCS tasks?

## Common Mistakes / Pitfalls

- **Not using `RunContinuationsAsynchronously`.** Default synchronous continuation execution from `SetResult` can cause deadlocks (if the continuation tries to acquire a lock held by the `SetResult` caller) or stack overflows (deep continuation chains).
- **Calling `Set*` inside a `lock` without `RunContinuationsAsynchronously`.** The continuation runs synchronously on the locked thread, and if the continuation tries to acquire the same lock — deadlock.
- **Using `SetResult` when a race is possible.** If two code paths can complete the TCS simultaneously, use `TrySetResult`; otherwise the second call throws.
- **Forgetting to dispose the `CancellationTokenRegistration` returned by `ct.Register`.** If the token outlives the TCS, the registered callback will fire after the TCS object is no longer in use, causing subtle errors.
- **Creating a `TaskCompletionSource<T>` inside a loop without completing or abandoning previous instances.** Leaking TCS instances (their tasks are rooted by the pending continuations) causes memory leaks.

## References

- [TaskCompletionSource<T> — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.tasks.taskcompletionsource-1)
- [The Nature of TaskCompletionSource — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/pfxteam/the-nature-of-taskcompletionsource/)
- [RunContinuationsAsynchronously — GitHub dotnet/runtime discussion](https://github.com/dotnet/runtime/issues/15509) (verify URL)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
- [See: task-vs-valuetask.md](./task-vs-valuetask.md)
- [See: cancellation-tokens.md](./cancellation-tokens.md)
