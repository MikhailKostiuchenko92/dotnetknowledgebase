# DI as a Creational Pattern

**Category:** OOP & Design / Creational Patterns
**Difficulty:** 🔴 Senior
**Tags:** `DI`, `creational`, `factory-delegate`, `keyed-services`, `.NET8`

## Question
> In modern .NET, how can a DI container act as a creational pattern, and how do factory delegates and keyed services in .NET 8 fit into that idea?

## Short Answer
A DI container is effectively a configurable object factory: it creates object graphs, applies lifetime rules, and decides which concrete implementation satisfies an abstraction. That makes it similar to a runtime-configured Abstract Factory for the whole application. Factory delegates such as `Func<T>` or custom factory services handle runtime-dependent creation, and .NET 8 keyed services let you register multiple implementations of the same service under different keys without hard-coded `switch` logic.

## Detailed Explanation
### Why DI is creational
Classic GoF patterns describe code-level ways to create objects. A DI container solves the same problem at application scale. Instead of classes calling `new` throughout the codebase, the container owns instantiation, constructor wiring, lifetime management, and often disposal.

That is why experienced .NET developers often say the container behaves like a configurable Abstract Factory. At startup, you configure mappings such as `INotifier -> EmailNotifier`, choose singleton/scoped/transient lifetimes, and then the container builds entire object graphs on demand.

### How the container works internally
When a service is requested, the container resolves its constructor dependencies recursively, creates required child services, applies the configured lifetime, and caches instances where appropriate. In practical terms:

| DI concept | Creational interpretation |
| --- | --- |
| Service registration | Factory configuration |
| Lifetime | Creation and reuse policy |
| Resolution | Building an object graph |
| Scoped/singleton disposal | Lifecycle ownership |

This matters because object creation is rarely just “call a constructor.” In real applications it also includes choosing implementations, controlling reuse, enforcing boundaries, and disposing resources correctly.

> Warning: A DI container is a powerful factory, but if you inject the container itself everywhere and resolve services manually, you fall into the Service Locator anti-pattern.

### Factory delegates and runtime-dependent creation
Constructor injection works best when the dependency is fixed at composition time. Sometimes the exact implementation depends on runtime data such as message type, region, or feature flag. That is where factory delegates or explicit factory services help.

In .NET, you can register a delegate like `Func<string, IMessageSender>` that looks up the appropriate implementation. This keeps runtime selection in one place instead of scattering `switch` statements across the codebase. It is also more explicit than injecting `IServiceProvider` directly into business logic.

A good rule is: if you need one runtime parameter, a small factory service or delegate is acceptable; if creation rules become rich, prefer a named factory abstraction with a meaningful method.

### Keyed services in .NET 8
.NET 8 introduced keyed services, which let you register multiple implementations of the same abstraction under keys such as `"email"` and `"sms"`. This is especially useful when several implementations are valid simultaneously and the choice depends on context.

Without keyed services, developers often implemented dictionaries, manual switches, or marker interfaces. Keyed services reduce boilerplate and make the selection part of DI configuration.

That said, keyed services should not become a hidden branching mechanism everywhere. If the key logic is business-significant, a proper domain abstraction may still be clearer.

### Trade-offs and when not to use it
Using DI as your primary creational mechanism improves testability, composition, and separation of concerns. It also makes cross-cutting changes easier because composition is centralized.

The trade-off is indirection. New team members may struggle if registrations are scattered or if too much behavior is encoded in configuration. Overusing factories and keys can also hide what the system actually does.

Do not use the container as a universal runtime lookup API from arbitrary places in the code. Prefer constructor injection first, then a focused factory when runtime variability is real. In interviews, the strong answer is: DI is the default creational mechanism in modern .NET applications, but it should remain explicit and disciplined.

## Code Example
```csharp
using System;
using Microsoft.Extensions.DependencyInjection;

namespace KnowledgeBase.OopDesign;

public interface IMessageSender
{
    void Send(string message);
}

public sealed class EmailSender : IMessageSender
{
    public void Send(string message) => Console.WriteLine($"Email -> {message}");
}

public sealed class SmsSender : IMessageSender
{
    public void Send(string message) => Console.WriteLine($"SMS -> {message}");
}

public sealed class MessageRouter(Func<string, IMessageSender> senderFactory)
{
    public void Notify(string channel, string message)
    {
        // Runtime choice stays inside the factory delegate.
        var sender = senderFactory(channel);
        sender.Send(message);
    }
}

internal static class Program
{
    private static void Main()
    {
        var services = new ServiceCollection();

        services.AddKeyedTransient<IMessageSender, EmailSender>("email");
        services.AddKeyedTransient<IMessageSender, SmsSender>("sms");

        services.AddSingleton<Func<string, IMessageSender>>(sp => key =>
            sp.GetRequiredKeyedService<IMessageSender>(key));

        services.AddTransient<MessageRouter>();

        using var provider = services.BuildServiceProvider();
        var router = provider.GetRequiredService<MessageRouter>();

        router.Notify("email", "Your interview starts in 10 minutes.");
        router.Notify("sms", "Join the call now.");
    }
}
```

## Common Follow-up Questions
- Why is a DI container similar to Abstract Factory?
- What is the difference between transient, scoped, and singleton in creational terms?
- When should you use a factory delegate instead of injecting a service directly?
- What problem do keyed services solve in .NET 8?
- Why is injecting `IServiceProvider` into business code often considered a smell?
- How would you test runtime selection logic built on top of keyed services?

## Common Mistakes / Pitfalls
- Injecting `IServiceProvider` everywhere and turning DI into Service Locator.
- Using singleton lifetime for services that depend on scoped data such as `DbContext`.
- Replacing simple constructor injection with keyed services when no real runtime variability exists.
- Hiding business rules in string keys that are not centralized or type-safe.
- Registering a factory delegate that throws at runtime because the key is missing or misspelled.

## References
- [Dependency injection in .NET](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection)
- [Dependency injection guidelines - .NET](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection-guidelines)
- [Dependency injection in ASP.NET Core - Keyed services](https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection#keyed-services)
- [What's new in ASP.NET Core in .NET 8](https://learn.microsoft.com/aspnet/core/release-notes/aspnetcore-8.0)
