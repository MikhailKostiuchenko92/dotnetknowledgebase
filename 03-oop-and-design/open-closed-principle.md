# Open/Closed Principle (OCP)

**Category:** OOP & Design / SOLID
**Difficulty:** 🟡 Middle
**Tags:** `OCP`, `SOLID`, `strategy`, `extension`

## Question
> What is the Open/Closed Principle, and how can you apply it in C# using inheritance, composition, or the Strategy pattern?

## Short Answer
The Open/Closed Principle says software entities should be open for extension but closed for modification. In practice, you should be able to add new behavior with new classes or composed strategies instead of repeatedly editing a fragile `switch` or base class. In C#, OCP is usually better achieved with composition and strategy than with deep inheritance trees.

## Detailed Explanation
### What OCP means in practice
OCP is about reducing the cost and risk of change. If every new business case forces you to edit an existing class, you keep reopening tested code and increasing the chance of regressions. A design follows OCP when you can introduce a new behavior — a new discount type, payment rule, or export format — by adding code rather than modifying stable code paths.

That does not mean “never modify existing files.” Real systems always evolve. The useful interpretation is that stable orchestration code should depend on extension points where variation is expected.

### Three common ways to apply OCP
In C#, people usually reach for one of three approaches:

| Approach | How it extends behavior | Strengths | Risks |
| --- | --- | --- | --- |
| Inheritance | Override virtual members in subclasses | Simple for small hierarchies | Fragile base classes, tight coupling |
| Composition | Assemble behavior from collaborators | Flexible, testable | More types to manage |
| Strategy pattern | Select interchangeable algorithms via interface | Clear variation point | Overkill for one-off logic |

Inheritance can support OCP when the base type is stable and carefully designed. But it often leaks implementation assumptions into subclasses. Composition is usually safer because behavior is built by plugging collaborators together. Strategy is a structured form of composition for algorithm families.

### Example: avoiding the growing switch
A classic OCP violation is a service with a `switch` on customer type or document format. Every time marketing invents a new discount, you edit the same class again. That is a sign the variation axis is known and deserves an extension point.

With the Strategy pattern, you define something like `IDiscountStrategy` and create `RegularDiscountStrategy`, `VipDiscountStrategy`, and `BlackFridayDiscountStrategy`. The pricing service does not need to know the details of each rule; it just executes the selected strategy. To support a new discount, you add a new strategy class.

> Warning: replacing every `switch` with polymorphism is not automatically good design. If the set of cases is tiny and stable, a simple conditional may be clearer than a mini-framework.

### Why composition usually wins
Composition supports OCP without forcing subtype relationships where they do not belong. A `CheckoutService` is not a kind of discount strategy; it uses one. That separation keeps responsibilities clearer and reduces behavioural surprises. It also works better with DI in ASP.NET Core because strategies can be registered and selected at runtime.

### Trade-offs and when not to over-abstract
OCP has a cost: abstractions, more files, more wiring, and sometimes less straightforward control flow. If you only have one rule and no realistic sign of variation, designing an extension point up front is speculative. Good engineers apply OCP to places that change often or where new cases are expected.

A strong interview answer mentions this trade-off. OCP is about planned extension around known change axes, not about abstracting everything “just in case.” In modern C#, composition plus focused interfaces is usually the best default, while inheritance should be used more carefully.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

namespace OopAndDesign.OcpSample;

// Before: a single PriceCalculator with a growing switch on customer type.
// After: each discount rule is a separate strategy.

public sealed record Order(decimal Total, string CustomerType);

public interface IDiscountStrategy
{
    string CustomerType { get; }
    decimal Apply(decimal total);
}

public sealed class RegularDiscountStrategy : IDiscountStrategy
{
    public string CustomerType => "Regular";
    public decimal Apply(decimal total) => total;
}

public sealed class VipDiscountStrategy : IDiscountStrategy
{
    public string CustomerType => "VIP";
    public decimal Apply(decimal total) => total * 0.90m;
}

public sealed class BlackFridayDiscountStrategy : IDiscountStrategy
{
    public string CustomerType => "BlackFriday";
    public decimal Apply(decimal total) => total * 0.75m;
}

public sealed class PriceCalculator(IEnumerable<IDiscountStrategy> strategies)
{
    private readonly Dictionary<string, IDiscountStrategy> _strategies =
        strategies.ToDictionary(strategy => strategy.CustomerType, StringComparer.OrdinalIgnoreCase);

    public decimal Calculate(Order order)
    {
        if (!_strategies.TryGetValue(order.CustomerType, out var strategy))
        {
            throw new InvalidOperationException($"No discount strategy for '{order.CustomerType}'.");
        }

        return strategy.Apply(order.Total); // Extension happens by adding a new strategy class.
    }
}

public static class Program
{
    public static void Main()
    {
        var calculator = new PriceCalculator([
            new RegularDiscountStrategy(),
            new VipDiscountStrategy(),
            new BlackFridayDiscountStrategy()
        ]);

        var finalTotal = calculator.Calculate(new Order(200m, "VIP"));
        Console.WriteLine($"Final total: {finalTotal:C}");
    }
}
```

## Common Follow-up Questions
- When would you use inheritance instead of composition for OCP?
- Is a `switch` statement always an OCP violation?
- How does the Strategy pattern help with OCP?
- What are the downsides of over-applying OCP?
- How would you implement OCP in ASP.NET Core with DI?

## Common Mistakes / Pitfalls
- Claiming OCP means existing code must never be edited again.
- Building extension points before there is any realistic variation.
- Using inheritance by default and ending up with a fragile base class hierarchy.
- Hiding business rules inside a service locator instead of modeling explicit strategies.
- Replacing a simple, stable conditional with unnecessary abstraction.

## References
- [Architectural principles for modern web applications with Azure](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles)
- [Inheritance in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/inheritance)
- [Polymorphism in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/polymorphism)
- [Strategy pattern](https://refactoring.guru/design-patterns/strategy)
