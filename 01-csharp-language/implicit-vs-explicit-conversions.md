# `implicit` vs `explicit` Conversions

**Category:** C# / Misc Language Mechanics
**Difficulty:** Middle
**Tags:** `implicit`, `explicit`, `conversion-operators`, `checked`, `csharp-11`

## Question

> What is the difference between `implicit` and `explicit` conversions in C#, and when should you define each?

Also asked as:
- "Which conversions should be automatic, and which should require a cast?"
- "Why are lossy or surprising conversions usually `explicit`?"
- "How do checked conversion operators from C# 11 affect custom types?"

## Short Answer

Use `implicit` only for conversions that are safe, lossless, and unsurprising to callers. Use `explicit` when data can be lost, validation can fail, or the conversion changes meaning enough that the caller should opt in with a cast. In modern C# on .NET 8/9, C# 11's checked conversion operators let your custom types participate correctly in `checked` overflow contexts as well.

## Detailed Explanation

### The core rule: automatic only when it is truly safe

The built-in numeric conversions set the mental model: `int` to `long` is implicit because every `int` fits in a `long`, while `long` to `int` is explicit because information might be lost.

| Conversion style | Caller syntax | Appropriate when | Example |
|---|---|---|---|
| `implicit` | No cast required | Safe, lossless, obvious | `int` -> `long` |
| `explicit` | Cast required | Potentially lossy, failing, or surprising | `long` -> `int` |

> **Warning:** If the caller could reasonably be surprised by the result, make the conversion `explicit` even if it usually succeeds.

### User-defined conversions and domain modeling

For custom types, the question is not only "can the bits fit?" but also "does the conversion preserve meaning?" Converting a domain type to a primitive for display or storage is often safe. Going back from a primitive to a domain type may require validation or may silently drop context.

That is why operator design and conversion design belong together. See [operator-overloading.md](./operator-overloading.md) for the broader API design rules.

### Checked conversion operators in C# 11+

Since C# 11, you can define checked user-defined conversion operators. That means `checked((MyType)value)` can call a conversion operator specifically designed to throw on overflow, while `unchecked((MyType)value)` can call the unchecked version.

| Context | Which operator is preferred | Typical behavior |
|---|---|---|
| `checked(...)` | `explicit operator checked` | Throw on overflow |
| `unchecked(...)` or default unchecked path | `explicit operator` | Allow truncation/wrapping if implemented that way |

This integrates naturally with the overflow rules covered in [checked-and-unchecked.md](./checked-and-unchecked.md).

### Guidance for .NET 8/9 APIs

Prefer named factory methods when the conversion carries too much business meaning. `OrderId.Parse`, `Money.FromCents`, or `Distance.FromMiles` can be clearer than operator-based conversion if the domain is not obvious from the call site.

## Code Example

```csharp
using System;

PacketSize size = (PacketSize)120;
int bytes = size; // Implicit widening back to int.

Console.WriteLine($"Normal size: {bytes} bytes");
Console.WriteLine($"Unchecked cast: {(int)unchecked((PacketSize)300)} bytes");

try
{
    PacketSize tooLarge = checked((PacketSize)300); // Uses the checked conversion operator.
    Console.WriteLine(tooLarge);
}
catch (OverflowException ex)
{
    Console.WriteLine($"Checked conversion failed: {ex.GetType().Name}");
}

public readonly struct PacketSize
{
    private readonly byte _bytes;

    public PacketSize(byte bytes)
    {
        _bytes = bytes;
    }

    public static implicit operator int(PacketSize value) => value._bytes; // Safe widening conversion.

    public static explicit operator PacketSize(int value)
        => new((byte)value); // Unchecked form may truncate.

    public static explicit operator checked PacketSize(int value)
        => new(checked((byte)value)); // Checked form throws on overflow.

    public override string ToString() => $"{_bytes} bytes";
}
```

## Common Follow-up Questions

- Why is `int` to `long` implicit while `long` to `int` is explicit?
- What makes a user-defined conversion "surprising" even if it usually succeeds?
- How do checked conversion operators behave differently in `checked` and `unchecked` contexts?
- When is a named factory method better than a conversion operator?
- How do conversion operators relate to general operator overloading rules?

## Common Mistakes / Pitfalls

- Defining `implicit` conversions that can lose data or throw exceptions.
- Using conversion operators for business workflows that deserve named APIs.
- Forgetting to provide checked behavior for narrowing conversions in performance-sensitive or correctness-sensitive code.
- Assuming a conversion is safe just because the types look small or simple.
- Making both directions implicit and creating ambiguous or overly magical code.

## References

- [User-defined explicit and implicit conversion operators - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/user-defined-conversion-operators)
- [The checked and unchecked statements - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/checked-and-unchecked)
- [See: operator-overloading.md](./operator-overloading.md)
- [See: checked-and-unchecked.md](./checked-and-unchecked.md)
- [See: target-typed-new.md](./target-typed-new.md)
