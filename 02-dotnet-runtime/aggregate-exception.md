# AggregateException in .NET

**Category:** .NET Runtime / Exceptions
**Difficulty:** 🟡 Middle
**Tags:** `AggregateException`, `Task.WhenAll`, `parallel`, `plinq`, `Flatten`, `Handle`

## Question
> What is `AggregateException`, and when does .NET throw it?

> How do `InnerException`, `InnerExceptions`, `Flatten()`, and `Handle()` work?

> Why does `await Task.WhenAll(...)` often show only one exception even if several tasks failed?

## Short Answer
`AggregateException` is the runtime’s container for multiple failures from parallel or task-based operations such as `Task.WhenAll`, `Parallel.For`, and PLINQ. `InnerException` exposes only the first contained exception, while `InnerExceptions` gives the full collection; `Flatten()` removes nested aggregates, and `Handle()` marks selected inner exceptions as handled. When you `await` a faulted task, the runtime usually rethrows one underlying exception directly, so you must inspect the task’s `Exception` property if you need the complete set.

## Detailed Explanation
### Why Aggregation Exists
In synchronous code, one call usually fails for one reason at one point in time. In parallel code, several operations may fail concurrently. The runtime needs a way to return all of them without discarding information. That is the job of `AggregateException`.

You most commonly see it from:
- `Task.Wait()` or `task.Result`
- `Parallel.For` / `Parallel.ForEach`
- PLINQ queries
- nested task coordination internals

### `InnerException` vs `InnerExceptions`
The distinction is important.

| Member | Meaning |
|---|---|
| `InnerException` | The first inner exception only |
| `InnerExceptions` | Read-only collection of all inner exceptions |
| `Flatten()` | Collapses nested `AggregateException` instances into one flat list |
| `Handle(...)` | Marks matching inner exceptions as handled; rethrows the rest |

A common bug is to log only `InnerException` and silently ignore the rest.

### Why `await` Feels Different
When you use `await`, the runtime typically unwraps the task exception and throws one original exception instead of the `AggregateException` wrapper. That makes async code feel more natural, but it also hides the fact that multiple tasks may have faulted.

For example, with `var combined = Task.WhenAll(tasks); await combined;`, the `await` may surface one exception, but `combined.Exception` still holds an `AggregateException` containing all failures. So the information is not destroyed; it is just not what the `await` statement throws by default.

> **Warning:** If you care about every failure from `Task.WhenAll`, keep a reference to the combined task and inspect `combined.Exception?.InnerExceptions` in the catch path.

### `Flatten()` and Nested Aggregates
Some parallel APIs can produce nested aggregates, especially when child tasks or composed operations each wrap their own failures. `Flatten()` recursively walks those layers and returns a single `AggregateException` whose `InnerExceptions` collection contains only non-aggregate exceptions.

This makes logging, filtering, and policy handling much simpler.

### `Handle()` Pattern
`Handle(Func<Exception, bool>)` is useful when some exception types are expected and can be ignored or converted into partial success. The delegate runs for each inner exception. If it returns `true`, that exception is considered handled. If any remain unhandled, the method throws a new `AggregateException` containing only those leftovers.

Use it sparingly. It is best when you have a very explicit policy, such as “ignore cancellation, but fail on everything else.”

### Interview Rule of Thumb
In synchronous waits (`Wait`, `Result`) expect `AggregateException`. In `await`-based code, expect one unwrapped exception unless you explicitly inspect the original task. That difference is the source of many interview questions.

Related: [Task Exception Handling](./task-exception-handling.md) and [Parallel & PLINQ](./parallel-and-plinq.md).

## Code Example
```csharp
namespace DotNetRuntimeExamples;

public static class AggregateExceptionDemo
{
    public static async Task RunAsync()
    {
        var combined = Task.WhenAll(
            Task.Run(() => throw new InvalidOperationException("First failure")),
            Task.Run(() => throw new IOException("Second failure")));

        try
        {
            await combined; // Typically rethrows one underlying exception.
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Await surfaced: {ex.GetType().Name}");

            foreach (var inner in combined.Exception?.Flatten().InnerExceptions ?? [])
            {
                Console.WriteLine($"Contained: {inner.GetType().Name} - {inner.Message}");
            }
        }
    }

    public static void HandleKnownFailures(AggregateException aggregate)
    {
        aggregate.Handle(ex => ex is OperationCanceledException); // Ignore only cancellations.
    }
}
```

## Common Follow-up Questions
- Why does `await` not usually throw `AggregateException` directly?
- When should I inspect `task.Exception` after `Task.WhenAll`?
- What kinds of APIs produce nested `AggregateException` instances?
- When is `Handle()` appropriate versus normal catch logic?
- Why is looking only at `InnerException` dangerous?

## Common Mistakes / Pitfalls
- Logging only `InnerException` and missing additional failures.
- Assuming `await Task.WhenAll` exposes every exception automatically.
- Forgetting to call `Flatten()` when nested aggregates are possible.
- Using `Handle()` to swallow exceptions too broadly.
- Mixing `Wait()`/`.Result` and `await` without understanding the different exception surfaces.

## References
- [AggregateException class](https://learn.microsoft.com/dotnet/api/system.aggregateexception)
- [Exception handling (Task Parallel Library)](https://learn.microsoft.com/dotnet/standard/parallel-programming/exception-handling-task-parallel-library)
- [Task.WhenAll](https://learn.microsoft.com/dotnet/api/system.threading.tasks.task.whenall)
- [Parallel LINQ (PLINQ)](https://learn.microsoft.com/dotnet/standard/parallel-programming/introduction-to-plinq)
