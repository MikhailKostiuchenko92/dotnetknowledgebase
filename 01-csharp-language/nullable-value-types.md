# Nullable Value Types

**Category:** C# / Type System
**Difficulty:** 🟡 Middle
**Tags:** `Nullable<T>`, `T?`, `nullable`, `lifting`, `HasValue`, `value-types`

## Question

> How do nullable value types work in C#? What is `Nullable<T>`, what is "lifting," and what is the difference between `HasValue` and `== null`?

Additional phrasings:
- *"What is the difference between `int?` and `int`? How is it represented in memory?"*
- *"What happens when you compare a nullable value type to `null`?"*

## Short Answer

`int?` is shorthand for `Nullable<int>`, a generic struct that wraps a value type with an additional `bool HasValue` flag. When `HasValue` is false the struct has no value (conceptually `null`). The C# compiler **lifts** operators and conversions to work transparently on nullable types: `int? a = 3; int? b = null; var c = a + b;` produces `null` because one operand has no value. Comparing a nullable to `null` is equivalent to checking `!HasValue`.

## Detailed Explanation

### What `Nullable<T>` Is

```csharp
public struct Nullable<T> where T : struct
{
    private readonly T _value;
    private readonly bool _hasValue;

    public bool HasValue => _hasValue;
    public T Value => _hasValue ? _value : throw new InvalidOperationException();
    public T GetValueOrDefault() => _value;
    public T GetValueOrDefault(T defaultValue) => _hasValue ? _value : defaultValue;
}
```

Two key properties:
- `T` is constrained to `struct` — you cannot create `Nullable<string>` (strings are already nullable as reference types).
- Accessing `.Value` when `HasValue == false` throws `InvalidOperationException`.

### Memory Layout

A `Nullable<int>` is **8 bytes** on most runtimes (4 bytes for the `int`, 4 bytes for the `bool` with padding) — larger than a plain `int` (4 bytes). This matters for structs inside arrays or hot data structures.

> The JIT applies special handling: comparing a `Nullable<T>` to `null` is lowered directly to a check of the hidden `_hasValue` flag — no boxing occurs.

### The `?` Shorthand

`int?` is syntactic sugar for `Nullable<int>`, transformed by the compiler. Everywhere you write `T?` for a value type, the compiler substitutes `Nullable<T>`.

### Lifted Operators

The compiler **lifts** operators to work on `Nullable<T>`:
- A lifted binary operator returns `null` if either operand is `null`.
- Comparison operators (`<`, `>`, `<=`, `>=`) return `false` (not `null`) if either operand is `null`.
- The equality operators (`==`, `!=`) follow nullable semantics: `null == null` is `true`.

```csharp
int? a = 5, b = null;
int? sum  = a + b;    // null
bool less = a < b;    // false (not null — comparison lifts to bool, not bool?)
bool eq   = b == null; // true
```

### Null Coalescing and Propagation

The `??` and `?.` operators integrate natively with nullable value types:

```csharp
int? x = null;
int y = x ?? 42;       // 42
int? z = x ?? default; // 0

// ??= (C# 8+)
x ??= 10;              // assigns 10 if x is null
```

### `HasValue` vs `== null`

They are semantically equivalent — the compiler translates `x == null` to `!x.HasValue` at the IL level. Use whichever reads more clearly:

```csharp
int? val = GetValue();
if (val.HasValue) { /* use val.Value */ }
if (val != null)  { /* same thing; val.Value is safe here */ }
if (val is int n) { /* pattern matching — also works, binds n */ }
```

Pattern matching (`is int n`) is the most modern idiom because it safely binds the value in one operation.

### Boxing a Nullable Value Type

A nullable value type boxes in a special way:
- If `HasValue == true`: boxing produces a **box of `T`**, not a box of `Nullable<T>`. The resulting `object` is an `int`, not a `Nullable<int>`.
- If `HasValue == false`: boxing produces **`null`** — no heap allocation.

This means `(object)(int?)5 is int` is `true`, and `(object)(int?)null == null` is `true`.

### Nullable Value Types vs Nullable Reference Types (C# 8+)

These are completely different concepts:

| | Nullable value type (`int?`) | Nullable reference type (`string?`) |
|---|---|---|
| Mechanism | `Nullable<T>` struct | Annotation + compiler warnings only |
| Runtime behavior | Actual `bool` flag in struct | No runtime difference vs `string` |
| Can be `null` at runtime? | Yes (controlled by `HasValue`) | Yes (it's just a `string` — annotations are compile-time only) |
| Available since | C# 2 / .NET 2.0 | C# 8 / .NET 3.0 |

[See: nullable-reference-types.md](./nullable-reference-types.md) for NRT coverage.

## Code Example

```csharp
// === Nullable<T> basics ===
int? age = null;
Console.WriteLine(age.HasValue);        // False
Console.WriteLine(age.GetValueOrDefault(-1)); // -1

age = 30;
Console.WriteLine(age.HasValue);        // True
Console.WriteLine(age.Value);           // 30

// === Lifted operators ===
int? a = 10, b = null;
Console.WriteLine(a + b);   // (empty — null)
Console.WriteLine(a + 5);   // 15
Console.WriteLine(a > b);   // False (comparison with null is always false)
Console.WriteLine(a == b);  // False
Console.WriteLine(b == null); // True

// === Pattern matching (preferred modern style) ===
int? score = GetScore();
string result = score switch
{
    null         => "no score",
    < 0          => "invalid",
    >= 90        => "A",
    >= 70        => "B",
    _            => "C or below"
};

int? GetScore() => new Random().Next(2) == 0 ? null : new Random().Next(101);

// === Boxing behavior ===
int? boxableVal = 42;
object boxed = boxableVal;    // boxes as int, not Nullable<int>
Console.WriteLine(boxed is int);          // True
Console.WriteLine(boxed is int n && n == 42); // True

int? nullVal = null;
object boxedNull = nullVal;   // boxes as null — no allocation
Console.WriteLine(boxedNull == null);     // True

// === ?? and ??= ===
int? config = null;
int timeout = config ?? 30;   // 30
config ??= 30;                 // now config = 30
Console.WriteLine(config);    // 30
```

## Common Follow-up Questions

- What happens when you call `.GetHashCode()` on a `null` nullable value type?
- Why is `Nullable<string>` not allowed?
- How does EF Core use `int?` and `bool?` to represent nullable database columns?
- How does the C# compiler handle `int?` in a `switch` expression?
- What is the difference between `T?` in a generic method with a `struct` constraint vs an unconstrained generic?
- How does `Nullable<T>` interact with `IEquatable<T>` and `IComparable<T>`?

## Common Mistakes / Pitfalls

- **Accessing `.Value` without checking `HasValue` first.** This throws `InvalidOperationException`, not a `NullReferenceException`. Always check `.HasValue`, use `GetValueOrDefault()`, or use the `??` / pattern matching approach.
- **Confusing `int?` (value type wrapper) with `string?` (NRT annotation).** The former has real runtime semantics; the latter is a compile-time-only hint.
- **Expecting `Nullable<string>` to compile.** It won't — `string` is a reference type, and `Nullable<T>` requires `where T : struct`.
- **Comparing nullable values with `<` / `>` and expecting `null` to propagate.** Comparisons (`<`, `>`, `<=`, `>=`) return `false` when either operand is `null`, not a lifted `bool?`. This differs from `+`/`-`/`*` which return `null`.
- **Using nullable value types in performance-sensitive structs without accounting for the size increase.** `Nullable<T>` is larger than `T` due to the `HasValue` flag plus padding. For a tight struct, consider a sentinel value approach instead (e.g., `int` with `-1` for "no value").

## References

- [Nullable value types — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/nullable-value-types)
- [Nullable<T> — .NET API reference](https://learn.microsoft.com/dotnet/api/system.nullable-1)
- [Using nullable types — C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/nullable-types/using-nullable-types)
- [Nullable arithmetic and lifted operators — C# spec](https://learn.microsoft.com/dotnet/csharp/language-reference/language-specification/expressions#11812-lifted-operators) (verify URL)
