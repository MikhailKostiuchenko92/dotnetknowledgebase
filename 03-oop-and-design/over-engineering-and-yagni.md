# What is over-engineering, and how does YAGNI help avoid it?

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🔴 Senior
**Tags:** `YAGNI`, `over-engineering`, `abstraction`, `simplicity`

## Question
> What does over-engineering look like in real systems, and how does YAGNI help you decide when simplicity is better than abstraction?

## Short Answer
Over-engineering happens when we introduce abstractions, patterns, or extension points before there is real evidence that we need them. YAGNI — "You Aren't Gonna Need It" — is a reminder to build for current requirements and delay complexity until it earns its keep. Senior engineers still think ahead, but they prefer simple designs with good seams over speculative frameworks.

## Detailed Explanation
### What over-engineering looks like
Over-engineering is not just "too many classes." It is the habit of solving future problems that may never arrive. In real .NET systems, that often looks like generic repository layers over EF Core, elaborate factory hierarchies for two implementations, event buses for one process, or plug-in models before the first real plugin exists.

The problem is economic. Every abstraction has a carrying cost: more files, more indirection, more configuration, more onboarding effort, and more places for bugs to hide.

| Simpler design | Over-engineered design |
| --- | --- |
| Solves current requirement directly | Optimizes for hypothetical scenarios |
| Few moving parts | Many extension points and interfaces |
| Easy to read and debug | Requires mental jumps across layers |
| Refactors when variation appears | Predicts variation too early |

### What YAGNI really means
YAGNI does **not** mean "never think ahead." It means do not pay implementation cost for imagined flexibility before you have evidence that it is needed. Good engineers still care about future change, but they usually prepare by keeping code modular and easy to refactor rather than by adding every pattern upfront.

A useful distinction is:

- **Good foresight:** choose names, boundaries, and tests that make future refactoring easier.
- **Premature abstraction:** build factories, strategies, pipelines, and extension hooks for variations that do not yet exist.

> Warning: teams often justify over-engineering by saying "we might need it later." That is often true in theory, but the question is whether the extra complexity is cheaper now than refactoring later. Usually it is not.

### Pattern obsession and false sophistication
Senior interviews often probe this point. Knowing GoF patterns is valuable, but forcing patterns into simple problems is a smell. If you have exactly one implementation and stable requirements, an interface may communicate less than a well-named concrete class. If you support two export formats, a switch expression may be clearer than a strategy/factory registry.

Patterns are tools for pressure points, not medals for architecture sophistication.

### When simplicity wins
Simplicity usually wins when requirements are well understood, the number of variants is small, and the change rate is low or unknown. In those cases, concrete code with clear seams is often easier to maintain than a generic framework.

However, under-engineering is also possible. If variation is already present, or upcoming change is highly probable and expensive to retrofit, a small abstraction may absolutely be worth it. That is why the best answer is evidence-based, not ideological.

### Practical decision-making
A strong senior answer sounds like this: start simple, leave refactoring room, watch for real duplication or variation, then extract abstractions once they reduce total cost. That aligns with YAGNI because it favors reversible decisions and avoids locking the team into speculative complexity too early.

## Code Example
```csharp
namespace InterviewKnowledgeBase.Examples;

using System.Text.Json;

internal static class Program
{
    private static void Main()
    {
        var report = new SalesReport("Q1", 125_000m);

        Console.WriteLine(BadExporterFactory.Create("json").Export(report));
        Console.WriteLine(SimpleReportExporter.Export(report, "json"));
    }
}

internal sealed record SalesReport(string Period, decimal Revenue);

internal interface IReportExporter
{
    string Export(SalesReport report);
}

internal sealed class JsonReportExporter : IReportExporter
{
    public string Export(SalesReport report) => JsonSerializer.Serialize(report);
}

internal sealed class CsvReportExporter : IReportExporter
{
    public string Export(SalesReport report) => $"{report.Period},{report.Revenue}";
}

internal static class BadExporterFactory
{
    public static IReportExporter Create(string format)
    {
        // Bad: for two stable formats, a full factory hierarchy is often unnecessary ceremony.
        return format.ToLowerInvariant() switch
        {
            "json" => new JsonReportExporter(),
            "csv" => new CsvReportExporter(),
            _ => throw new NotSupportedException($"Format '{format}' is not supported.")
        };
    }
}

internal static class SimpleReportExporter
{
    public static string Export(SalesReport report, string format)
    {
        // Refactored: simple code wins until real variation pressure appears.
        return format.ToLowerInvariant() switch
        {
            "json" => JsonSerializer.Serialize(report),
            "csv" => $"{report.Period},{report.Revenue}",
            _ => throw new NotSupportedException($"Format '{format}' is not supported.")
        };
    }
}
```

## Common Follow-up Questions
- How do you distinguish good foresight from premature abstraction?
- When is an interface with a single implementation still justified?
- What are common examples of over-engineering in ASP.NET Core or EF Core applications?
- How does YAGNI relate to the Open/Closed Principle?
- What signals tell you that it is finally time to extract a pattern or abstraction?
- How can over-engineering increase delivery risk even when the design looks "clean"?

## Common Mistakes / Pitfalls
- Treating YAGNI as an excuse to ignore likely near-term requirements that are already visible.
- Adding generic repositories, factories, or plugin systems with no proven variation.
- Mistaking number of classes for design quality and rewarding indirection for its own sake.
- Refusing to refactor later because the team already invested in a speculative architecture.
- Calling any abstraction over-engineering even when there is clear duplication or real change pressure.

## References
- [Yagni](https://martinfowler.com/bliki/Yagni.html)
- [Beck Design Rules](https://martinfowler.com/bliki/BeckDesignRules.html)
- [Common Web Application Architectures](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures)
