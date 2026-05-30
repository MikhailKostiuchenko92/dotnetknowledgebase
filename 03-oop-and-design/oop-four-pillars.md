# The Four Pillars of OOP

**Category:** OOP & Design
**Difficulty:** 🟢 Junior
**Tags:** `oop`, `encapsulation`, `inheritance`, `polymorphism`, `abstraction`

## Question
> What are the four pillars of object-oriented programming, and how do they show up in C#?

## Short Answer
The four pillars are encapsulation, inheritance, polymorphism, and abstraction. In C#, encapsulation protects an object's state, inheritance lets one type build on another, polymorphism lets the same call behave differently depending on the runtime type, and abstraction exposes only the essential contract. Together, they help you model business concepts with clearer boundaries and more maintainable code.

## Detailed Explanation
### What the four pillars mean
The “four pillars” are a teaching model for explaining how object-oriented code is organized. They are not four mandatory features you must always use, but four ideas that appear repeatedly in well-designed C# code.

| Pillar | Core idea | Typical C# tools | Main benefit |
| --- | --- | --- | --- |
| Encapsulation | Hide internal state and protect invariants | `private`, `protected`, properties, methods | Prevent invalid object state |
| Inheritance | Derive a more specific type from a base type | `:` inheritance, `virtual`, `abstract` | Reuse and specialization |
| Polymorphism | One call can produce different behavior | `virtual`/`override`, interfaces | Extensible behavior |
| Abstraction | Expose the important surface, hide details | abstract classes, interfaces | Simpler mental model |

### Encapsulation: protect invariants
Encapsulation is about controlling how an object is used. Instead of letting outside code change fields directly, the object exposes safe operations such as `Deposit`, `Cancel`, or `Accelerate`. In C#, access modifiers and properties are the mechanical tools, but the design goal is stronger than “make fields private.” The real goal is to keep the object valid.

For example, a `Vehicle` should decide whether negative acceleration is allowed. If callers can assign any number directly to a field, the object can end up in an impossible state. Encapsulation keeps business rules close to the data they protect.

> Warning: a public auto-property with an unrestricted setter is only weak encapsulation. You hid the field, but you may still be exposing unsafe state changes.

### Inheritance: specialization of a base concept
Inheritance models an “is-a” relationship. A `Car` is a `Vehicle`, so it can inherit shared members and add specialized behavior. In C#, a derived class gets the accessible members of its base class and can override `virtual` or `abstract` members.

Inheritance is useful when there is a stable conceptual hierarchy and the derived type should truly be substitutable for the base type. It becomes risky when it is used only for code reuse, because the derived type becomes tightly coupled to the base class’s implementation details.

### Polymorphism: same call, different behavior
Polymorphism means you can treat multiple concrete types through a common contract and still get type-specific behavior. In C#, that usually happens through virtual dispatch or interfaces. A `List<Vehicle>` can hold both `Car` and `Bike`, and calling `Describe()` on each item runs the correct override.

This matters because higher-level code can work with abstractions instead of `if`/`switch` chains on concrete types. That lowers coupling and makes extension easier.

### Abstraction: focus on the contract
Abstraction means you present only what callers need to know. An abstract class or interface tells consumers what operations exist without forcing them to care about internal implementation details. A caller can use a `Vehicle` or `IStartable` without knowing how each type starts itself.

Abstraction reduces mental load. Instead of thinking about every detail of every concrete class, you think in terms of capabilities and contracts.

### Why the pillars matter together
The pillars are most useful when combined. Abstraction defines the contract, encapsulation protects the internal rules, inheritance can share or refine behavior, and polymorphism lets callers work through the contract. That is why OOP is less about memorizing definitions and more about building types with good boundaries.

At the same time, these are tools, not goals. Modern C# also uses records, pattern matching, and composition heavily. Good design is about choosing the simplest model that preserves correctness and flexibility.

## Code Example
```csharp
namespace OopAndDesignExamples;

public interface IStartable
{
    void Start();
}

public abstract class Vehicle
{
    private int _speed;

    public int Speed => _speed; // Encapsulation: callers can read, not assign arbitrarily.

    public void Accelerate(int delta)
    {
        if (delta <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(delta), "Acceleration must be positive.");
        }

        _speed += delta;
    }

    public abstract string Describe(); // Abstraction: derived types must explain themselves.
}

public sealed class Car : Vehicle, IStartable
{
    public void Start() => Console.WriteLine("Car started silently.");

    public override string Describe() => $"Car moving at {Speed} km/h"; // Polymorphism.
}

public sealed class Bike : Vehicle, IStartable
{
    public void Start() => Console.WriteLine("Bike rider starts pedaling.");

    public override string Describe() => $"Bike moving at {Speed} km/h"; // Polymorphism.
}

public static class Program
{
    public static void Main()
    {
        List<Vehicle> vehicles = [new Car(), new Bike()];

        foreach (Vehicle vehicle in vehicles)
        {
            vehicle.Accelerate(10); // Shared behavior from the base class.
            Console.WriteLine(vehicle.Describe());
        }

        IStartable startable = new Car(); // Abstraction via interface.
        startable.Start();
    }
}
```

## Common Follow-up Questions
- What is the difference between abstraction and encapsulation?
- When is inheritance a bad choice in C#?
- How does polymorphism work with interfaces compared to virtual methods?
- Can you have polymorphism without inheritance?
- What C# features help with encapsulation besides access modifiers?

## Common Mistakes / Pitfalls
- Treating inheritance as the default reuse mechanism instead of checking whether composition fits better.
- Saying abstraction and encapsulation are the same thing; they are related but solve different problems.
- Assuming private fields alone guarantee good encapsulation even when public setters bypass validation.
- Overusing deep inheritance hierarchies that make behavior hard to reason about.
- Forgetting that polymorphism requires a common contract such as a base class or interface.

## References
- [Object-oriented programming fundamentals (C#)](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/)
- [Inheritance (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/inheritance)
- [Polymorphism (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/polymorphism)
- [Interfaces (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/interfaces)
