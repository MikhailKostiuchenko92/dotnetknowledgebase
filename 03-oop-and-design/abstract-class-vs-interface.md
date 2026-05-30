# Abstract Class vs Interface

**Category:** OOP & Design
**Difficulty:** 🟢 Junior
**Tags:** `abstract-class`, `interface`, `default-interface-members`

## Question
> When should you use an abstract class instead of an interface in C#?

## Short Answer
Use an abstract class when related types share common state or base implementation and you want to provide a controlled inheritance hierarchy. Use an interface when you want to describe a capability or contract that many unrelated types can implement. In modern C#, default interface members blur the line slightly, but interfaces still cannot own instance state the way abstract classes can.

## Detailed Explanation
### Shared base behavior vs shared contract
An abstract class is a partially implemented base type. It can contain constructors, fields, properties, concrete methods, abstract methods, and protected members. That makes it useful when several derived types have common behavior or state that should live in one place.

An interface is primarily a contract. It tells callers what members exist, but traditionally not how they are implemented. Since C# 8, interfaces can include default implementations for some members, mainly to help versioning and shared behavior, but they still are not a substitute for a rich base class.

| Question | Abstract class | Interface |
| --- | --- | --- |
| Can hold instance state? | Yes | No instance fields |
| Can have constructors? | Yes | No instance constructors for implementers |
| Supports multiple inheritance? | No, only one base class | Yes, many interfaces |
| Best for | Shared base behavior and state | Capabilities and contracts |
| Versioning with default behavior | Possible | Supported via default interface members |

### When abstract classes fit well
Abstract classes work well when your types are closely related and there is a real “is-a” relationship. For example, all payment processors may need common logging, validation, and a processor name. That shared logic belongs naturally in a base class.

They also let you expose `protected` helpers that only derived types should use. Interfaces cannot provide that kind of inheritance-oriented API surface.

### When interfaces are the better choice
Interfaces are better when you want loose coupling. A type can implement multiple interfaces even though it can inherit only one class. That makes interfaces ideal for dependency injection, testing, and cross-cutting capabilities such as caching, auditing, retry policies, or serialization.

Interfaces also decouple callers from inheritance trees. A service that depends on `IPaymentGateway` does not care whether the concrete type inherits from some particular base class.

> Warning: if you choose an abstract class only because you want code reuse, you may accidentally force unrelated types into a rigid hierarchy. Reuse alone is not a good reason for inheritance.

### Default interface members: useful, but limited
Default interface members let you add new members without immediately breaking every implementer. They also allow small shared behaviors directly in the interface. This is helpful for evolving public APIs.

However, default interface members do not give interfaces full abstract-class powers. They cannot define per-instance state, and they are usually consumed through the interface type. They are best seen as a versioning and convenience feature, not as a replacement for base classes.

### Practical decision rule
A good interview answer is:
- Choose an abstract class when you need shared state, base implementation, or protected extension points.
- Choose an interface when you need a contract that unrelated types can implement.
- Combine both when needed: a concrete class might inherit one abstract base class and implement several interfaces.

That hybrid approach is very common in real C# systems.

## Code Example
```csharp
namespace OopAndDesignExamples;

public abstract class PaymentProcessor
{
    protected PaymentProcessor(string processorName)
    {
        ProcessorName = processorName;
    }

    protected string ProcessorName { get; }

    public void LogStart(decimal amount) => Console.WriteLine($"{ProcessorName} processing {amount:C}...");

    public abstract void Process(decimal amount); // Must be implemented by derived classes.
}

public interface IRefundable
{
    void Refund(decimal amount);
}

public interface IAuditable
{
    void Audit(string message) => Console.WriteLine($"AUDIT: {message}"); // Default interface member.
}

public sealed class CardProcessor : PaymentProcessor, IRefundable, IAuditable
{
    public CardProcessor() : base("CardProcessor")
    {
    }

    public override void Process(decimal amount)
    {
        LogStart(amount); // Shared behavior from the abstract base class.
        Console.WriteLine("Charging the card.");
    }

    public void Refund(decimal amount) => Console.WriteLine($"Refunding {amount:C} to the card.");
}

public static class Program
{
    public static void Main()
    {
        var processor = new CardProcessor();
        processor.Process(99.99m);
        processor.Refund(20m);

        IAuditable auditable = processor; // Default interface member is called through the interface.
        auditable.Audit("Refund issued.");
    }
}
```

## Common Follow-up Questions
- Can an interface contain implementation in modern C#?
- Why can a class implement multiple interfaces but inherit only one base class?
- What are the main limitations of default interface members?
- When would you combine an abstract class with interfaces in the same design?
- How does dependency injection typically prefer interfaces over abstract classes?

## Common Mistakes / Pitfalls
- Using an abstract class for unrelated types just to share helper code.
- Assuming default interface members provide instance state like fields in a base class.
- Creating very “fat” interfaces that violate interface segregation.
- Depending on concrete base classes in application code when an interface would reduce coupling.
- Forgetting that a class can inherit only one base class, which limits future design flexibility.

## References
- [Interfaces (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/interfaces)
- [The `abstract` keyword (C# Reference)](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/abstract)
- [Update interfaces with default interface methods](https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/interface-implementation/default-interface-methods-versions)
- [What's new in C# 8.0 - Default interface methods](https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-8#default-interface-methods)
