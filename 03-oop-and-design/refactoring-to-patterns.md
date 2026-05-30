# What does refactoring to patterns mean?

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🔴 Senior
**Tags:** `refactoring`, `GoF`, `strangler-fig`, `code-smells`

## Question
> How do you recognize when a GoF pattern is the right refactoring target, and how would you introduce it incrementally instead of rewriting everything?

## Short Answer
Refactoring to patterns means you do not start with a pattern and force the code into it; you let recurring smells and change pressure reveal when a pattern would simplify the design. A good engineer maps a concrete problem — such as a switch explosion, object construction complexity, or tight coupling — to a pattern that addresses that pressure. The change should be incremental: add seams, move one behavior at a time, and use approaches like strangler fig when legacy code is too risky to replace in one shot.

## Detailed Explanation
### Start with smells, not pattern names
Patterns are valuable because they solve recurring design problems, but they become harmful when treated as goals instead of tools. The right question is not "Which pattern should I use?" It is "What pain do I need to remove?"

Common mappings look like this:

| Smell or pressure | Likely pattern direction | Why it helps |
| --- | --- | --- |
| Large `switch` on behavior | Strategy / State | Replaces branching with polymorphism |
| Complex object creation | Factory Method / Builder | Isolates creation rules |
| Too many condition-based wrappers | Decorator | Adds behavior without subclass explosion |
| Legacy subsystem replacement | Facade + Strangler Fig | Creates a safe migration seam |

The senior-level insight is that patterns should emerge from refactoring pressure. If the smell disappears with a simple method extraction, you may not need a full pattern at all.

### How to recognize a good fit
A GoF pattern is a good fit when it reduces change cost, clarifies intent, and gives the variation a proper home. For example, if payment behavior changes by method and new methods keep arriving, Strategy is a strong candidate. If object construction depends on environment or feature flags, a factory may improve the design.

What you want to avoid is speculative patterning. If there are only two cases and they rarely change, a switch expression may still be the clearest solution.

> Warning: patterns should remove a concrete pain point. If they only increase indirection and vocabulary, you probably refactored too early or too far.

### Incremental refactoring approach
The safest sequence is usually:

1. Add tests around current behavior.
2. Isolate one seam, such as one `switch` or one constructor hotspot.
3. Introduce the new abstraction next to the old code.
4. Migrate one case at a time.
5. Delete the old branch only after behavior is proven equivalent.

This is especially important in legacy systems. If the subsystem is large, combine the local pattern refactor with a **strangler-fig** approach at the boundary. Route some requests to the new implementation while the old path remains available. That reduces migration risk and gives you rollback options.

### Refactoring to patterns in legacy .NET systems
In .NET applications, this often appears when replacing giant service classes, branching controllers, or legacy integration code. A façade can hide the old gateway, a strategy set can absorb behavior variation, and dependency injection can wire the new implementations cleanly. None of that requires a rewrite if you add seams carefully.

### Trade-offs
Patterns add vocabulary and structure, but also more types and more indirection. The win comes only when that structure matches real change patterns. In interviews, emphasize that the goal is not elegance by catalog; it is lower coupling, lower regression risk, and easier future change.

## Code Example
```csharp
namespace InterviewKnowledgeBase.Examples;

internal static class Program
{
    private static void Main()
    {
        Console.WriteLine(BadPaymentProcessor.Process("card", 100m));

        var facade = new PaymentFacade(
            new LegacyPaymentAdapter(),
            new StrategyPaymentProcessor([
                new CardPaymentStrategy(),
                new PayPalPaymentStrategy()
            ]));

        Console.WriteLine(facade.Process("paypal", 100m));
    }
}

internal static class BadPaymentProcessor
{
    public static string Process(string method, decimal amount)
    {
        // Bad: each new method makes this switch harder to maintain.
        return method.ToLowerInvariant() switch
        {
            "card" => $"Legacy card payment: {amount:C}",
            "paypal" => $"Legacy PayPal payment: {amount:C}",
            _ => throw new NotSupportedException($"Method '{method}' is not supported.")
        };
    }
}

internal interface IPaymentStrategy
{
    string Method { get; }
    string Process(decimal amount);
}

internal sealed class CardPaymentStrategy : IPaymentStrategy
{
    public string Method => "card";
    public string Process(decimal amount) => $"Card strategy payment: {amount:C}";
}

internal sealed class PayPalPaymentStrategy : IPaymentStrategy
{
    public string Method => "paypal";
    public string Process(decimal amount) => $"PayPal strategy payment: {amount:C}";
}

internal sealed class StrategyPaymentProcessor(IEnumerable<IPaymentStrategy> strategies)
{
    private readonly Dictionary<string, IPaymentStrategy> _strategies = strategies.ToDictionary(s => s.Method, StringComparer.OrdinalIgnoreCase);

    public string Process(string method, decimal amount) => _strategies[method].Process(amount);
}

internal sealed class LegacyPaymentAdapter
{
    public string Process(string method, decimal amount) => BadPaymentProcessor.Process(method, amount);
}

internal sealed class PaymentFacade(LegacyPaymentAdapter legacy, StrategyPaymentProcessor modern)
{
    public string Process(string method, decimal amount)
    {
        // Strangler-fig seam: only migrated methods use the new pattern-based path.
        return method.Equals("paypal", StringComparison.OrdinalIgnoreCase)
            ? modern.Process(method, amount)
            : legacy.Process(method, amount);
    }
}
```

## Common Follow-up Questions
- How do you know when a switch statement should become Strategy rather than stay a switch?
- Which patterns are most commonly introduced during legacy refactoring?
- Why is strangler fig safer than a full rewrite for large subsystems?
- How do tests guide incremental refactoring to patterns?
- What are the costs of introducing a pattern too early?
- How would you explain the difference between refactoring to patterns and pattern obsession?

## Common Mistakes / Pitfalls
- Starting from a favorite pattern instead of from a concrete smell or change pressure.
- Rewriting a whole subsystem instead of introducing one seam and migrating incrementally.
- Adding a pattern that increases indirection without reducing duplication or coupling.
- Leaving old and new paths alive forever and never deleting the legacy branch.
- Assuming a GoF pattern automatically makes the design "senior-level" regardless of fit.

## References
- [Strategy](https://refactoring.guru/design-patterns/strategy)
- [Factory Method](https://refactoring.guru/design-patterns/factory-method)
- [Switch Statements](https://refactoring.guru/smells/switch-statements)
- [Strangler Fig Application](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Strangler Fig Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig)
