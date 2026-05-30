# Property and Positional Patterns

**Category:** C# / Pattern Matching
**Difficulty:** Middle
**Tags:** `property-patterns`, `positional-patterns`, `deconstruct`, `records`, `nested-patterns`

## Question
> What are property patterns and positional patterns in C#, and when should you use each one?

Related phrasings:
- "How does `{ Property: pattern }` work, including nested property checks?"
- "What enables positional patterns, and what role does `Deconstruct` play?"
- "When is a property pattern clearer than a positional pattern?"

## Short Answer
Property patterns match named members such as `{ Total: > 100m, Customer: { IsVip: true } }`, while positional patterns match values by deconstruction order such as `(0, 0)` or `(var x, var y)`. In .NET 8/9 with C# 12/13, both are core pattern-matching tools and work especially well inside switch expressions. Property patterns are usually clearer for domain models because names make intent obvious, while positional patterns are concise for tuples, records, and geometric or mathematical shapes.

## Detailed Explanation

### Property Patterns: Matching by Member Name
A property pattern checks one or more accessible members by name:

```csharp
order is { Total: > 100m, Customer: { IsVip: true } }
```

This is readable because the pattern itself documents what matters. It also composes naturally with nested patterns, relational patterns, and list patterns.

Property patterns are often the safer default for business objects because they are resilient to mental mismatch. You can see immediately which property is being checked.

### Positional Patterns: Matching by Deconstruction Order
A positional pattern matches data by position instead of by property name. It works with:

- tuples
- record types with positional shape
- types exposing a suitable `Deconstruct` method

Example:

```csharp
point is (0, 0)
```

The trade-off is that positions are shorter but less self-documenting. You have to know what the first, second, and third values mean.

| Pattern style | Example | Best use |
|---|---|---|
| Property | `{ X: 0, Y: 0 }` | Domain models, readable business rules |
| Positional | `(0, 0)` | Tuples, records, mathematical coordinates |

### Nested Property Patterns
One of the strongest features of property patterns is nesting. Instead of splitting checks across multiple `if` blocks, you can describe the full shape in one place:

```csharp
order is
{
    Customer: { IsVip: true, Country: "UA" },
    ShippingAddress: { City: "Kyiv" },
    Lines: [_, ..]
}
```

This kind of code is common in API validation, routing, and domain classification.

> **Tip:** Nested property patterns are often better than chained null checks because they express both null-safety and shape requirements in one construct.

### What `Deconstruct` Does for Positional Patterns
Positional patterns depend on deconstruction. Records get convenient support automatically through their positional shape, and ordinary types can participate by defining a `Deconstruct` method.

That means you can make your own type pattern-friendly without converting it to a record.

```csharp
public void Deconstruct(out int x, out int y)
```

Once that exists, the type can be matched positionally.

### Choosing Between the Two
In interview answers, the strongest rule of thumb is:

- choose **property patterns** when names matter
- choose **positional patterns** when the order is already obvious and part of the type's meaning

For a `Point`, `(0, 0)` is natural. For an `Order`, `{ Total: > 1000m, Status: "Paid" }` is usually better than positional matching.

### Composing with Other Pattern Types
Property and positional patterns do not live alone. They combine with:

- relational patterns such as `> 100m`
- logical patterns such as `and` or `not`
- list patterns such as `[_, ..]`
- switch expressions from [switch-expressions.md](./switch-expressions.md)

That composability is what makes pattern matching expressive in C# 12/13.

## Code Example
```csharp
using System;

var order = new Order(
    new Customer(true, "UA"),
    new Address("Kyiv", "Khreshchatyk Street"),
    1250m,
    ["book", "keyboard"]);

bool isVipKyivOrder = order is
{
    Customer: { IsVip: true, Country: "UA" },
    ShippingAddress: { City: "Kyiv" },
    Items: [_, ..],
    Total: >= 1000m
};

Console.WriteLine(isVipKyivOrder); // True

var point = new Point(0, 5);
string pointType = point switch
{
    (0, 0) => "origin",
    (0, _) => "on Y axis",
    (_, 0) => "on X axis",
    _ => "somewhere else"
};

Console.WriteLine(pointType);

public sealed record Customer(bool IsVip, string Country);
public sealed record Address(string City, string Street);
public sealed record Order(Customer Customer, Address ShippingAddress, decimal Total, string[] Items);
public sealed class Point(int x, int y)
{
    public int X { get; } = x;
    public int Y { get; } = y;

    public void Deconstruct(out int xValue, out int yValue)
    {
        xValue = X;
        yValue = Y;
    }
}
```

## Common Follow-up Questions
- When should you prefer a property pattern over a positional pattern?
- What must a non-record type provide to support positional patterns?
- How do nested property patterns help with null-safe shape checking?
- Can property and positional patterns be combined with relational or list patterns?
- Why can positional patterns become brittle in business-domain code?

## Common Mistakes / Pitfalls
- Using positional patterns when readers cannot easily remember what each position means.
- Assuming only records support positional patterns; any type with `Deconstruct` can work.
- Forgetting that property patterns depend on accessible members with matching names.
- Writing overly deep nested patterns that hurt readability instead of helping it.
- Missing opportunities to use property patterns instead of multiple null checks and casts.

## References
- [Patterns - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/patterns)
- [Pattern matching overview](https://learn.microsoft.com/dotnet/csharp/fundamentals/functional/pattern-matching)
- [The `switch` expression - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/switch-expression)
- [See: pattern-matching-overview.md](./pattern-matching-overview.md)
- [See: list-patterns.md](./list-patterns.md)
- [See: switch-expressions.md](./switch-expressions.md)
