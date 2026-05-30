# Sealed Classes and Methods

**Category:** OOP & Design
**Difficulty:** 🟢 Junior
**Tags:** `sealed`, `performance`, `devirtualization`

## Question
> What does the `sealed` keyword do in C#, and why would you seal a class or a method?

## Short Answer
`sealed` prevents further inheritance. A sealed class cannot be derived from, and a sealed override stops deeper subclasses from overriding that particular method again. You use it to express design intent, reduce extension points you do not want to support, and sometimes enable JIT optimizations such as easier devirtualization.

## Detailed Explanation
### What `sealed` means in practice
In C#, `sealed` closes a type or a specific overridden member for further inheritance. If a class is sealed, no other class can derive from it. If a method is declared as `sealed override`, the current class still overrides the base implementation, but classes below it cannot replace that behavior again.

This is useful because inheritance is part of your public design surface. Once you allow others to subclass your type, you are implicitly supporting extension scenarios, lifecycle rules, and override points. `sealed` makes the opposite statement: “this type or behavior is intentionally closed.”

| Use of `sealed` | Effect | Typical reason |
| --- | --- | --- |
| `sealed class` | No one can inherit from the class | Protect invariants, simplify API surface |
| `sealed override` | Stops further overrides of a specific member | Lock down behavior in a hierarchy |
| Not sealed | Inheritance remains open | Framework extensibility or customization |

### Design intent and correctness
A common reason to seal a class is to protect invariants. Suppose a type depends on strict rules for security tokens, value objects, or thread-safe state transitions. If derived classes can override core behavior, they may weaken those guarantees.

Sealing can also make APIs easier to understand. Consumers do not have to wonder whether a type is designed for inheritance or whether overriding a method is safe. That clarity matters in public libraries.

> Warning: if a class is not explicitly designed and documented for inheritance, sealing it is often safer than leaving accidental extension points open.

### Sealed methods in hierarchies
A sealed method is only allowed when it is also an override. That means the method was virtual somewhere above, the current class overrides it, and then closes the override chain. This is useful when a mid-level type wants to customize a behavior once and prevent derived classes from changing a critical part again.

For example, a framework might allow a base authentication method to be customized, but once a security-sensitive subclass hardens it, the library may seal that override to preserve the guarantee.

### Performance: devirtualization, but not magic
From a performance perspective, sealing can help the JIT. If the runtime can prove there is no further override, it may replace a virtual call with a more direct call path, inline the method, and optimize surrounding code more aggressively. This is called devirtualization.

However, that should be seen as a bonus, not the main reason to add `sealed`. Modern .NET JITs can sometimes devirtualize even non-sealed calls when they have enough type information. So the bigger reason is usually design clarity and correctness.

### When not to use it
Do not seal everything automatically. If you are building a framework where inheritance is a legitimate extension model, sealing can make the library harder to use. Also, mocking some classes in tests can be harder when they are sealed, although modern mocking libraries sometimes work around that.

The right mental model is: seal types and methods that should not vary. Leave inheritance open only where you are intentionally supporting variation.

## Code Example
```csharp
namespace OopAndDesignExamples;

public class ReportFormatter
{
    public virtual string Format(string value) => $"Base: {value}";
}

public class SecureReportFormatter : ReportFormatter
{
    public sealed override string Format(string value)
    {
        // This override is locked down for all further derived types.
        return $"Secure: {value.Trim().ToUpperInvariant()}";
    }
}

public sealed class ApiToken
{
    public ApiToken(string value)
    {
        Value = string.IsNullOrWhiteSpace(value)
            ? throw new ArgumentException("Token is required.", nameof(value))
            : value;
    }

    public string Value { get; }
}

public static class Program
{
    public static void Main()
    {
        ReportFormatter formatter = new SecureReportFormatter();
        Console.WriteLine(formatter.Format("  confidential  "));

        var token = new ApiToken("abc-123");
        Console.WriteLine($"Token created: {token.Value}");

        // The following is impossible:
        // public class CustomToken : ApiToken { } // Error: ApiToken is sealed.
    }
}
```

## Common Follow-up Questions
- What is the difference between a sealed class and a sealed method?
- Why can `sealed` help the JIT optimize virtual calls?
- Can you combine `sealed` with `abstract` on the same class?
- When is leaving a class unsealed the better design choice?
- How does sealing affect mocking and testability?

## Common Mistakes / Pitfalls
- Sealing classes only for performance without any design reason.
- Leaving classes open for inheritance even though they were never designed to be safely subclassed.
- Forgetting that `sealed` on a method must be used together with `override`.
- Assuming `sealed` always creates measurable speedups in real applications.
- Sealing framework extension points that users legitimately need to customize.

## References
- [The `sealed` keyword (C# Reference)](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/sealed)
- [The `override` keyword (C# Reference)](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/override)
- [The `virtual` keyword (C# Reference)](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/virtual)
- [Performance Improvements in .NET 6](https://devblogs.microsoft.com/dotnet/performance-improvements-in-net-6/)
