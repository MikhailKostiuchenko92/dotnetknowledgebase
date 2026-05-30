# Equality: `==` vs `Equals` vs `ReferenceEquals`

**Category:** C# / Type System
**Difficulty:** 🟡 Middle
**Tags:** `equality`, `==`, `Equals`, `ReferenceEquals`, `IEquatable`, `contract`, `GetHashCode`

## Question

> What is the difference between `==`, `Equals()`, and `ReferenceEquals()` in C#? What contract must a correct `Equals` implementation satisfy?

Additional phrasings:
- *"Why can `==` return a different result from `.Equals()` on the same two objects?"*
- *"What rules must you follow when overriding `Equals` and `GetHashCode`?"*

## Short Answer

`ReferenceEquals` always checks object identity (same memory address) and cannot be overridden. `Equals` is a virtual method — its default on `object` checks identity, but types can override it for value equality (e.g., `string`, `DateTime`, records). `==` is an operator that can be overloaded per type and is resolved at compile time based on the static type of the operands; for classes it defaults to reference equality, while `string` and `record` override it for value equality. The contract for `Equals` requires reflexivity, symmetry, transitivity, consistency, and `null`-safety.

## Detailed Explanation

### `ReferenceEquals(a, b)`

`Object.ReferenceEquals` is a **static method** that returns `true` only when `a` and `b` are the exact same object instance (or both `null`). It **cannot be overridden** and performs no virtual dispatch. Even boxing two equal value types yields `false`:

```csharp
int x = 1;
object a = x, b = x;   // two separate boxes
Console.WriteLine(ReferenceEquals(a, b)); // false — different heap objects
```

Use `ReferenceEquals` when you explicitly need identity comparison regardless of any overrides.

### `Equals(object? obj)` — Virtual, Overridable

`object.Equals` is a **virtual instance method**. Its default implementation checks reference equality (same as `ReferenceEquals`). Types that represent values override it:

| Type | `Equals` behavior |
|---|---|
| `object` (default) | Reference equality |
| `string` | Character-by-character comparison |
| `int`, `double`, numeric types | Numeric value equality |
| User `struct` | `ValueType.Equals`: field-by-field via reflection (slow!) |
| `record class` | Compiler-generated: member-by-member structural equality |
| `record struct` | Same as `record class` |
| `DateTime`, `Guid`, etc. | Value equality (overridden) |

`ValueType.Equals` (for plain `struct`) uses reflection internally — it is **slow and allocates**. Always override `Equals` (and `GetHashCode`) on structs you use as dictionary keys or frequently compare.

### `==` Operator — Compile-Time Overloadable

`==` is resolved at **compile time** based on the **static type** of the operands — it is not virtual. This means:

```csharp
object a = "hello";
object b = "hello";
Console.WriteLine(a == b);          // true — string interning AND object == uses reference eq... wait
```

Actually, when the **static type** is `object`, the `object.operator==` is called, which is `ReferenceEquals`. But in this specific case, string literals are interned, so they happen to be the same reference. This is an implementation detail — never rely on it.

```csharp
string a = new string("hello".ToCharArray()); // force non-interned
string b = new string("hello".ToCharArray());
Console.WriteLine(a == b);          // true — string.operator== is called (value equality)
Console.WriteLine((object)a == (object)b); // false — object.operator== is called (reference equality)
```

This is the most common source of bugs and interview trick questions.

### The `Equals` Contract

A correct `Equals` override must be:

1. **Reflexive:** `x.Equals(x)` is always `true`.
2. **Symmetric:** `x.Equals(y)` ↔ `y.Equals(x)`.
3. **Transitive:** if `x.Equals(y)` and `y.Equals(z)`, then `x.Equals(z)`.
4. **Consistent:** repeated calls with unchanged objects return the same value.
5. **Null-safe:** `x.Equals(null)` returns `false` (never throws).

Violating any of these can cause subtle bugs in collections, LINQ, and dictionary lookups.

### `IEquatable<T>` — Strongly Typed Equality

Implementing `IEquatable<T>` provides a typed `Equals(T other)` overload that avoids boxing for value types and allows direct comparison:

```csharp
struct Point : IEquatable<Point>
{
    public int X, Y;
    public bool Equals(Point other) => X == other.X && Y == other.Y;
    public override bool Equals(object? obj) => obj is Point p && Equals(p);
    public override int GetHashCode() => HashCode.Combine(X, Y);
    public static bool operator==(Point a, Point b) => a.Equals(b);
    public static bool operator!=(Point a, Point b) => !a.Equals(b);
}
```

This is the recommended pattern for any type used as a dictionary key or in equality comparisons.

### Records: Automatic Value Equality

`record class` and `record struct` have compiler-generated structural equality — you get `Equals`, `GetHashCode`, and `==` for free based on all declared properties:

```csharp
record Person(string Name, int Age);
var p1 = new Person("Alice", 30);
var p2 = new Person("Alice", 30);
Console.WriteLine(p1 == p2);         // true — value equality
Console.WriteLine(p1.Equals(p2));    // true
Console.WriteLine(ReferenceEquals(p1, p2)); // false — different instances
```

[See: value-equality-in-records.md](./value-equality-in-records.md) for customizing record equality.
[See: gethashcode-contract.md](./gethashcode-contract.md) for `GetHashCode` rules.

## Code Example

```csharp
// === String: == uses value equality when static type is string ===
string s1 = new string("abc".ToCharArray()); // non-interned
string s2 = new string("abc".ToCharArray());
Console.WriteLine(s1 == s2);               // true  — string.operator==
Console.WriteLine(s1.Equals(s2));          // true
Console.WriteLine(ReferenceEquals(s1, s2)); // false — different instances
Console.WriteLine((object)s1 == (object)s2); // false — object.operator==

// === Class with no overrides: default reference equality ===
class Box { public int Value; }
var b1 = new Box { Value = 1 };
var b2 = new Box { Value = 1 };
Console.WriteLine(b1 == b2);        // false — reference equality (same as ReferenceEquals)
Console.WriteLine(b1.Equals(b2));   // false — same

// === Record: compiler-generated value equality ===
record Point(int X, int Y);
var p1 = new Point(1, 2);
var p2 = new Point(1, 2);
Console.WriteLine(p1 == p2);        // true — record equality
Console.WriteLine(ReferenceEquals(p1, p2)); // false

// === IEquatable<T> on struct: avoid boxing, fast comparison ===
struct Money(decimal Amount, string Currency) : IEquatable<Money>
{
    public bool Equals(Money other) =>
        Amount == other.Amount && Currency == other.Currency;
    public override bool Equals(object? obj) => obj is Money m && Equals(m);
    public override int GetHashCode() => HashCode.Combine(Amount, Currency);
    public static bool operator ==(Money a, Money b) => a.Equals(b);
    public static bool operator !=(Money a, Money b) => !a.Equals(b);
}

var m1 = new Money(9.99m, "USD");
var m2 = new Money(9.99m, "USD");
Console.WriteLine(m1 == m2);        // true
Console.WriteLine(m1.Equals(m2));   // true (no boxing)
```

## Common Follow-up Questions

- What rules must `GetHashCode` follow, and what happens if you override `Equals` without overriding `GetHashCode`?
- Why is it dangerous to use a mutable object as a dictionary key?
- How does `record`'s synthesized equality handle inheritance?
- How do `EqualityComparer<T>.Default` and custom `IEqualityComparer<T>` work?
- What does the Roslyn analyzer `CS0660`/`CS0661` warn about, and why?
- How does `StringComparison` affect `string.Equals` vs `==`?

## Common Mistakes / Pitfalls

- **Overriding `Equals` without overriding `GetHashCode`.** The C# compiler warns about this (`CS0659`). If two objects are equal they must have the same hash code. Violating this breaks `Dictionary<>`, `HashSet<>`, and LINQ `Distinct`.
- **Using `==` on an `object`-typed variable when you expect value equality.** The `object.operator==` performs reference equality. Cast to the concrete type first, or use `.Equals()`.
- **Relying on string literal interning.** `"abc" == "abc"` is `true` (same interned string), but dynamically constructed equal strings compared as `object` may be `false`. Never assume interning.
- **Forgetting `null` handling in `Equals`.** `x.Equals(null)` must return `false` without throwing. Forgetting this causes `NullReferenceException` surprises.
- **Mutable struct / class as dictionary key.** If the fields used in `GetHashCode` change after insertion, the key can no longer be found in the dictionary — a silent data loss bug.

## References

- [Object.Equals — .NET API](https://learn.microsoft.com/dotnet/api/system.object.equals)
- [Object.ReferenceEquals — .NET API](https://learn.microsoft.com/dotnet/api/system.object.referenceequals)
- [IEquatable<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.iequatable-1)
- [Equality comparisons — C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/statements-expressions-operators/equality-comparisons)
- [How to define value equality for a class — C# how-to guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/statements-expressions-operators/how-to-define-value-equality-for-a-type)
