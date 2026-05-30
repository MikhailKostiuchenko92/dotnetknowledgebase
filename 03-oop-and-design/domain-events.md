# Domain Events

**Category:** OOP & Design / Domain-Driven Design
**Difficulty:** 🔴 Senior
**Tags:** `DDD`, `domain-events`, `integration-events`, `MediatR`

## Question
> What are domain events, how are they different from integration events, and where should they be raised and dispatched in a DDD application using tools like MediatR?

## Short Answer
A domain event represents something important that already happened inside the domain, such as `OrderPlaced` or `CreditLimitExceeded`. It is different from an integration event, which is a message published to other bounded contexts or external systems. In a typical DDD design, the domain raises events inside entities or aggregates, while the application layer dispatches them after persistence, often using MediatR and sometimes an outbox for reliable external publication.

## Detailed Explanation
### What a domain event is
A domain event is a past-tense statement about a meaningful business fact. It captures something the domain cares about, not a technical callback. Examples include `InvoiceIssued`, `PaymentCaptured`, or `CustomerRegistered`. The main benefit is decoupling: the aggregate that causes the event does not need to know all the downstream reactions.

Instead of putting every side effect directly inside an aggregate method, the aggregate can record that something happened. Later, handlers can update read models, send emails, start workflows, or trigger policies.

### Domain events vs integration events
The distinction is critical in interviews. Domain events live inside a bounded context and express internal domain facts. Integration events are contracts for communication with other contexts, services, or external systems.

| Aspect | Domain Event | Integration Event |
| --- | --- | --- |
| Scope | Inside one bounded context | Between contexts or systems |
| Purpose | Decouple internal domain reactions | Communicate across boundaries |
| Timing | Often raised during command handling | Usually published after commit |
| Shape | Rich domain language | Stable external contract |
| Reliability concerns | In-process consistency | Delivery, retries, idempotency |

A common implementation is to handle a domain event internally and then translate it into an integration event if external communication is needed.

### Where events should be raised
In DDD, domain events are usually raised inside the domain model, most often by aggregates. That is where the business fact becomes true. For example, when `Order.Submit()` succeeds, the aggregate can add an `OrderSubmitted` event to an internal collection.

This keeps the event close to the business rule. If you only create events in controllers or handlers, you risk forgetting them or publishing them when the domain change did not really happen.

### Where events should be dispatched
Dispatching is usually not a domain concern. The application layer coordinates persistence, transaction boundaries, and message handling infrastructure. A common flow is:
1. load aggregate;
2. call domain method;
3. save changes;
4. dispatch collected domain events.

This separation matters because the domain should not depend on MediatR, EF Core, or a message broker. The application layer can extract events from tracked aggregates and publish them through MediatR notifications.

> Warning: if you publish external messages before the database commit succeeds, you can create ghost events for changes that never persisted. This is why integration events usually need an outbox or equivalent reliable delivery mechanism.

### MediatR and practical .NET usage
MediatR is often used as an in-process dispatcher. A domain event can implement `INotification`, or you can map domain event objects to notifications in the application layer. Handlers then react independently. This works well for internal policies such as sending a confirmation email, creating a read model entry, or starting another use case.

For external publication, many teams convert a domain event into an integration event and store it in an outbox table in the same transaction. A background worker then publishes it reliably.

### Trade-offs and when not to use them
Domain events improve decoupling and extensibility, but they also make flow less obvious. Debugging can be harder because behavior is distributed across handlers. Overusing events for simple direct collaboration can also make a codebase noisy.

Use domain events for meaningful business facts and important reactions. Do not use them as a generic replacement for normal method calls.

## Code Example
```csharp
namespace DomainDrivenDesignSamples;

public interface IDomainEvent;

public sealed record OrderSubmitted(Guid OrderId) : IDomainEvent;

public sealed class Order
{
    private readonly List<IDomainEvent> _domainEvents = [];

    public Order(Guid id) => Id = id;

    public Guid Id { get; }
    public bool IsSubmitted { get; private set; }
    public IReadOnlyCollection<IDomainEvent> DomainEvents => _domainEvents;

    public void Submit()
    {
        if (IsSubmitted)
        {
            throw new InvalidOperationException("Order is already submitted.");
        }

        IsSubmitted = true;
        _domainEvents.Add(new OrderSubmitted(Id)); // Raise inside the domain.
    }

    public void ClearDomainEvents() => _domainEvents.Clear();
}

public static class Program
{
    public static void Main()
    {
        var order = new Order(Guid.NewGuid());
        order.Submit();

        foreach (var domainEvent in order.DomainEvents)
        {
            Console.WriteLine(domainEvent); // Application layer would dispatch via MediatR.
        }

        order.ClearDomainEvents();
    }
}
```

## Common Follow-up Questions
- Why should domain events usually be raised in the domain but dispatched in the application layer?
- When should a domain event become an integration event?
- What problem does the outbox pattern solve?
- How do you make event handlers idempotent?
- Can domain event handlers update another aggregate?
- What are the downsides of using MediatR everywhere?

## Common Mistakes / Pitfalls
- Publishing integration events directly from entities or aggregates.
- Treating domain events as mere technical callbacks instead of meaningful business facts.
- Dispatching external messages before the transaction commits.
- Letting the domain layer depend directly on MediatR or message-broker APIs.
- Creating too many tiny event handlers so business flow becomes hard to trace.

## References
- [Domain events: design and implementation](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation)
- [Integration events](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/multi-container-microservice-net-applications/integration-event-based-microservice-communications)
- [MediatR](https://github.com/jbogard/MediatR)
- [Transactional Outbox](https://microservices.io/patterns/data/transactional-outbox.html)
