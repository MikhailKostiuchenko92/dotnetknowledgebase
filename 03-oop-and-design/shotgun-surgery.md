# Shotgun Surgery

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🟡 Middle
**Tags:** `shotgun-surgery`, `code-smell`, `SRP`, `refactoring`

## Question
> What is shotgun surgery, and why does a small business change sometimes force edits across controllers, services, repositories, and UI code?

## Short Answer
Shotgun surgery is a code smell where one logical change requires many small edits scattered across the system. It usually means a responsibility is split across the wrong boundaries, so the code changes together but is not located together. The fix is to centralize the changing concept behind one abstraction and refactor incrementally, often using SRP, Extract Class, and Move Method.

## Detailed Explanation
### What the smell looks like
If a single rule change sends you on a repo-wide search-and-replace trip, that is shotgun surgery. A new tax rule might require updates in controllers, pricing services, export jobs, report formatters, and validation code. The problem is not simply that several layers are involved; the problem is that one concept has been duplicated or partially embedded in many places.

| Situation | Healthy design | Shotgun surgery smell |
| --- | --- | --- |
| One pricing rule changes | Update one policy/service | Update many unrelated files |
| One validation rule changes | Update one validator/value object | Touch controller, service, DB mapper, UI |
| One output format changes | Update one formatter | Edit every caller manually |

The deeper issue is usually an SRP violation. Code that should change for one reason has been spread across multiple modules that have other reasons to change as well.

### Why it happens
Shotgun surgery often appears after copy-paste optimization. A rule is added in one place, then duplicated “just for now” in another layer. Over time, different parts of the system each own a slice of the same concept. Another cause is leaky architecture: presentation, application, and domain layers all know too much about the same business rule.

This smell increases risk because developers must remember every location that needs updating. Missing one location creates inconsistent behavior, which is often worse than a total failure because it may only affect some paths.

> Warning: not every multi-file change is shotgun surgery. Real cross-cutting concerns sometimes require coordinated edits. The smell is about unnecessary scattering of one concept, not about any change that spans layers.

### How to fix it
Start by naming the thing that changes together. Is it a discount policy, a tax rule, a formatting strategy, or a validation concept? Then move the logic behind one stable abstraction. That might be a value object, a policy class, a strategy, or a domain method.

The key refactorings are usually:
- **Extract Class** for the shared responsibility.
- **Move Method** to the object that owns the rule.
- **Introduce Interface/Strategy** if multiple variants exist.

After centralization, callers should depend on the abstraction, not re-implement the rule. That turns a scattered set of edits into one focused change.

### Practical interview framing
A good answer connects the smell to change coupling. Modules that change together should usually be designed together. Shotgun surgery is the signal that the architecture does not line up with the way the business evolves.

## Code Example
```csharp
using System;

namespace InterviewKnowledgeBase.OopAndDesign;

internal static class Program
{
    private static void Main()
    {
        var policy = new TaxPolicy(0.20m);
        var service = new InvoiceService(policy);
        var exporter = new InvoiceExporter(policy);

        Console.WriteLine(service.CalculateTotal(100m));
        Console.WriteLine(exporter.Export(100m));
    }
}

internal sealed class TaxPolicy(decimal rate)
{
    public decimal Apply(decimal netAmount) => netAmount * (1 + rate); // One place to change the rule.
}

internal sealed class InvoiceService(TaxPolicy taxPolicy)
{
    public decimal CalculateTotal(decimal netAmount) => taxPolicy.Apply(netAmount);
}

internal sealed class InvoiceExporter(TaxPolicy taxPolicy)
{
    public string Export(decimal netAmount) => $"Exported total: {taxPolicy.Apply(netAmount):0.00}";
}
```

## Common Follow-up Questions
- How is shotgun surgery related to SRP and cohesion?
- What is the difference between shotgun surgery and divergent change?
- Which refactorings help most when you see this smell?
- Why is copy-paste business logic a common cause?
- How do you tell the difference between valid cross-cutting change and a real smell?

## Common Mistakes / Pitfalls
- Calling every multi-file change shotgun surgery even when the architecture legitimately spans concerns.
- Creating an abstraction with the right name but leaving duplicated logic in place.
- Refactoring too broadly instead of first centralizing the exact thing that changes.
- Hiding scattered rules behind static helpers that do not really restore ownership.
- Ignoring tests and missing one behavior path during consolidation.

## References
- [Shotgun Surgery](https://refactoring.guru/smells/shotgun-surgery)
- [Single Responsibility Principle](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles)
- [Move Method](https://refactoring.guru/move-method)
- [Extract Class](https://refactoring.guru/extract-class)
