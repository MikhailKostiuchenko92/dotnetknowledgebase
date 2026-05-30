# What is an Anemic Domain Model?

**Category:** OOP & Design / Anti-Patterns & Code Smells
**Difficulty:** 🟡 Middle
**Tags:** `anemic-domain-model`, `DDD`, `anti-pattern`, `rich-domain-model`

## Question
> What is an anemic domain model, how is it different from a rich domain model, and when is it a problem?

## Short Answer
An anemic domain model has domain objects that mostly hold data while behavior lives in services around them. That often leads to service bloat, weak invariants, and domain rules scattered across the application. In DDD, a richer model is usually preferred for complex domains, but simple CRUD-style systems may not need it.

## Detailed Explanation
### What it is
Martin Fowler's term **Anemic Domain Model** describes a model that looks object-oriented on the surface but behaves like a set of DTOs. Entities expose fields or setters, while business logic lives in services such as `OrderService`, `CustomerManager`, or `InvoiceProcessor`. The objects hold state, but they do not protect or use that state meaningfully.

A **rich domain model** does the opposite: it puts business rules and invariants close to the data they govern. For example, an `Order` should know how to add a line, calculate totals, or reject cancellation after shipment. That keeps behavior and state together.

| Model style | Where business rules live | Typical result |
| --- | --- | --- |
| Anemic | Application/domain services | Services grow, entities stay passive |
| Rich | Entities and value objects | Invariants are enforced near the data |

### Why teams end up with it
Anemic models often appear when teams map database tables directly to classes and then put all logic into services. ORMs can encourage this style if developers think of entities as persistence containers first and domain concepts second. It can also happen when teams misunderstand layering and assume entities should be "just data" while all behavior belongs in services.

The danger is not merely aesthetics. If every rule lives in services, the services become procedural scripts operating on bags of data. Then any caller can put an entity into an invalid state because the entity itself does not defend its invariants.

> Warning: an anemic model is not "bad because Fowler said so." It is bad when the domain is complex enough that scattered rules, duplicated validation, and weak invariants start hurting correctness.

### Why DDD pushes toward richer models
DDD focuses on modeling the core business domain. In that context, entities and value objects should represent business concepts, not just storage records. Rich models help because they make illegal states harder to represent and business language more explicit.

For example, instead of `order.Status = "Paid"`, a richer model might expose `order.MarkAsPaid(paymentReference)`. That method can validate transitions, raise domain events, and keep the aggregate consistent. This reduces service bloat and makes behavior easier to discover.

### Trade-offs and when an anemic model is acceptable
The important nuance is that **not every system needs a rich domain model**. If the application is mostly CRUD screens over simple data with minimal rules, rich entities may add ceremony without much benefit. In such cases, transaction scripts or thin services can be perfectly reasonable.

The anti-pattern label matters when the domain has meaningful rules, workflows, and invariants but the code still treats entities as passive records. That is when service classes become huge, duplicated rule checks appear in multiple use cases, and bugs show up because callers bypass the expected workflow.

### How to improve it incrementally
You do not have to redesign everything at once. Start by moving the most important invariant into the entity or value object. Introduce intention-revealing methods like `Cancel`, `AddLine`, or `ChangeAddress`. Then shrink services so they orchestrate use cases rather than implement all business behavior. That is usually the clearest interview answer: rich domain models are about **placing behavior where it belongs**, not about forcing every class to be clever.

## Code Example
```csharp
namespace InterviewKnowledgeBase.Examples;

internal static class Program
{
    private static void Main()
    {
        var anemicOrder = new AnemicOrder();
        anemicOrder.Lines.Add(new OrderLine("Laptop", 1, 1_000m));
        Console.WriteLine($"Anemic total: {AnemicOrderService.CalculateTotal(anemicOrder):C}");

        var richOrder = new RichOrder();
        richOrder.AddLine("Laptop", 1, 1_000m);
        Console.WriteLine($"Rich total: {richOrder.CalculateTotal():C}");
    }
}

internal sealed record OrderLine(string Product, int Quantity, decimal UnitPrice);

internal sealed class AnemicOrder
{
    public List<OrderLine> Lines { get; } = [];
    public bool IsCancelled { get; set; }
}

internal static class AnemicOrderService
{
    public static decimal CalculateTotal(AnemicOrder order)
    {
        // Bad: the service owns domain rules while the entity is passive data.
        if (order.IsCancelled)
        {
            throw new InvalidOperationException("Cancelled orders cannot be priced.");
        }

        return order.Lines.Sum(line => line.Quantity * line.UnitPrice);
    }
}

internal sealed class RichOrder
{
    private readonly List<OrderLine> _lines = [];
    private bool _isCancelled;

    public void AddLine(string product, int quantity, decimal unitPrice)
    {
        if (_isCancelled)
        {
            throw new InvalidOperationException("Cannot add lines to a cancelled order.");
        }

        _lines.Add(new OrderLine(product, quantity, unitPrice)); // Good: invariant stays inside the entity.
    }

    public void Cancel() => _isCancelled = true;

    public decimal CalculateTotal()
    {
        if (_isCancelled)
        {
            throw new InvalidOperationException("Cancelled orders cannot be priced.");
        }

        return _lines.Sum(line => line.Quantity * line.UnitPrice);
    }
}
```

## Common Follow-up Questions
- Why do ORMs sometimes encourage an anemic model by accident?
- When is a transaction-script style simpler than a rich domain model?
- What kinds of rules should live in entities versus application services?
- How do value objects help make a domain model richer?
- What is service bloat and how do you recognize it?
- How do aggregates relate to enforcing invariants?

## Common Mistakes / Pitfalls
- Calling every DTO-based CRUD app an anti-pattern even when the domain is trivial.
- Moving orchestration into entities and making them depend on repositories or email senders.
- Leaving setters public, which lets callers bypass the entity's rules.
- Creating a rich domain model in name only while real rules still live in services.
- Confusing domain services, which can be valid, with dumping all behavior into service classes.

## References
- [Anemic Domain Model](https://martinfowler.com/bliki/AnemicDomainModel.html)
- [Designing validations in the domain model layer](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-model-layer-validations)
- [Implementing value objects](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/implement-value-objects)
- [Common Web Application Architectures](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures)
