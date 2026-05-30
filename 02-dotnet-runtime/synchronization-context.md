# What Is SynchronizationContext in .NET?

**Category:** .NET Runtime / Threading Model  
**Difficulty:** Middle  
**Tags:** `async`, `await`, `synchronizationcontext`, `configureawait`, `ui-thread`

## Question
> What does `SynchronizationContext` do in .NET, and why does it matter for `await`?
>
> How is `SynchronizationContext` different in WinForms, WPF, ASP.NET Classic, and ASP.NET Core?
>
> Why does `ConfigureAwait(false)` help avoid deadlocks in library code?

## Short Answer
`SynchronizationContext` is an abstraction that knows how to marshal work back onto an environment-specific execution context, such as a UI thread or an ASP.NET Classic request context. By default, `await` captures `SynchronizationContext.Current` when it suspends, and later posts the continuation back there; if no synchronization context exists, it falls back to the current `TaskScheduler`. ASP.NET Core intentionally has no custom `SynchronizationContext`, which removes a major class of deadlocks that used to happen when code blocked on async work in UI apps or ASP.NET Classic.

## Detailed Explanation
### What `SynchronizationContext` represents
`SynchronizationContext` is not a thread itself and not a scheduler implementation like the ThreadPool. It is a small abstraction with operations such as `Post` and `Send` that say, “run this delegate in whatever environment-specific way is correct here.” The environment decides what “correct” means.

For a UI app, correct usually means “back on the one UI thread that owns controls.” For ASP.NET Classic, it meant “back onto the request context so code runs one piece at a time for that request.” In a plain console app or ASP.NET Core request, there is usually no special context, so `SynchronizationContext.Current` is `null`.

### How `await` uses it
When an `await` sees an incomplete awaitable, the generated async state machine captures the current continuation target before returning to its caller. The rough rule is:

1. Capture `SynchronizationContext.Current` if it is non-null.
2. Otherwise capture `TaskScheduler.Current`.
3. When the awaited operation completes, schedule the continuation there.

That behavior is convenient for application code. In WinForms and WPF, it means you can `await` and then safely update controls without manually dispatching back to the UI thread.

> The capture happens at the `await`, not at method entry. If the context changes before a later `await`, the later continuation may capture something different.

### Environment differences

| Environment | `SynchronizationContext.Current` | Practical effect |
| --- | --- | --- |
| WinForms | `WindowsFormsSynchronizationContext` | Continuations return to the UI thread |
| WPF | `DispatcherSynchronizationContext` | Continuations return to the dispatcher thread |
| ASP.NET Classic | `AspNetSynchronizationContext` | Request code resumes in the request context, one active thread at a time |
| ASP.NET Core | Usually `null` | Continuations resume on ThreadPool threads; no request-affine sync context |
| Console / Worker service | Usually `null` | No special marshalling unless you install one |

ASP.NET Classic is the historical source of many interview questions. Blocking with `.Result` or `.Wait()` could deadlock because the calling thread held the request context while the async continuation was trying to post back into that same context. UI deadlocks follow the same pattern.

### Why `ConfigureAwait(false)` matters
`ConfigureAwait(false)` tells the awaiter not to capture the current synchronization context for that await. In library code, that is usually desirable because libraries should not assume they must resume on the caller's UI or request context. Skipping capture reduces overhead and avoids contributing to deadlock scenarios when callers unfortunately block.

That is why the common guidance is: application code may need context capture, but general-purpose library code should usually use `ConfigureAwait(false)` unless it explicitly depends on a captured context.

> `ConfigureAwait(false)` does not make code “more asynchronous.” It only changes where the continuation runs after the awaited operation completes.

### `TaskScheduler` fallback and ASP.NET Core
If `SynchronizationContext.Current` is `null`, `await` can still observe `TaskScheduler.Current`. For most code, that means the default ThreadPool scheduler. In ASP.NET Core, there is no special request scheduler or request synchronization context, so continuations usually resume on whatever ThreadPool thread is available. That design improves scalability and avoids the old ASP.NET Classic deadlock trap.

For related topics, see [ConfigureAwait](./configureawait.md) and [Deadlock in Async Code](./deadlock-in-async.md).

## Code Example
```csharp
using System.Collections.Concurrent;

namespace RuntimeSamples.SynchronizationContextDemo;

internal static class Program
{
    public static async Task Main()
    {
        using var context = new SingleThreadSynchronizationContext();
        SynchronizationContext.SetSynchronizationContext(context);

        var messageLoop = context.RunAsync(); // Processes posted continuations on one dedicated thread.

        Console.WriteLine($"Main thread before await: {Environment.CurrentManagedThreadId}");

        await DemonstrateCaptureAsync();
        await DemonstrateNoCaptureAsync();

        context.Complete();
        await messageLoop;
    }

    private static async Task DemonstrateCaptureAsync()
    {
        Console.WriteLine($"Capture demo start: {Environment.CurrentManagedThreadId}");
        await Task.Delay(50); // Captures the current SynchronizationContext.
        Console.WriteLine($"Capture demo continuation: {Environment.CurrentManagedThreadId}");
    }

    private static async Task DemonstrateNoCaptureAsync()
    {
        Console.WriteLine($"No-capture demo start: {Environment.CurrentManagedThreadId}");
        await Task.Delay(50).ConfigureAwait(false); // Skips context capture.
        Console.WriteLine($"No-capture demo continuation: {Environment.CurrentManagedThreadId}");
    }
}

internal sealed class SingleThreadSynchronizationContext : SynchronizationContext, IDisposable
{
    private readonly BlockingCollection<(SendOrPostCallback Callback, object? State)> _queue = new();
    private readonly Thread _thread;

    public SingleThreadSynchronizationContext()
    {
        _thread = new Thread(ProcessQueue) { IsBackground = true, Name = "SyncContextThread" };
        _thread.Start();
    }

    public override void Post(SendOrPostCallback d, object? state) => _queue.Add((d, state));

    public Task RunAsync() => Task.CompletedTask; // Thread already started in the constructor.

    public void Complete() => _queue.CompleteAdding();

    private void ProcessQueue()
    {
        SetSynchronizationContext(this); // Continuations posted here run on this dedicated thread.

        foreach (var (callback, state) in _queue.GetConsumingEnumerable())
        {
            callback(state);
        }
    }

    public void Dispose()
    {
        Complete();
        _queue.Dispose();
    }
}
```

## Common Follow-up Questions
- Does `await` always capture `SynchronizationContext.Current`?
- What happens when `SynchronizationContext.Current` is `null`?
- Why did ASP.NET Core remove the old ASP.NET synchronization context model?
- Is the ASP.NET Classic request context always the exact same physical thread?
- When should application code intentionally keep the captured context?
- How is `ExecutionContext` different from `SynchronizationContext`?

## Common Mistakes / Pitfalls
- Thinking `SynchronizationContext` is identical to a thread rather than a marshalling abstraction.
- Assuming ASP.NET Core behaves like ASP.NET Classic for async continuation affinity.
- Calling `.Result` or `.Wait()` on async code in UI or ASP.NET Classic code paths.
- Using `ConfigureAwait(false)` in code that must update UI controls afterward.
- Forgetting that `await` can also fall back to `TaskScheduler.Current` when no synchronization context exists.

## References
- https://learn.microsoft.com/dotnet/api/system.threading.synchronizationcontext
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/
- https://devblogs.microsoft.com/dotnet/configureawait-faq/
- https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel
