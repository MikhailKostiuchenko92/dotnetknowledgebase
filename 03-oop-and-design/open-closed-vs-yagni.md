# Open/Closed Principle vs YAGNI

**Category:** OOP & Design / Trade-offs
**Difficulty:** 🔴 Senior
**Tags:** `OCP`, `YAGNI`, `abstraction`, `design-trade-offs`

## Question
> How do you balance the Open/Closed Principle with YAGNI, and when is an abstraction actually worth introducing?

## Short Answer
OCP encourages you to design for extension around likely change points, while YAGNI warns you not to build abstractions before they are justified. The balance is to introduce extension points when variation is real, repeated, and expensive to keep editing in one place. If a behavior is simple, stable, and unlikely to gain new variants soon, the simplest concrete code is usually the better choice.

## Detailed Explanation
### Why OCP and YAGNI seem to conflict
OCP says software should be open for extension and closed for modification. YAGNI says “you aren’t gonna need it,” meaning you should not build speculative flexibility. These ideas pull in opposite directions only when OCP is interpreted too aggressively. If you try to make every class extensible on day one, you usually create abstractions for imaginary futures.

The real question is not “Should I apply OCP or YAGNI?” It is “Is this a genuine axis of change?”

### When OCP is justified
OCP pays off when you already have evidence that new variants will appear. Evidence can come from repeated requirement changes, a domain that naturally supports plug-ins, or boundaries where external systems differ by environment. Examples include pricing rules by market, notification channels, file export formats, or payment providers.

| Signal | Keep it simple | Introduce an extension point |
| --- | --- | --- |
| Number of variants | One stable case | Multiple existing or imminent cases |
| Cost of change | One small edit | Repeated risky edits in stable code |
| Domain volatility | Low | Known to evolve |
| Consumer count | Local code | Shared behavior used across features |
| Testing impact | Minimal | Reopening tested code often |

### When YAGNI should win
If you have a single implementation, no history of variation, and no credible product signal that more are coming, a concrete class is often best. Engineers often over-abstract after hearing about SOLID. They introduce interfaces, factories, strategies, and registries before the code needs them. That increases ceremony and makes the happy path harder to read.

A simple `if` or `switch` can be perfectly fine when the cases are few and stable. The smell is not the syntax; the smell is repeated modification pressure on the same code path.

> Warning: speculative abstraction is technical debt too. It adds indirection, naming burden, and testing cost even before it solves a real problem.

### Practical heuristics for the balance
A useful rule is “refactor toward OCP after the change pattern becomes visible.” Often the first implementation should be straightforward. After the second or third meaningful variation, promote the varying part into a strategy or plug-in abstraction. Another good heuristic is to abstract around business volatility, not around framework usage alone.

For example, a single shipping rule does not need `IShippingCostStrategy`. But once you support domestic, international, and same-day rules, the variation is real and the abstraction starts paying rent.

### Why this matters in C# systems
ASP.NET Core and DI containers make abstraction cheap, so teams sometimes overuse interfaces. But cheap to create does not mean cheap to understand. The best C# designs evolve: start concrete, extract interfaces or strategies when tests, requirements, and change history show the need.

### Interview-ready conclusion
A strong senior answer says: apply OCP intentionally, not preemptively. Use YAGNI to resist speculative design, and use OCP once you can identify a stable extension seam with real business variation. Good design is not maximum flexibility; it is the right amount of flexibility at the right time.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

namespace OopAndDesign.OcpVsYagniSample;

/*
Before (YAGNI-friendly):
public static decimal Calculate(string destination, decimal weight) =>
    destination == "Domestic" ? 5m + weight : 15m + (weight * 2m);

After variation becomes real, promote the changing rule into strategies.
*/

public sealed record Shipment(string DestinationType, decimal WeightKg);

public interface IShippingRule
{
    string DestinationType { get; }
    decimal Calculate(Shipment shipment);
}

public sealed class DomesticShippingRule : IShippingRule
{
    public string DestinationType => "Domestic";
    public decimal Calculate(Shipment shipment) => 5m + shipment.WeightKg;
}

public sealed class InternationalShippingRule : IShippingRule
{
    public string DestinationType => "International";
    public decimal Calculate(Shipment shipment) => 15m + (shipment.WeightKg * 2m);
}

public sealed class SameDayShippingRule : IShippingRule
{
    public string DestinationType => "SameDay";
    public decimal Calculate(Shipment shipment) => 20m + (shipment.WeightKg * 3m);
}

public sealed class ShippingCalculator(IEnumerable<IShippingRule> rules)
{
    private readonly Dictionary<string, IShippingRule> _rules =
        rules.ToDictionary(rule => rule.DestinationType, StringComparer.OrdinalIgnoreCase);

    public decimal Calculate(Shipment shipment)
    {
        if (!_rules.TryGetValue(shipment.DestinationType, out var rule))
        {
            throw new InvalidOperationException($"No rule for '{shipment.DestinationType}'.");
        }

        return rule.Calculate(shipment);
    }
}

public static class Program
{
    public static void Main()
    {
        var calculator = new ShippingCalculator([
            new DomesticShippingRule(),
            new InternationalShippingRule(),
            new SameDayShippingRule()
        ]);

        Console.WriteLine(calculator.Calculate(new Shipment("SameDay", 2m)));
    }
}
```

## Common Follow-up Questions
- Is a `switch` statement always a YAGNI-friendly choice?
- What signals tell you a variation point is real enough for OCP?
- How many implementations should exist before introducing an interface?
- How does change history help decide between OCP and YAGNI?
- What are examples of harmful speculative abstraction in .NET projects?
- How do DI containers encourage both good and bad abstraction decisions?

## Common Mistakes / Pitfalls
- Treating OCP as a requirement to abstract everything from the start.
- Using YAGNI as an excuse to ignore obvious repeated variation.
- Adding interfaces around stable leaf classes with no meaningful alternative implementation.
- Replacing a simple local conditional with a complex framework of strategies too early.
- Waiting too long to extract an extension point after repeated changes already made the code brittle.

## References
- [Architectural principles for modern web applications with Azure](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles)
- [Dependency injection in .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection)
- [Strategy pattern](https://refactoring.guru/design-patterns/strategy)
- [Speculative Generality code smell](https://refactoring.guru/smells/speculative-generality)
- [YAGNI](https://martinfowler.com/bliki/Yagni.html)
