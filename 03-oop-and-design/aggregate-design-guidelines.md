# Aggregate Design Guidelines

**Category:** OOP & Design / Domain-Driven Design
**Difficulty:** 🔴 Senior
**Tags:** `DDD`, `aggregate`, `eventual-consistency`, `design`

## Question
> What are the main aggregate design guidelines in DDD, why are small aggregates preferred, and how do you handle eventual consistency and compensation between aggregates?

## Short Answer
Good aggregate design starts with invariants: objects that must change together consistently belong together, and everything else should be kept outside the boundary. Small aggregates are preferred because they reduce contention, simplify transactions, and improve throughput. When different aggregates need to react to each other, you usually coordinate them with eventual consistency using domain events, and sometimes add compensation logic when a later step fails.

## Detailed Explanation
### Start from invariants, not object graphs
A strong aggregate design rule is to model around consistency requirements, not around database relationships or navigation convenience. If several pieces of state must always be valid together immediately after an operation, they likely belong to the same aggregate. If they can be reconciled later, they should probably be separate aggregates.

This is why aggregate design often feels smaller than a relational model. A large database schema does not imply one large aggregate.

### Why small aggregates are preferred
Small aggregates reduce the amount of data loaded and locked for each command. They also reduce write contention because fewer users or processes compete for the same consistency boundary. That becomes especially important in distributed systems or high-throughput domains.

Large aggregates create several problems: bigger transactions, more concurrency conflicts, slower persistence, and temptation to allow direct child mutation to avoid loading the full graph. They also make caching and scaling harder.

| Guideline | Why it helps | Typical outcome |
| --- | --- | --- |
| Keep aggregates small | Less contention and faster transactions | Better throughput |
| Enforce invariants in the root | One place for consistency rules | Safer behavior |
| Reference other aggregates by ID | Clear boundaries and smaller graphs | Lower coupling |
| Prefer eventual consistency across boundaries | Avoid giant transactions | Better scalability |

### Eventual consistency between aggregates
When one aggregate changes and another must react, you usually do not put both in one transaction unless the rule truly demands immediate consistency. Instead, the first aggregate emits a domain event. The application layer handles it and updates other aggregates or publishes integration events.

For example, when an order is submitted, the `Order` aggregate can emit `OrderSubmitted`. A handler may reserve inventory in a separate `InventoryItem` aggregate. For a short time, the system may show the order as submitted while reservation is still processing. That is eventual consistency.

### Compensation and failure handling
If a later step fails, you often need compensation instead of rollback. In distributed or asynchronous workflows, the original transaction has already committed. Compensation means performing a new business action to counterbalance the earlier one, such as canceling a reservation, reopening a payment authorization, or marking an order as pending review.

This is a business decision, not just a technical retry. The compensating action should reflect what the domain wants to happen after a partial failure.

> Warning: do not use eventual consistency for rules that absolutely must hold immediately, such as “do not allow the same seat to be sold twice” unless you also have a design that preserves that guarantee safely.

### Trade-offs
Small aggregates improve scalability and maintainability, but they require more careful thinking about asynchronous workflows, retries, idempotency, and user expectations. Strong consistency is simpler to reason about but can force large, slow, and highly contended transaction boundaries.

Senior-level design is about choosing the minimum consistency boundary that preserves important invariants without collapsing the whole model into a single transaction.

### Practical rules of thumb
Design one transaction per aggregate modification. Use optimistic concurrency. Publish domain events for cross-aggregate coordination. Keep handlers idempotent. Add compensation only where the business cares about reversing or correcting prior actions.

## Code Example
```csharp
namespace DomainDrivenDesignSamples;

public interface IDomainEvent;
public sealed record OrderSubmitted(Guid OrderId) : IDomainEvent;

public sealed class Order
{
    private readonly List<IDomainEvent> _events = [];

    public Order(Guid id) => Id = id;

    public Guid Id { get; }
    public bool IsSubmitted { get; private set; }
    public IReadOnlyCollection<IDomainEvent> Events => _events;

    public void Submit()
    {
        if (IsSubmitted)
        {
            throw new InvalidOperationException("Order already submitted.");
        }

        IsSubmitted = true;
        _events.Add(new OrderSubmitted(Id)); // Another aggregate can react later.
    }
}

public sealed class InventoryItem(Guid productId, int availableUnits)
{
    public Guid ProductId { get; } = productId;
    public int AvailableUnits { get; private set; } = availableUnits;

    public void Reserve(int quantity)
    {
        if (quantity > AvailableUnits)
        {
            throw new InvalidOperationException("Not enough stock.");
        }

        AvailableUnits -= quantity;
    }
}

public static class Program
{
    public static void Main()
    {
        var order = new Order(Guid.NewGuid());
        order.Submit();

        foreach (var domainEvent in order.Events)
        {
            Console.WriteLine(domainEvent); // Application layer would coordinate follow-up work.
        }
    }
}
```

## Common Follow-up Questions
- How do you identify whether two objects belong in the same aggregate?
- Why are large aggregates bad for optimistic concurrency?
- When is eventual consistency unacceptable?
- What is compensation, and how is it different from rollback?
- How do you make cross-aggregate handlers idempotent?
- Can a single command modify multiple aggregates?

## Common Mistakes / Pitfalls
- Designing aggregates to match database foreign keys instead of business invariants.
- Building oversized aggregates to avoid dealing with eventual consistency.
- Using eventual consistency for rules that actually require immediate guarantees.
- Forgetting retries, idempotency, and duplicate-message handling in cross-aggregate workflows.
- Treating compensation as a technical undo instead of a business decision.

## References
- [Microservice domain model](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- [Domain events: design and implementation](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation)
- [The Aggregate Pattern](https://www.dddcommunity.org/wp-content/uploads/files/pdf_articles/Vernon_2011_1.pdf)
- [Saga distributed transactions pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/saga)
