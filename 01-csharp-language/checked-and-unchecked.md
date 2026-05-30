# `checked` and `unchecked`

**Category:** C# / Misc Language Mechanics
**Difficulty:** Middle
**Tags:** `checked`, `unchecked`, `overflow`, `overflowexception`, `numeric-conversions`

## Question

> How do `checked` and `unchecked` work in C#, and what is the default overflow behavior?

Also asked as:
- "When does integer overflow throw `OverflowException` versus wrap around?"
- "What is the difference between a checked statement and a checked operator expression?"
- "How do `checked` and `unchecked` affect numeric casts and user-defined checked operators?"

## Short Answer

For integral arithmetic and narrowing numeric conversions, unchecked behavior usually wraps or truncates, while checked behavior throws `OverflowException`. C# lets you apply this either to a whole block with a statement or to a single expression with an operator form. In .NET 8/9 code, use `checked` around correctness-critical arithmetic and remember that user-defined checked operators can participate as well.

## Detailed Explanation

### What the default overflow behavior means

In C#, overflow behavior matters most for integral numeric types such as `int`, `long`, `byte`, and their unsigned counterparts. If an operation exceeds the destination range, the result either wraps/truncates or throws, depending on the overflow-checking context.

| Scenario | `unchecked` behavior | `checked` behavior |
|---|---|---|
| `int.MaxValue + 1` | Wraps to a negative value | Throws `OverflowException` |
| `(byte)300` | Truncates to `44` | Throws `OverflowException` |
| Checked user-defined conversion | Uses unchecked form if available | Uses checked form if defined |

### Statement form vs operator form

You can control overflow behavior for a whole block or a single expression.

| Form | Example | Best use |
|---|---|---|
| Statement | `checked { ... }` | Several related calculations |
| Expression/operator | `checked(a + b)` | One specific arithmetic operation or cast |
| Statement | `unchecked { ... }` | Intentional wraparound block |
| Expression/operator | `unchecked((byte)value)` | One specific conversion |

> **Tip:** Prefer the expression form when you want the risky operation to be obvious at the exact call site.

### What actually throws

`checked` is mainly about integral arithmetic and conversions. It does **not** turn every numeric problem into an exception. For example, floating-point math follows IEEE behavior, so overflow usually produces `Infinity` instead of `OverflowException`.

Constant expressions are also special: if the compiler can prove overflow at compile time, it may report a compile-time error unless you explicitly place the expression in an `unchecked` context.

### Guidance for modern .NET code

Wraparound can be correct in specialized low-level code, hashing, or protocol logic, but in most business code it is a bug. That is why `checked` is a good default around financial calculations, counters, pagination math, and any domain where silent overflow would be dangerous.

This topic connects directly to [implicit-vs-explicit-conversions.md](./implicit-vs-explicit-conversions.md) because narrowing conversions are one of the most common overflow cases.

## Code Example

```csharp
using System;

int max = int.MaxValue;
int source = 300;

int wrapped = unchecked(max + 1); // Wraps around to int.MinValue.
Console.WriteLine($"Unchecked result: {wrapped}");

try
{
    int failing = checked(max + 1); // Throws instead of wrapping.
    Console.WriteLine(failing);
}
catch (OverflowException ex)
{
    Console.WriteLine($"Checked arithmetic failed: {ex.GetType().Name}");
}

byte truncated = unchecked((byte)source); // Truncates to 44.
Console.WriteLine($"Unchecked cast: {truncated}");

try
{
    byte failingCast = checked((byte)source); // Throws OverflowException.
    Console.WriteLine(failingCast);
}
catch (OverflowException ex)
{
    Console.WriteLine($"Checked cast failed: {ex.GetType().Name}");
}
```

## Common Follow-up Questions

- Which C# numeric operations are most affected by `checked` and `unchecked`?
- When should you use a statement form instead of an expression form?
- Why does `checked` throw for integral overflow but floating-point overflow usually does not?
- How do checked user-defined conversion operators fit into this model?
- When is intentional wraparound actually acceptable?

## Common Mistakes / Pitfalls

- Assuming overflow always throws by default in all contexts.
- Using unchecked arithmetic in business code without documenting why wraparound is acceptable.
- Forgetting that narrowing casts like `(byte)value` are overflow-sensitive too.
- Believing `checked` protects against every numeric bug, including floating-point precision issues.
- Hiding risky arithmetic far away from the place where overflow matters.

## References

- [The checked and unchecked statements - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/checked-and-unchecked)
- [User-defined explicit and implicit conversion operators - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/user-defined-conversion-operators)
- [See: implicit-vs-explicit-conversions.md](./implicit-vs-explicit-conversions.md)
- [See: operator-overloading.md](./operator-overloading.md)
- [See: readonly-vs-const.md](./readonly-vs-const.md)
