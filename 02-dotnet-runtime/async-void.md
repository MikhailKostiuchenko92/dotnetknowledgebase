# Why Is `async void` Dangerous?

**Category:** .NET Runtime / Async/Await Internals  
**Difficulty:** Middle  
**Tags:** `async-void`, `exceptions`, `fire-and-forget`, `event-handlers`, `testing`

## Question
> Why is `async void` considered dangerous in C#?

> When is `async void` acceptable, and when should you return `Task` instead?

> Why can't callers catch exceptions from an `async void` method?

## Short Answer
`async void` is dangerous because it gives the caller no `Task` to await, observe, or compose. Exceptions do not flow back to the caller through a returned task; instead they are raised to the current `SynchronizationContext` or treated as unhandled. That makes error handling, cancellation, and testing much harder. In practice, the only broadly legitimate use case is event handlers whose delegate signature requires `void`.

## Detailed Explanation
### Why the caller loses control
An `async Task` method returns a `Task` object that represents completion, failure, or cancellation. That task is what lets the caller `await`, attach continuations, combine operations, or catch asynchronous exceptions in a normal `try`/`catch` around `await`.

`async void` removes that control surface. The method still runs asynchronously, but there is no object for the caller to observe. As a result:

- the caller cannot await completion
- the caller cannot know when work finished
- the caller cannot compose it with `WhenAll` or timeouts
- the caller cannot catch exceptions through a normal `await`

| Return type | Awaitable by caller | Exceptions stored for caller? | Good default? |
| --- | --- | --- | --- |
| `Task` | Yes | Yes | Yes |
| `Task<T>` | Yes | Yes | Yes |
| `ValueTask<T>` | Yes | Yes | Specialized |
| `void` | No | No | Only for event handlers |

### Exception behavior is the real problem
If an `async Task` method throws after an `await`, the exception is stored on the task and rethrown when the caller awaits it. With `async void`, there is no returned task, so the exception is instead posted to the current `SynchronizationContext` or escalated as an unhandled exception.

That means this does **not** work reliably:

```csharp
try
{
    DangerousAsyncVoid();
}
catch
{
    // Usually will not catch exceptions thrown after an await.
}
```

The call returns immediately, and the exception happens later on a continuation.

> Warning: `async void` is effectively fire-and-forget from the caller's perspective. If it fails, the failure often escapes normal application control flow.

### The one normal use case: event handlers
UI and event patterns often require `void`-returning delegates, such as `EventHandler` or `RoutedEventHandler`. In that one case, `async void` is appropriate because the signature is imposed externally.

Even there, the handler should catch and log its own exceptions if failure matters. A good pattern is to keep the event handler thin and move real logic into an `async Task` method that can be tested independently.

### Safer fire-and-forget alternatives
If you truly need background work, prefer explicit fire-and-forget patterns such as:

- `_ = RunAsync();` where `RunAsync` handles its own exceptions internally
- `Task.Run(...)` for CPU-bound offloading plus explicit exception logging
- a hosted background service or queue for durable application work

These alternatives make the design intent explicit. They do not make lost exceptions impossible, but they are much safer than exposing `async void` APIs. For related behavior, see [async-await-overview.md](./async-await-overview.md) and [task-exception-handling.md](./task-exception-handling.md).

### Testing is awkward
Most test frameworks understand `Task`-returning methods. They can await them and fail the test when the task faults. `async void` does not fit that model, so frameworks need custom `SynchronizationContext` tricks to detect completion and exceptions. That is why production code and test helpers should almost always prefer `Task`.

## Code Example
```csharp
using System;
using System.Threading.Tasks;

namespace RuntimeSamples.AsyncVoid;

internal static class Program
{
    private static async Task Main()
    {
        var notifier = new Notifier();
        notifier.Tick += OnTickAsync; // Event handlers are the legitimate `async void` case.

        notifier.RaiseTick();
        StartBackgroundRefresh();

        await Task.Delay(200); // Keep the demo alive long enough to observe output.
    }

    private static async void OnTickAsync(object? sender, EventArgs e)
    {
        try
        {
            await Task.Delay(50);
            Console.WriteLine("Handled event asynchronously.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Event handler failed: {ex.Message}");
        }
    }

    private static void StartBackgroundRefresh()
    {
        _ = RefreshCacheAsync(); // Fire-and-forget, but the async method handles its own failures.
    }

    private static async Task RefreshCacheAsync()
    {
        try
        {
            await Task.Delay(50);
            Console.WriteLine("Background refresh finished safely.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Background refresh failed: {ex.Message}");
        }
    }
}

internal sealed class Notifier
{
    public event EventHandler? Tick;

    public void RaiseTick() => Tick?.Invoke(this, EventArgs.Empty);
}
```

## Common Follow-up Questions
- Why can't a caller await or catch failures from `async void`?
- Why are event handlers the main exception to the “never use `async void`” rule?
- What is a safe fire-and-forget pattern if I really need one?
- How do test frameworks treat `async Task` versus `async void`?
- What happens to `async void` exceptions in a UI application?

## Common Mistakes / Pitfalls
- Exposing `async void` from services, repositories, controllers, or libraries.
- Wrapping a call to `async void` in `try`/`catch` and assuming it handles asynchronous failures.
- Using `async void` just to avoid changing a method signature to `Task`.
- Starting fire-and-forget work without internal exception logging or supervision.
- Writing unit tests against `async void` methods instead of extracting `Task`-returning logic.

## References
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-return-types
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.task
- https://learn.microsoft.com/dotnet/api/system.threading.synchronizationcontext
- https://devblogs.microsoft.com/dotnet/asyncawait-faq/