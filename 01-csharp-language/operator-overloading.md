# Operator Overloading

**Category:** C# / Misc Language Mechanics
**Difficulty:** Middle
**Tags:** `operator-overloading`, `equality`, `conversion-operators`, `i-equatable`, `api-design`

## Question

> When should you overload operators in C#, and what rules apply to equality and conversion operators?

Also asked as:
- "How do you overload `+` or `==` correctly in a custom type?"
- "Why must equality operators come in pairs?"
- "Are conversion operators part of operator overloading, and when are they appropriate?"

## Short Answer

Operator overloading is appropriate when a custom type has a natural, unsurprising operator meaning, such as vector addition or money comparison. If you overload equality, you must provide the matching pair (`==` and `!=`) and keep it consistent with `Equals` and `GetHashCode`. Conversion operators are part of the same design surface, but in .NET 8/9 code they should be used sparingly and only when the conversion is obvious and safe to reason about.

## Detailed Explanation

### When operator overloading is a good fit

Operator overloading is about making domain types feel natural, not about being clever. Good candidates are mathematical or value-object types where operators map cleanly to user expectations.

| Good fit | Why it works | Poor fit | Why it confuses |
|---|---|---|---|
| `Vector + Vector` | Natural arithmetic meaning | `Repository + Repository` | No established meaning |
| `Money == Money` | Value comparison is intuitive | `User == string` | Hidden business logic |
| `Duration < Duration` | Ordering is obvious | `ServiceA * ServiceB` | Looks magical and unclear |

> **Tip:** If the operator meaning would need a code review comment to explain it, it is probably better as a named method.

### Equality operators must stay consistent

If you overload `==`, you must also overload `!=`. In practice, equality design should also line up with `Equals` and `GetHashCode`, especially for value-like types used in dictionaries or sets.

| Member | Why it matters |
|---|---|
| `==` and `!=` | Language-level equality syntax |
| `Equals` | Polymorphic equality API used by the BCL |
| `GetHashCode` | Required for hash-based collections |
| `IEquatable<T>` | Avoids boxing and improves typed equality |

This is closely related to [equality-equals-vs-reference-equals.md](./equality-equals-vs-reference-equals.md) and [gethashcode-contract.md](./gethashcode-contract.md).

### Conversion operators are part of the same design surface

User-defined `implicit` and `explicit` conversion operators are also operator overloads. They can be useful when moving between a domain type and a primitive representation, but the same design rule applies: the conversion must be predictable.

- Prefer `implicit` only when the conversion is safe and unsurprising.
- Prefer `explicit` when validation, truncation, or semantic interpretation is involved.
- For the deeper rules, see [implicit-vs-explicit-conversions.md](./implicit-vs-explicit-conversions.md).

### Design guidance for .NET 8/9 APIs

Modern C# gives you many concise features, but operator overloads are still long-lived API surface. Favor clarity over brevity. For simple formatting or parsing, named methods like `Parse`, `TryParse`, `FromMeters`, or `ToKilometers` are often better than custom operators.

## Code Example

```csharp
using System;

Distance morningRun = (Distance)2500; // Explicit: not every double is valid in every domain.
Distance eveningRun = (Distance)1800;
Distance total = morningRun + eveningRun; // Natural operator overload.

double meters = total; // Implicit: reading the numeric value is safe and unsurprising.

Console.WriteLine(total);
Console.WriteLine(morningRun == eveningRun);
Console.WriteLine($"Meters: {meters}");

public readonly struct Distance : IEquatable<Distance>
{
    public Distance(double meters)
    {
        if (meters < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(meters), "Distance cannot be negative.");
        }

        Meters = meters;
    }

    public double Meters { get; }

    public static Distance operator +(Distance left, Distance right)
        => new(left.Meters + right.Meters);

    public static bool operator ==(Distance left, Distance right) => left.Equals(right);
    public static bool operator !=(Distance left, Distance right) => !left.Equals(right);

    public static implicit operator double(Distance value) => value.Meters;
    public static explicit operator Distance(double meters) => new(meters);

    public bool Equals(Distance other) => Meters.Equals(other.Meters);
    public override bool Equals(object? obj) => obj is Distance other && Equals(other);
    public override int GetHashCode() => Meters.GetHashCode();
    public override string ToString() => $"{Meters:0.##} m";
}
```

## Common Follow-up Questions

- Which C# operators can and cannot be overloaded?
- Why must `==` and `!=` be defined together?
- Why should `Equals` and `GetHashCode` stay consistent with overloaded equality?
- When is a named method better than a custom operator?
- When should a conversion operator be `implicit` versus `explicit`?

## Common Mistakes / Pitfalls

- Overloading operators for types that do not have an obvious mathematical or value-like meaning.
- Implementing `==` without `!=`, or equality operators without matching `Equals` and `GetHashCode` behavior.
- Hiding business rules behind conversion operators that look simpler than they really are.
- Returning results that violate obvious expectations, such as adding values with incompatible units.
- Treating operator overloading as a readability win when it actually makes the API harder to discover.

## References

- [Operator overloading - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/operator-overloading)
- [User-defined explicit and implicit conversion operators - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/user-defined-conversion-operators)
- [See: implicit-vs-explicit-conversions.md](./implicit-vs-explicit-conversions.md)
- [See: equality-equals-vs-reference-equals.md](./equality-equals-vs-reference-equals.md)
- [See: gethashcode-contract.md](./gethashcode-contract.md)
