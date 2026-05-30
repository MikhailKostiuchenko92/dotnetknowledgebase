# `throw;` vs `throw ex;`

**Category:** C# / Exceptions
**Difficulty:** Middle
**Tags:** `throw`, `rethrow`, `stack-trace`, `ExceptionDispatchInfo`, `exceptions`

## Question

> What is the difference between `throw;` and `throw ex;` in C#, and why does it matter for stack traces?

Also asked as:
- "Why does `throw ex;` lose useful debugging information?"
- "When should I use `ExceptionDispatchInfo.Capture().Throw()` instead of a normal rethrow?"

## Short Answer

Inside a `catch` block, `throw;` rethrows the current exception while preserving the original stack trace. `throw ex;` throws the exception object again as a new throw site, which resets the stack trace to the current location and hides where the problem originally happened. If you need to capture an exception and rethrow it later on another boundary, use `ExceptionDispatchInfo.Capture(ex).Throw()`.

## Detailed Explanation

### The Core Difference

When code is already in a `catch` block, the runtime knows there is an active exception being handled. `throw;` tells it to continue propagating that same exception unchanged.

`throw ex;` is different. It explicitly throws the exception variable again from the current line. The object is the same, but the throw site is treated as the current method, so the stack trace starts there.

| Statement | Preserves original stack trace? | Typical use |
|---|---|---|
| `throw;` | Yes | Rethrow from inside `catch` |
| `throw ex;` | No | Almost never correct |
| `ExceptionDispatchInfo.Capture(ex).Throw()` | Yes | Rethrow later or across boundaries |

### Why Stack Trace Preservation Matters

The stack trace is often the fastest way to find the true source of a bug. If the original failure happened in `Repository.LoadCustomer()`, but your logs show only `Service.HandleRequest()` because you used `throw ex;`, you just made production debugging harder.

This is why analyzers flag `throw ex;` and why CA2200 exists.

> **Warning:** If you catch only to log and then continue propagating, use `throw;`. Otherwise your log may point to the logging layer instead of the actual bug.

### Correct Rethrow Pattern

The common pattern is:

```csharp
catch (Exception ex)
{
    logger.LogError(ex, "Failed while processing order {OrderId}", orderId);
    throw;
}
```

That adds context to logs without damaging the diagnostic information carried by the exception.

### When `ExceptionDispatchInfo` Is Needed

`throw;` only works inside the active `catch` block. Sometimes you need to store the exception and rethrow it later, for example:
- Crossing async/sync boundaries.
- Moving an exception from one callback to another.
- Deferring the rethrow until cleanup or aggregation logic finishes.

In that case, use `ExceptionDispatchInfo`.

```csharp
var edi = ExceptionDispatchInfo.Capture(ex);
// later
edi.Throw();
```

This preserves the original stack trace and appends the rethrow location with the familiar marker indicating the previous location where the exception was thrown.

### Wrapping Is Different from Rethrowing

Sometimes you do not want a bare rethrow. You want to add a new abstraction-specific exception:

```csharp
catch (SqlException ex)
{
    throw new CustomerRepositoryException("Could not load customer", ex);
}
```

That is not the same decision as `throw;` vs `throw ex;`. Wrapping is valid when it improves abstraction or context. The original exception remains available as `InnerException`.

See [custom-exceptions-best-practices.md](./custom-exceptions-best-practices.md).

### Common Interview Rule

If the interviewer asks for the rule, the safest concise answer is:
- Use `throw;` to rethrow from `catch`.
- Avoid `throw ex;` because it resets the stack trace.
- Use `ExceptionDispatchInfo` when rethrowing later.

## Code Example

```csharp
using System;
using System.Runtime.ExceptionServices;

try
{
    CallWithPreservedStackTrace();
}
catch (Exception ex)
{
    Console.WriteLine("Preserved stack trace:");
    Console.WriteLine(ex.StackTrace);
}

try
{
    CallWithResetStackTrace();
}
catch (Exception ex)
{
    Console.WriteLine();
    Console.WriteLine("Reset stack trace:");
    Console.WriteLine(ex.StackTrace);
}

try
{
    CallWithExceptionDispatchInfo();
}
catch (Exception ex)
{
    Console.WriteLine();
    Console.WriteLine("Captured and rethrown later:");
    Console.WriteLine(ex.StackTrace);
}

static void CallWithPreservedStackTrace()
{
    try
    {
        ThrowDeep();
    }
    catch
    {
        throw; // Preserves ThrowDeep in the stack trace.
    }
}

static void CallWithResetStackTrace()
{
    try
    {
        ThrowDeep();
    }
    catch (Exception ex)
    {
        throw ex; // Resets the visible throw site to this method.
    }
}

static void CallWithExceptionDispatchInfo()
{
    ExceptionDispatchInfo? captured = null;

    try
    {
        ThrowDeep();
    }
    catch (Exception ex)
    {
        captured = ExceptionDispatchInfo.Capture(ex);
    }

    captured!.Throw(); // Preserves the original throw site even though this is later.
}

static void ThrowDeep() => throw new InvalidOperationException("Boom from the original source");
```

## Common Follow-up Questions

- Why does `throw;` work only inside a `catch` block?
- When is wrapping an exception with `InnerException` better than rethrowing the original one?
- What does `ExceptionDispatchInfo` preserve that `throw ex;` does not?
- Why do analyzers like CA2200 flag `throw ex;`?
- How do stack traces behave when exceptions flow through `async` methods?

## Common Mistakes / Pitfalls

- Logging inside `catch` and then using `throw ex;`, which destroys the original failure location.
- Confusing wrapping with rethrowing and losing abstraction boundaries.
- Capturing an exception to rethrow later without `ExceptionDispatchInfo`.
- Catching exceptions only to rethrow immediately when no extra logging, translation, or cleanup is needed.

## References

- [CA2200: Rethrow to preserve stack details — Microsoft Learn](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2200)
- [ExceptionDispatchInfo Class — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.exceptionservices.exceptiondispatchinfo)
- [Best practices for exceptions — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/exceptions/best-practices-for-exceptions)
- [See: custom-exceptions-best-practices.md](./custom-exceptions-best-practices.md)
- [See: exception-handling-fundamentals.md](./exception-handling-fundamentals.md)
