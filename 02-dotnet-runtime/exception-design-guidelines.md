# Exception Design Guidelines in .NET

**Category:** .NET Runtime / Exceptions
**Difficulty:** 🟢 Junior
**Tags:** `exceptions`, `design-guidelines`, `custom-exceptions`, `rethrow`, `error-handling`

## Question
> What are the main exception design guidelines in .NET?

> When should you throw a custom exception, and when should you catch one?

> How do you decide whether to let an exception bubble up or handle it locally?

## Short Answer
Exceptions should represent truly exceptional conditions, not expected control flow such as failed parsing or “not found” checks on hot paths. In modern .NET, custom exceptions should inherit directly from `Exception`; `ApplicationException` is legacy and should not be used for new code. Catch exceptions only when you can recover, translate them into a better abstraction, or add meaningful context at an application boundary.

## Detailed Explanation
### Start with the Exception Hierarchy
At the top of the hierarchy is `System.Exception`. Most framework exceptions either inherit directly from it or from `SystemException`, which the runtime and BCL use for built-in failure categories such as `InvalidOperationException`, `ArgumentException`, and `IOException`. Historically .NET also exposed `ApplicationException`, but that type never created a useful semantic boundary and is now considered legacy. New application or library exceptions should inherit from `Exception` instead.

### Throw Only for Exceptional Conditions
Throwing is expensive compared with returning a normal status. A throw allocates an exception object, captures stack information, and starts stack unwinding. That cost is fine when something abnormal happens, but it is the wrong tool for routine outcomes like parse failures, cache misses, or validation branches that are expected in normal traffic.

A good rule is:

| Scenario | Preferred approach |
|---|---|
| Caller can reasonably expect failure often | `TryXxx`, result object, boolean return |
| Invariant is broken or operation cannot continue correctly | Throw an exception |
| Bug or invalid API usage | Throw a specific argument/state exception |

This is why the framework has `int.TryParse` and `Dictionary<TKey,TValue>.TryGetValue` in addition to exception-throwing APIs.

### Custom Exceptions Should Be Rare but Intentional
Create a custom exception when the caller benefits from a domain-specific failure type that can be caught separately. For example, `ConfigurationValidationException` may make sense in a reusable configuration library. If you do create one, keep it simple: inherit from `Exception`, name it with the `Exception` suffix, and provide the standard constructors.

For modern .NET 8/9-only code, the message and inner-exception constructors are usually sufficient. If you multi-target .NET Framework or need legacy formatter-based compatibility, also add the serialization constructor.

### Write Useful Messages
Exception messages should explain what went wrong, ideally with the relevant value or state. They should not scold the caller. “Customer with id 42 was not found in the billing store” is more useful than “Invalid customer id.” Include values when that improves diagnosis, but avoid leaking secrets such as tokens, passwords, or connection strings.

> **Warning:** Do not put sensitive data into exception messages just because exceptions are “internal.” They often end up in logs, telemetry, and support dumps.

### Catch Only with a Purpose
Catching every `Exception` at every layer makes code noisy and often harmful. It breaks stack clarity, encourages duplicated logging, and can hide the real fault. Let exceptions bubble until you reach a place that can do something meaningful: retry, compensate, convert to an HTTP response, fail a message, or shut down gracefully.

If you catch only to log, rethrow correctly with bare `throw;` so the original stack trace is preserved. At library boundaries, consider wrapping an implementation-specific exception in a more meaningful abstraction and storing the original in `InnerException`.

### Prefer App-Boundary Handling
In most applications, broad exception handling belongs near boundaries: ASP.NET Core middleware, background-worker loops, message consumers, CLI entry points, or UI event dispatchers. Lower layers should normally either succeed or throw a specific exception and let the boundary decide how to present or log it.

Related: [Throw vs Rethrow](./throw-vs-rethrow.md).

## Code Example
```csharp
using System.Runtime.Serialization;

namespace DotNetRuntimeExamples;

[Serializable]
public sealed class CustomerNotFoundException : Exception
{
    public int CustomerId { get; }

    public CustomerNotFoundException(int customerId)
        : base($"Customer with id {customerId} was not found.") // Include the failing value.
    {
        CustomerId = customerId;
    }

    public CustomerNotFoundException(string message)
        : base(message)
    {
    }

    public CustomerNotFoundException(string message, Exception innerException)
        : base(message, innerException) // Preserve the lower-level cause.
    {
    }

#if NETFRAMEWORK
    protected CustomerNotFoundException(SerializationInfo info, StreamingContext context)
        : base(info, context) // Legacy formatter-based compatibility only.
    {
        CustomerId = info.GetInt32(nameof(CustomerId));
    }
#endif
}

public sealed class CustomerService
{
    public string GetDisplayName(int customerId)
    {
        if (customerId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(customerId)); // Caller bug.
        }

        try
        {
            return Lookup(customerId);
        }
        catch (IOException ex)
        {
            throw new CustomerNotFoundException(
                $"Customer lookup failed for id {customerId}.",
                ex); // Add context without losing the original exception.
        }
    }

    private static string Lookup(int customerId) => throw new IOException("Database file is unavailable.");
}
```

## Common Follow-up Questions
- When should I create a custom exception instead of reusing `InvalidOperationException` or `ArgumentException`?
- Why is `ApplicationException` considered legacy?
- Should library code log and rethrow, or just throw?
- What belongs in an exception message versus structured logging metadata?
- Where should broad `catch (Exception)` blocks live in a typical ASP.NET Core app?

## Common Mistakes / Pitfalls
- Using exceptions for normal branching such as parse failure or missing dictionary keys on hot paths.
- Creating custom exception types for every tiny error instead of reusing existing framework exceptions.
- Writing vague messages like “operation failed” with no useful state or value.
- Catching `Exception` in every layer and logging the same failure multiple times.
- Rethrowing with `throw ex;`, which destroys the original stack trace.

## References
- [Best practices for exceptions](https://learn.microsoft.com/dotnet/standard/exceptions/best-practices-for-exceptions)
- [Exception class](https://learn.microsoft.com/dotnet/api/system.exception)
- [CA2201: Do not raise reserved exception types](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2201)
- [CA1032: Implement standard exception constructors](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1032)
