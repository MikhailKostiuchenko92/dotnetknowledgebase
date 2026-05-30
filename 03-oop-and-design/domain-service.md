# Domain Service

**Category:** OOP & Design / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `domain-service`, `stateless`, `domain-logic`

## Question
> What is a domain service, when should you use one, and how is it different from an application service or logic placed inside an entity or value object?

## Short Answer
A domain service holds domain logic that does not naturally belong to a single entity or value object. It is usually stateless and expresses a business operation such as pricing, currency conversion, or account transfer. An application service coordinates use cases and infrastructure, while a domain service contains business decision logic itself.

## Detailed Explanation
### Why domain services exist
DDD prefers business behavior to live inside entities and value objects when possible. That keeps the model rich and cohesive. But some rules do not belong cleanly to one object. They may involve multiple aggregates, a domain policy, or a calculation that represents business knowledge without having its own identity.

That is where a domain service fits. It captures domain logic that is still part of the business model but would be awkward or misleading if forced into an entity.

### Typical examples
Classic examples include money transfer between accounts, pricing calculations, exchange-rate policy, route planning, or credit eligibility rules. For example, if transferring money requires both source and destination accounts plus overdraft rules, putting all logic on one account may make the design asymmetric and confusing.

A good domain service has a domain-focused name such as `TransferService`, `PricingService`, or `CreditPolicyService`, not a generic technical name like `Helper` or `Manager`.

| Concern | Entity / Value Object | Domain Service | Application Service |
| --- | --- | --- | --- |
| Main responsibility | Own behavior and invariants | Domain logic spanning concepts | Orchestrate use case steps |
| Business knowledge | Yes | Yes | Usually minimal |
| Infrastructure access | Avoid | Avoid if possible | Often yes |
| State | Own state | Usually stateless | Coordinates external calls |

### Domain service vs application service
This distinction is important in interviews. An application service coordinates work: load aggregates, call domain methods, commit transaction, publish events. It defines the use case boundary. It should not become the place where all business rules accumulate.

A domain service, by contrast, answers a business question or executes business logic. If you removed infrastructure details, the domain service would still make sense to a domain expert.

For example, “transfer money from A to B if the source account can be debited” is domain logic. “Open a transaction, load accounts, call transfer, save changes, publish notification” is application logic.

### Why statelessness is preferred
Domain services are often stateless because they represent behavior, not business identity. Stateless services are simpler to reason about and easier to test. They can still depend on domain abstractions such as policy providers or exchange rate sources if needed, but the service itself should not accumulate mutable process state.

> Warning: if a so-called domain service becomes a giant class containing all business rules, you may be recreating the anemic domain model problem under a different name.

### Trade-offs and when not to use one
Do not create a domain service just because a method feels long. First ask whether the behavior belongs to an entity or value object. If it depends heavily on one entity’s state and invariants, it probably belongs there. If it is mostly orchestration of repositories, transactions, and notifications, it likely belongs in the application layer.

Use a domain service when the logic is truly domain-level but spans multiple concepts or does not have a natural home. That keeps the model expressive without forcing fake ownership.

### Practical design guideline
Start with behavior on the most relevant domain object. If that creates awkward coupling or misleading ownership, extract a domain service with a business-oriented API. Keep it small, focused, and free from infrastructure details unless unavoidable.

## Code Example
```csharp
namespace DomainDrivenDesignSamples;

public sealed class BankAccount(Guid id, decimal balance)
{
    public Guid Id { get; } = id;
    public decimal Balance { get; private set; } = balance;

    public void Debit(decimal amount)
    {
        if (amount <= 0 || Balance < amount)
        {
            throw new InvalidOperationException("Insufficient funds or invalid amount.");
        }

        Balance -= amount;
    }

    public void Credit(decimal amount)
    {
        if (amount <= 0)
        {
            throw new InvalidOperationException("Amount must be positive.");
        }

        Balance += amount;
    }
}

public sealed class TransferService
{
    public void Transfer(BankAccount source, BankAccount destination, decimal amount)
    {
        source.Debit(amount);      // Domain rule uses both accounts.
        destination.Credit(amount);
    }
}

public static class Program
{
    public static void Main()
    {
        var source = new BankAccount(Guid.NewGuid(), 500m);
        var destination = new BankAccount(Guid.NewGuid(), 100m);

        new TransferService().Transfer(source, destination, 75m);

        Console.WriteLine($"Source: {source.Balance}, Destination: {destination.Balance}");
    }
}
```

## Common Follow-up Questions
- How do you decide whether logic belongs in an entity or a domain service?
- Can a domain service depend on repositories or external APIs?
- Why are domain services usually stateless?
- What is the difference between a domain service and an application service?
- Can a domain service work across multiple aggregates?

## Common Mistakes / Pitfalls
- Moving all business logic into services and leaving entities anemic.
- Using “service” as a vague name for code that is really application orchestration.
- Adding mutable state to domain services even though the behavior is naturally stateless.
- Hiding infrastructure logic inside domain services, which makes the domain depend on technical details.
- Creating a domain service for behavior that clearly belongs inside one entity.

## References
- [Design a microservice domain model](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- [Anemic Domain Model](https://martinfowler.com/bliki/AnemicDomainModel.html)
- [Service Layer](https://martinfowler.com/eaaCatalog/serviceLayer.html)
- [Implementing domain entities](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/seedwork-domain-model-base-classes-interfaces)
