# `virtual`, `override`, and `new` Keywords

**Category:** C# / OOP in C#
**Difficulty:** Middle
**Tags:** `virtual`, `override`, `new`, `polymorphism`, `sealed override`

## Question

> What do the `virtual`, `override`, and `new` keywords do in C#, and how do they affect polymorphism?

Also asked as:
- "What is the difference between overriding a method and hiding it with `new`?"
- "When would you use `sealed override` or `base.SomeMethod()`?"

## Short Answer

`virtual` marks a base-class member as overridable, `override` replaces that virtual behavior in a derived class, and `new` hides a member instead of participating in runtime polymorphism. If you call an overridden member through a base-class reference, the derived override still runs; if you hide with `new`, the member chosen depends on the compile-time reference type. `sealed override` lets a derived class override once and then stop further overrides.

## Detailed Explanation

### `virtual` Starts the Polymorphic Contract

A method, property, or indexer marked `virtual` tells the runtime that derived classes may provide a different implementation.

```csharp
public virtual string Describe() => "Base";
```

Without `virtual` (or `abstract`), the member is not polymorphic in the normal inheritance sense.

### `override` Replaces the Virtual Behavior

A derived class uses `override` to provide its own implementation of an inherited virtual or abstract member.

When you call the member through a base reference, runtime dispatch still chooses the most derived override.

That is core OOP polymorphism.

### `new` Hides Instead of Overriding

`new` does **not** participate in virtual dispatch. It hides an inherited member with another member that has the same name.

That means the chosen member depends on the compile-time type of the variable:
- Base reference -> base member.
- Derived reference -> derived hidden member.

| Keyword | Works with polymorphic dispatch? | Typical purpose |
|---|---|---|
| `virtual` | Enables it | Allow overriding in derived classes |
| `override` | Yes | Replace inherited virtual behavior |
| `new` | No | Intentionally hide a member |
| `sealed override` | Yes, but stops further overrides | Finalize the override chain |

### Why `new` Can Be Dangerous

Using `new` is sometimes necessary, but it often surprises readers because the behavior changes based on reference type. That can create bugs that look inconsistent at runtime.

If your intent is polymorphism, use `virtual` + `override`. If your intent is deliberate hiding, use `new` explicitly so the compiler warning becomes an intentional design choice.

> **Warning:** If you write a member with the same name as a base member and forget `override`, you may accidentally hide instead of override. Always check compiler messages carefully.

### `base` Calls and Reuse

Inside an override, you can call `base.Member()` to reuse some base behavior before or after extending it.

That is useful when the base implementation is still partially correct and the derived type only needs to add logic. However, excessive base-calling can also indicate a fragile inheritance hierarchy.

### `sealed override`

A derived class can override a virtual member and then mark that override as `sealed`:

```csharp
public sealed override void Execute() { }
```

This means the current class customizes the virtual behavior, but any classes derived from it may no longer override that member.

This is useful when:
- A framework wants one controlled customization point.
- A middle layer has finalized the behavior.
- Further overrides would break invariants.

### Practical Design Guidance

Use inheritance-based polymorphism only when there is a true "is-a" relationship and a stable base contract. In many real systems, composition plus interfaces is easier to evolve. But when you do use inheritance, know the semantics precisely:
- `virtual`/`override` for runtime polymorphism.
- `new` for hiding, not polymorphism.
- `sealed override` to stop override chains.

See also [abstract-class-vs-interface.md](./abstract-class-vs-interface.md).

## Code Example

```csharp
using System;

Animal a1 = new Dog();
Console.WriteLine(a1.Speak()); // Dog override runs through base reference.

Animal a2 = new Cat();
Console.WriteLine(a2.TypeName()); // Base method, because Cat hides with 'new'.

Cat cat = new();
Console.WriteLine(cat.TypeName()); // Hidden Cat method.

Animal a3 = new Husky();
Console.WriteLine(a3.Speak()); // Husky uses the sealed override from Husky.

class Animal
{
    public virtual string Speak() => "Some animal sound";

    public string TypeName() => "Animal";
}

class Dog : Animal
{
    public override string Speak() => "Woof";
}

class Husky : Dog
{
    public sealed override string Speak() => base.Speak() + " from a husky";
}

class Cat : Animal
{
    public override string Speak() => "Meow";

    public new string TypeName() => "Cat"; // Hides, does not override.
}
```

## Common Follow-up Questions

- Why does `new` not participate in runtime polymorphism?
- When would `sealed override` be useful in a framework or base library?
- What happens if you define a same-named member and forget `override`?
- When is `base.SomeMethod()` appropriate inside an override?
- Why might composition be preferable to deep inheritance hierarchies?

## Common Mistakes / Pitfalls

- Using `new` when you actually wanted polymorphic overriding.
- Forgetting to mark a base member `virtual`, then being surprised that derived behavior is not used through a base reference.
- Overusing inheritance when composition would be simpler and safer.
- Calling `base` in overrides without understanding whether the base implementation is part of the derived invariant.

## References

- [virtual — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/virtual)
- [override — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/override)
- [new modifier — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/new-modifier)
- [See: abstract-class-vs-interface.md](./abstract-class-vs-interface.md)
- [See: interface-default-implementations.md](./interface-default-implementations.md)
