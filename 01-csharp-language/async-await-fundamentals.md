# Async/Await Fundamentals

**Category:** C# / Async / Tasks
**Difficulty:** Middle
**Tags:** `async`, `await`, `state-machine`, `Task`, `continuation`

## Question

> What does the `async` keyword actually do to a method? How does the compiler transform an `async` method, and what happens at runtime when execution hits an `await`?

Also asked as:
- "Walk me through what happens under the hood when you `await` a `Task`."
- "Why doesn't `async` make a method run on a thread pool thread?"

## Short Answer

The `async` keyword instructs the compiler to transform the method body into a state machine struct. When the method hits an `await`, it checks whether the awaited operation is already complete — if so, execution continues synchronously. If not, it registers a continuation and **returns control to the caller immediately**, without blocking any thread. When the awaited operation completes, the continuation resumes the state machine, typically on the captured `SynchronizationContext` or `TaskScheduler`.

## Detailed Explanation

### The Compiler Transformation

Marking a method `async` triggers a Roslyn lowering pass. The method body is split at every `await` point into numbered "states." The compiler generates:

1. A private struct (or class for complex flows) implementing `IAsyncStateMachine`.
2. A `MoveNext()` method containing a `switch` over the state number.
3. An `AsyncTaskMethodBuilder<T>` (or `AsyncValueTaskMethodBuilder<T>`) that drives the state machine and creates the returned `Task`.

```
public async Task<int> GetValueAsync()
{
    var data = await FetchAsync();   // state 0 → state 1
    return data.Length;
}

// ≈ compiler output (simplified):
private struct <GetValueAsync>d__0 : IAsyncStateMachine
{
    public int <>1__state;                         // current state
    public AsyncTaskMethodBuilder<int> <>t__builder; // task factory
    private TaskAwaiter<string> <>u__1;            // saved awaiter

    void MoveNext()
    {
        switch (<>1__state)
        {
            case -1: // initial
                var awaiter = FetchAsync().GetAwaiter();
                if (!awaiter.IsCompleted)
                {
                    <>1__state = 0;
                    <>u__1 = awaiter;
                    <>t__builder.AwaitUnsafeOnCompleted(ref awaiter, ref this);
                    return;   // ← return to caller HERE, no thread blocked
                }
                goto case 0;
            case 0:  // resume after FetchAsync completes
                var data = <>u__1.GetResult();
                <>t__builder.SetResult(data.Length);
                break;
        }
    }
}
```

The returned `Task<int>` object is created by the builder **before** the state machine runs. The caller receives it immediately and can `await` it (or not).

### `await` — Not a Thread Yield

A common misconception: `await` does **not** create a new thread or move work to the thread pool. It:

1. Calls `GetAwaiter()` on the awaitable.
2. Checks `IsCompleted` — if `true`, continues **synchronously** with zero overhead.
3. If `false`, calls `OnCompleted` (or `UnsafeOnCompleted`) on the awaiter to register the continuation, then returns control up the call stack.

The thread that was executing the method is now free to do other work. When the I/O or timer fires, the continuation is scheduled (on the captured `SynchronizationContext`, a specific `TaskScheduler`, or the thread pool) and `MoveNext()` is called again.

### The Awaitable Pattern

You can `await` anything that:
- Exposes `GetAwaiter()` returning an object with:
  - `bool IsCompleted { get; }`
  - `void OnCompleted(Action continuation)`
  - `T GetResult()`

Built-in awaitables: `Task`, `Task<T>`, `ValueTask`, `ValueTask<T>`, `IAsyncEnumerable<T>` (via `await foreach`), `YieldAwaitable` (`Task.Yield()`), `ConfiguredTaskAwaitable` (`ConfigureAwait`).

### `async void` vs `async Task`

| | `async Task` | `async void` |
|---|---|---|
| Caller can `await` | ✅ | ❌ |
| Exceptions propagate to caller | ✅ | ❌ (go to `SynchronizationContext`) |
| Can be cancelled | ✅ with `CancellationToken` | awkward |
| Use case | Everything | Event handlers **only** |

> **Rule:** Never use `async void` except for event handlers. See [async-void-pitfalls.md](./async-void-pitfalls.md).

### Synchronous Completion — The Fast Path

If the awaited `Task` is already complete when `await` is reached (common with `Task.FromResult`, cached results, or completed I/O), the state machine never suspends: `IsCompleted == true` causes `MoveNext` to fall through immediately, making the whole call synchronous with minimal overhead.

### `async` Does Not Mean "Runs on Thread Pool"

```csharp
public async Task<int> ComputeAsync()
{
    // This runs on the CALLER'S thread until the first real await
    int x = ExpensiveCpuWork();   // blocks the caller's thread!
    await Task.Delay(1);          // first suspension point
    return x;
}
```

To push CPU work off the caller's thread, use `await Task.Run(() => ExpensiveCpuWork())`. See [cpu-bound-vs-io-bound-async.md](./cpu-bound-vs-io-bound-async.md).

## Code Example

```csharp
using System;
using System.Net.Http;
using System.Threading.Tasks;

// --- Basic async/await ---
static async Task<string> FetchTitleAsync(string url)
{
    using var client = new HttpClient();
    string html = await client.GetStringAsync(url);   // non-blocking I/O wait
    int start = html.IndexOf("<title>") + 7;
    int end   = html.IndexOf("</title>", start);
    return start >= 7 && end > start ? html[start..end] : "(no title)";
}

// --- Demonstrating synchronous fast path ---
static async Task<int> MaybeAsyncAsync(bool simulate)
{
    Task<int> work = simulate
        ? Task.Delay(10).ContinueWith(_ => 42)
        : Task.FromResult(42);   // already complete

    int result = await work;     // if already complete: zero overhead, no suspension
    return result * 2;
}

// --- Chaining awaits ---
static async Task<string> OrchestratAsync()
{
    // Two sequential async operations
    int id      = await GetUserIdAsync();
    string name = await GetUserNameAsync(id);
    return $"Hello, {name}!";
}

static Task<int>    GetUserIdAsync()       => Task.FromResult(7);
static Task<string> GetUserNameAsync(int _) => Task.FromResult("Alice");

// --- Entry point ---
static async Task Main()
{
    // Both calls return Task; no thread is blocked while awaiting
    Task<int> t1 = MaybeAsyncAsync(simulate: false);
    Task<int> t2 = MaybeAsyncAsync(simulate: true);

    int[] results = await Task.WhenAll(t1, t2);
    Console.WriteLine(string.Join(", ", results));   // 84, 84

    Console.WriteLine(await OrchestratAsync());      // Hello, Alice!
}
```

## Common Follow-up Questions

- What is `SynchronizationContext` and how does it affect where a continuation resumes after `await`?
- Why does calling `.Result` or `.Wait()` on a `Task` inside an async method risk deadlock?
- When should you use `ValueTask<T>` instead of `Task<T>`?
- What does `ConfigureAwait(false)` do and when is it necessary?
- How does the compiler handle exceptions thrown inside an `async` method — where does the exception end up?

## Common Mistakes / Pitfalls

- **Thinking `async` moves work to a background thread.** It does not. The method runs synchronously until the first `await` that actually suspends. CPU-bound work still blocks the caller's thread.
- **Using `async void` outside event handlers.** Exceptions from `async void` cannot be caught at the call site — they crash the process via the `SynchronizationContext`.
- **Awaiting in a loop sequentially when calls are independent.** `for (var i...) await Fetch(i)` runs requests one-by-one. Use `Task.WhenAll` to fire them concurrently.
- **Forgetting that `await` may resume on a different thread.** If you capture thread-local state before an `await`, do not assume it is available after the continuation resumes.
- **Not propagating `CancellationToken` through the async chain.** The token must be passed to every inner awaitable; ignoring it means cancellation has no effect deeper in the call stack.

## References

- [Asynchronous programming — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/)
- [Async/Await — Best Practices in Asynchronous Programming — Stephen Cleary (MSDN)](https://learn.microsoft.com/archive/msdn-magazine/2013/march/async-await-best-practices-in-asynchronous-programming)
- [Dissecting the async machine — Sergey Tepliakov (.NET Blog)](https://devblogs.microsoft.com/premier-developer/dissecting-the-async-methods-in-c/)
- [See: configure-await-false.md](./configure-await-false.md)
- [See: synchronization-context.md](./synchronization-context.md)
- [See: task-vs-valuetask.md](./task-vs-valuetask.md)
