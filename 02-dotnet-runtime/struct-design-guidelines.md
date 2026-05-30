# Struct Design Guidelines

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🟡 Middle
**Tags:** `struct`, `design guidelines`, `immutability`, `IEquatable<T>`, `defensive copies`, `value semantics`

## Question

> When should you use a `struct` instead of a `class` in .NET?

Also asked as:
> What are the main design guidelines for custom structs?
> Why do people mention a 16-byte guideline and `IEquatable<T>` when designing value types?

## Short Answer

Use a `struct` when the type is small, immutable, and represents a value rather than an identity-bearing object. The classic guideline is to keep it around 16 bytes or less, avoid inheritance needs, and implement `IEquatable<T>` so equality checks stay efficient and avoid boxing. If the type is large, mutable, or meant to be shared and updated through references, a `class` is usually the better design.

## Detailed Explanation

### The Core Heuristic

A custom struct should model a **value**: something where two instances with the same data are naturally considered equal, like a point, range, timestamp pair, or money amount. Structs excel when they are copied freely, embedded inline, and short-lived.

The usual heuristic is:

| Good candidate for `struct` | Better as `class` |
|---|---|
| Small data payload | Large object graph |
| Immutable state | Mutable shared state |
| Value semantics | Identity/lifecycle matters |
| No inheritance needed | Inheritance/polymorphism needed |
| Frequently allocated temporaries | Long-lived domain entities |

### Why the 16-Byte Guideline Exists

The “16-byte rule” is not a hard CLR limit, but a practical design guideline. On modern 64-bit systems, 16 bytes fits in two 64-bit words, which often aligns well with register-based calling conventions and keeps copies relatively cheap.

That does **not** mean a 24-byte struct is always wrong. It means once a struct gets larger, the cost of copying grows, and hidden copies become more expensive. This matters in loops, method calls, LINQ pipelines, and collections.

> **Warning:** Developers sometimes choose `struct` to “avoid heap allocation,” then accidentally create a large value type that gets copied everywhere. That can be slower than a small heap allocation plus a copied reference.

### Immutability Is the Default Goal

Mutable structs are a common source of bugs because copies are easy to create accidentally. If you mutate one copy, the caller may not see the change they expected. Readonly contexts can also trigger defensive copies for mutable structs, making behavior and performance harder to reason about.

That is why the recommended pattern is a **small immutable readonly struct**. See [readonly-struct.md](./readonly-struct.md).

### Equality: Default vs Custom

All structs inherit `ValueType`, which provides default field-by-field equality. That is convenient, but it is usually slower than implementing `IEquatable<T>` yourself because the runtime may need reflection-like logic and some call paths can box.

A well-designed struct should usually implement:

- `IEquatable<T>`
- `override bool Equals(object?)`
- `override int GetHashCode()`
- optional `==` and `!=` operators

This gives you predictable value equality and better behavior in generic collections like `Dictionary<TKey, TValue>` or `HashSet<T>`.

### Defensive Copies in Readonly Contexts

Even if a struct is semantically a value, mutability hurts performance. When a non-readonly struct is accessed through an `in` parameter or readonly field, the compiler may create a defensive copy before invoking members. That hidden copy is one reason mutable structs are discouraged.

### Practical Interview Answer

A strong answer combines design and performance: use a struct for small immutable value objects, keep it around 16 bytes when practical, implement `IEquatable<T>`, and avoid mutable structs because of copy-related bugs and defensive-copy penalties.

## Code Example

```csharp
namespace RuntimeSamples;

public readonly struct CurrencyAmount(decimal amount, string currency) : IEquatable<CurrencyAmount>
{
    public decimal Amount { get; } = amount;
    public string Currency { get; } = currency;

    public bool Equals(CurrencyAmount other) =>
        Amount == other.Amount && string.Equals(Currency, other.Currency, StringComparison.Ordinal);

    public override bool Equals(object? obj) => obj is CurrencyAmount other && Equals(other);
    public override int GetHashCode() => HashCode.Combine(Amount, Currency);

    public static bool operator ==(CurrencyAmount left, CurrencyAmount right) => left.Equals(right);
    public static bool operator !=(CurrencyAmount left, CurrencyAmount right) => !left.Equals(right);
}

public static class StructGuidelinesDemo
{
    public static void Main()
    {
        CurrencyAmount a = new(10m, "USD");
        CurrencyAmount b = new(10m, "USD");

        Console.WriteLine(a == b); // True: value equality

        HashSet<CurrencyAmount> amounts = [a, b];
        Console.WriteLine(amounts.Count); // 1 because equality is implemented correctly
    }
}
```

## Common Follow-up Questions

- What problems do mutable structs cause in real code?
- Why is `IEquatable<T>` better than relying only on `Equals(object)`?
- Is the 16-byte rule strict, or just a guideline?
- How do readonly fields and `in` parameters interact with mutable structs?
- Why are `DateTime`, `Guid`, and `decimal` structs rather than classes?

## Common Mistakes / Pitfalls

- Choosing `struct` purely to avoid heap allocation without considering copy cost.
- Creating a mutable struct and then being surprised by changes happening on a copy instead of the original value.
- Skipping `IEquatable<T>` and paying for slower or boxing-prone equality paths.
- Designing a struct that logically needs inheritance or identity.
- Treating the 16-byte rule as a law instead of a performance-oriented guideline.

## References

- [Choosing between class and struct](https://learn.microsoft.com/dotnet/standard/design-guidelines/choosing-between-class-and-struct)
- [struct - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/struct)
- [IEquatable<T> - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.iequatable-1)
- [Guidelines for overriding Equals and operator ==](https://learn.microsoft.com/dotnet/standard/design-guidelines/equality-operators)
