# SynchronizationContext

**Category:** C# / Async / Tasks
**Difficulty:** Senior
**Tags:** `SynchronizationContext`, `async`, `await`, `WPF`, `ASP.NET`, `continuation`

## Question

> What is `SynchronizationContext` and how does it affect where `async`/`await` continuations run? How does it differ between ASP.NET classic, ASP.NET Core, WPF, and console applications?

Also asked as:
- "Why does the same `async` code behave differently in WPF versus ASP.NET Core?"
- "What does 'capturing the synchronization context' mean at the `await` point?"

## Short Answer

`SynchronizationContext` is an abstraction that controls how code is scheduled for execution in a particular environment — the UI thread in WPF/WinForms, a thread-bound request context in classic ASP.NET, or no special scheduling in ASP.NET Core (where it's `null`). When an `async` method hits an `await`, it captures `SynchronizationContext.Current`. When the awaited operation completes, the continuation is **posted** back to that context, which ensures UI updates happen on the UI thread and classic ASP.NET request state is available after the await. ASP.NET Core removes this context entirely, freeing continuations to run on any thread pool thread.

## Detailed Explanation

### The Role of `SynchronizationContext`

The `await` machinery calls `SynchronizationContext.Current?.Post(continuation, null)` to schedule the continuation when the awaited operation finishes. If `Current` is `null`, the continuation is queued directly to the thread pool.

```
await point captured: SC = SynchronizationContext.Current

operation completes (thread pool) →
  if SC != null  → SC.Post(continuation) → runs on SC-specific thread
  if SC == null  → ThreadPool.QueueUserWorkItem(continuation)
```

Each environment installs a different subclass:

| Environment | `SynchronizationContext` type | Behavior |
|---|---|---|
| WPF / WinForms | `DispatcherSynchronizationContext` / `WindowsFormsSynchronizationContext` | `Post` marshals to the UI thread via the message pump |
| ASP.NET (classic, .NET Framework) | `AspNetSynchronizationContext` | Ensures at most one piece of async code runs per request at a time; restores `HttpContext.Current` |
| ASP.NET Core | **`null`** | No context installed; continuations run on any thread pool thread |
| Console / test runners | `null` (default) or custom | Usually `null`; some test frameworks install their own |
| `Task.Run` lambda body | `null` (cleared on pool threads) | Intentionally no context inside `Task.Run` |

### WPF — Single-Threaded Dispatcher

The WPF `Dispatcher` owns the UI thread. Any access to a `DependencyObject` from another thread throws `InvalidOperationException`. `DispatcherSynchronizationContext.Post` puts the callback on the dispatcher queue:

```csharp
// WPF event handler — continuation correctly returns to UI thread
private async void Button_Click(object sender, RoutedEventArgs e)
{
    string data = await LoadDataAsync();   // captures DispatcherSynchronizationContext
    TextBox.Text = data;                   // ✅ runs on UI thread after resume
}
```

If `LoadDataAsync` uses `ConfigureAwait(false)` internally, its continuations run on thread pool. But the **button click handler** itself, having captured the dispatcher context at its own `await`, still resumes on the UI thread.

### Classic ASP.NET — `AspNetSynchronizationContext`

Classic ASP.NET's context:
- Ensures only one thread runs per request at a time (single-threaded semantics for `HttpContext.Current`, session state, etc.).
- This is the source of the classic `.Result`/`.Wait()` deadlock: the blocked thread holds the context; the continuation tries to re-enter the same context. See [deadlocks-with-result-and-wait.md](./deadlocks-with-result-and-wait.md).

### ASP.NET Core — No Context

ASP.NET Core's request pipeline runs entirely on thread pool threads with **no `SynchronizationContext`**. All ASP.NET Core services that need per-request state (e.g., `HttpContext`, `IHttpContextAccessor`, scoped DI services) use `AsyncLocal<T>` under the hood — values that flow with the async execution context, not via the `SynchronizationContext`.

This eliminates the classic deadlock and removes the overhead of context switching, at the cost of losing the "return to original thread" guarantee.

### `ExecutionContext` vs `SynchronizationContext`

These are often confused:

| | `SynchronizationContext` | `ExecutionContext` |
|---|---|---|
| Purpose | Scheduling model (which thread/queue) | Ambient data flow (`AsyncLocal<T>`, security, culture) |
| Flows across `await`? | Captured at await, resumed on it | Always flows (suppressed only explicitly) |
| Populated by | Environment (WPF, ASP.NET) | CLR always maintains it |
| `AsyncLocal<T>` | Not involved | Stored here |

`ConfigureAwait(false)` skips `SynchronizationContext` capture but **never suppresses `ExecutionContext` flow**. `HttpContext.User`, `ILogger` scope data, and `CancellationToken` registrations all flow correctly even after `ConfigureAwait(false)`.

### Installing a Custom `SynchronizationContext`

```csharp
SynchronizationContext.SetSynchronizationContext(new MyContext());
try
{
    await SomeWorkAsync();   // continuations posted via MyContext
}
finally
{
    SynchronizationContext.SetSynchronizationContext(null);
}
```

Test frameworks (xUnit, NUnit) sometimes install custom contexts to marshal test continuations or enforce single-threaded execution in specific tests.

## Code Example

```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

// --- Observing context capture ---
static async Task DemoContextAsync()
{
    Console.WriteLine($"[1] SC: {SynchronizationContext.Current?.GetType().Name ?? "null"}, " +
                      $"Thread: {Thread.CurrentThread.ManagedThreadId}");

    await Task.Delay(10);   // suspends; continuation scheduled via captured SC (or pool)

    Console.WriteLine($"[2] SC: {SynchronizationContext.Current?.GetType().Name ?? "null"}, " +
                      $"Thread: {Thread.CurrentThread.ManagedThreadId}");
}

// In a console app (no SC): [1] null/T1  →  [2] null/T2  (different threads, no marshalling)
// In WPF (button click):   [1] DispatcherSC/T1  →  [2] DispatcherSC/T1  (same UI thread)

// --- ConfigureAwait(false) breaks context capture ---
static async Task DemoConfigureAwaitAsync()
{
    Console.WriteLine($"[1] Thread: {Thread.CurrentThread.ManagedThreadId}");

    await Task.Delay(10).ConfigureAwait(false);   // explicitly ignores SC

    Console.WriteLine($"[2] Thread: {Thread.CurrentThread.ManagedThreadId}");
    // In WPF: [2] is now a DIFFERENT thread (pool thread), not the UI thread!
    // Accessing UI controls here would throw InvalidOperationException
}

// --- AsyncLocal flows regardless of ConfigureAwait ---
static readonly AsyncLocal<string> _requestId = new();

static async Task DemoAsyncLocalAsync()
{
    _requestId.Value = "req-123";

    await Task.Delay(10).ConfigureAwait(false);   // no SC capture

    Console.WriteLine(_requestId.Value);           // "req-123" — AsyncLocal still flows ✅
}

// --- Console entry point ---
await DemoContextAsync();
await DemoAsyncLocalAsync();
```

## Common Follow-up Questions

- How do xUnit and NUnit use custom `SynchronizationContext` to support async test methods?
- Why does `Task.Run` clear `SynchronizationContext.Current` inside its body?
- How does `IAsyncEnumerable<T>` / `await foreach` interact with `SynchronizationContext`?
- What happens to `SynchronizationContext` when you use `Parallel.ForEachAsync`?
- How does Blazor's `ComponentBase.InvokeAsync` use `SynchronizationContext` to marshal to the render thread?

## Common Mistakes / Pitfalls

- **Using `Thread.CurrentThread` identity to pass data across awaits.** After resuming on the UI thread via SC, it's the same thread — but in ASP.NET Core, it may not be. Never pass request state via thread-local storage in async code; use `AsyncLocal<T>` or DI.
- **Forgetting that `ConfigureAwait(false)` changes which thread you're on after the await.** In WPF, continuing UI work on a thread pool thread causes `InvalidOperationException`. Reserve `ConfigureAwait(false)` for library operations with no subsequent UI interaction.
- **Assuming `HttpContext.Current` is available after an await in classic ASP.NET.** If any awaited call uses `ConfigureAwait(false)`, `HttpContext.Current` may be `null` after the continuation because `AspNetSynchronizationContext` wasn't re-entered. This is one of the strongest reasons to use `ConfigureAwait(false)` consistently in library code — but app code should *not* use it if it relies on `HttpContext.Current`.
- **Installing a custom `SynchronizationContext` without restoring it.** Not restoring in a `finally` block leaves the thread in the wrong context, affecting subsequent async work on the same thread.
- **Expecting `.Result` to be safe because there's no `SynchronizationContext` in ASP.NET Core.** While the deadlock from the classic `AspNetSynchronizationContext` doesn't occur, `.Result` still blocks a thread pool thread — which can cause thread pool starvation under load.

## References

- [SynchronizationContext — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.threading.synchronizationcontext)
- [It's All About the SynchronizationContext — Stephen Cleary (MSDN)](https://learn.microsoft.com/archive/msdn-magazine/2011/february/msdn-magazine-parallel-computing-it-s-all-about-the-synchronizationcontext)
- [ExecutionContext vs SynchronizationContext — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/pfxteam/executioncontext-vs-synchronizationcontext/)
- [ConfigureAwait FAQ — Stephen Toub (.NET Blog)](https://devblogs.microsoft.com/dotnet/configureawait-faq/)
- [See: async-await-fundamentals.md](./async-await-fundamentals.md)
- [See: configure-await-false.md](./configure-await-false.md)
- [See: deadlocks-with-result-and-wait.md](./deadlocks-with-result-and-wait.md)
