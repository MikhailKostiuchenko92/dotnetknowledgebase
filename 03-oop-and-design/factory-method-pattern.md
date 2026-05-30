# Factory Method Pattern

**Category:** OOP & Design / Creational Patterns
**Difficulty:** 🟢 Junior
**Tags:** `factory-method`, `creational`, `abstract-factory`

## Question
> Can you explain the Factory Method pattern, why it is sometimes called a virtual constructor, and how it differs from just using `new` directly?

## Short Answer
Factory Method moves object creation behind a polymorphic method, so a base class can define the workflow while subclasses choose which concrete product to instantiate. It is often called a virtual constructor because the creation decision is delegated through overriding instead of hard-coded `new` calls. Use it when client code should work with abstractions and when object creation varies by subclass, but avoid it if a direct constructor call is simpler and stable.

## Detailed Explanation
### What the pattern is
Factory Method is a creational pattern where a base type declares a method for creating a product, and derived types override that method to return different concrete implementations. The client works with the abstraction of the product and often with the abstraction of the creator as well.

The key idea is not “hide every constructor.” It is “separate the algorithm that uses an object from the decision of which concrete object should be created.” That is why the pattern is also called the virtual constructor idiom: instead of saying `new Truck()`, the base class calls a virtual method like `CreateTransport()`.

### Why not just use `new`?
Using `new` directly is fine when the type is obvious, stable, and local. It becomes problematic when higher-level logic must stay independent of concrete classes.

| Approach | Advantage | Limitation |
| --- | --- | --- |
| Direct `new` | Simple and explicit | Couples the caller to a concrete type. |
| Factory Method | Uses polymorphism to vary creation | Adds more types and indirection. |
| Abstract Factory | Creates whole product families | Heavier pattern for bigger scenarios. |

If a shipping workflow creates `Truck` today and may create `Ship` tomorrow, direct constructor calls spread that decision all over the codebase. Factory Method centralizes it in subclasses.

### How it works internally
Usually there are two roles:
1. A **product hierarchy** such as `ITransport`, `Truck`, and `Ship`.
2. A **creator hierarchy** such as `Logistics`, `RoadLogistics`, and `SeaLogistics`.

The base creator often contains business logic that depends only on the product abstraction. Inside that logic, it calls the factory method. Derived creators override the factory method and return the matching concrete product.

This is important because the base class is still useful even though it does not know exact concrete types. It owns the workflow; subclasses own instantiation.

> Warning: Factory Method is not just a helper function called `CreateSomething`. The pattern specifically relies on inheritance and overriding to vary creation behavior.

### Why it matters
Factory Method improves the Open/Closed Principle. You can introduce a new product and a matching creator without editing the core workflow class. It also improves testability because client code can target interfaces or abstract base classes.

In C#, it fits naturally with abstract classes, virtual methods, interfaces, and dependency injection. Frameworks often expose extensibility points that behave like factory methods, letting you plug in a custom product while preserving the existing pipeline.

### Trade-offs and when not to use it
The trade-off is additional abstraction. For a simple object created in one place, Factory Method is overengineering. It also works best when creation varies along inheritance lines. If you need to switch between whole related families of objects, Abstract Factory is usually the better fit.

Another common misuse is building a “simple factory” with a giant `switch` and calling it Factory Method. That can still be useful, but it is a different design. In interviews, mention that true Factory Method usually means a polymorphic creation method, not just a static helper.

Use Factory Method when a base workflow should stay generic while subclasses decide the exact product. Use plain `new` when the extra flexibility does not buy you anything.

## Code Example
```csharp
using System;

namespace KnowledgeBase.OopDesign;

public interface INotificationSender
{
    string Send(string message);
}

public sealed class EmailSender : INotificationSender
{
    public string Send(string message) => $"Email: {message}";
}

public sealed class SmsSender : INotificationSender
{
    public string Send(string message) => $"SMS: {message}";
}

public abstract class NotificationWorkflow
{
    // Factory Method: subclasses decide which product to create.
    protected abstract INotificationSender CreateSender();

    public void Process(string message)
    {
        var sender = CreateSender();
        Console.WriteLine(sender.Send(message));
    }
}

public sealed class EmailWorkflow : NotificationWorkflow
{
    protected override INotificationSender CreateSender() => new EmailSender();
}

public sealed class SmsWorkflow : NotificationWorkflow
{
    protected override INotificationSender CreateSender() => new SmsSender();
}

internal static class Program
{
    private static void Main()
    {
        NotificationWorkflow workflow = DateTime.UtcNow.Second % 2 == 0
            ? new EmailWorkflow()
            : new SmsWorkflow();

        workflow.Process("Interview scheduled for Monday.");
    }
}
```

## Common Follow-up Questions
- Why is Factory Method called a virtual constructor?
- How is Factory Method different from a simple factory or static factory helper?
- When would you prefer Factory Method over Abstract Factory?
- Can Factory Method work without inheritance?
- How does Factory Method help with unit testing?

## Common Mistakes / Pitfalls
- Calling any helper named `Create` a Factory Method even when there is no polymorphic override.
- Using the pattern for one trivial constructor call where direct `new` is clearer.
- Letting the base creator depend on concrete product types, which defeats the point.
- Confusing Factory Method with Abstract Factory, which creates related product families.
- Putting all creation branches into one huge `switch` instead of using subtype-specific behavior.

## References
- [Factory Method](https://refactoring.guru/design-patterns/factory-method)
- [Abstract Factory](https://refactoring.guru/design-patterns/abstract-factory)
- [Polymorphism - C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/object-oriented/polymorphism)
- [Interfaces - C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/interfaces)
