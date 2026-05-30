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

### Anti-corruption layer
An anti-corruption layer protects one context from another context’s model. Instead of importing external types directly, the consuming context translates them into its own concepts. This is especially useful when integrating with legacy systems, vendor software, or upstream contexts with different semantics.

### Open host service and published language
An open host service exposes a well-defined protocol for other contexts to consume. A published language is the shared contract or vocabulary used in that integration, such as a stable set of message schemas, API formats, or event contracts.

Together, these patterns help a context present itself clearly to other contexts without exposing its internal model directly.

| Pattern | Main idea | Main trade-off |
| --- | --- | --- |
| Shared kernel | Share a small part of the model | Stronger coupling |
| Anti-corruption layer | Translate and isolate foreign models | Extra code and maintenance |
| Open host service | Offer a stable integration surface | Requires contract governance |
| Published language | Define explicit shared contract terms | Versioning and compatibility work |

### How to choose between patterns
Use a shared kernel only when the shared concepts are small, stable, and jointly owned. Use an anti-corruption layer when one model would otherwise damage another. Use an open host service when you want multiple consumers to integrate through a stable boundary. Use a published language when contract clarity matters more than internal model exposure.

> Warning: the easiest short-term integration is often direct type sharing across contexts, but that usually creates the worst long-term coupling.

### Internals and architectural consequences
These patterns affect code structure, deployment, and team autonomy. ACLs create translators and dedicated integration models. Open host services require versioned contracts and compatibility strategy. Shared kernels need coordination and careful scope control. Published languages often live in schemas, message definitions, or API contracts rather than in shared domain classes.

### Trade-offs and when not to overdesign
Not every integration needs a formal context map document, but every serious integration benefits from explicit boundary thinking. Small systems may start with simple APIs, but as teams and models diverge, explicit context mapping becomes much more valuable.

Senior-level maturity is recognizing that integration is a modeling problem, not just a transport problem.

## Code Example
```csharp
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
- [Anti-Corruption Layer](https://learn.microsoft.com/en-us/azure/architecture/patterns/anti-corruption-layer)
- [Open Host Service](https://martinfowler.com/bliki/OpenHostService.html)
- [Published Language](https://martinfowler.com/bliki/PublishedLanguage.html)
