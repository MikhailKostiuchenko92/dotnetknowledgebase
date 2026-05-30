# Exception Filters (`when`)

**Category:** C# / Exceptions
**Difficulty:** Middle
**Tags:** `exceptions`, `when`, `exception-filters`, `stack-unwinding`, `catch`

## Question

> What are exception filters in C#, and why would you use `catch (Exception ex) when (...)` instead of catching first and checking inside the block?

Also asked as:
- "When does an exception filter run relative to stack unwinding?"
- "Why can `catch (...) when (...)` preserve debugging context better than nested `if` logic inside `catch`?"

## Short Answer

An exception filter is a condition attached to a `catch` block using `when`. The runtime evaluates the filter before stack unwinding finishes, and the catch block runs only if the filter returns `true`. This lets you handle only the cases you want while preserving better stack/debugging context and avoiding over-catching exceptions that should continue propagating.

## Detailed Explanation

### What an Exception Filter Is

A filter lets you say, "Catch this exception type only if an additional condition is true."

```csharp
catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
```

Without a filter, you would have to catch the exception first and then inspect it inside the block. That is less precise because you have already committed to handling it.

### Filters Run Before the Handler Commits

The most important detail is that the `when` expression is evaluated **before the exception is considered handled** and before normal stack unwinding fully commits to that handler.

That matters because if the filter returns `false`, the runtime keeps searching for another matching handler as if this `catch` block was never selected.

| Pattern | What happens |
|---|---|
| `catch (Ex ex) when (condition)` and condition is `true` | Handler runs |
| `catch (Ex ex) when (condition)` and condition is `false` | Search continues upward |
| `catch (Ex ex) { if (!condition) throw; }` | Exception was already caught; stack has started unwinding |

This is why filters are cleaner than "catch everything, then decide."

### Why Filters Preserve More Context

A classic debugging advantage is that filters inspect the exception while the original stack is still intact. In practical terms, that means debuggers and diagnostic tools can show a more faithful picture of where the exception came from and what intermediate frames existed.

It also avoids the awkward pattern of catching an exception that you do not truly intend to handle.

> **Tip:** Use filters when the exception type is right but only some values, status codes, HRESULTs, or custom properties should be handled locally.

### Good Use Cases

Common examples include:
- Handle a `HttpRequestException` only for 404, not for every network failure.
- Handle a database exception only for deadlock error codes.
- Ignore `OperationCanceledException` only when the current cancellation token requested cancellation.
- Log-and-handle only certain domain error codes while letting the rest bubble up.

This keeps your exception handling specific and readable.

### Filters vs Logic Inside `catch`

Consider these two patterns.

**Preferred:**
```csharp
catch (CustomException ex) when (ex.Code == "TRANSIENT")
{
    return Retry();
}
```

**Less precise:**
```csharp
catch (CustomException ex)
{
    if (ex.Code != "TRANSIENT")
        throw;

    return Retry();
}
```

The second version works, but it catches first and decides later. That means you have already changed the control flow, and rethrowing can complicate debugging and maintenance.

### Important Behavior Details

If the filter itself throws, the runtime treats that as if the filter returned `false`, and it keeps searching for another handler. The new exception from the filter does not replace the original one.

Because of that, filter expressions should stay simple and side-effect free. Avoid calling code that can throw unexpectedly or mutate state.

### Filters in Async and Cancellation Code

Filters are especially useful in async code when handling cancellation correctly:

```csharp
catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
```

That avoids accidentally swallowing an `OperationCanceledException` caused by some other token or timeout source. See [async-exception-handling.md](./async-exception-handling.md).

## Code Example

```csharp
using System;

try
{
    throw new OrderProcessingException("Inventory temporarily unavailable", errorCode: 409);
}
catch (OrderProcessingException ex) when (ex.ErrorCode == 409)
{
    // Handle only the specific, known-recoverable case.
    Console.WriteLine("Retry later: inventory conflict.");
}
catch (OrderProcessingException ex)
{
    // Other order errors still reach a more general handler.
    Console.WriteLine($"Unhandled order error: {ex.ErrorCode} - {ex.Message}");
}

sealed class OrderProcessingException : Exception
{
    public int ErrorCode { get; }

    public OrderProcessingException(string message, int errorCode) : base(message)
    {
        ErrorCode = errorCode;
    }
}
```

## Common Follow-up Questions

- What happens if the code inside a `when` filter throws an exception?
- Why do exception filters preserve better debugging information than rethrowing from inside `catch`?
- When should you use a filter with `OperationCanceledException`?
- Can you access the caught exception variable inside the filter expression?
- How do exception filters compare with pattern matching on result objects instead of using exceptions?

## Common Mistakes / Pitfalls

- Catching a broad exception first, then using `if` logic, instead of expressing the condition directly with `when`.
- Putting complex or side-effect-heavy code inside the filter expression.
- Assuming a failed filter means the exception was handled; it was not.
- Swallowing cancellation too broadly by catching every `OperationCanceledException` without checking the right token.

## References

- [Exception-handling statements — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/exception-handling-statements)
- [User-filtered exception handlers (C# / .NET) — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/exceptions/using-user-filtered-exception-handlers)
- [Best practices for exceptions — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/exceptions/best-practices-for-exceptions)
- [See: async-exception-handling.md](./async-exception-handling.md)
- [See: throw-vs-throw-ex.md](./throw-vs-throw-ex.md)
