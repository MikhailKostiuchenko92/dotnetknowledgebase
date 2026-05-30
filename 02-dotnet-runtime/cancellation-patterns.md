# How Should Cancellation Be Modeled in .NET Async Code?

**Category:** .NET Runtime / Async/Await Internals  
**Difficulty:** Middle  
**Tags:** `cancellationtoken`, `cancellationtokensource`, `linked-tokens`, `timeouts`, `operationcanceledexception`

## Question
> How does cooperative cancellation work in .NET async code?

> What is the difference between `CancellationToken` and `CancellationTokenSource`?

> How should you pass cancellation through an async call chain, and what exceptions should you expect?

## Short Answer
.NET uses cooperative cancellation: the caller requests cancellation, and the callee decides how and when to stop. `CancellationTokenSource` owns the mutable cancel signal, while `CancellationToken` is the lightweight value passed down through APIs, usually as the last parameter. Linked token sources let one operation react to multiple cancellation reasons, such as user cancellation plus timeout. When cancellation is observed, APIs typically throw `OperationCanceledException`; `TaskCanceledException` is a more specific subclass often seen when awaiting tasks.

## Detailed Explanation
### Cancellation is a request, not a kill switch
Unlike forcibly aborting a thread, .NET cancellation is cooperative. A caller signals intent to stop, but the running operation must observe the token and exit responsibly. That design avoids corrupted state and lets code release resources cleanly.

Typical callee behaviors include:

- passing the token into cancellable framework APIs
- checking `IsCancellationRequested`
- calling `ThrowIfCancellationRequested()` at safe checkpoints
- registering a callback for cleanup or wake-up logic

> Warning: calling `Cancel()` does not guarantee the work has already stopped. It only guarantees that the token now reports a cancellation request.

### `CancellationToken` vs `CancellationTokenSource`
These two types have different responsibilities:

| Type | Responsibility | Mutable? | Typical owner |
| --- | --- | --- | --- |
| `CancellationTokenSource` | Creates and triggers cancellation | Yes | Caller/orchestrator |
| `CancellationToken` | Carries the signal to callees | No | Passed through APIs |

The source can cancel immediately with `Cancel()`, after a delay with `CancelAfter(...)`, or automatically when constructed with a timeout. The token is cheap to copy and should flow through all async layers so lower-level operations can participate.

### Linked tokens and callbacks
Real operations often have more than one reason to stop: maybe the user closed the page, the host is shutting down, or a per-request timeout elapsed. `CancellationTokenSource.CreateLinkedTokenSource(...)` lets one operation observe any of those upstream signals.

`CancellationToken.Register(callback)` attaches synchronous callbacks that run when cancellation is requested. That is useful for waking blocked components or cleaning up registrations, but it should stay lightweight because it runs during cancellation processing.

### Exceptions and timeout patterns
The canonical cancellation exception is `OperationCanceledException`. `TaskCanceledException` derives from it and is typically produced by task-related APIs. In catch blocks, treat `TaskCanceledException` as a task-specific shape of cancellation, not as a fundamentally different category.

For timeouts, the base library still models the timeout as a normal cancellation token. Teams sometimes call that a “timeout token,” but the actual BCL API remains `CancellationTokenSource(TimeSpan)` or `CancelAfter(...)`. In .NET 8, timeout-related APIs also expanded around `TimeProvider` and `WaitAsync(...)`, but the token abstraction itself is still just `CancellationToken`.

### API design convention
A well-designed async method usually accepts `CancellationToken cancellationToken = default` as its last parameter. That convention makes APIs predictable and easy to chain. If one layer ignores the token, the whole stack becomes less cancellable.

Another good guideline is to treat cancellation as part of the method contract, not as optional plumbing. If your method starts child operations, timers, or stream reads, pass the token into each one instead of only checking it once at the top. That produces faster shutdown, less wasted I/O, and more consistent behavior during timeout scenarios. This topic pairs naturally with [async-await-overview.md](./async-await-overview.md) and [task-exception-handling.md](./task-exception-handling.md).

## Code Example
```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

namespace RuntimeSamples.CancellationPatterns;

internal static class Program
{
    private static async Task Main()
    {
        using var userCts = new CancellationTokenSource();
        using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(1));
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(userCts.Token, timeoutCts.Token);

        try
        {
            string result = await DownloadAsync(linkedCts.Token);
            Console.WriteLine(result);
        }
        catch (OperationCanceledException)
        {
            Console.WriteLine("Operation canceled cooperatively.");
        }
    }

    private static async Task<string> DownloadAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.Register(() => Console.WriteLine("Cancellation requested."));

        // Pass the token through every async layer.
        await Task.Delay(2_000, cancellationToken);
        return "done";
    }
}
```

## Common Follow-up Questions
- Why is `CancellationToken` usually the last parameter in async APIs?
- When do you use `CreateLinkedTokenSource(...)`?
- What is the difference between `OperationCanceledException` and `TaskCanceledException`?
- Why is cancellation modeled cooperatively instead of aborting threads?
- How should timeout and user cancellation be combined in one operation?

## Common Mistakes / Pitfalls
- Treating cancellation like an immediate forced stop.
- Creating a token parameter but never passing it into awaited framework APIs.
- Catching `Exception` and accidentally swallowing cancellation.
- Forgetting to dispose `CancellationTokenSource` or linked token sources.
- Using expensive or blocking logic inside `CancellationToken.Register(...)` callbacks.

## References
- https://learn.microsoft.com/dotnet/api/system.threading.cancellationtoken
- https://learn.microsoft.com/dotnet/api/system.threading.cancellationtokensource
- https://learn.microsoft.com/dotnet/api/system.threading.cancellationtokensource.createlinkedtokensource
- https://learn.microsoft.com/dotnet/api/system.operationcanceledexception
- https://learn.microsoft.com/dotnet/standard/threading/cancellation-in-managed-threads