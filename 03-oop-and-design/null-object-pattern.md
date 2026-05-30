# Null Object Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🟢 Junior
**Tags:** `null-object`, `behavioral`, `null-safety`, `NullLogger`

## Question
> What is the Null Object pattern, and how is it different from just checking for `null` or using the null-conditional operator?

## Short Answer
The Null Object pattern replaces `null` with a real object that implements the same contract but does nothing or provides a safe default behavior. That removes repetitive null checks and keeps client code polymorphic. It is different from `?.` because `?.` skips a call at the call site, while a null object is a deliberate design choice with explicit semantics.

## Detailed Explanation
### What it is
Null Object is a special-case implementation of an interface or base class. Instead of returning `null` and forcing every caller to defend itself, you return an object whose behavior is safe and predictable. That means callers can keep using the dependency normally.

A well-known .NET example is `NullLogger<T>`. If you do not want real logging, you can inject a logger that accepts calls and discards them. The consuming class does not need `if (logger != null)` around every log statement.

### How it works internally
The pattern relies on ordinary polymorphism. You define a contract such as `INotifier`, `ILogger<T>`, or `ICache`. Then you provide at least two implementations:

- a real implementation that performs work;
- a null implementation that intentionally does nothing or returns neutral values.

That keeps the consuming service simple because it always talks to an object, never to “maybe an object.” In practice, the null implementation must still preserve the contract. For example, it should not throw unexpectedly, mutate state, or hide an error that the caller truly needs to know about.

| Technique | Meaning | Best use |
| --- | --- | --- |
| `null` + checks | Dependency may be absent | Legacy APIs, optional data |
| `?.` / `??` | Guard at the call site | Small, local null handling |
| Null Object | Absence becomes behavior | Reusable service dependencies |

### Why it matters
The pattern improves readability because business code stops being dominated by defensive `null` checks. It also reduces the risk of `NullReferenceException` and makes constructor invariants stronger: a class can require an `INotifier`, and the caller decides whether that notifier is real or inert.

It works especially well for optional cross-cutting concerns such as logging, metrics, notifications, auditing, or caching. Those concerns often have meaningful “do nothing” behavior.

> A null object should represent an intentional no-op or neutral behavior. It is not a license to silently swallow real business failures.

### Trade-offs and when not to use it
The main risk is **masking bugs**. If a dependency must exist for correctness, a null object can hide misconfiguration. For example, a payment gateway should probably fail fast rather than quietly doing nothing.

It also does not replace nullable reference types. Nullable annotations tell the compiler about nullability; Null Object changes runtime design. These techniques complement each other.

Use Null Object when:
- a dependency is optional;
- “do nothing” is a valid behavior;
- repeated null checks are cluttering the code.

Avoid it when:
- missing the dependency is a configuration error;
- the fallback behavior would hide data loss or business failure;
- the “null” behavior is so different that it deserves explicit branching.

In interviews, a strong answer mentions both the benefit—cleaner polymorphic code—and the danger—silent failure if applied to critical logic.

## Code Example
```csharp
using System;

namespace OopAndDesign.NullObjectPattern;

public interface INotifier
{
    void Send(string message);
}

public sealed class EmailNotifier : INotifier
{
    public void Send(string message) =>
        Console.WriteLine($"Email sent: {message}");
}

public sealed class NullNotifier : INotifier
{
    public void Send(string message)
    {
        // Intentionally no-op: caller can still invoke the dependency safely.
    }
}

public sealed class OrderService(INotifier notifier)
{
    public void PlaceOrder(int orderId)
    {
        Console.WriteLine($"Order {orderId} placed.");
        notifier.Send($"Order {orderId} confirmation");
    }
}

public static class Program
{
    public static void Main()
    {
        var serviceWithEmail = new OrderService(new EmailNotifier());
        serviceWithEmail.PlaceOrder(1001);

        Console.WriteLine();

        var serviceWithoutEmail = new OrderService(new NullNotifier());
        serviceWithoutEmail.PlaceOrder(1002);
    }
}
```

## Common Follow-up Questions
- How is Null Object different from `?.` and `??`?
- When would a null object hide a bug instead of helping?
- Why is `NullLogger<T>` a good example of this pattern?
- Can Null Object be combined with dependency injection?
- How does this pattern relate to nullable reference types?

## Common Mistakes / Pitfalls
- Using a null object for critical dependencies where failure should be explicit.
- Making the null implementation behave inconsistently with the interface contract.
- Assuming Null Object removes the need for nullable annotations and domain validation.
- Swallowing exceptions inside the null implementation and hiding real problems.

## References
- [Special Case (Martin Fowler)](https://martinfowler.com/eaaCatalog/specialCase.html)
- [NullLogger<T> Class](https://learn.microsoft.com/dotnet/api/microsoft.extensions.logging.abstractions.nulllogger-1)
- [Nullable reference types - C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/null-safety/nullable-reference-types)
