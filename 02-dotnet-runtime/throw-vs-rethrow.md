# Throw vs Rethrow in .NET

**Category:** .NET Runtime / Exceptions
**Difficulty:** 🟢 Junior
**Tags:** `throw`, `rethrow`, `stack-trace`, `ExceptionDispatchInfo`, `AggregateException`

## Question
> What is the difference between `throw;` and `throw ex;` in C#?

> Why does `throw ex;` lose part of the stack trace?

> How should you rethrow exceptions across async or task boundaries?

## Short Answer
Inside a `catch` block, bare `throw;` preserves the original stack trace and is almost always the correct choice. `throw ex;` starts a new throw from the current line, which makes diagnostics harder because the original failure location is truncated. If you need to rethrow later or on another thread, use `ExceptionDispatchInfo.Capture(ex).Throw()` so the original stack is preserved.

## Detailed Explanation
### Why Stack Trace Preservation Matters
An exception is most valuable when it tells you where the failure started. If a database call fails deep in the call chain, the original stack trace shows the true origin. Resetting that trace makes debugging slower because you only see the place where somebody rethrew it, not the method that actually failed.

### `throw;` vs `throw ex;`
Inside a `catch`, the runtime treats these forms differently.

| Form | Result |
|---|---|
| `throw;` | Reuses the current exception and preserves the original stack trace |
| `throw ex;` | Throws the same object again from the current line, resetting the visible stack trace |
| `new Exception("wrapper", ex)` | Creates a new exception, keeping the original in `InnerException` |

That difference is the reason analyzer rule CA2200 warns about `throw ex;`. In catch blocks, use bare `throw;` unless you intentionally want to wrap the exception in a new abstraction.

### When Wrapping Is Better Than Rethrowing
Sometimes you do want a new exception. Example: a repository might catch `SqlException` and throw `OrderPersistenceException` so callers are not tightly coupled to SQL Server details. In that case, do not lose the original exception—store it as `InnerException`. Tools and logs can inspect both the high-level message and the low-level cause.

> **Warning:** Logging and then wrapping at multiple layers creates exception pyramids that are hard to read. Wrap once at the layer where abstraction changes.

### Rethrowing Later with `ExceptionDispatchInfo`
`throw;` only works inside the active `catch` block. If you need to capture an exception and rethrow it later—perhaps after hopping to another thread, completing a callback, or passing it through a queue—use `ExceptionDispatchInfo`.

`ExceptionDispatchInfo.Capture(ex).Throw()` preserves the original stack and appends a marker that the exception was rethrown. That is the right tool for cross-thread or deferred rethrow scenarios, including some advanced async and task integration code.

### `AggregateException` and Parallel Work
Parallel APIs may collect several failures into an `AggregateException`. Its `InnerException` property returns only the first one; `InnerExceptions` contains them all. `Flatten()` removes nested aggregates, and `Handle()` lets you mark specific inner exceptions as handled while any remaining ones are rethrown.

With `await`, the runtime usually unwraps and throws the first inner exception directly, which is convenient but means you may not see the full set of failures unless you inspect the task itself. For full details, see [AggregateException](./aggregate-exception.md).

### Practical Rule of Thumb
Use this sequence in real code:
1. Catch only where you can add value.
2. If you are only logging or cleaning up, rethrow with `throw;`.
3. If you are translating the exception for another abstraction, create a new exception and keep the old one as `InnerException`.
4. If you must rethrow outside the catch block, use `ExceptionDispatchInfo`.

## Code Example
```csharp
using System.Runtime.ExceptionServices;

namespace DotNetRuntimeExamples;

public static class RethrowDemo
{
    public static void Run()
    {
        try
        {
            DangerousOperation();
        }
        catch (InvalidOperationException ex)
        {
            Console.WriteLine($"Logged once: {ex.Message}");

            // Correct: keeps the original failure location.
            ExceptionDispatchInfo.Capture(ex).Throw();
            throw; // Unreachable, but satisfies flow analysis in some examples.
        }
    }

    public static void Wrap()
    {
        try
        {
            DangerousOperation();
        }
        catch (InvalidOperationException ex)
        {
            throw new ApplicationException("Order processing failed.", ex); // Preserve the cause.
        }
    }

    private static void DangerousOperation()
    {
        throw new InvalidOperationException("The original failure happened here.");
    }
}
```

## Common Follow-up Questions
- Why does CA2200 flag `throw ex;`?
- When should I wrap an exception instead of rethrowing it?
- How does `ExceptionDispatchInfo` differ from storing the exception and later doing `throw ex;`?
- What happens to stack traces when `await` unwraps task exceptions?
- When do I need `AggregateException.Flatten()` or `Handle()`?

## Common Mistakes / Pitfalls
- Using `throw ex;` in every catch block and destroying the original failure location.
- Wrapping exceptions without including the original one as `InnerException`.
- Logging the same exception repeatedly at multiple layers before rethrowing it.
- Looking only at `AggregateException.InnerException` and missing additional failures.
- Assuming `await` always exposes every inner exception from `Task.WhenAll`.

## References
- [CA2200: Rethrow to preserve stack details](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2200)
- [ExceptionDispatchInfo class](https://learn.microsoft.com/dotnet/api/system.runtime.exceptionservices.exceptiondispatchinfo)
- [Best practices for exceptions](https://learn.microsoft.com/dotnet/standard/exceptions/best-practices-for-exceptions)
- [Exception handling (Task Parallel Library)](https://learn.microsoft.com/dotnet/standard/parallel-programming/exception-handling-task-parallel-library)
