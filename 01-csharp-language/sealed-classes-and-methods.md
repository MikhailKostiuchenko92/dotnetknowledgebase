# Sealed Classes and Methods

**Category:** C# / OOP in C#
**Difficulty:** Middle
**Tags:** `sealed`, `inheritance`, `polymorphism`, `devirtualization`, `sealed override`

## Question

> What does `sealed` mean in C#, and when should you use sealed classes or sealed methods?

Also asked as:
- "How do you prevent inheritance in C#?"
- "What is `sealed override`, and does it help performance?"
- "When is sealing a type a good design decision instead of an unnecessary restriction?"

## Short Answer

`sealed` stops further inheritance or further overriding. A sealed class cannot be inherited, and a `sealed override` closes an override chain for one member. You usually use it to express design intent, protect invariants, simplify versioning, and sometimes help the JIT devirtualize calls when the runtime knows no more derived implementation can exist.

## Detailed Explanation

### What `sealed` Actually Does

In C#, `sealed` can be applied in two main places:

| Usage | Meaning |
|---|---|
| `sealed class MyType` | No other class can inherit from `MyType` |
| `sealed override` | This override is final; further derived classes cannot override it |

That makes `sealed` part of the API contract, not just a compiler hint. It tells other developers, "this type or this specific polymorphic customization point ends here."

### Why Seal a Class

A sealed class is appropriate when inheritance would weaken correctness or make the API harder to evolve. Common reasons include:

- The type has invariants that subclasses could break.
- The type is a small leaf object, such as an options or helper implementation.
- The type was never designed as an extensibility point.
- The maintainer wants freedom to refactor internals without worrying about subclass behavior.

For example, a domain value object, a cache key type, or a framework implementation detail is often better sealed than accidentally extensible.

> **Tip:** Do not treat inheritance as the default customization mechanism. If a type is not explicitly designed for derivation, sealing it is often the safer choice.

### `sealed override` and Override Chains

Sometimes the base class should stay extensible, but one derived layer wants to finalize a specific behavior. That is what `sealed override` is for.

A typical example is a framework base type that exposes `virtual Validate()`, then a derived class overrides it and locks the behavior because further overrides would bypass critical rules.

This connects directly to [virtual-override-new-keywords.md](./virtual-override-new-keywords.md): `virtual` opens a dispatch point, `override` customizes it, and `sealed override` closes it again.

### Design Intent and Versioning

Sealing communicates intent very clearly during interviews and in production code:

- **Extensible base types** should document which members are safe to override.
- **Non-extensible leaf types** should often be sealed.

This matters for versioning. Once third parties inherit from your class, later internal changes can become breaking changes because derived classes may depend on call order, protected members, or constructor behavior. A sealed class avoids that fragile-base-class problem.

### Performance: JIT Devirtualization

`sealed` can also have a performance angle. Virtual calls normally require runtime dispatch. If the JIT can prove the exact target type is sealed, or the called override is sealed, it may devirtualize the call and sometimes inline it.

That said, performance should be a secondary benefit. You should not seal a public API only because you hope for a micro-optimization. Modern JITs already devirtualize in many cases when they can infer the concrete type.

### When Not to Seal

Sealing can be overused. If a class is clearly intended as a reusable base type, sealing it blocks legitimate extension. In test-heavy codebases, sealing everything can also make some proxy-based mocking approaches harder, though interfaces are usually a better answer than inheritance-based mocking anyway.

Use `sealed` deliberately: not too early, not too late, and only when the type's role is truly non-extensible.

See also [abstract-class-vs-interface.md](./abstract-class-vs-interface.md) and [virtual-override-new-keywords.md](./virtual-override-new-keywords.md).

## Code Example

```csharp
using System;

Animal pet = new Dog("Milo");
Console.WriteLine(pet.Describe());       // Dog: Milo
Console.WriteLine(pet.Speak());          // Woof

Dog dog = new("Milo");
Console.WriteLine(dog.Describe());       // Same result, but this override is sealed.

abstract class Animal
{
    protected Animal(string name) => Name = name;

    public string Name { get; }

    public virtual string Describe() => $"Animal: {Name}";
    public virtual string Speak() => "Some sound";
}

sealed class Dog : Animal // No inheritance from Dog is allowed.
{
    public Dog(string name) : base(name) { }

    public sealed override string Describe() => $"Dog: {Name}"; // Override chain ends here.
    public override string Speak() => "Woof";
}

// class Husky : Dog { } // Compile-time error: cannot derive from sealed type 'Dog'.
```

## Common Follow-up Questions

- What problem does `sealed override` solve compared to a non-virtual method?
- How does `sealed` relate to the fragile base class problem?
- Does sealing always improve performance, or only in some JIT scenarios?
- When should you expose inheritance versus an interface-based extension point?
- Can a sealed class still implement interfaces and participate in polymorphism?

## Common Mistakes / Pitfalls

- Sealing a class by default without thinking about whether it is supposed to be a framework extension point.
- Assuming `sealed` is primarily a performance keyword instead of a design keyword.
- Forgetting that `sealed override` only applies to an overridden member, not the whole class.
- Exposing `protected` members broadly and then sealing too late, after consumers have already inherited from the type.

## References

- [sealed - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/sealed)
- [How to define abstract properties](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/how-to-define-abstract-properties)
- [See: virtual-override-new-keywords.md](./virtual-override-new-keywords.md)
- [See: abstract-class-vs-interface.md](./abstract-class-vs-interface.md)
