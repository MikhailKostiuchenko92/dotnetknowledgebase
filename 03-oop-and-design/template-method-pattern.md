# Template Method Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🟡 Middle
**Tags:** `template-method`, `behavioral`, `hooks`, `strategy`

## Question
> What is the Template Method pattern, and how is it different from the Strategy pattern?

## Short Answer
Template Method defines the skeleton of an algorithm in a base class and lets subclasses override selected steps without changing the overall flow. It is useful when the process is stable but some parts vary. Compared to Strategy, Template Method uses inheritance and compile-time structure, while Strategy uses composition and runtime interchangeability.

## Detailed Explanation
### What it is
Template Method is a behavioral pattern where a base class defines the high-level sequence of steps, and derived classes customize specific steps. The algorithm “shape” stays fixed, but certain operations are deferred to subclasses.

This is often described with the **Hollywood Principle**: “Don’t call us, we’ll call you.” The base class controls the workflow and invokes overridable methods at the right moments.

A typical example is an import pipeline: validate input, parse content, transform records, and save results. Every importer follows the same overall recipe, but CSV and JSON importers parse differently.

### How it works internally
The base class exposes one main method—the template method—that calls smaller methods in a particular order. Some steps are concrete and shared. Others are abstract or virtual hooks.

Common variants:
- **Abstract steps** must be implemented by subclasses.
- **Virtual hooks** are optional extension points with default behavior.
- **Non-virtual template method** protects the algorithm order from being changed accidentally.

| Pattern | Variation mechanism | Best when |
| --- | --- | --- |
| Template Method | Inheritance | Workflow is fixed, steps vary |
| Strategy | Composition | Whole algorithm should be swappable |
| Simple base class helpers | Reuse only | No real algorithm template exists |

### Why it matters
Template Method is valuable when you want consistency. The base class can enforce validation, logging, timing, or transaction boundaries, and derived classes only fill in the variable details. That prevents duplication and keeps process rules centralized.

It also makes invariants explicit. For example, if every exporter must open a connection, write a header, write rows, and flush, the template method guarantees that order.

### Strategy vs Template Method
This is a frequent interview comparison.

Use **Template Method** when the algorithm structure itself should not change and subclasses are closely related. Use **Strategy** when behavior should be selected or replaced at runtime, often through dependency injection.

Template Method is more opinionated because the base class controls flow. Strategy is more flexible because objects can be composed without inheritance.

> Template Method can create fragile base-class designs. If the base class changes carelessly, every subclass may break in subtle ways.

### Trade-offs and when not to use it
The biggest downside is inheritance coupling. Subclasses depend on the base class contract, including call order and hook semantics. Over time that can become rigid, especially if subclasses need more freedom than the template allows.

Use Template Method when:
- the process is standardized;
- only a few well-defined steps differ;
- you want the base class to enforce ordering or invariants.

Avoid it when:
- variation needs to change at runtime;
- subclasses would need to override half the base class;
- composition would keep the design more flexible.

In a strong answer, say that Template Method is about **reusing a stable workflow**, while Strategy is about **replacing behavior cleanly**.

## Code Example
```csharp
using System;

namespace OopAndDesign.TemplateMethodPattern;

public abstract class ReportExporter
{
    public void Export()
    {
        var data = LoadData();
        var formatted = FormatData(data);
        WriteHeader();
        WriteBody(formatted);
        AfterExport();
    }

    protected virtual string LoadData() => "Alice,95;Bob,88";
    protected abstract string FormatData(string rawData);
    protected abstract void WriteBody(string formattedData);

    protected void WriteHeader() => Console.WriteLine("=== Report Export ===");

    protected virtual void AfterExport()
    {
        // Optional hook for subclasses.
    }
}

public sealed class CsvReportExporter : ReportExporter
{
    protected override string FormatData(string rawData) => rawData.Replace(';', '\n');

    protected override void WriteBody(string formattedData) =>
        Console.WriteLine(formattedData);
}

public sealed class JsonReportExporter : ReportExporter
{
    protected override string FormatData(string rawData)
    {
        var rows = rawData.Split(';', StringSplitOptions.RemoveEmptyEntries);
        return "[\n  \"" + string.Join("\",\n  \"", rows) + "\"\n]";
    }

    protected override void WriteBody(string formattedData) =>
        Console.WriteLine(formattedData);

    protected override void AfterExport() => Console.WriteLine("JSON export finished.");
}

public static class Program
{
    public static void Main()
    {
        ReportExporter csv = new CsvReportExporter();
        csv.Export();

        Console.WriteLine();

        ReportExporter json = new JsonReportExporter();
        json.Export();
    }
}
```

## Common Follow-up Questions
- How is Template Method different from Strategy in practice?
- What are hooks, and why are they useful?
- When does Template Method become a fragile base class problem?
- Should the template method itself be virtual?
- How would dependency injection change this design?

## Common Mistakes / Pitfalls
- Using inheritance when composition would be simpler and more flexible.
- Making too many template steps overridable and losing control of the algorithm.
- Letting subclasses depend on undocumented side effects inside the base class.
- Creating deep inheritance hierarchies just to reuse a small amount of code.

## References
- [Template Method pattern - Refactoring.Guru](https://refactoring.guru/design-patterns/template-method)
- [Strategy pattern - Refactoring.Guru](https://refactoring.guru/design-patterns/strategy)
- [Inheritance - C# Fundamentals](https://learn.microsoft.com/dotnet/csharp/fundamentals/object-oriented/inheritance)
