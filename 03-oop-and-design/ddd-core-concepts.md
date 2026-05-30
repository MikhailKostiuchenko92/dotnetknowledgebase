# DDD Core Concepts

**Category:** OOP & Design / Domain-Driven Design
**Difficulty:** 🟢 Junior
**Tags:** `DDD`, `ubiquitous-language`, `bounded-context`, `domain-model`

## Question
> What are the core concepts of Domain-Driven Design, such as ubiquitous language, bounded context, domain model, and the difference between strategic and tactical DDD?

## Short Answer
Domain-Driven Design is a way to model software around the business domain instead of around database tables or framework concerns. Its core ideas are building a shared language with domain experts, keeping each model inside a clear bounded context, and expressing business rules in a domain model. Strategic DDD is about how big parts of the system relate to each other, while tactical DDD is about the code patterns you use inside one context.

## Detailed Explanation
### What DDD is trying to solve
Domain-Driven Design, usually called DDD, is useful when the business problem is complex and the hardest part of the system is not infrastructure but understanding the domain correctly. Instead of starting from controllers, tables, or CRUD screens, DDD starts from the business language and rules. The goal is to reduce the gap between what the business means and what the code expresses.

A good interview answer should make it clear that DDD is not just a set of patterns like entities, repositories, and aggregates. Those are only tactical tools. The deeper idea is to align software with the domain so the model stays understandable and changeable.

### Ubiquitous language
Ubiquitous language means the team uses the same terms in conversations, code, documentation, tests, and UI where possible. If the business says “policy,” “quote,” “shipment,” or “settlement,” the code should usually use those terms too. That reduces translation mistakes such as one team saying “customer” while another really means “billing account.”

This is important because naming shapes design. Once the language is stable, classes, methods, and events become easier to understand, and business experts can review design decisions with less friction.

### Bounded context
A bounded context is an explicit boundary inside which a particular model and vocabulary are valid. The same word can mean different things in different contexts. For example, in an e-commerce system, “Order” in Sales may represent a customer purchase, while in Fulfillment it may represent a packing and shipping workflow.

Without bounded contexts, teams often force one large shared model across the entire system. That usually creates confusion, bloated entities, and endless compromises.

| Concept | Main question | Example |
| --- | --- | --- |
| Ubiquitous language | What words do we use? | “Order placed”, “Credit limit”, “Shipment” |
| Bounded context | Where is that language valid? | Sales vs Billing vs Fulfillment |
| Domain model | How do rules behave in code? | Order, Invoice, Money, CreditPolicy |
| Strategic DDD | How do contexts relate? | ACL, shared kernel, published language |
| Tactical DDD | How do we implement one context? | Entity, value object, aggregate, repository |

> Warning: a bounded context is not just a namespace or microservice. It is a semantic boundary around a model. A single service can contain multiple contexts, and one context can exist inside a modular monolith.

### Domain model
The domain model is the code representation of important business concepts and rules. It is more than data storage. A rich domain model contains behavior, invariants, and concepts meaningful to the business. For example, an `Order` should know whether it can be canceled, not just expose a writable `Status` property for anyone to change.

Internally, this often leads to entities, value objects, aggregates, domain services, and domain events. But the reason for using them is to protect domain rules and keep business behavior close to domain concepts.

### Strategic vs tactical DDD
Strategic DDD focuses on system-level design: finding subdomains, defining bounded contexts, and choosing how contexts integrate. This matters in larger systems because different teams and models evolve independently.

Tactical DDD focuses on implementation patterns inside one bounded context. That includes entities with identity, value objects with structural equality, aggregates as consistency boundaries, repositories for aggregate access, and domain events for important business facts.

The trade-off is that tactical patterns add structure and discipline, but they also add complexity. If the domain is simple CRUD, full DDD may be unnecessary overhead.

### When to use and when not to use DDD
DDD is most valuable in domains with complicated rules, frequent change, and costly misunderstandings, such as finance, logistics, healthcare, or pricing. It is less valuable for small apps where complexity is mostly technical rather than business-driven.

If you use DDD everywhere by default, you can overengineer simple features. If you ignore it in a complex domain, your code often becomes a thin shell over database tables and business logic leaks everywhere.

## Code Example
```csharp
namespace DomainDrivenDesignSamples;

public sealed class Money(decimal amount, string currency)
{
    public decimal Amount { get; } = amount;
    public string Currency { get; } = currency;
}

public sealed class Order
{
    private readonly List<string> _events = [];

    public Order(Guid id, Money total)
    {
        Id = id;
        Total = total;
    }

    public Guid Id { get; }
    public Money Total { get; }
    public bool IsSubmitted { get; private set; }

    public IReadOnlyCollection<string> Events => _events;

    public void Submit()
    {
        if (IsSubmitted)
        {
            throw new InvalidOperationException("Order is already submitted.");
        }

        IsSubmitted = true; // Keep the business rule inside the domain model.
        _events.Add($"OrderSubmitted:{Id}"); // A meaningful domain fact.
    }
}

public static class Program
{
    public static void Main()
    {
        var order = new Order(Guid.NewGuid(), new Money(120m, "USD"));
        order.Submit();

        Console.WriteLine($"Submitted: {order.IsSubmitted}");
        Console.WriteLine(string.Join(Environment.NewLine, order.Events));
    }
}
```

## Common Follow-up Questions
- What problem does ubiquitous language solve in real projects?
- Can one microservice contain more than one bounded context?
- What is the difference between a domain model and an anemic model?
- How do strategic and tactical DDD complement each other?
- When is DDD overkill for a project?

## Common Mistakes / Pitfalls
- Treating DDD as only a list of patterns instead of a modeling approach centered on the business domain.
- Assuming a bounded context is always identical to a team, service, or database.
- Reusing the same entity model across unrelated parts of the business because the names look similar.
- Building “DDD layers” but still keeping all business rules in controllers or service classes.
- Applying full DDD ceremony to simple CRUD modules that do not have complex domain rules.

## References
- [Domain-driven design microservice architecture](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/domain-analysis)
- [Bounded Context](https://martinfowler.com/bliki/BoundedContext.html)
- [DDD, CQRS, and Event Sourcing explained](https://www.martinfowler.com/bliki/CQRS.html)
- [Tackling Complexity in the Heart of Software](https://www.domainlanguage.com/ddd/)
