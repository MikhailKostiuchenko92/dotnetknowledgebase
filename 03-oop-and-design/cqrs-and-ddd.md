# CQRS and DDD

**Category:** OOP & Design / Domain-Driven Design
**Difficulty:** 🔴 Senior
**Tags:** `DDD`, `CQRS`, `read-model`, `write-model`, `eventual-consistency`

## Question
> How does CQRS relate to DDD, why is it often a natural consequence of rich domain modeling, and how do you handle separate read and write models with eventual consistency?

## Short Answer
CQRS separates commands that change state from queries that read state, and that often fits naturally with DDD because the write side protects domain invariants while the read side is optimized for retrieval. In a rich domain model, aggregates are usually a poor shape for UI queries, so a dedicated read model becomes attractive. The trade-off is added complexity, especially around eventual consistency, synchronization, and operational debugging.

## Detailed Explanation
### Why CQRS often appears with DDD
DDD and CQRS are different ideas, but they complement each other well. DDD focuses on modeling the write side around business behavior, invariants, and consistency boundaries. Once you do that, the write model often becomes intentionally strict and aggregate-oriented. That is great for commands, but not ideal for flexible reads.

For example, a dashboard may need denormalized data from multiple aggregates, sorted and filtered for the UI. Forcing that query through aggregate repositories can be awkward and inefficient. CQRS solves this by letting the write side and read side use different models.

### Write model vs read model
The write model handles commands and business rules. It typically uses aggregates, value objects, domain services, repositories, and domain events. The goal is correctness and consistency.

The read model serves queries. It is shaped for retrieval, not for enforcing invariants. It may use direct SQL, projections, document views, or cache-friendly DTOs.

| Side | Main goal | Typical shape |
| --- | --- | --- |
| Write model | Enforce business rules | Aggregates, commands, repositories |
| Read model | Return data efficiently | Projections, DTOs, denormalized views |
| Synchronization | Keep reads current enough | Domain events, handlers, projections |

### Why this is a natural consequence of DDD
Once aggregates are designed correctly, they are usually small and focused. That is good for transactional correctness, but not for broad read scenarios. Rather than corrupting the domain model with query-specific concerns, CQRS allows the domain to stay clean while the read side is optimized independently.

That is why many teams say CQRS is not mandatory for DDD, but it often emerges naturally in complex domains.

### Eventual consistency handling
If the read model is updated asynchronously from domain events, it will lag behind the write model for a short time. That is eventual consistency. Handling it well requires both technical and product thinking.

Common strategies include showing “processing” states, refreshing after command completion, making handlers idempotent, retrying failed projections, and designing UIs that tolerate short delays. In some cases, a query can read directly from the write store immediately after a command if strong read-after-write consistency is required for that specific screen.

> Warning: CQRS is not “use MediatR for commands and queries.” The real idea is different models and responsibilities, not just separate handler classes.

### Trade-offs and when not to use it
CQRS increases complexity: more models, more handlers, more synchronization logic, and more operational moving parts. For simple CRUD systems, the cost may outweigh the benefit. But in systems with rich business logic and demanding read scenarios, CQRS helps keep the domain model clean and the query side fast.

### Practical design guidance
Use rich aggregates for commands. Use specialized read models for queries. Synchronize through domain events or integration pipelines. Keep projections disposable and rebuildable where possible. Apply CQRS where domain complexity justifies it, not as a default architecture rule.

## Code Example
```csharp
namespace DomainDrivenDesignSamples;

public sealed class Order
{
    public Guid Id { get; } = Guid.NewGuid();
    public bool IsSubmitted { get; private set; }

    public void Submit()
    {
        if (IsSubmitted)
        {
            throw new InvalidOperationException("Order already submitted.");
        }

        IsSubmitted = true; // Write model enforces rules.
    }
}

public sealed record OrderSummary(Guid OrderId, string Status); // Read model shape.

public static class Program
{
    public static void Main()
    {
        var order = new Order();
        order.Submit();

        var readModel = new OrderSummary(order.Id, order.IsSubmitted ? "Submitted" : "Draft");
        Console.WriteLine($"{readModel.OrderId}: {readModel.Status}");
    }
}
```

## Common Follow-up Questions
- Is CQRS required to do DDD correctly?
- Why are aggregates often a poor fit for UI queries?
- How do you keep read models synchronized with write models?
- When is eventual consistency acceptable to the business?
- How do you rebuild projections safely?
- What is the difference between CQRS and event sourcing?

## Common Mistakes / Pitfalls
- Thinking CQRS only means separate command and query handlers with the same underlying model.
- Applying full CQRS to simple CRUD modules without a real need.
- Querying aggregates directly for reporting or dashboard screens and bloating the write model.
- Ignoring eventual consistency in the user experience and operational monitoring.
- Treating read model failures as harmless even when they affect business visibility.

## References
- [CQRS architecture style](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)
- [Microservice application layer: CQRS](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-application-layer-web-api-design)
- [CQRS](https://martinfowler.com/bliki/CQRS.html)
- [Domain events: design and implementation](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation)
