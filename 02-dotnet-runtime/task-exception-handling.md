# How Are Exceptions Handled with `Task` and `await`?

**Category:** .NET Runtime / Async/Await Internals  
**Difficulty:** Middle  
**Tags:** `task-exceptions`, `aggregateexception`, `whenall`, `unobservedtaskexception`, `exceptiondispatchinfo`

## Question
> How do exceptions behave differently with `await` versus `.Result` or `.Wait()`?

> What happens when multiple tasks fail inside `Task.WhenAll`?

> What is `UnobservedTaskException`, and why should tasks always be awaited?

## Short Answer
When you `await` a faulted task, C# rethrows the underlying exception rather than surfacing an `AggregateException` wrapper. In contrast, blocking APIs such as `.Result` and `.Wait()` expose `AggregateException`, which is one reason async code should stay async end-to-end. `Task.WhenAll` captures all failures; on `await`, the first exception is rethrown while the aggregate remains available on the task's `Exception` property. A faulted task that is never awaited can eventually trigger `TaskScheduler.UnobservedTaskException` during garbage collection.

## Detailed Explanation
### `await` versus blocking waits
A `Task` represents completion, result, cancellation, or failure. If that task faults, the exception is stored on the task object. The way you consume the task determines how the exception is surfaced.

| Consumption style | What caller sees | Why it matters |
| --- | --- | --- |
| `await task` | Original exception rethrown | Cleaner async flow |
| `task.Result` | `AggregateException` | Blocking + wrapper |
| `task.Wait()` | `AggregateException` | Blocking + wrapper |
| `Task.WhenAll(...)` then `await` | First exception rethrown, all stored on task | Need to inspect aggregate for full list |

`await` gives the most natural behavior because it unwraps the fault and preserves async control flow. `.Result`, `.Wait()`, and `GetAwaiter().GetResult()` are fundamentally different because they synchronously block the current thread.

### `AggregateException` and `Task.WhenAll`
`AggregateException` exists because parallel work may fail in more than one place at once. If three child tasks fault, there is no single “the” exception object representing the whole group. `Task.WhenAll` captures all of them.

When you `await` the `WhenAll` task, the runtime rethrows one exception for ergonomic reasons, but the aggregate is still available via `whenAllTask.Exception`. Good interview answers mention both facts: `await` is convenient, but if you need the full failure set, inspect the aggregate.

### Unobserved exceptions
If a task faults and nobody ever awaits it, reads `Exception`, or otherwise observes the failure, the exception can remain stored until the task becomes unreachable and gets finalized. At that point the runtime may raise `TaskScheduler.UnobservedTaskException`.

Modern .NET no longer tears down the process by default for those exceptions, but they are still a correctness smell. An unobserved task usually means lost work, lost telemetry, or silent data corruption risk.

> Warning: fire-and-forget work without explicit exception handling is not “harmless background work.” It is often just hidden failure.

### Preserving stack traces on rethrow
If you need to capture an exception and rethrow it later, use `ExceptionDispatchInfo.Capture(ex).Throw()`. That preserves the original stack trace instead of making it look like the exception originated at the later rethrow site.

This is especially useful in infrastructure code, task wrappers, or custom schedulers.

### Best practices
The simplest rule is still the best one: always await tasks unless you have a deliberate fire-and-forget strategy with logging and error handling. If multiple tasks may fail, keep a reference to the combined task so you can inspect `Exception.InnerExceptions` after the await. If you must translate exceptions across layers, preserve the stack trace instead of wrapping blindly. This topic pairs with [async-await-overview.md](./async-await-overview.md) and future coverage of [aggregate-exception.md](./aggregate-exception.md).

## Code Example
```csharp
using System;
using System.Runtime.ExceptionServices;
using System.Threading.Tasks;

namespace RuntimeSamples.TaskExceptionHandling;

internal static class Program
{
    private static async Task Main()
    {
        Task first = Task.Run(() => throw new InvalidOperationException("First failure"));
        Task second = Task.Run(() => throw new ApplicationException("Second failure"));
        Task all = Task.WhenAll(first, second);

        try
        {
            await all;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Await rethrew: {ex.GetType().Name} - {ex.Message}");

            if (all.Exception is AggregateException aggregate)
            {
                foreach (Exception inner in aggregate.InnerExceptions)
                {
                    Console.WriteLine($"Captured inner: {inner.Message}");
                }
            }
        }

        try
        {
            throw new InvalidOperationException("Original stack trace example");
        }
        catch (Exception ex)
        {
            try
            {
                ExceptionDispatchInfo.Capture(ex).Throw(); // Preserves the original throw site.
            }
            catch (Exception preserved)
            {
                Console.WriteLine($"Preserved: {preserved.GetType().Name}");
            }
        }
    }
}
```

## Common Follow-up Questions
- Why does `await` usually feel nicer than `.Result` or `.Wait()` for exception handling?
- How do you inspect all failures from `Task.WhenAll`?
- What is `UnobservedTaskException`, and does it still crash modern .NET processes?
- When would you use `ExceptionDispatchInfo.Capture(...).Throw()`?
- Why is `GetAwaiter().GetResult()` not the same as `await`?

## Common Mistakes / Pitfalls
- Assuming `await Task.WhenAll(...)` exposes every exception directly in the caught variable.
- Blocking on tasks with `.Result` or `.Wait()` in async-capable code paths.
- Starting fire-and-forget tasks and never logging or observing failures.
- Rethrowing with `throw ex;` and destroying the original stack trace.
- Catching `Exception` and accidentally swallowing `OperationCanceledException` together with real faults.

## References
- https://learn.microsoft.com/dotnet/standard/parallel-programming/exception-handling-task-parallel-library
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.task.whenall
- https://learn.microsoft.com/dotnet/api/system.threading.tasks.taskscheduler.unobservedtaskexception
- https://learn.microsoft.com/dotnet/api/system.runtime.exceptionservices.exceptiondispatchinfo
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios