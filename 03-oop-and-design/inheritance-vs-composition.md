# Inheritance vs Composition

**Category:** OOP & Design
**Difficulty:** 🟡 Middle
**Tags:** `inheritance`, `composition`, `fragile-base-class`, `solid`

## Question
> Why do people say “favor composition over inheritance,” and when is inheritance still a good choice in C#?

## Short Answer
Composition usually creates looser coupling because an object delegates behavior to other objects instead of becoming permanently tied to a base class. Inheritance is powerful, but it can lead to fragile hierarchies where changes in the base class ripple unexpectedly into derived classes. Inheritance is still a good choice when there is a true “is-a” relationship, the abstraction is stable, and substitutability is real.

## Detailed Explanation
### The core difference
Inheritance means one type derives from another and automatically gets its accessible members. Composition means one object contains or depends on other objects and delegates work to them. In everyday design terms, inheritance models “is-a,” while composition models “has-a” or “uses-a.”

| Aspect | Inheritance | Composition |
| --- | --- | --- |
| Relationship | `Car` is a `Vehicle` | `Car` has an `IEngine` |
| Coupling | Tight to base class | Usually looser |
| Flexibility | Fixed by hierarchy | Swappable at runtime or construction |
| Reuse style | Reuse via subclassing | Reuse via delegation |
| Common risk | Fragile base class | More small types and wiring |

### Why composition is often preferred
Composition tends to be safer because each dependency has a narrower, explicit contract. If a class uses `IPriceCalculator` or `ILogger`, it depends only on what it needs. With inheritance, a derived class is coupled to a whole base type, including members it may not care about.

Composition also supports the Single Responsibility Principle better. A class can delegate logging, formatting, pricing, or authorization to dedicated collaborators instead of inheriting a large chunk of behavior.

Another benefit is runtime flexibility. With composition, you can replace implementations through dependency injection or configuration. With inheritance, the behavior is often fixed at compile time by the hierarchy.

### The fragile base class problem
The classic warning is the fragile base class problem. A base class changes internally, and derived classes break even though their own code did not change. Maybe the base class adds a new call order, assumes a method is safe to call in the constructor, or modifies a virtual method’s contract subtly.

Because derived classes know so much about the base class, even innocent refactoring can become dangerous. That is one reason deep inheritance trees are often hard to maintain.

> Warning: inheritance for “easy code reuse” is one of the fastest ways to create accidental coupling. Reuse is not the same thing as a stable abstraction.

### When inheritance is still a good choice
Inheritance is not bad; it is just easier to misuse. It works well when:
- the relationship is genuinely hierarchical,
- the base abstraction is stable,
- derived types are fully substitutable for the base type,
- and the base class is intentionally designed for extension.

Frameworks often use inheritance effectively for templates, base controllers, or domain hierarchies. Abstract base classes can also centralize shared state and lifecycle rules in a way that composition alone would make awkward.

### A practical decision rule
If the main reason you want inheritance is “I want to reuse some code,” composition is usually the better first choice. If the main reason is “this really is the same concept at a more specialized level,” inheritance may be appropriate.

In real C# applications, a healthy mix is common: composition for most behavior, inheritance for a few stable core hierarchies.

## Code Example
```csharp
namespace OopAndDesignExamples;

// Before: inheritance forces all birds into the same movement model.
public abstract class Bird
{
    public abstract void Move();
}

public sealed class Sparrow : Bird
{
    public override void Move() => Console.WriteLine("Sparrow flies.");
}

public sealed class Penguin : Bird
{
    public override void Move() => Console.WriteLine("Penguin waddles and swims.");
}

// After: composition separates the bird from the movement strategy.
public interface IMovement
{
    void Move();
}

public sealed class FlyMovement : IMovement
{
    public void Move() => Console.WriteLine("Flying through the air.");
}

public sealed class SwimMovement : IMovement
{
    public void Move() => Console.WriteLine("Swimming through the water.");
}

public sealed class ComposedBird(string name, IMovement movement)
{
    public string Name { get; } = name;
    private IMovement Movement { get; } = movement;

    public void Move()
    {
        Console.Write($"{Name}: ");
        Movement.Move(); // Behavior is delegated instead of inherited.
    }
}

public static class Program
{
    public static void Main()
    {
        Bird sparrow = new Sparrow();
        sparrow.Move();

        var composedSparrow = new ComposedBird("Composed sparrow", new FlyMovement());
        var composedPenguin = new ComposedBird("Composed penguin", new SwimMovement());

        composedSparrow.Move();
        composedPenguin.Move();
    }
}
```

## Common Follow-up Questions
- What is the fragile base class problem?
- How does composition support the SOLID principles better?
- Can inheritance and composition be combined in the same design?
- When is an abstract base class better than injecting collaborators?
- Why are deep inheritance hierarchies hard to maintain?

## Common Mistakes / Pitfalls
- Using inheritance only to reuse a few helper methods.
- Forcing unrelated types into one hierarchy because they look similar today.
- Violating substitutability, such as derived types that throw for inherited operations.
- Building deep inheritance trees that become hard to change safely.
- Overcorrecting and turning simple designs into excessive composition with dozens of tiny wrappers.

## References
- [Object-oriented programming fundamentals (C#)](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/)
- [Inheritance (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/inheritance)
- [Strategy Pattern](https://refactoring.guru/design-patterns/strategy)
- [Decorator Pattern](https://refactoring.guru/design-patterns/decorator)
