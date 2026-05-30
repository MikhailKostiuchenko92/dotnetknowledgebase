# Pattern Matching Overview

**Category:** C# / Pattern Matching
**Difficulty:** Middle
**Tags:** `pattern-matching`, `switch`, `is`, `property-patterns`, `list-patterns`, `logical-patterns`

## Question
> What is pattern matching in C#, and what kinds of patterns should a .NET developer know?

Related phrasings:
- "Can you explain constant, type, relational, logical, property, positional, and list patterns?"
- "How does modern pattern matching in C# 12/13 improve code compared with old `if`/`switch` chains?"
- "What do `var` and discard patterns do?"

## Short Answer
Pattern matching lets you test a value's shape, type, or contents and optionally bind matched data to local variables. In .NET 8/9 with C# 12/13, it covers constant, type, relational, logical, property, positional, and list patterns, plus helper forms such as `var` and discard. The result is code that is usually shorter, safer, and easier to read than repeated casts and nested `if` statements.

## Detailed Explanation

### What Pattern Matching Really Means
Pattern matching is more than "type checking with nicer syntax." A pattern can answer questions like:

- is this value an `int`?
- is this order's total greater than 100?
- does this object have `{ Status: "Paid", Customer: { IsVip: true } }`?
- does this array look like `["api", .., "health"]`?

That combination of testing and variable binding is why pattern matching became central to modern C# code.

### Core Pattern Categories
The main pattern categories you should know are below.

| Pattern kind | Example | Typical use |
|---|---|---|
| Constant | `x is 0`, `status is "Ready"` | Match exact values |
| Type | `obj is Customer customer` | Check type and bind value |
| Relational | `score is >= 90` | Compare ordered values |
| Logical | `is > 0 and < 10`, `is not null` | Combine or negate patterns |
| Property | `order is { Total: > 100m }` | Match object members by name |
| Positional | `point is (0, 0)` | Match deconstructed positions |
| List | `segments is ["api", .., "health"]` | Match sequences by shape |
| `var` | `x is var value` | Bind the current value |
| Discard | `_` | Catch-all match |

### Type, Constant, and Relational Patterns
The most common starting point is a type pattern such as `obj is User user`. It both checks the type and introduces a strongly typed local variable.

Constant and relational patterns extend the idea beyond types. Instead of writing `if (score >= 90 && score <= 100)`, you can say `score is >= 90 and <= 100`. That is often more readable inside a [switch-expressions.md](./switch-expressions.md) arm.

### Property and Positional Patterns
Property patterns let you inspect members by name:

```csharp
order is { Customer.IsVip: true, Total: > 1000m }
```

Positional patterns use a value's deconstruction order, either from a record's primary constructor or an explicit `Deconstruct` method:

```csharp
point is (0, 0)
```

These patterns are covered in more detail in [property-and-positional-patterns.md](./property-and-positional-patterns.md).

### Logical Patterns: `and`, `or`, `not`
Logical patterns make patterns composable. They are especially useful for ranges and exclusions:

- `c is >= 'a' and <= 'z'`
- `value is null or ""`
- `input is not null`

> **Tip:** Mention operator precedence in interviews. `not` binds tightly, then `and`, then `or`. Parentheses improve clarity when a condition is non-trivial.

### List Patterns
List patterns, added in C# 11 and fully relevant in C# 12/13, let you match arrays and other list-like types by shape. For example:

- `[]` for empty
- `[x]` for exactly one item
- `[head, .. tail]` for a sequence with a first element and the rest

They are powerful in parsers, command routing, and small protocol handlers. See [list-patterns.md](./list-patterns.md).

### `var` and Discard Patterns
The `var` pattern always matches and binds the current value to a new variable. It is useful when you want to name a subexpression in a switch arm or continue a fluent pattern pipeline.

The discard pattern `_` means "anything else." It is often the final fallback arm in a switch.

### Why Pattern Matching Matters in Real .NET Code
In .NET 8/9 applications, pattern matching appears everywhere:

- ASP.NET Core request classification
- result mapping and error handling
- command parsing
- domain rule checks
- null-safe flow with [nullable-reference-types.md](./nullable-reference-types.md)

Compared with old `if (obj != null && obj is Foo)` style code, modern patterns are terser and reduce double-checking and manual casts.

## Code Example
```csharp
using System;

object? input = new Order(new Customer(true), 1250m, ["api", "v1", "orders"]);

string description = input switch
{
    null => "No value",
    0 => "Constant pattern: zero",
    int number and > 0 and < 10 => $"Relational + logical pattern: small number {number}",
    string { Length: > 5 } text => $"Property pattern on string length: {text}",
    Order { Customer: { IsVip: true }, Total: > 1000m } order =>
        $"VIP order above 1000: {order.Total}",
    Order { Segments: ["api", .., "orders"] } => "List pattern matched API orders route",
    var value => $"Fallback with var pattern: {value}"
};

Console.WriteLine(description);

public sealed record Customer(bool IsVip);
public sealed record Order(Customer Customer, decimal Total, string[] Segments);
```

## Common Follow-up Questions
- What is the difference between a type pattern and using `as` followed by a null check?
- When should you prefer a switch expression over `if`/`else` pattern checks?
- How do property, positional, and list patterns differ conceptually?
- What are `var` and discard patterns used for?
- How do `and`, `or`, and `not` interact in more complex patterns?

## Common Mistakes / Pitfalls
- Treating pattern matching as only a type-checking feature and missing property or list patterns.
- Forgetting operator precedence when combining `not`, `and`, and `or`.
- Writing patterns in the wrong order so an earlier broad arm makes a later arm unreachable.
- Using positional patterns when member names would be clearer and less brittle.
- Ignoring null handling even though patterns can express `null` and `not null` cleanly.

## References
- [Pattern matching overview](https://learn.microsoft.com/dotnet/csharp/fundamentals/functional/pattern-matching)
- [Patterns - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/patterns)
- [The `switch` expression - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/switch-expression)
- [See: switch-expressions.md](./switch-expressions.md)
- [See: property-and-positional-patterns.md](./property-and-positional-patterns.md)
- [See: list-patterns.md](./list-patterns.md)
