# `readonly struct`

**Category:** C# / Records & Immutability
**Difficulty:** Middle
**Tags:** `readonly-struct`, `in`, `defensive-copies`, `immutability`, `performance`

## Question

> What does `readonly struct` mean in C#, and why can it improve correctness and performance?

Also asked as:
- "When should a struct be marked `readonly`?"
- "What are defensive copies, and how does `readonly struct` help avoid them?"
- "How does `in` interact with readonly structs?"

## Short Answer

A `readonly struct` is a value type whose instance fields cannot be modified after construction. That gives the compiler and JIT a stronger immutability contract, which helps prevent accidental state changes and can reduce defensive copies when the struct is passed by `in` or accessed through readonly references. It is a good fit for small immutable value objects, but it is not appropriate for mutable state containers.

## Detailed Explanation

### The Immutability Contract

Marking a struct as `readonly` means all instance fields must also be readonly, and instance members cannot mutate the struct's state. This is stronger than a naming convention; it is part of the type contract enforced by the compiler.

That matters because structs are copied by value. If a struct is conceptually immutable, `readonly struct` makes that explicit and prevents accidental mutation bugs.

### Defensive Copies

One of the most interview-worthy details is defensive copying. When the compiler has a readonly reference to a *mutable* struct, calling an instance member may require making a copy to ensure the original value is not mutated indirectly.

That can happen with:

- `in` parameters
- readonly fields
- `ref readonly` locals or returns

If the struct is declared `readonly`, the compiler knows instance members cannot mutate state, so many of those defensive copies become unnecessary.

| Scenario | Mutable struct | `readonly struct` |
|---|---|---|
| `in` parameter member call | May copy defensively | Often no defensive copy needed |
| Readonly field access | May copy | Safer and cheaper |
| Semantic intent | Unclear | Explicitly immutable |

### `in` Parameters and Performance

The `in` modifier passes a readonly reference to avoid copying large structs. But if the struct itself is not readonly, some of the benefit can disappear because of defensive copies during member access.

That is why `in` and `readonly struct` are often discussed together. They complement each other.

> **Tip:** The strongest combination for value-like data is often "small immutable struct" or "small `readonly record struct`" rather than a mutable struct with hidden behavior.

### JIT and Optimization Angle

Because the type is immutable by contract, the compiler and JIT can reason about it more aggressively. The main win is usually correctness first and reduced copies second, not some magical blanket speed boost.

### When to Use It

Good candidates:

- coordinates, money, date ranges, measurements
- small domain value objects
- types that should behave like primitive values

Poor candidates:

- structs with internal counters or setters
- large mutable aggregates
- types where mutation is part of the normal lifecycle

See also [class-vs-struct.md](./class-vs-struct.md), [value-types-vs-reference-types.md](./value-types-vs-reference-types.md), and [record-struct-vs-record-class.md](./record-struct-vs-record-class.md).

## Code Example

```csharp
using System;

Distance marathon = new(42.195);
Console.WriteLine(GetKilometers(in marathon));

public readonly struct Distance
{
    public Distance(double kilometers)
    {
        if (kilometers < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(kilometers));
        }

        Kilometers = kilometers;
    }

    public double Kilometers { get; }

    public double Miles => Kilometers * 0.621371; // Safe: no mutation.

    public override string ToString() => $"{Kilometers:0.###} km";
}

static double GetKilometers(in Distance distance)
{
    // Because Distance is readonly, the compiler does not need a defensive copy
    // just to read members like Kilometers or Miles.
    return distance.Kilometers;
}
```

## Common Follow-up Questions

- Why can member access on a readonly reference cause defensive copies for mutable structs?
- How does `readonly struct` differ from a struct with only get-only properties?
- When does `in` help, and when is it unnecessary overhead?
- Why should readonly structs usually remain small?
- How does `readonly record struct` relate to `readonly struct`?

## Common Mistakes / Pitfalls

- Using mutable structs where value semantics and copying become confusing.
- Assuming `readonly struct` means the entire object graph is deeply immutable.
- Marking a large struct readonly and then copying it everywhere anyway.
- Forgetting that a non-readonly instance member on a struct can trigger copies when used through readonly references.
- Choosing a struct at all when a small immutable class or record would be clearer.

## References

- [Structure types - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/struct)
- [Method parameters and modifiers](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/method-parameters)
- [See: class-vs-struct.md](./class-vs-struct.md)
- [See: record-struct-vs-record-class.md](./record-struct-vs-record-class.md)
- [See: value-types-vs-reference-types.md](./value-types-vs-reference-types.md)
