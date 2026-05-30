# Abstract Factory Pattern

**Category:** OOP & Design / Creational Patterns
**Difficulty:** 🟡 Middle
**Tags:** `abstract-factory`, `creational`, `product-family`

## Question
> What is the Abstract Factory pattern, when would you use it for product families, and how is it different from Factory Method?

## Short Answer
Abstract Factory creates families of related objects through one factory interface, so the client can switch the entire family without knowing concrete classes. It is useful when products must stay compatible, such as dark-theme UI controls or provider-specific infrastructure objects. Compared with Factory Method, which usually decides one product through inheritance, Abstract Factory coordinates multiple related products through composition.

## Detailed Explanation
### What the pattern is
Abstract Factory is a creational pattern that exposes an interface for creating a set of related products. Instead of asking for one object in isolation, the client asks a factory for several objects that belong to the same family.

A classic example is UI theming: a factory for the “Light” family creates a light button, light checkbox, and light dialog; a factory for the “Dark” family creates the matching dark versions. The client uses interfaces such as `IButton` and `ICheckbox`, so it stays unaware of the concrete types.

The main value is consistency. If products are meant to collaborate, Abstract Factory guarantees they come from the same family and therefore fit together.

### Product families and runtime switching
This pattern becomes valuable when an application must switch families at runtime. For example, a reporting system might choose between SQL Server-specific and PostgreSQL-specific objects, or a desktop app might choose between themes or operating-system styles.

| Concept | Example |
| --- | --- |
| Product family | All “Dark” UI controls |
| Product type | Button, checkbox, dialog |
| Concrete factory | `DarkThemeFactory` |
| Client benefit | One configuration change swaps the whole family |

Internally, the client holds a reference to an abstract factory such as `IUiFactory`. Once the concrete factory is selected, all products are produced through that factory. The client code never needs `if/else` checks for each product creation point.

> Warning: Abstract Factory does not remove all complexity. It shifts complexity into stable abstractions so the rest of the codebase stays clean.

### How it differs from Factory Method
These two patterns are related but solve different scopes of creation.

| Pattern | Main focus | Typical mechanism |
| --- | --- | --- |
| Factory Method | Create one product variation | Inheritance + overridden creator method |
| Abstract Factory | Create multiple related products | Composition + a factory object with several methods |

Factory Method often appears inside an Abstract Factory implementation. For example, each concrete factory method like `CreateButton()` is itself a factory method, but the broader pattern is Abstract Factory because the client consumes a family-producing factory object.

### Why it matters
Abstract Factory supports the Open/Closed Principle and reduces coupling to concrete classes. It also makes configuration-driven applications easier to reason about: one place chooses the family, and the rest of the code uses abstractions.

It is especially strong when compatibility matters more than individual object variation. That is common in UI libraries, database providers, serializers, and integration layers where objects must cooperate with matching conventions.

### Trade-offs and when not to use it
The trade-off is that adding a **new family** is easy, but adding a **new product type** can be expensive because you must change the abstract factory interface and every concrete factory. That is the opposite of some other patterns.

Do not use Abstract Factory if you only create one object type or if families are unlikely to change. In that case, Factory Method, a simple factory, or direct DI registration is usually easier.

In interviews, a strong summary is: use Abstract Factory when you need to create coordinated families of objects and swap those families safely at runtime.

## Code Example
```csharp
using System;

namespace KnowledgeBase.OopDesign;

public interface IButton
{
    void Render();
}

public interface ICheckbox
{
    void Render();
}

public interface IUiFactory
{
    IButton CreateButton();
    ICheckbox CreateCheckbox();
}

public sealed class LightButton : IButton
{
    public void Render() => Console.WriteLine("Rendering LightButton");
}

public sealed class LightCheckbox : ICheckbox
{
    public void Render() => Console.WriteLine("Rendering LightCheckbox");
}

public sealed class DarkButton : IButton
{
    public void Render() => Console.WriteLine("Rendering DarkButton");
}

public sealed class DarkCheckbox : ICheckbox
{
    public void Render() => Console.WriteLine("Rendering DarkCheckbox");
}

public sealed class LightUiFactory : IUiFactory
{
    public IButton CreateButton() => new LightButton();
    public ICheckbox CreateCheckbox() => new LightCheckbox();
}

public sealed class DarkUiFactory : IUiFactory
{
    public IButton CreateButton() => new DarkButton();
    public ICheckbox CreateCheckbox() => new DarkCheckbox();
}

internal static class Program
{
    private static void Main()
    {
        IUiFactory factory = DateTime.Now.Hour >= 18
            ? new DarkUiFactory()
            : new LightUiFactory();

        // Both products come from the same family.
        var button = factory.CreateButton();
        var checkbox = factory.CreateCheckbox();

        button.Render();
        checkbox.Render();
    }
}
```

## Common Follow-up Questions
- What is a product family in Abstract Factory?
- Why is Abstract Factory better than scattered `if/else` checks for theming or providers?
- How is Abstract Factory related to Factory Method?
- What happens when you add a new product type to the family?
- Would you implement this with DI in a modern .NET application?

## Common Mistakes / Pitfalls
- Using Abstract Factory when there is only one product type and no real family concept.
- Forgetting that products from the same family should be compatible by design.
- Confusing “adding a new family” with “adding a new product type”; the pattern favors the first more than the second.
- Letting client code depend on concrete factory classes instead of abstract product interfaces.
- Creating mixed families accidentally, such as a dark button with a light checkbox.

## References
- [Abstract Factory](https://refactoring.guru/design-patterns/abstract-factory)
- [Abstract Factory in C# Example](https://refactoring.guru/design-patterns/abstract-factory/csharp/example)
- [Factory Method](https://refactoring.guru/design-patterns/factory-method)
- [Interfaces - C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/interfaces)
