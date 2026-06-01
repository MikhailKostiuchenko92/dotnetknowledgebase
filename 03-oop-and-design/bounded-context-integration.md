# Bounded Context Integration

**Category:** OOP & Design / Domain-Driven Design
**Difficulty:** 🔴 Senior
**Tags:** `DDD`, `bounded-context`, `context-map`, `integration`

## Question
> How do bounded contexts integrate in DDD, and what context map patterns such as shared kernel, anti-corruption layer, open host service, and published language are used to manage those integrations?

## Short Answer
Bounded contexts integrate through explicit translation and relationship patterns, not by sharing one giant model. A context map describes those relationships and clarifies how models, teams, and contracts influence each other. Patterns like shared kernel, anti-corruption layer, open host service, and published language help teams balance reuse, autonomy, and coupling.

## Detailed Explanation
### Why context integration matters
DDD encourages separate bounded contexts because different parts of a business often need different models. But those contexts still need to collaborate. The risk is that integration pressure slowly erases boundaries and pushes teams back toward one shared, confusing model.

A context map documents how bounded contexts relate, which side influences the other, and what integration style is used. It is as much an organizational and language tool as it is a technical one.

### Shared kernel
A shared kernel is a small, explicitly shared part of the model used by two or more teams. It can work when the shared concepts are stable and the teams coordinate closely. The benefit is reduced duplication for a truly common core.

The downside is coupling. Any change to the shared kernel requires coordination, versioning discipline, and trust between teams. If the shared part grows too much, it becomes a stealth monolith.

### Anti-corruption layer, open host service, and published language
An anti-corruption layer protects one context from another context’s model. Instead of importing external types directly, the consuming context translates them into its own concepts. This is especially useful when integrating with legacy systems, vendor software, or upstream contexts with different semantics.

An open host service exposes a well-defined protocol for other contexts to consume. A published language is the shared contract or vocabulary used in that integration, such as a stable set of message schemas, API formats, or event contracts.

| Pattern | Main benefit | Main risk |
| --- | --- | --- |
| Shared kernel | Reuse of truly common concepts | Tight coupling between teams |
| Anti-corruption layer | Protects domain language and autonomy | Extra translation code |
| Open host service | Stable public integration surface | Versioning and compatibility burden |
| Published language | Shared contract for many consumers | Governance can slow change |

### Trade-offs and when to choose each
A shared kernel fits only when the shared model is small and both teams can coordinate closely. An ACL is safer when one side is legacy, vendor-controlled, or semantically different. Open host service and published language fit when one context intentionally serves many consumers and wants a stable external contract.

> Warning: the mistake is not choosing the “wrong pattern name.” The mistake is integrating bounded contexts casually through shared tables, copied DTOs, or leaked domain entities until boundaries become meaningless.

The senior-level answer is to tie the choice to team autonomy, rate of change, and failure tolerance—not to pattern popularity.

## Code Example
```csharp
using System;

namespace DomainDrivenDesignSamples;

// Published language from another context.
public sealed record BillingInvoiceCreated(string InvoiceNumber, decimal TotalAmount);

// Our context model.
public sealed record InvoiceId(string Value);
public sealed record Money(decimal Amount, string Currency);

public sealed class AccountingAcl
{
    public AccountingInvoice Translate(BillingInvoiceCreated message)
    {
        // Translate foreign terms into our own model.
        return new AccountingInvoice(new InvoiceId(message.InvoiceNumber), new Money(message.TotalAmount, "USD"));
    }
}

public sealed class AccountingInvoice(InvoiceId id, Money total)
{
    public InvoiceId Id { get; } = id;
    public Money Total { get; } = total;
}

public static class Program
{
    public static void Main()
    {
        var message = new BillingInvoiceCreated("INV-2025-001", 150m);
        var invoice = new AccountingAcl().Translate(message);

        Console.WriteLine($"{invoice.Id.Value}: {invoice.Total.Amount} {invoice.Total.Currency}");
    }
}
```

## Common Follow-up Questions
- When is a shared kernel a good idea, and when is it dangerous?
- How is a published language different from the internal domain model?
- Why is an anti-corruption layer more than a mapper?
- How do open host services relate to public APIs or event contracts?
- Can two bounded contexts use the same words but mean different things?
- How do organizational team boundaries affect context maps?

## Common Mistakes / Pitfalls
- Sharing domain classes directly across bounded contexts to “save time.”
- Letting a shared kernel grow until it becomes a hidden monolith.
- Treating an ACL as only field-to-field mapping without conceptual translation.
- Exposing internal entities directly as public integration contracts.
- Forgetting versioning and compatibility when defining a published language.

## References
- [Bounded Context](https://martinfowler.com/bliki/BoundedContext.html)
- [Ubiquitous Language](https://martinfowler.com/bliki/UbiquitousLanguage.html)
- [Anti-Corruption Layer](https://learn.microsoft.com/en-us/azure/architecture/patterns/anti-corruption-layer)
- [DDD Resources](https://www.domainlanguage.com/ddd/)
