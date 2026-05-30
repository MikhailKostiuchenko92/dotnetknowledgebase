# `default` Keyword and Default Values

**Category:** C# / Type System
**Difficulty:** 🟢 Junior
**Tags:** `default`, `default(T)`, `default-literal`, `value-types`, `null`, `zero`

## Question

> What does the `default` keyword do in C#, and what value does it produce for different types?

Additional phrasings:
- *"What is the difference between `default(T)` and the `default` literal introduced in C# 7.1?"*
- *"What is the default value of a `struct` that has no parameterless constructor?"*

## Short Answer

`default(T)` produces the **zero value** for a type: `0` for numeric types, `false` for `bool`, `'\0'` for `char`, `null` for reference types and `Nullable<T>`, and a struct with all fields zeroed. Since C# 7.1, the `default` literal can be used anywhere the compiler can infer the type, dropping the redundant `(T)`. Default values matter because they are the initial values of uninitialized fields and array elements, and appear in generic code that must produce a "nothing" value.

## Detailed Explanation

### Default Values by Type Category

| Type category | Default value |
|---|---|
| Numeric (`int`, `double`, `decimal`, …) | `0` / `0.0` / `0M` |
| `bool` | `false` |
| `char` | `'\0'` (null character) |
| `enum` | `0` cast to the enum type (the member with value 0, if one exists) |
| Reference type (`class`, `string`, `interface`, `delegate`) | `null` |
| `Nullable<T>` / `T?` | `null` (i.e., `new Nullable<T>()` — `HasValue == false`) |
| `struct` | All fields recursively zeroed |
| Pointer types | `null` (zero address) |

### `default(T)` Syntax

The explicit form:

```csharp
int n = default(int);       // 0
string s = default(string); // null
DateTime dt = default(DateTime); // 01/01/0001 00:00:00
```

This is valid for any type `T`, including generics:

```csharp
T Zero<T>() => default(T); // returns 0, false, null, or zeroed struct depending on T
```

### `default` Literal (C# 7.1+)

The `default` literal drops the explicit type when the compiler can infer it:

```csharp
int n = default;            // same as default(int)
string s = default;         // same as default(string)

void Foo(DateTime dt = default) { } // optional parameter default
```

This is especially useful in generic code, optional parameters, and `switch` expressions.

### Structs and Default Values

A `struct` always has an implicit parameterless constructor that zeroes all fields. You cannot prevent this — even if you define your own parameterless `struct` constructor (C# 10+), the `default` expression still produces the all-zero version, **not** your custom constructor result:

```csharp
struct Angle
{
    public Angle() => Degrees = 90; // custom parameterless ctor (C# 10+)
    public double Degrees { get; }
}

Angle a = new Angle();     // Degrees = 90  (calls your ctor)
Angle b = default;         // Degrees = 0   (zero-initialized, skips your ctor)
Angle[] arr = new Angle[3]; // all elements have Degrees = 0
```

> **Important:** This means `default(T)` for a struct may produce an **invalid or sentinel value** if the struct's design requires all instances to be created via a constructor (e.g., a `struct` representing a non-zero money amount). If your struct has an invariant that the default breaks, document this clearly.

### Generic Code

`default` is the idiomatic way to return "nothing" in generic methods:

```csharp
// Works for both value types and reference types
T FirstOrDefault<T>(IEnumerable<T> source)
{
    foreach (var item in source)
        return item;
    return default; // 0 for int, null for class, zeroed struct for struct
}
```

This is exactly how `Enumerable.FirstOrDefault` is implemented.

### `default` in Pattern Matching (C# 8+)

`default` serves as the catch-all arm in a `switch` expression, matching any value:

```csharp
string Describe(int n) => n switch
{
    0 => "zero",
    < 0 => "negative",
    _ => "positive"  // '_' discard pattern, not 'default'
};
```

Note: in a `switch` *statement*, the `default:` label is the catch-all case — that usage pre-dates C# 7.1.

## Code Example

```csharp
// === Explicit default(T) ===
Console.WriteLine(default(int));       // 0
Console.WriteLine(default(bool));      // False
Console.WriteLine(default(char));      // (null char '\0')
Console.WriteLine(default(string));    // (prints nothing — null)
Console.WriteLine(default(DateTime));  // 1/1/0001 12:00:00 AM

// === default literal (C# 7.1) — type inferred ===
int x = default;          // 0
double y = default;       // 0.0
string? s = default;      // null

// === default in optional parameter ===
void Greet(string name = default!) // null-forgiving to appease NRT
    => Console.WriteLine(name ?? "stranger");

// === default(T) in generics ===
T Identity<T>(T? value) where T : struct => value ?? default;
Console.WriteLine(Identity<int>(null)); // 0

// === Struct default — bypasses custom ctor ===
struct Counter
{
    public Counter() => Value = 1; // C# 10+ custom parameterless ctor
    public int Value { get; private set; }
}

Counter c1 = new Counter();  // Value = 1
Counter c2 = default;        // Value = 0 (zero-init, NOT your ctor)
Counter[] arr = new Counter[5]; // all Value = 0

Console.WriteLine($"new: {c1.Value}, default: {c2.Value}, arr[0]: {arr[0].Value}");
// new: 1, default: 0, arr[0]: 0

// === default in switch expression ===
string Classify(object? obj) => obj switch
{
    null => "null",
    int n when n > 0 => "positive int",
    string str => $"string: {str}",
    _ => "something else"
};
```

## Common Follow-up Questions

- Why does `default` for a struct bypass a custom parameterless constructor?
- How does `default` interact with nullable reference types — does `default(string)` generate a warning?
- How do you constrain a generic type parameter so that `default(T)` returns `null` (reference type only)?
- How is `default` used in `switch` expressions vs `switch` statements?
- What value does `default(CancellationToken)` produce, and is it safe to use?

## Common Mistakes / Pitfalls

- **Assuming `default` always means `null`.** For value types, `default` means zero, not null. `default(int)` is `0`, not a nullable.
- **Relying on `default(struct)` being valid.** If a struct has invariants (e.g., "ID must be non-zero"), `default` may produce an invalid sentinel. Design structs so that the zero state is meaningful, or document the limitation clearly.
- **Forgetting that arrays and uninitialized fields use `default`.** `new int[10]` gives you `{0,0,0,...}`, `new string[3]` gives `{null, null, null}`. NRT analysis will warn about accessing these without null checks.
- **Using `default` in a switch expression thinking it's the catch-all pattern.** In `switch` expressions, the catch-all is `_` (the discard pattern), not `default`. `default` only appears in `switch` *statements*.
- **`default(T)` in generics with `where T : struct` creating an unexpected sentinel state.** If callers interpret the zero-struct as "no result," make sure the API contract documents this or use `T?` with a nullable constraint.

## References

- [default value expressions — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/default)
- [Default values of C# types](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/default-values)
- [Structure types — parameterless constructors (C# 10)](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/struct#parameterless-constructors-and-field-initializers)
