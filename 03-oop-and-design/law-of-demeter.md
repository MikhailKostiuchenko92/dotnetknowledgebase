# Law of Demeter

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🟡 Middle
**Tags:** `law-of-demeter`, `tell-dont-ask`, `coupling`, `fluent-api`

## Question
> What is the Law of Demeter, how does it relate to Tell Don’t Ask, and why are fluent APIs often considered an intentional exception?

## Short Answer
The Law of Demeter says an object should talk mainly to its close collaborators instead of reaching deeply through object graphs like `order.Customer.Address.City`. The goal is reducing coupling so internal structure changes do not ripple everywhere. It is closely related to Tell Don’t Ask, but fluent APIs are often acceptable because the chain is part of one deliberate interface rather than a leak through many internal objects.

## Detailed Explanation
### What the Law of Demeter means
The classic summary is “only talk to your immediate friends.” In practice, it means a method should avoid navigating through multiple layers of internal structure to get something done. Code like `order.Customer.Address.GetPostalCode()` exposes knowledge of the whole object graph. If any intermediate shape changes, callers break.

| Style | Example | Coupling impact |
| --- | --- | --- |
| Ask through graph | `order.Customer.Address.City` | High coupling to structure |
| Tell object what to do | `order.GetShippingCity()` | Lower coupling |
| Fluent interface | `query.Where(...).OrderBy(...)` | Usually intentional, stable chain |

The law is about dependency direction, not banning dots. One method call can still violate the spirit if it exposes too much structure, and several dots can be fine if they are part of one abstraction boundary.

### Relationship to Tell Don’t Ask
Tell Don’t Ask says you should tell an object what outcome you need instead of pulling out its data and making decisions elsewhere. The Law of Demeter supports that style. If every caller drills into nested objects to make decisions, behavior gets scattered and encapsulation weakens.

For example, instead of writing logic based on `order.Customer.IsVip` and `order.Total`, you might ask `order.CalculateShipping()`. That keeps the rule inside the object or aggregate that understands the domain.

> Warning: the Law of Demeter is a heuristic, not a rigid syntax rule. Refactoring every property access into a method can create useless forwarding methods and make the design worse.

### Why fluent APIs are usually fine
Fluent APIs such as LINQ, builders, and options configuration often look like Demeter violations because they chain many calls. But the difference is that the chain is intentionally designed as one cohesive interface. Each method returns another object representing the same abstraction or a closely related stage in the same DSL.

That is very different from reaching into `order.Customer.Address.Country.Code` because you know too much about the internals of several unrelated objects. Fluent chains are usually stable because the library authors designed them as a public surface. Deep object-graph navigation is brittle because it relies on accidental exposure.

### Trade-offs and practical use
If you apply the law too aggressively, you can end up with thin pass-through methods everywhere. If you ignore it completely, small model changes cause widespread breakage. The practical balance is to watch for repeated graph traversal, especially when decision-making logic depends on internal state of other objects.

In interviews, a strong answer is: the Law of Demeter reduces coupling by discouraging deep navigation through internals. It aligns with Tell Don’t Ask. Fluent APIs are usually an intentional exception because the chain itself is the public abstraction.

## Code Example
```csharp
using System;

namespace InterviewKnowledgeBase.OopAndDesign;

internal static class Program
{
    private static void Main()
    {
        var order = new Order(new Customer(new Address("Kyiv")));

        Console.WriteLine(order.GetShippingCity());

        var report = new ReportBuilder()
            .WithTitle("Orders")
            .WithFormat("csv")
            .Build(); // Fluent API: intentional and cohesive.

        Console.WriteLine(report);
    }
}

internal sealed record Address(string City);
internal sealed record Customer(Address Address);

internal sealed class Order(Customer customer)
{
    private Customer Customer { get; } = customer;

    public string GetShippingCity() => Customer.Address.City; // Internal traversal stays inside the object.
}

internal sealed class ReportBuilder
{
    private string _title = "Untitled";
    private string _format = "txt";

    public ReportBuilder WithTitle(string title)
    {
        _title = title;
        return this;
    }

    public ReportBuilder WithFormat(string format)
    {
        _format = format;
        return this;
    }

    public string Build() => $"Report: {_title} ({_format})";
}
```

## Common Follow-up Questions
- Is the Law of Demeter just “don’t use dots”?
- How does it relate to Tell Don’t Ask and encapsulation?
- Why are fluent APIs usually not considered harmful here?
- When do forwarding methods become over-engineering?
- How can LoD violations increase change ripple across a codebase?

## Common Mistakes / Pitfalls
- Treating any chained call as automatically bad without looking at the abstraction boundary.
- Exposing nested internals widely and letting callers make business decisions on them.
- Adding lots of pass-through methods that do not improve encapsulation or intent.
- Confusing DTO projection code with rich domain behavior and applying the law blindly everywhere.
- Assuming a single method call is always safe even if it leaks too much structure.

## References
- [The Law of Demeter](https://www.c-sharpcorner.com/article/the-law-of-demeter/)
- [TellDontAsk](https://martinfowler.com/bliki/TellDontAsk.html)
- [Fluent interfaces](https://martinfowler.com/bliki/FluentInterface.html)
- [Encapsulation - C# Programming Guide](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/)
