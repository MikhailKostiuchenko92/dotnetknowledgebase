# When Would You Use `TaskCompletionSource<T>`?

**Category:** .NET Runtime / Async/Await Internals  
**Difficulty:** Middle  
**Tags:** `taskcompletionsource`, `tap`, `callbacks`, `runcontinuationsasynchronously`, `ivalueTaskSource`

## Question
> What is `TaskCompletionSource<T>` and why would you use it?

> How do you wrap a callback-based API into a `Task<T>`-based API?

> What is the difference between `SetResult` and `TrySetResult`, and why does `RunContinuationsAsynchronously` matter?

## Short Answer
`TaskCompletionSource<T>` lets you manually control the completion of a `Task<T>` instead of relying on an `async` method body to do it automatically. It is commonly used as a bridge when adapting callback-based, event-based, or legacy APM-style APIs into the Task-based Asynchronous Pattern. `SetResult`, `SetException`, and `SetCanceled` complete the task exactly once; the `TrySet...` variants are safer when cancellation, timeout, or multiple callbacks may race. `TaskCreationOptions.RunContinuationsAsynchronously` is important because it prevents downstream continuations from running inline on the thread that calls `SetResult`.

## Detailed Explanation
### Manual completion instead of compiler-generated completion
Normally, an `async Task<T>` method completes when control reaches `return` or throws. `TaskCompletionSource<T>` exists for cases where completion is driven by something external: a callback, an event, a timer, a socket notification, or a custom state machine.

In other words, `TaskCompletionSource<T>` separates two things:

- the consumer-facing `Task<T>`
- the producer-side authority to signal completion

That makes it a foundational interoperability tool.

### The classic bridge pattern
Legacy .NET APIs often signal completion through callbacks or events. Modern code wants `await`. `TaskCompletionSource<T>` is the bridge between those worlds.

| Scenario | Without `TaskCompletionSource<T>` | With `TaskCompletionSource<T>` |
| --- | --- | --- |
| Callback-based API | Nested callbacks | `await`-friendly wrapper |
| Event-based completion | Manual event plumbing | Task completes from event handler |
| Competing completion paths | Lots of flags/locking | `TrySet...` race-safe completion |

This is especially useful when migrating APM (`Begin`/`End`) or EAP-style APIs into TAP.

### `Set...` versus `TrySet...`
A `TaskCompletionSource<T>` can only transition once. After it completes, further completion attempts are invalid.

- `SetResult`, `SetException`, `SetCanceled` throw if the task was already completed
- `TrySetResult`, `TrySetException`, `TrySetCanceled` return `false` instead

If multiple things might win the race—callback success, timeout, cancellation, disconnect—prefer the `TrySet...` methods. They make shutdown logic predictable and avoid secondary exceptions during cleanup.

### Why `RunContinuationsAsynchronously` matters
By default, a continuation awaiting the task may run inline when the TCS is completed. That can be dangerous if completion happens under a lock, on an I/O callback thread, or on a thread that must stay responsive.

`TaskCreationOptions.RunContinuationsAsynchronously` tells the runtime to queue continuations instead of executing them inline on the `SetResult` caller. That avoids surprising reentrancy and lock inversions.

> Warning: using a bare `TaskCompletionSource<T>` inside locks or callback threads can cause subtle latency and reentrancy bugs if continuations run inline.

### `IValueTaskSource<T>` is the lower-allocation cousin
For very hot runtime paths, `IValueTaskSource<T>` provides similar manual completion semantics for `ValueTask<T>` with reusable pooled backing objects. It is more efficient but much harder to implement correctly. Most application code should use `TaskCompletionSource<T>` and only study `IValueTaskSource<T>` after [task-and-valuetask.md](./task-and-valuetask.md) and [async-await-overview.md](./async-await-overview.md).

One more practical point: a TCS wrapper should usually also handle cleanup. If you subscribe to an event, unsubscribe when the task completes. If you register cancellation, dispose that registration. If a callback can fire more than once, guard completion with `TrySet...`. These wrappers also need to think about timeouts, shutdown paths, and duplicate callbacks. Those details are what separate a robust bridge from a wrapper that leaks handlers or occasionally throws under race conditions.

## Code Example
```csharp
using System;
using System.Threading;
using System.Threading.Tasks;

namespace RuntimeSamples.TaskCompletionSourceDemo;

internal static class Program
{
    private static async Task Main()
    {
        var legacy = new LegacyCalculator();
        int sum = await AddAsync(legacy, 20, 22, CancellationToken.None);
        Console.WriteLine(sum);
    }

    private static async Task<int> AddAsync(
        LegacyCalculator calculator,
        int left,
        int right,
        CancellationToken cancellationToken)
    {
        var tcs = new TaskCompletionSource<int>(TaskCreationOptions.RunContinuationsAsynchronously);

        using CancellationTokenRegistration registration =
            cancellationToken.Register(() => tcs.TrySetCanceled(cancellationToken));

        calculator.BeginAdd(
            left,
            right,
            result => tcs.TrySetResult(result),
            error => tcs.TrySetException(error));

        return await tcs.Task;
    }
}

internal sealed class LegacyCalculator
{
    public void BeginAdd(int left, int right, Action<int> onSuccess, Action<Exception> onError)
    {
        ThreadPool.QueueUserWorkItem(_ =>
        {
            try
            {
                onSuccess(left + right);
            }
            catch (Exception ex)
            {
                onError(ex);
            }
        });
    }
}
```

## Common Follow-up Questions
- What kinds of legacy APIs are good candidates for `TaskCompletionSource<T>` wrappers?
- Why are `TrySetResult` and friends safer than `SetResult` in race-prone code?
- What problems does `RunContinuationsAsynchronously` prevent?
- When should I use `TaskCompletionSource<T>` versus an ordinary `async` method?
- How does `IValueTaskSource<T>` relate to this pattern?

## Common Mistakes / Pitfalls
- Completing the same `TaskCompletionSource<T>` from multiple code paths with `Set...` and causing secondary exceptions.
- Forgetting to handle cancellation or timeout when wrapping long-running external operations.
- Completing the TCS while holding a lock and allowing inline continuations to re-enter unexpectedly.
- Not unsubscribing from events after the task completes when using event-based wrappers.
- Using TCS for simple async logic that should just be an `async` method.

## References
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.taskcompletionsource-1
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.taskcreationoptions
- https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/task-based-asynchronous-pattern-tap
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.sources.ivaluetasksource-1
- https://devblogs.microsoft.com/dotnet/the-nature-of-taskcompletionsourcetresult/