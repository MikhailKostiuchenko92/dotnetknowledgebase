# Aggregate Pattern

**Category:** OOP & Design / Domain-Driven Design
**Difficulty:** 🔴 Senior
**Tags:** `DDD`, `aggregate`, `consistency`, `invariants`

## Question
> What is an aggregate in Domain-Driven Design, why is the aggregate root important, and why should other aggregates reference it by ID instead of by object reference?

## Short Answer
An aggregate is a cluster of domain objects treated as one consistency boundary for updates. The aggregate root is the only object that outside code should load or modify directly, because it enforces invariants for the whole aggregate. Other aggregates should usually reference it by ID so boundaries stay explicit, transactions stay small, and separate aggregates can evolve independently.

## Detailed Explanation
### What an aggregate really is
An aggregate is not just a parent entity with children. In DDD, it is a transactional consistency boundary. Inside that boundary, the aggregate root is responsible for protecting invariants, coordinating changes, and ensuring the aggregate never enters an invalid state after a completed operation.

For example, an `Order` aggregate may contain `OrderLine` items. Rules like “an order must contain at least one line before submission” or “the total must equal the sum of its lines” belong inside that aggregate. Outside code should not modify `OrderLine` objects independently because that could bypass the rules.

### Why the aggregate root matters
The aggregate root is the gateway. Clients load the root, call domain methods on it, and persist it as a unit. That gives one place where business invariants are enforced.

Without a root, other parts of the system can mutate internals directly. That usually leads to anemic models, duplicated validation, and inconsistent data. A well-designed root exposes intention-revealing methods such as `AddLine`, `Submit`, or `Cancel`, not arbitrary setters.

| Concept | Purpose | Typical rule |
| --- | --- | --- |
| Aggregate | Consistency boundary | Change together in one transaction |
| Aggregate root | Entry point and guardian | Outside code talks to root only |
| Invariant | Business rule that must always hold | Total must match line items |
| Cross-aggregate reference | Relationship across boundaries | Reference by ID, not object graph |

### Why cross-aggregate references should be by ID
A common senior-level point is that other aggregates should reference an aggregate root by ID instead of holding a live object reference. This keeps boundaries clean. If `Shipment` holds a direct `Order` object and `Invoice` also navigates into `Order`, you effectively create one huge graph that is hard to load, hard to persist, and easy to break.

Referencing by ID has several benefits:
- it prevents accidental modification of another aggregate’s internals;
- it avoids large object graphs and expensive ORM tracking;
- it encourages separate transactions and eventual consistency where appropriate;
- it makes aggregate ownership and boundaries obvious in the code.

> Warning: if two objects must always be updated atomically to preserve a rule, they may belong in the same aggregate. If they can change independently and synchronize later, they should likely be separate aggregates.

### Internals: consistency and transaction size
Aggregates are intentionally small. Every command that modifies an aggregate should be able to load it, enforce invariants, and save it in a single transaction. If an aggregate grows too large, contention increases, concurrency conflicts become common, and performance suffers.

This is why “one aggregate per entire business concept” is often wrong. A customer, order history, loyalty ledger, and shipping preferences may all belong to different aggregates even if they are related in the business.

### Trade-offs and when not to overuse aggregates
Strong consistency inside an aggregate is valuable, but over-modeling can hurt. If you put too much inside one aggregate, every change becomes heavier. If you split too aggressively, important invariants may leak across boundaries and become eventually consistent when they should not be.

The design question is: which rules truly must hold immediately after each transaction? Those rules define aggregate boundaries.

### Practical guidance
Design commands around business behavior, not setters. Keep aggregates focused. Persist and version them independently. Use domain events to coordinate changes across aggregates instead of navigating large in-memory graphs.

## Code Example
```csharp
namespace DomainDrivenDesignSamples;

public sealed record ProductId(Guid Value);

public sealed class Order
{
    private readonly List<OrderLine> _lines = [];

    public Order(Guid id)
    {
        Id = id;
    }

    public Guid Id { get; }
    public IReadOnlyCollection<OrderLine> Lines => _lines;
    public bool IsSubmitted { get; private set; }

    public void AddLine(ProductId productId, int quantity)
    {
        if (IsSubmitted)
        {
            throw new InvalidOperationException("Submitted orders cannot be changed.");
        }

        if (quantity <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(quantity));
        }

        _lines.Add(new OrderLine(productId, quantity)); // Modify children through the root.
    }

    public void Submit()
    {
        if (_lines.Count == 0)
        {
            throw new InvalidOperationException("Order must contain at least one line.");
        }

        IsSubmitted = true;
    }
}

public sealed record OrderLine(ProductId ProductId, int Quantity);

public sealed class Shipment(Guid id, Guid orderId) // Reference another aggregate by ID.
{
    public Guid Id { get; } = id;
    public Guid OrderId { get; } = orderId;
}

public static class Program
{
    public static void Main()
    {
        var order = new Order(Guid.NewGuid());
        order.AddLine(new ProductId(Guid.NewGuid()), 2);
        order.Submit();

        var shipment = new Shipment(Guid.NewGuid(), order.Id);
        Console.WriteLine($"Shipment created for order {shipment.OrderId}");
    }
}
```

## Common Follow-up Questions
- How do you find the right aggregate boundary?
- Why are small aggregates preferred in high-throughput systems?
- When is eventual consistency acceptable between aggregates?
- What is the difference between an entity and an aggregate root?
- How do optimistic concurrency and aggregates relate?
- When would two concepts that look separate actually belong in one aggregate?

## Common Mistakes / Pitfalls
- Treating an aggregate as just an ORM object graph instead of a consistency boundary.
- Allowing external code to mutate child entities directly and bypass invariants.
- Using object references between aggregates, creating giant graphs and hidden coupling.
- Making aggregates too large, which increases lock time, contention, and concurrency conflicts.
- Splitting aggregates so aggressively that critical invariants can no longer be enforced transactionally.

## References
- [Design a microservice domain model](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- [Martin Fowler - Aggregate](https://martinfowler.com/bliki/DDD_Aggregate.html)
- [The Aggregate Pattern](https://www.dddcommunity.org/wp-content/uploads/files/pdf_articles/Vernon_2011_1.pdf)
- [Implementing domain entities](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/seedwork-domain-model-base-classes-interfaces)
