# What is the Law of Demeter?

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🟡 Middle
**Tags:** `law-of-demeter`, `tell-dont-ask`, `coupling`, `fluent-api`

## Question
> What is the Law of Demeter, how does it relate to Tell Don't Ask, and are there exceptions like fluent APIs?

## Short Answer
The Law of Demeter says an object should talk only to its close collaborators instead of navigating deep object graphs. In practice, code like `order.Customer.Address.CountryCode` increases coupling because callers need to know too much about internal structure. Tell Don't Ask is closely related: prefer telling an object what you want done instead of pulling data out and deciding externally, while fluent APIs are a common intentional exception because the chain is part of one designed abstraction.

## Detailed Explanation
### What the Law of Demeter means
The Law of Demeter is often summarized as **"only talk to your immediate friends."** A method should usually call methods on:

- itself,
- its parameters,
- objects it creates,
- and its direct fields or collaborators.

The warning sign is a long navigation chain such as `order.Customer.Address.Country.Code`. That means the caller depends on the internal structure of several objects, not just on `order`.

| Style | Example | Coupling impact |
| --- | --- | --- |
| Ask through object graph | `order.Customer.Address.CountryCode` | Caller knows too much about internals |
| Tell the object | `order.GetShippingCountryCode()` | Boundary stays stable |

### Why it matters
The real issue is not line length. It is coupling. If `Customer` stops exposing `Address`, or `Address` gets split into `BillingAddress` and `ShippingAddress`, many callers break. The more code reaches through a graph, the more ripple effects you get from internal refactoring.

This is why the principle overlaps with **Tell Don't Ask**. When callers repeatedly extract state and make decisions elsewhere, behavior is living in the wrong place. If an `Order` knows how to determine its shipping destination, the caller should tell the order to provide that answer or perform the action.

> Warning: blindly exposing object graphs through getters may look convenient, but it leaks structure and makes internal changes expensive.

### Method chaining versus LoD
A common interview trap is assuming all chaining violates the rule. That is not true. Fluent APIs such as LINQ or `builder.WithX().WithY().Build()` are usually designed as a single abstraction. Each method intentionally returns the same conceptual object, so the chain does not necessarily reveal deep internal structure.

The key question is: **am I traversing unrelated domain objects, or am I using one fluent interface on purpose?**

- `query.Where(...).OrderBy(...).Select(...)` is usually fine.
- `order.Customer.Address.Country.GetVatRules().Rate` is usually suspicious.

### When not to apply it rigidly
Like many design principles, this one is heuristic, not law in the legal sense. Sometimes reading a simple property from a child object is completely reasonable, especially in DTOs, view models, or serialization shapes. Also, adding forwarding methods everywhere can create noisy pass-through APIs if there is no real behavior to protect.

The point is to prevent **knowledge leakage**. If callers must understand too much about nested structures to do their job, your model is probably exposing the wrong boundary.

### Practical refactoring moves
Typical fixes include moving behavior closer to the data, adding intention-revealing methods, and collapsing message chains behind a clearer API. Refactorings like Move Method and Hide Delegate are common here. In a good interview answer, mention that LoD reduces coupling, Tell Don't Ask keeps behavior where it belongs, and fluent APIs are a deliberate exception when the chain represents one abstraction.

## Code Example
```csharp
namespace InterviewKnowledgeBase.Examples;

internal static class Program
{
    private static void Main()
    {
        Order order = new(new Customer(new Address("NL")));

        Console.WriteLine($"Bad: {BadShippingCalculator.GetVatRegion(order)}");
        Console.WriteLine($"Good: {GoodShippingCalculator.GetVatRegion(order)}");

        // Fluent API chains are often intentional because they stay within one abstraction.
        string[] result = ["ada", "grace", "linus"];
        Console.WriteLine(string.Join(", ", result.Where(name => name.Length > 3).Select(name => name.ToUpperInvariant())));
    }
}

internal sealed record Order(Customer Customer)
{
    public string GetShippingCountryCode() => Customer.Address.CountryCode; // Better: one stable entry point.
}

internal sealed record Customer(Address Address);
internal sealed record Address(string CountryCode);

internal static class BadShippingCalculator
{
    public static string GetVatRegion(Order order)
    {
        // Bad: message chain exposes the full object graph to the caller.
        return order.Customer.Address.CountryCode == "NL" ? "EU" : "Other";
    }
}

internal static class GoodShippingCalculator
{
    public static string GetVatRegion(Order order)
    {
        // Good: the caller asks Order for what it needs instead of traversing internals.
        return order.GetShippingCountryCode() == "NL" ? "EU" : "Other";
    }
}
```

## Common Follow-up Questions
- How is the Law of Demeter related to Tell Don't Ask?
- What is a message chain smell?
- When is a fluent API chain acceptable?
- Does the Law of Demeter apply the same way to DTOs and domain models?
- What refactorings help reduce Demeter violations?
- Can too many forwarding methods become a smell of their own?

## Common Mistakes / Pitfalls
- Treating every method chain as a violation without checking whether it is one intentional abstraction.
- Adding trivial pass-through methods everywhere and making the API noisier than necessary.
- Exposing deep object graphs through getters and then wondering why refactors ripple widely.
- Using Tell Don't Ask as an excuse to hide simple data access that is perfectly reasonable in DTOs.
- Focusing on syntax length instead of the real issue, which is coupling and leaked structure.

## References
- [Tell Don't Ask](https://martinfowler.com/bliki/TellDontAsk.html)
- [Message Chains](https://refactoring.guru/smells/message-chains)
- [Moving Features Between Objects](https://refactoring.guru/refactoring/techniques/moving-features-between-objects)
