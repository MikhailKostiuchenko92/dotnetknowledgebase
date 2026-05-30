# Prototype Pattern

**Category:** OOP & Design / Creational Patterns
**Difficulty:** 🟡 Middle
**Tags:** `prototype`, `creational`, `cloning`, `ICloneable`, `records`

## Question
> What is the Prototype pattern in C#, what is the difference between shallow and deep copy, and how do `ICloneable`, `MemberwiseClone`, and record `with` expressions fit into it?

## Short Answer
Prototype creates new objects by copying an existing instance instead of constructing from scratch. In C#, the hard part is deciding whether the copy should be shallow or deep, because nested reference-type state changes the semantics. `MemberwiseClone` and record `with` expressions are useful building blocks, but `ICloneable` is often avoided in public APIs because it does not clearly specify copy depth.

## Detailed Explanation
### What the pattern is
Prototype is a creational pattern where an existing object acts as a template for new objects. Instead of recreating all configuration manually, you clone a preconfigured instance and then adjust a few fields.

This is useful when object creation is expensive, when configuration is large, or when you want to preserve a known-good baseline. Common examples include document templates, UI element duplication, request blueprints, and domain objects with many default settings.

### Shallow copy vs deep copy
This pattern sounds simple until references are involved.

| Copy type | What gets copied | Risk |
| --- | --- | --- |
| Shallow copy | Value fields are copied; reference fields point to the same nested objects | Mutating nested state affects both instances. |
| Deep copy | Nested reference objects are copied too | More work, more allocations, must define copy rules carefully. |

If your object contains only value types and immutable references, a shallow copy may be enough. If it contains mutable lists, dictionaries, or child objects, shallow copying can be dangerous because the original and the clone share internal state.

`MemberwiseClone` creates a shallow copy. That makes it fast and useful, but not sufficient for many real-world object graphs.

> Warning: The most common Prototype bug is thinking “I cloned it” means “it is fully independent.” That is only true if you intentionally perform a deep copy where needed.

### `ICloneable` and why it is controversial
`ICloneable` exists in .NET, but many developers avoid exposing it in public APIs because `Clone()` does not say whether the result is shallow or deep. That ambiguity makes callers guess, which is dangerous.

A better design is often an explicit method name such as `ShallowCopy()`, `DeepCopy()`, or a copy constructor. Those names communicate intent. In interviews, mentioning the ambiguity of `ICloneable` is usually a good signal of practical experience.

### Modern C# approach: records and `with`
Records make Prototype-style copying much nicer. A `with` expression creates a copy with selected members changed. That is especially elegant for immutable models.

However, `with` is not magical deep cloning. It copies the record and then updates specified members, but nested mutable references are still shared unless you replace them too. So the Prototype discussion still matters even with modern syntax.

### Why the pattern matters
Prototype can simplify construction logic and avoid repeating large setup code. It can also preserve invariants by starting from a valid template object. In some cases it is more expressive than a Builder because the baseline already exists.

But the trade-off is copy semantics. If your type has complicated ownership rules, event subscriptions, unmanaged resources, or shared caches, cloning can be error-prone. A copy that looks cheap may accidentally duplicate expensive state or, worse, share mutable internals.

### When to use and when not to use
Use Prototype when templates are natural, cloning semantics are well-defined, and you want fast derivation from a baseline instance. Prefer immutable objects when possible because copying is safer and easier to reason about.

Avoid Prototype when object graphs are large and mutable, when resource ownership is unclear, or when a factory/builder communicates intent better. In .NET, records with `with` are often the cleanest modern form of Prototype for immutable data.

## Code Example
```csharp
using System;

namespace KnowledgeBase.OopDesign;

public sealed record Address(string City, string Country);

public sealed record Employee(string Name, Address Address, string[] Skills)
{
    public Employee ShallowCopy() => this with { };

    public Employee DeepCopy() => this with
    {
        Address = Address with { },      // Copy nested record.
        Skills = [.. Skills]             // Copy mutable array.
    };
}

internal static class Program
{
    private static void Main()
    {
        var original = new Employee("Mila", new Address("Kyiv", "Ukraine"), ["C#", ".NET"]);

        var shallow = original.ShallowCopy();
        var deep = original.DeepCopy();

        shallow.Skills[0] = "Azure"; // Shared with original because shallow copy reused the array.
        deep.Skills[1] = "SQL";      // Independent because deep copy cloned the array.

        Console.WriteLine($"Original skills: {string.Join(", ", original.Skills)}");
        Console.WriteLine($"Shallow skills:  {string.Join(", ", shallow.Skills)}");
        Console.WriteLine($"Deep skills:     {string.Join(", ", deep.Skills)}");
    }
}
```

## Common Follow-up Questions
- Why is `ICloneable` considered ambiguous in public APIs?
- What exactly does `MemberwiseClone` copy?
- Does a record `with` expression perform a deep copy?
- When would you choose a copy constructor over Prototype?
- How would you clone an object graph that contains collections and child entities?

## Common Mistakes / Pitfalls
- Assuming `MemberwiseClone` gives a deep copy of nested reference-type fields.
- Exposing `ICloneable.Clone()` without documenting whether the copy is shallow or deep.
- Using `with` on records and forgetting that nested mutable references may still be shared.
- Cloning objects that hold unmanaged resources, event handlers, or external connections without clear ownership rules.
- Copying EF Core tracked entities blindly and expecting the change tracker to behave correctly.

## References
- [Prototype](https://refactoring.guru/design-patterns/prototype)
- [ICloneable Interface](https://learn.microsoft.com/dotnet/api/system.icloneable)
- [Object.MemberwiseClone Method](https://learn.microsoft.com/dotnet/api/system.object.memberwiseclone)
- [Records - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/record)
