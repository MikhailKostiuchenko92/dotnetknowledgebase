# readonly struct

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🟢 Junior
**Tags:** `readonly struct`, `in`, `defensive copies`, `immutability`, `IEquatable<T>`, `struct`

## Question

> What is a `readonly struct`, and why is it useful in C#?

Also asked as:
> How do `readonly struct` and `in` parameters work together?
> What is the defensive copy problem for non-readonly structs passed by `in`?

## Short Answer

A `readonly struct` guarantees that all instance fields are effectively immutable after construction, which makes the type safer and easier for the compiler to optimize. It works especially well with `in` parameters, because the compiler can pass the struct by readonly reference without creating defensive copies. For performance-sensitive value types, `readonly struct` is often the right default when the type represents a small immutable value.

## Detailed Explanation

### What `readonly struct` Guarantees

A normal struct can expose mutable fields or methods that modify internal state. A `readonly struct` tells the compiler that instance members must not mutate the current instance after construction. That improves correctness and communicates intent: this type behaves like a stable value, not a mini mutable object.

| Feature | Normal struct | `readonly struct` |
|---|---|---|
| Mutable instance fields allowed | Yes | No |
| Mutating instance members allowed | Yes | No |
| Safe with `in` parameters | Maybe | Yes, preferred |
| Defensive-copy risk in readonly contexts | Higher | Lower |

### `in` Parameters and Why They Exist

Passing a struct by value copies it. For tiny structs that is fine, but for larger structs repeated copying can add overhead. The `in` modifier passes a value type by reference while promising the callee will not mutate it.

That gives you two goals at once:

- avoid copying at the call boundary
- preserve value semantics by preventing mutation through the parameter

However, this only works cleanly if the struct itself is designed for readonly use.

### The Defensive Copy Problem

If a non-readonly struct is passed as `in`, the compiler must still protect readonly semantics. If you call an instance member that is not known to be readonly-safe, the compiler may create a **defensive copy** first. That means you thought you avoided copying, but a copy still happened.

> **Warning:** `in` does not automatically mean “zero copies.” For a mutable or non-readonly struct, calling instance members can trigger hidden defensive copies.

This is why `readonly struct` matters. Once the compiler knows instance members cannot mutate state, it can use the readonly reference directly instead of copying.

### Why This Improves API Design

`readonly struct` makes the intended semantics obvious:

- the value should not change after construction
- equality can be based on data, not identity
- passing by readonly reference is safe

That fits common value objects such as coordinates, ranges, GUID wrappers, or money amounts.

### Practical Guidelines

A good `readonly struct` should usually be:

- **small** enough that copies are cheap if they still happen
- **immutable** in public API shape
- explicit about equality, ideally implementing `IEquatable<T>`
- free of methods that conceptually mutate internal state

If the type is large, frequently boxed, or logically mutable, a class may be a better fit. See [struct-design-guidelines.md](./struct-design-guidelines.md).

### Interview-Ready Summary

The best concise answer is: `readonly struct` is both a correctness feature and a performance feature. It prevents mutation, works better with `in` parameters, and avoids hidden defensive copies that can surprise developers using non-readonly structs.

## Code Example

```csharp
namespace RuntimeSamples;

public readonly struct Measurement(double value, string unit) : IEquatable<Measurement>
{
    public double Value { get; } = value;
    public string Unit { get; } = unit;

    public bool Equals(Measurement other) => Value == other.Value && Unit == other.Unit;
    public override bool Equals(object? obj) => obj is Measurement other && Equals(other);
    public override int GetHashCode() => HashCode.Combine(Value, Unit);

    // Safe to call through an `in` parameter because the struct is readonly.
    public override string ToString() => $"{Value} {Unit}";
}

public struct MutableMeasurement(double value)
{
    public double Value = value;

    public readonly double GetValue() => Value;
}

public static class ReadonlyStructDemo
{
    public static void Print(in Measurement measurement)
    {
        Console.WriteLine(measurement); // No defensive copy required.
    }

    public static void PrintMutable(in MutableMeasurement measurement)
    {
        Console.WriteLine(measurement.GetValue());
        // With a non-readonly struct, some member access patterns can force defensive copies.
    }

    public static void Main()
    {
        Measurement distance = new(12.5, "km");
        Print(in distance);
    }
}
```

## Common Follow-up Questions

- What is the difference between `ref`, `in`, and `out` for struct parameters?
- Why can non-readonly structs trigger defensive copies in readonly contexts?
- Should every struct be declared `readonly` by default?
- How does `readonly struct` interact with `record struct`?
- Why is `IEquatable<T>` recommended for value types?

## Common Mistakes / Pitfalls

- Using `in` with a mutable struct and assuming that no copies will occur.
- Declaring a struct `readonly` but then designing APIs that conceptually require mutation.
- Forgetting to implement efficient equality for an immutable value type.
- Making a `readonly struct` too large, so even unavoidable copies become expensive.
- Confusing `readonly struct` with thread safety for contained reference-type fields.

## References

- [struct - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/struct)
- [Method parameters and modifiers (`in`, `ref`, `out`)](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/method-parameters)
- [Choosing between class and struct](https://learn.microsoft.com/dotnet/standard/design-guidelines/choosing-between-class-and-struct)
- [IEquatable<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.iequatable-1)
