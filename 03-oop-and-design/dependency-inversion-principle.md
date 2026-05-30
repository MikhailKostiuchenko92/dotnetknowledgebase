# Dependency Inversion Principle (DIP)

**Category:** OOP & Design / SOLID
**Difficulty:** 🟢 Junior
**Tags:** `DIP`, `SOLID`, `abstractions`, `dependency-injection`

## Question
> What is the Dependency Inversion Principle, and how is it different from using a DI container in .NET?

## Short Answer
The Dependency Inversion Principle says high-level policy code should not depend directly on low-level implementation details; both should depend on abstractions. In C#, that usually means business services depend on interfaces such as repositories, gateways, or senders instead of concrete classes. A DI container helps wire those dependencies together at runtime, but the container itself is not the principle.

## Detailed Explanation
### The core idea behind DIP
DIP is often summarized in two parts: high-level modules should not depend on low-level modules, and abstractions should not depend on details. High-level modules contain business policy — the rules the system actually cares about. Low-level modules contain technical details such as SQL access, SMTP sending, file storage, or HTTP calls. If policy code directly creates and uses those details, the design becomes rigid and hard to test.

A classic example is an `OrderService` that directly new-ups `SqlOrderRepository` and `SmtpEmailSender`. That service now knows about storage and delivery technology. If you want to switch from SQL Server to an API or from SMTP to a queue, the high-level class must be edited.

### What inversion really means
The “inversion” in DIP is about the direction of source code dependencies. Without DIP, business code points downward to infrastructure details. With DIP, both business code and infrastructure code point toward an abstraction defined around business needs. For example, an `INotificationSender` interface might live near the application layer, while `EmailNotificationSender` is an infrastructure implementation.

| Design choice | Without DIP | With DIP |
| --- | --- | --- |
| High-level service | Depends on concrete classes | Depends on interfaces/abstractions |
| Change impact | Policy changes with infrastructure changes | Infrastructure can vary independently |
| Testing | Needs real dependencies or heavy setup | Easy to replace with test doubles |
| Coupling | Tight | Looser, explicit |

### DIP vs dependency injection container
This distinction matters in interviews. DIP is a design principle. Dependency injection is a technique, and a DI container is just a tool that automates object creation and wiring. You can follow DIP without any container by manually passing dependencies through constructors. You can also use a DI container and still violate DIP if your business code depends on concrete framework-heavy services everywhere.

In ASP.NET Core, the built-in container encourages constructor injection, which often helps you implement DIP. But the container does not magically create good boundaries. You still need good abstractions and good ownership of interfaces.

> Warning: adding an interface for every class is **not** DIP. If a concrete class is stable, private, and not a true variation point, an interface may add noise without improving the design.

### Why DIP helps in real systems
DIP makes systems easier to test, extend, and reason about. Tests can substitute fakes or mocks for gateways. Infrastructure concerns can evolve without rewriting core policy. Application services become easier to read because they express intent — “save invoice,” “send notification” — rather than implementation details.

It is also useful for architecture boundaries. Clean Architecture, Hexagonal Architecture, and Onion Architecture all rely on the same idea: business rules should remain independent from frameworks and external systems.

### Trade-offs and when not to overuse it
DIP introduces abstractions, and abstractions have cost. Too many interfaces can fragment the codebase, especially if the abstractions are generic and weakly named. The best abstractions are not technical wrappers around libraries; they model what the application needs.

Use DIP when a dependency is volatile, external, expensive to test, or likely to have multiple implementations. Avoid premature abstraction for leaf classes with no meaningful variation. In interviews, the best answer clearly separates the principle from the DI container and explains dependency direction rather than just saying “use constructor injection.”

## Code Example
```csharp
using System;

namespace OopAndDesign.DipSample;

public sealed record Invoice(int Id, decimal Total);

public interface IInvoiceRepository
{
    void Save(Invoice invoice);
}

public interface INotificationSender
{
    void Send(string message);
}

public sealed class ConsoleInvoiceRepository : IInvoiceRepository
{
    public void Save(Invoice invoice)
    {
        Console.WriteLine($"Saved invoice {invoice.Id} for {invoice.Total:C}.");
    }
}

public sealed class EmailNotificationSender : INotificationSender
{
    public void Send(string message)
    {
        Console.WriteLine($"Email sent: {message}");
    }
}

public sealed class InvoiceService(
    IInvoiceRepository repository,
    INotificationSender notificationSender)
{
    public void FinalizeInvoice(Invoice invoice)
    {
        repository.Save(invoice); // High-level policy depends on abstractions.
        notificationSender.Send($"Invoice {invoice.Id} was finalized.");
    }
}

public static class Program
{
    public static void Main()
    {
        // A DI container could compose this in ASP.NET Core, but manual wiring also follows DIP.
        var service = new InvoiceService(new ConsoleInvoiceRepository(), new EmailNotificationSender());
        service.FinalizeInvoice(new Invoice(42, 250m));
    }
}
```

## Common Follow-up Questions
- How is DIP different from dependency injection?
- Where should abstractions live in a layered architecture?
- When is an interface unnecessary?
- How does DIP improve testability?
- How is DIP related to Clean Architecture or Hexagonal Architecture?

## Common Mistakes / Pitfalls
- Saying DIP and DI container are the same thing.
- Creating pass-through interfaces for every class even when there is no variation point.
- Putting abstractions in the infrastructure layer so business code still depends on details.
- Injecting a service locator or `IServiceProvider` everywhere, which hides real dependencies.
- Naming abstractions after technology rather than business intent.

## References
- [Dependency injection in .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection)
- [Architectural principles for modern web applications with Azure](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/architectural-principles)
- [Interfaces in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/interfaces)
- [Strategy pattern](https://refactoring.guru/design-patterns/strategy)
