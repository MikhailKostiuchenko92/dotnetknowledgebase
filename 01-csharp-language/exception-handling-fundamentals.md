# Exception Handling Fundamentals

**Category:** C# / Exceptions
**Difficulty:** Junior
**Tags:** `exceptions`, `try`, `catch`, `finally`, `System.Exception`

## Question

> How does exception handling work in C#? What do `try`, `catch`, and `finally` do, and when should you catch `Exception`?

Also asked as:
- "What is the difference between `catch`, `finally`, and `throw` in C#?"
- "Should I catch every exception with `catch (Exception)`?"

## Short Answer

C# uses exceptions to signal errors that normal code cannot handle inline. `try` wraps code that may fail, `catch` handles matching exceptions, and `finally` runs cleanup code whether an exception happened or not. Catch specific exceptions when you can recover meaningfully; catch `Exception` only at application boundaries for logging, cleanup, or translating failures.

## Detailed Explanation

### What an Exception Is

An exception is an object, usually derived from `System.Exception`, that represents an error condition. When code throws an exception, normal execution stops and the runtime looks for the nearest matching `catch` block up the call stack.

That is different from returning `false` or `null`. Exceptions are meant for failures that break the normal path, not for routine branching.

### The Basic Flow: `try`, `catch`, `finally`

A typical exception-handling block looks like this:
- `try`: code that may throw.
- `catch`: handles one or more exception types.
- `finally`: cleanup that must happen either way.

| Keyword | Purpose | Runs when no exception occurs? | Runs when exception occurs? |
|---|---|---|---|
| `try` | Wrap risky code | Yes | Yes |
| `catch` | Handle matching exception | No | Yes, if type matches |
| `finally` | Cleanup resources | Yes | Yes |

If no `catch` matches, the exception keeps propagating upward until it is handled or the process fails.

### Exception Hierarchy Matters

All standard exceptions inherit from `System.Exception`. There are more specific types such as:
- `ArgumentNullException`
- `InvalidOperationException`
- `FormatException`
- `IOException`

You should usually catch the most specific type you can handle. Order matters: place more specific catches before broader ones.

```csharp
catch (FormatException)
catch (Exception) // broader catch comes later
```

If you reverse that order, the broader catch would grab everything first.

### What `finally` Is For

`finally` is for cleanup, not error handling. It runs whether the `try` block succeeds, throws, or even returns early.

Common uses:
- Releasing unmanaged resources.
- Closing handles or connections.
- Restoring temporary state.

> **Tip:** In modern C#, prefer `using` / `await using` for disposable resources when possible. Use `finally` when cleanup is not naturally modeled by `IDisposable`.

See [idisposable-and-using.md](./idisposable-and-using.md).

### When to Catch `Exception`

Catching `Exception` is sometimes correct, but only at the right layer. Good places include:
- Top-level request handlers.
- Background worker boundaries.
- Application startup/shutdown boundaries.
- Logging and translating exceptions into user-friendly or domain-specific errors.

Bad places include:
- Deep inside reusable library code where you cannot recover.
- Empty `catch` blocks that hide real failures.
- Places where you continue execution in a corrupted or unknown state.

A good rule is: catch an exception only if you can do one of these:
1. Recover.
2. Add useful context and rethrow.
3. Translate to a better abstraction.
4. Log at the boundary and stop the operation safely.

### Rethrowing Correctly

If you need to log and let the error continue, use `throw;`, not `throw ex;`, so the original stack trace stays intact. That topic is covered in [throw-vs-throw-ex.md](./throw-vs-throw-ex.md).

## Code Example

```csharp
using System;

try
{
    Console.Write("Enter a number: ");
    string input = Console.ReadLine() ?? string.Empty;

    int value = int.Parse(input); // May throw FormatException or OverflowException.
    int result = 100 / value;     // May throw DivideByZeroException.

    Console.WriteLine($"Result: {result}");
}
catch (FormatException)
{
    Console.WriteLine("Please enter a valid integer.");
}
catch (OverflowException)
{
    Console.WriteLine("The number is outside the Int32 range.");
}
catch (DivideByZeroException)
{
    Console.WriteLine("Zero is not allowed here.");
}
catch (Exception ex)
{
    // Broad catch at the boundary for unexpected failures.
    Console.WriteLine($"Unexpected error: {ex.Message}");
}
finally
{
    // Runs whether parsing/division succeeded or failed.
    Console.WriteLine("Finished processing input.");
}
```

## Common Follow-up Questions

- What is the difference between `throw;` and `throw ex;`?
- When should you use `finally` versus `using`?
- Why is catching `Exception` too broad in most library code?
- What happens if no `catch` block handles an exception?
- How do exceptions behave differently in `async` methods? ([See: async-exception-handling.md](./async-exception-handling.md))

## Common Mistakes / Pitfalls

- Catching `Exception` everywhere and accidentally hiding bugs that should fail fast.
- Using empty `catch` blocks that swallow errors without logging or recovery.
- Putting business logic in `finally` instead of using it only for cleanup.
- Catching exceptions you cannot actually handle, then continuing with invalid state.

## References

- [Exception-handling statements — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/exception-handling-statements)
- [System.Exception Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.exception)
- [Best practices for exceptions — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/exceptions/best-practices-for-exceptions)
- [See: async-exception-handling.md](./async-exception-handling.md)
- [See: idisposable-and-using.md](./idisposable-and-using.md)
