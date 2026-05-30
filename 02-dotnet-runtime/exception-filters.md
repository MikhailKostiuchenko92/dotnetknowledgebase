# Exception Filters in .NET

**Category:** .NET Runtime / Exceptions
**Difficulty:** 🟡 Middle
**Tags:** `exception-filters`, `when`, `catch`, `il`, `logging`, `stack-unwinding`

## Question
> What are exception filters in C#, and how are they different from a normal `catch` block?

> Why can `catch (...) when (...)` inspect an exception without really catching it?

> When should you use an exception filter instead of catching and rethrowing?

## Short Answer
An exception filter is a `catch` clause with a `when` condition, and it maps to an IL `filter` block. The key advantage is that the filter runs during the first pass of exception handling, before stack unwinding, so if it returns `false` the exception keeps searching without the current frame being treated as caught. That makes filters great for conditional handling and one-time logging without changing the control flow of unmatched exceptions.

## Detailed Explanation
### What a Filter Really Is
In C#, `catch (Exception ex) when (condition)` looks like a small syntax feature, but under the hood it is a distinct runtime mechanism. Unlike a normal `catch`, a filter executes as part of the search phase of exception handling. The runtime asks, “Does this handler want the exception?” before it unwinds the stack.

That behavior is different from catching and then writing `if (...) throw;`. In the `if/throw` version, the stack is already unwound into the catch block. With a filter that returns `false`, the current frame is not considered to have handled the exception at all.

### Why That Matters
This gives filters two practical advantages.

| Approach | Stack unwound before decision? | Good for |
|---|---|---|
| `catch` then `if` then `throw;` | Yes | Real handling after entering catch |
| `catch ... when (...)` | No, if filter is false | Inspection, conditional handling, lightweight logging |

Because unwinding is skipped when the filter returns `false`, the runtime avoids the extra cleanup and control-flow disturbance for non-matching cases. It also means local state is still intact while the filter evaluates.

### Logging Without Catching
A classic pattern is:

`catch (Exception ex) when (Log(ex) == false)`

The helper logs the exception and returns `false`, so the exception continues propagating. This lets you record diagnostic information without turning the current layer into the handler.

> **Warning:** Use this pattern carefully. Logging should be side-effect-light and should not become a hidden dependency that changes correctness if the filter runs more than once in future refactors.

### Filters Must Be Safe and Idempotent
Because filters run during the search phase, they should avoid important side effects. A filter should answer “Should this catch handle the exception?” rather than mutate application state. If the filter opens transactions, changes counters that affect logic, or partially updates business state, you can create subtle bugs because the handler may never actually run.

Good filter logic is usually limited to:
- type or property inspection
- environment checks
- diagnostics/logging
- cheap policy decisions

### Performance and Readability
Filters are not a magic performance feature, but they can be cheaper than catch-and-rethrow when the match fails because the runtime does not unwind into the frame. More importantly, they express intent clearly. “Only catch this when the HTTP status is 404” is easier to understand in a filter than in a catch with nested `if` logic.

### When to Prefer a Normal Catch
Use a regular `catch` when you genuinely plan to handle, compensate, retry, or wrap the exception. Filters are best for gating whether the catch should run at all. They are not a substitute for structured recovery logic.

For the runtime model behind this behavior, see [CLR Exception Model](./clr-exception-model.md).

## Code Example
```csharp
namespace DotNetRuntimeExamples;

public static class ExceptionFilterDemo
{
    public static void Run()
    {
        try
        {
            throw new InvalidOperationException("Transient failure");
        }
        catch (InvalidOperationException ex) when (Log(ex) == false)
        {
            // This block is never entered because the filter returns false.
            Console.WriteLine("Unreachable handler");
        }
    }

    public static void Handle404()
    {
        try
        {
            throw new HttpRequestException(
                "Resource was not found.",
                inner: null,
                statusCode: System.Net.HttpStatusCode.NotFound);
        }
        catch (HttpRequestException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            Console.WriteLine("Handled only the 404 case."); // Specific handling path.
        }
    }

    private static bool Log(Exception ex)
    {
        Console.WriteLine($"Observed: {ex.Message}"); // Diagnostic side effect only.
        return false; // Keep searching for a real handler.
    }
}
```

## Common Follow-up Questions
- Why is `catch (...) when (...)` different from catching and rethrowing?
- Do filters run before or after `finally` blocks?
- Can filters improve performance?
- What kinds of side effects are unsafe in a filter?
- When is the logging-with-false pattern appropriate?

## Common Mistakes / Pitfalls
- Putting business-state mutations in a filter expression.
- Assuming the filter means the exception was already caught and unwound.
- Using filters for complex logic that belongs in the actual handler.
- Forgetting that a false filter means cleanup in outer frames has not run yet.
- Replacing every normal catch with a filter even when real recovery is needed.

## References
- [User-filtered exception handlers](https://learn.microsoft.com/dotnet/standard/exceptions/using-user-filtered-exception-handlers)
- [Exceptions and exception handling](https://learn.microsoft.com/dotnet/csharp/fundamentals/exceptions/)
- [catch clause](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/exception-handling-statements)
- [System.Exception class](https://learn.microsoft.com/dotnet/api/system.exception)
