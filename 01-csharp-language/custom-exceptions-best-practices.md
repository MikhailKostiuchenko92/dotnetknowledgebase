# Custom Exceptions Best Practices

**Category:** C# / Exceptions
**Difficulty:** Middle
**Tags:** `exceptions`, `custom-exceptions`, `design`, `InnerException`, `naming`

## Question

> When should you create a custom exception in C#, and what are the current best practices for designing one?

Also asked as:
- "Do I still need `[Serializable]` and a serialization constructor on custom exceptions in modern .NET?"
- "What constructors should a custom exception type have?"

## Short Answer

Create a custom exception when a built-in exception type cannot clearly express a meaningful domain or infrastructure failure in your API. In modern .NET, a custom exception should usually end with `Exception`, inherit from `Exception` or a relevant base type, and expose the standard three constructors: parameterless, message, and message plus inner exception. In .NET 5+ / .NET 8+, `[Serializable]` and the old serialization constructor are usually unnecessary unless you explicitly support legacy remoting-style serialization scenarios.

## Detailed Explanation

### When a Custom Exception Is Justified

You do not create a custom exception for every error. Most failures are already well represented by built-in types such as `ArgumentException`, `ArgumentNullException`, `InvalidOperationException`, `NotSupportedException`, or `TimeoutException`.

Create a custom exception when:
- Consumers need to distinguish your failure from generic runtime errors.
- The exception carries domain meaning in your API boundary.
- Catching the type directly is clearer than inspecting messages or error codes.
- You are building a reusable library or a domain model with explicit error contracts.

Examples include `OrderValidationException`, `PaymentDeclinedException`, or `CustomerRepositoryException`.

### When Not to Create One

Avoid custom exceptions when a built-in type already says enough.

| Scenario | Better choice |
|---|---|
| Caller passed `null` | `ArgumentNullException` |
| Method called in invalid state | `InvalidOperationException` |
| Feature intentionally unsupported | `NotSupportedException` |
| Domain-specific failure meaningful to callers | Custom exception |

If the only difference is the message text, a new type is probably not worth it.

### Recommended Shape in Modern .NET

For most applications and libraries targeting .NET 8/9, use these rules:
- Name it with the `Exception` suffix.
- Make it `sealed` unless you expect inheritance.
- Provide the standard three constructors.
- Add extra properties only when they are genuinely useful and stable.
- Keep it immutable after construction.

The three common constructors are:
1. Parameterless.
2. `string message`.
3. `string message, Exception innerException`.

That gives callers and wrappers a predictable API.

### What About `[Serializable]`?

Older .NET Framework guidance often required `[Serializable]` plus a protected serialization constructor using `SerializationInfo` and `StreamingContext`. That existed for binary formatter, remoting, and cross-AppDomain scenarios.

In modern .NET (5+ through 8/9):
- BinaryFormatter is obsolete and unsafe.
- .NET remoting/AppDomains are not normal application patterns.
- Many applications never serialize exception objects.

So in most modern code bases, you do **not** need `[Serializable]` or the legacy serialization constructor.

> **Tip:** Add legacy serialization support only if your runtime environment, compatibility target, or framework contract explicitly requires it. Do not cargo-cult old patterns into every new exception class.

### Wrapping with `InnerException`

If your layer wants to expose a better abstraction, wrap lower-level exceptions instead of losing them.

```csharp
catch (HttpRequestException ex)
{
    throw new PaymentGatewayException("Payment provider call failed.", ex);
}
```

That preserves the underlying cause while presenting a clearer boundary-specific error.

### Avoid Overdesign

Do not add dozens of exception subclasses unless consumers really benefit. Too many custom exception types create API noise and fragile catch logic. Often one well-named exception plus an error code or extra property is enough.

See also [throw-vs-throw-ex.md](./throw-vs-throw-ex.md) and [exception-handling-fundamentals.md](./exception-handling-fundamentals.md).

## Code Example

```csharp
using System;

try
{
    throw new PaymentGatewayException("Payment provider rejected the request.");
}
catch (PaymentGatewayException ex)
{
    Console.WriteLine(ex.Message);
}

sealed class PaymentGatewayException : Exception
{
    public PaymentGatewayException()
    {
    }

    public PaymentGatewayException(string message)
        : base(message)
    {
    }

    public PaymentGatewayException(string message, Exception innerException)
        : base(message, innerException)
    {
    }
}
```

## Common Follow-up Questions

- When should you prefer a built-in exception like `InvalidOperationException` over a custom one?
- Why is `InnerException` important when translating low-level failures?
- When would extra custom properties on an exception be justified?
- Why is `[Serializable]` usually unnecessary in .NET 8/9?
- Should custom exceptions usually be `sealed`?

## Common Mistakes / Pitfalls

- Creating a custom exception when `ArgumentException` or `InvalidOperationException` already fits perfectly.
- Forgetting the `message, innerException` constructor and losing the original cause when wrapping exceptions.
- Naming a type without the `Exception` suffix, which makes APIs harder to read.
- Adding mutable state or too many custom properties that make the type harder to version.
- Copying old `[Serializable]` boilerplate into modern .NET code without a real need.

## References

- [Best practices for exceptions — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/exceptions/best-practices-for-exceptions)
- [How to create user-defined exceptions — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/exceptions/how-to-create-user-defined-exceptions)
- [Design guidelines for exceptions (verify URL)](https://learn.microsoft.com/dotnet/standard/design-guidelines/exceptions)
- [See: throw-vs-throw-ex.md](./throw-vs-throw-ex.md)
- [See: exception-handling-fundamentals.md](./exception-handling-fundamentals.md)
