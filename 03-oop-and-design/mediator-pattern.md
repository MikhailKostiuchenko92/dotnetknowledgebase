# Mediator Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🟡 Middle
**Tags:** `mediator`, `behavioral`, `MediatR`, `coupling`

## Question
> What is the Mediator pattern, how does it reduce coupling, and how is a library like MediatR different from an event bus?

## Short Answer
Mediator centralizes communication between components so they do not call each other directly. Instead of one service knowing many collaborators, it sends a request or notification to a mediator, which routes it to the appropriate handler. In .NET, MediatR is a popular in-process mediator; it is not the same as an event bus because it typically coordinates communication inside one application process rather than distributing messages across services.

## Detailed Explanation
### What problem the pattern solves
The Mediator pattern reduces **many-to-many coupling**. Without it, controllers, services, validators, and handlers can become tangled because each component directly references several others. With a mediator, a sender depends on one abstraction, and the mediator forwards the message to the right handler.

This is especially useful in application layers where you want request handling to be explicit and isolated: “place order,” “cancel booking,” “get customer summary,” or “publish order created.”

| Style | Coupling shape |
| --- | --- |
| Direct calls | Many components know many other components |
| Mediator | Senders know only the mediator abstraction |

### Requests vs notifications
A strong interview answer usually mentions the two common message styles:

- **Request/response**: one logical handler returns a result.
- **Notification/event**: zero or many handlers react to a message.

MediatR models this distinction clearly with `IRequest<TResponse>` and `INotification`. That split is useful because commands and queries usually expect one owner, while domain notifications may fan out to multiple reactions such as logging, cache invalidation, or side effects.

### Mediator vs event bus
This is where candidates often blur concepts. A mediator is usually **in-process** and synchronous or locally asynchronous. An event bus is often **inter-process**, durable, and infrastructure-heavy.

| Concern | Mediator | Event bus |
| --- | --- | --- |
| Typical scope | Inside one app/process | Across services/processes |
| Delivery | In-memory dispatch | Broker/network delivery |
| Reliability concerns | Usually app-level only | Retries, ordering, durability |
| Main goal | Decouple in-process collaborators | Integrate distributed systems |

> MediatR is not RabbitMQ, Azure Service Bus, or Kafka. It solves application-layer orchestration and decoupling, not distributed messaging guarantees.

### Benefits and trade-offs
Mediator can make use cases clean: controllers become thin, handlers get focused dependencies, and cross-cutting behaviors such as validation or logging can be inserted as pipeline behaviors.

The trade-off is indirection. If overused, a codebase can become “everything is a request,” making simple flows harder to trace. Debugging can feel like message hopping instead of reading straightforward object collaboration. The pattern also does not remove business complexity; it only reorganizes it.

### When to use it
Use mediator when you want a clear application boundary and one-message-per-use-case style. It works well with CQRS, validation pipelines, and modular monoliths. Do not reach for it when a direct dependency is simpler, obvious, and stable. A service that only calls one repository and one clock may not need a mediator layer in between.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace OopAndDesign.MediatorPattern;

public interface IRequest<TResponse> { }
public interface INotification { }

public sealed record GetGreeting(string Name) : IRequest<string>;
public sealed record UserCreated(string Name) : INotification;

public interface IRequestHandler<in TRequest, TResponse> where TRequest : IRequest<TResponse>
{
    Task<TResponse> Handle(TRequest request);
}

public interface INotificationHandler<in TNotification> where TNotification : INotification
{
    Task Handle(TNotification notification);
}

public sealed class GreetingHandler : IRequestHandler<GetGreeting, string>
{
    public Task<string> Handle(GetGreeting request) => Task.FromResult($"Hello, {request.Name}!");
}

public sealed class AuditHandler : INotificationHandler<UserCreated>
{
    public Task Handle(UserCreated notification)
    {
        Console.WriteLine($"Audit: created {notification.Name}");
        return Task.CompletedTask;
    }
}

public sealed class SimpleMediator(
    IRequestHandler<GetGreeting, string> greetingHandler,
    IEnumerable<INotificationHandler<UserCreated>> userCreatedHandlers)
{
    public Task<string> Send(GetGreeting request) => greetingHandler.Handle(request);

    public async Task Publish(UserCreated notification)
    {
        foreach (var handler in userCreatedHandlers)
        {
            await handler.Handle(notification); // Fan-out for notifications.
        }
    }
}

public static class Program
{
    public static async Task Main()
    {
        var mediator = new SimpleMediator(
            new GreetingHandler(),
            new[] { new AuditHandler() });

        Console.WriteLine(await mediator.Send(new GetGreeting("Mikhail")));
        await mediator.Publish(new UserCreated("Mikhail"));
    }
}
```

## Common Follow-up Questions
- How is a mediator different from an event bus or message broker?
- When would MediatR improve a codebase, and when would it be overkill?
- What is the difference between a request and a notification?
- How do pipeline behaviors fit into the mediator approach?
- Does mediator eliminate coupling or just move it?
- How would you debug or trace mediator-heavy applications?

## Common Mistakes / Pitfalls
- Calling MediatR a distributed messaging solution.
- Creating request objects for trivial one-line operations that do not benefit from the abstraction.
- Treating notifications as guaranteed, durable integration events.
- Hiding important business flow behind too much indirection.
- Letting handlers become mini-god objects with many dependencies.

## References
- [Mediator](https://refactoring.guru/design-patterns/mediator)
- [MediatR repository](https://github.com/jbogard/MediatR)
- [Vertical Slice Architecture](https://www.jimmybogard.com/vertical-slice-architecture/)
