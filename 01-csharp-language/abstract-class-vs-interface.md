# Abstract Class vs Interface

**Category:** C# / OOP in C#
**Difficulty:** Middle
**Tags:** `abstract-class`, `interface`, `polymorphism`, `default-interface-methods`, `inheritance`

## Question

> What is the difference between an abstract class and an interface in C#, and when should you choose one over the other?

Also asked as:
- "If interfaces can have default implementations now, do we still need abstract classes?"
- "Why can a class inherit only one abstract base class but implement many interfaces?"

## Short Answer

An abstract class is a base type for closely related objects that may share state, protected members, and reusable implementation. An interface is a contract that describes capabilities and can be implemented by unrelated types, including multiple interfaces on the same class. In modern C#, default interface members reduce some gaps, but abstract classes still matter when you need shared state, non-public members, constructor logic, or a stronger inheritance relationship.

## Detailed Explanation

### What an Abstract Class Gives You

An abstract class is a class that cannot be instantiated directly. It is designed to be inherited.

It can contain:
- Abstract members that derived classes must implement.
- Concrete members with shared logic.
- Fields and state.
- Constructors.
- `protected` members for derived-class extensibility.

That makes it useful when derived types are part of one family and should share both behavior and internal structure.

### What an Interface Gives You

An interface defines a contract. It says what a type can do, not what it is internally.

Modern interfaces can include more than pure signatures because C# 8 introduced default interface implementations, but interfaces still cannot hold instance fields or constructor state the way a base class can.

Interfaces are ideal when:
- Unrelated types share a capability.
- You want multiple contracts on the same type.
- Consumers should depend on behavior, not inheritance hierarchy.
- You want loose coupling for testing, DI, or plugin-style architecture.

### Comparison Table

| Aspect | Abstract class | Interface |
|---|---|---|
| Inheritance count | A class can inherit only one | A class can implement many |
| Instance state/fields | Yes | No instance fields |
| Constructors | Yes | No instance constructors for implementers |
| Access modifiers on members | Full range, including `protected` | Public contract plus some default/static/private interface members |
| Best for | Shared base implementation and family relationship | Capabilities and loose contracts |

### Why Default Interface Members Did Not Replace Abstract Classes

Default interface implementations are mainly a **versioning** feature. They let interface authors add a new member with a default body without forcing every implementer to break immediately.

That is useful, but it does not replace the role of an abstract class because interfaces still do not provide shared instance state or a rich inheritance model with protected hooks and constructor-enforced invariants.

> **Tip:** If you need shared state, template-method style base behavior, or protected extension points, choose an abstract class. If you need a capability contract across unrelated types, choose an interface.

### Typical Design Guidance

A practical rule is:
- Use an **interface** for the public abstraction you inject and mock.
- Use an **abstract base class** only when several implementations truly need shared implementation or invariant enforcement.

That often leads to patterns like:
- `IMessageSender` as the contract.
- `MessageSenderBase` as an optional helper base for common behavior.

### Trade-Offs in Real Projects

Interfaces improve flexibility because a type can implement many of them. Abstract classes improve reuse when implementations are closely related.

In DI-heavy applications, interfaces are common because they express substitutability well. In framework code, abstract classes are also common because they centralize cross-cutting base behavior.

See also [interface-default-implementations.md](./interface-default-implementations.md) and [virtual-override-new-keywords.md](./virtual-override-new-keywords.md).

## Code Example

```csharp
using System;

INotifier emailNotifier = new EmailNotifier();
emailNotifier.Notify("Build completed.");

ReportNotifier reportNotifier = new EmailReportNotifier();
reportNotifier.SendReport("Daily summary");

interface INotifier
{
    void Notify(string message);

    // Default implementation is allowed in modern C#.
    void NotifyWithPrefix(string prefix, string message) => Notify($"[{prefix}] {message}");
}

abstract class ReportNotifier
{
    // Shared state and constructor logic belong naturally in a base class.
    protected ReportNotifier(string channelName) => ChannelName = channelName;

    protected string ChannelName { get; }

    public void SendReport(string reportName)
    {
        Console.WriteLine($"Preparing report for {ChannelName}...");
        Send(reportName); // Template method delegates the variation point.
    }

    protected abstract void Send(string reportName);
}

sealed class EmailNotifier : INotifier
{
    public void Notify(string message) => Console.WriteLine($"Email: {message}");
}

sealed class EmailReportNotifier : ReportNotifier
{
    public EmailReportNotifier() : base("email")
    {
    }

    protected override void Send(string reportName) => Console.WriteLine($"Sending '{reportName}' by email");
}
```

## Common Follow-up Questions

- Why do abstract classes support shared state while interfaces do not?
- When do default interface methods help with versioning?
- Why are interfaces often preferred for dependency injection?
- Can you combine both by exposing an interface and also having an abstract helper base class?
- When is an abstract class a better fit than composition?

## Common Mistakes / Pitfalls

- Using an abstract class just because several types are similar, even though composition would be simpler.
- Using an interface where every implementer is forced to duplicate large amounts of identical code.
- Assuming default interface members make abstract classes obsolete.
- Treating interfaces as a place for hidden shared state or lifecycle management.

## References

- [Interfaces — C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/interfaces/)
- [Abstract and sealed classes and class members — C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/abstract-and-sealed-classes-and-class-members)
- [Default interface methods tutorial — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/advanced-topics/interface-implementation/default-interface-methods-versions)
- [See: interface-default-implementations.md](./interface-default-implementations.md)
- [See: virtual-override-new-keywords.md](./virtual-override-new-keywords.md)
