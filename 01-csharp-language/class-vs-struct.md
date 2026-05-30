# Class vs Struct

**Category:** C# / OOP in C#
**Difficulty:** Junior
**Tags:** `class`, `struct`, `value-types`, `reference-types`, `boxing`, `readonly struct`

## Question

> What is the difference between a `class` and a `struct` in C#, and when should you choose one over the other?

Also asked as:
- "Are structs always on the stack and classes always on the heap?"
- "Why are small immutable structs usually recommended over large mutable ones?"

## Short Answer

A `class` is a reference type, while a `struct` is a value type. Structs are copied by value, are best when they are small and immutable, and can often avoid extra allocation pressure; classes are better for shared mutable identity, inheritance, and larger object graphs. The popular shortcut "struct = stack, class = heap" is incomplete: storage location depends on usage, while the deeper difference is value semantics versus reference semantics.

## Detailed Explanation

### The Real Difference: Semantics First

The most important distinction is not stack versus heap. It is **value semantics** versus **reference semantics**.

- A `class` variable usually holds a reference to an object.
- A `struct` variable contains the data itself.

That means assignment behaves differently. Assigning a class variable copies the reference. Assigning a struct variable copies the value.

### Why "Stack vs Heap" Is Only Partly True

Developers often say structs live on the stack and classes live on the heap. That is only a tendency, not a rule.

For example:
- A local struct may be stored inline in a stack frame.
- A struct field inside a class is stored inline inside the heap object.
- A boxed struct is wrapped in a heap allocation.
- The runtime may optimize storage in ways you should not depend on.

So the interview-safe phrasing is: **classes are reference types, structs are value types, and their storage location depends on context.**

### Comparison Table

| Aspect | `class` | `struct` |
|---|---|---|
| Type category | Reference type | Value type |
| Assignment | Copies reference | Copies value |
| Nullability | Can be `null` (unless non-nullable annotation) | Non-null by default; `T?` uses `Nullable<T>` |
| Inheritance | Supports class inheritance | Cannot inherit from another struct/class |
| Default use case | Shared identity and behavior | Small, data-like values |
| Boxing risk | No boxing for class instance | Boxing can occur when cast to `object` or interface |

### When a Struct Is a Good Fit

A struct is usually a good choice when:
- It represents a single value or small group of values.
- It is logically value-like, such as a point, date range, money amount, or measurement.
- It is immutable.
- Copying it is cheap.

This is why framework types like `DateTime`, `Guid`, `TimeSpan`, and `int` are structs.

`readonly struct` is especially useful because it expresses immutability intent and can help avoid defensive copies in some scenarios.

> **Tip:** Prefer a small immutable `readonly struct` for value-like concepts. If the type is large, frequently mutated, or identity-based, a class is usually safer.

### When a Class Is a Better Fit

Choose a class when:
- The type has identity beyond its field values.
- Multiple callers should observe the same mutable instance.
- You need inheritance or polymorphism.
- The object is large enough that copying would be expensive.

Entity and service objects are usually classes, not structs.

### Boxing and Performance Pitfalls

Structs can improve performance, but only when used carefully. A common trap is boxing. Boxing happens when a value type is converted to `object`, `dynamic`, or an interface reference. That creates an allocation and defeats part of the reason you chose a struct.

Another trap is making a large mutable struct. Because structs copy by value, mutating copies can lead to confusing bugs and extra copying cost.

See also [value-types-vs-reference-types.md](./value-types-vs-reference-types.md).

## Code Example

```csharp
using System;

Person alice = new("Alice");
Person alias = alice;
alias.Name = "Updated";

Console.WriteLine(alice.Name); // Updated: both variables reference the same object.

Point p1 = new(10, 20);
Point p2 = p1;
p2 = p2 with { X = 99 }; // Copy, then change the copy.

Console.WriteLine($"p1 = ({p1.X}, {p1.Y})"); // (10, 20)
Console.WriteLine($"p2 = ({p2.X}, {p2.Y})"); // (99, 20)

object boxed = p1; // Boxing: the struct is wrapped in an object allocation.
Console.WriteLine(boxed);

sealed class Person
{
    public string Name { get; set; }

    public Person(string name) => Name = name;
}

readonly record struct Point(int X, int Y);
```

## Common Follow-up Questions

- Why is "structs live on the stack" an oversimplification?
- What is boxing, and why can it hurt performance?
- When should you use `readonly struct`?
- Why are large mutable structs usually discouraged?
- How does passing a struct by `in`, `ref`, or `readonly ref` change copying behavior?

## Common Mistakes / Pitfalls

- Choosing a struct only because you want "stack allocation" without considering semantics.
- Creating a large mutable struct that gets copied frequently.
- Forgetting about boxing when a struct is used through `object` or an interface.
- Using a struct for an entity-like type that really needs identity and shared mutation.

## References

- [Structure types — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/struct)
- [Classes — C# reference](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/classes)
- [Boxing and Unboxing — C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/types/boxing-and-unboxing)
- [See: value-types-vs-reference-types.md](./value-types-vs-reference-types.md)
- [See: boxing-and-unboxing.md](./boxing-and-unboxing.md)
