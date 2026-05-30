# DDD Layers and Clean Architecture

**Category:** OOP & Design / Domain-Driven Design
**Difficulty:** 🟡 Middle
**Tags:** `DDD`, `clean-architecture`, `layers`, `architecture`

## Question
> How do the classic DDD layers map to Clean Architecture, and what responsibilities belong in the Domain, Application, Infrastructure, and UI layers?

## Short Answer
Classic DDD layers map well to Clean Architecture: the Domain layer holds business rules, the Application layer coordinates use cases, Infrastructure implements technical details, and the UI or Presentation layer handles delivery concerns like HTTP or messaging. The dependency direction should point inward, so the core business model does not depend on frameworks or databases. Clean Architecture is not a replacement for DDD; it is a structural way to protect the DDD model.

## Detailed Explanation
### The shared idea behind both approaches
DDD and Clean Architecture solve related but different problems. DDD focuses on modeling the business domain well. Clean Architecture focuses on keeping dependencies pointing toward the core so business logic remains isolated from frameworks and delivery mechanisms.

They fit naturally together. DDD gives you the model and language; Clean Architecture gives you the dependency rules that keep that model from being polluted.

### Mapping the layers
A common DDD layering approach has Domain, Application, Infrastructure, and Presentation or UI. That maps closely to Clean Architecture’s entities, use cases, interface adapters, and frameworks/drivers.

| Layer | Main responsibility | Typical contents |
| --- | --- | --- |
| Domain | Business rules and model | Entities, value objects, aggregates, domain services, domain events |
| Application | Use case orchestration | Commands, handlers, application services, transaction coordination |
| Infrastructure | Technical implementation | EF Core, repositories, email, broker, file storage |
| UI / Presentation | Input and output | Controllers, endpoints, message consumers, view models |

### Domain layer
The Domain layer is the heart of the system. It should contain the business concepts, invariants, and behaviors. This is where DDD patterns live. It should not depend on ASP.NET Core, EF Core, MediatR, or a database provider.

Internally, the Domain layer answers questions like “what is allowed?” and “how does this concept behave?” not “how is it stored?” or “how does HTTP work?”

### Application layer
The Application layer coordinates use cases. It loads aggregates through abstractions, calls domain methods, commits transactions, and dispatches domain events. It can depend on the Domain layer, but the Domain layer should not depend on it.

This layer often contains command handlers, query handlers, DTOs for use-case boundaries, and interfaces for repositories or external services. The application layer is not where core business rules should accumulate. It orchestrates; the domain decides.

### Infrastructure layer
Infrastructure contains the technical plumbing: repository implementations, EF Core mappings, email senders, payment gateway clients, caching, and message bus integration. It depends on the Application and Domain abstractions, not the other way around.

This separation makes infrastructure replaceable in principle and at least isolated in practice. Even if you never swap EF Core for something else, the real benefit is protecting the business model from infrastructure concerns.

> Warning: many projects claim to use Clean Architecture but place all business decisions in application services and leave the domain as data-only objects. That preserves directory structure, not actual architectural intent.

### UI or Presentation layer
The outermost layer receives requests and returns responses. In ASP.NET Core, this includes controllers, minimal API endpoints, filters, and request/response models. It should translate transport concerns into application requests and keep HTTP-specific details out of the core.

### Trade-offs and when not to overengineer
This structure improves testability, maintainability, and separation of concerns, but it also adds indirection. For small CRUD applications, strict layering can become ceremony. In larger or long-lived systems with meaningful business complexity, the clarity is usually worth it.

The practical balance is to keep the boundaries clear where business complexity exists, rather than enforcing maximal abstraction everywhere.

## Code Example
```csharp
namespace DomainDrivenDesignSamples;

// Domain layer
public sealed class Order
{
    public bool IsSubmitted { get; private set; }

    public void Submit()
    {
        if (IsSubmitted)
        {
            throw new InvalidOperationException("Order already submitted.");
        }

        IsSubmitted = true;
    }
}

// Application layer
public sealed class SubmitOrderHandler
{
    public void Handle(Order order)
    {
        order.Submit(); // Delegate business decision to the domain.
    }
}

// UI / Presentation layer
public static class Program
{
    public static void Main()
    {
        var order = new Order();
        var handler = new SubmitOrderHandler();

        handler.Handle(order); // In a real app, a controller or endpoint would call this.
        Console.WriteLine($"Submitted: {order.IsSubmitted}");
    }
}
```

## Common Follow-up Questions
- What should never go into the Domain layer?
- How is the Application layer different from the Domain layer?
- Where should repository interfaces and implementations live?
- Can you use Clean Architecture without DDD, or DDD without Clean Architecture?
- When is strict layering too much for a project?

## Common Mistakes / Pitfalls
- Putting EF Core annotations, HTTP models, or framework dependencies into domain entities.
- Filling the Application layer with business rules and leaving the Domain layer anemic.
- Treating the UI layer as harmless and letting it call infrastructure directly.
- Over-abstracting simple CRUD modules with unnecessary handlers and interfaces.
- Confusing folder names with real dependency rules.

## References
- [Common web application architectures](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures)
- [Clean Architecture with ASP.NET Core](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles)
- [Microservice domain model](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model)
- [The Clean Architecture](https://blog.cleancoder.com/uncle-bob/2011/11/22/Clean-Architecture.html)
