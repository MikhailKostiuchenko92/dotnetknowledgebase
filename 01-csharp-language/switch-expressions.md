# Switch Expressions

**Category:** C# / Pattern Matching
**Difficulty:** Middle
**Tags:** `switch-expression`, `pattern-matching`, `guards`, `exhaustiveness`, `expressions`

## Question
> What is a switch expression in C#, and how is it different from the traditional `switch` statement?

Related phrasings:
- "When should I use a switch expression instead of a switch statement or `if`/`else` chain?"
- "How do arm ordering, guards, and exhaustiveness work in a switch expression?"
- "What happens if no switch-expression arm matches at runtime?"

## Short Answer
A switch expression returns a value, so it is ideal when you want to map an input to a result in a concise, expression-oriented way. In C# 12/13 on .NET 8/9, switch expressions work with modern pattern matching, support guards, and encourage exhaustive handling of cases. Compared with the old switch statement, they are usually shorter and clearer for classification logic, but they are not meant for large blocks of side-effect-heavy code.

## Detailed Explanation

### What Makes a Switch Expression Different
The classic `switch` statement is statement-based: each case usually performs actions. A switch expression is value-based: every arm produces a result.

That difference matters because it nudges you toward code that is easier to reason about. Instead of mutating a temporary variable across cases, you compute a value directly.

| Feature | `switch` statement | `switch` expression |
|---|---|---|
| Primary purpose | Execute statements | Produce a value |
| Syntax style | Case blocks | Comma-separated arms |
| Fall-through behavior | Restricted, but still statement-oriented | No fall-through |
| Pattern matching support | Yes | Yes, often more natural |
| Best for | Side effects, larger imperative branches | Classification and mapping |

### Basic Syntax
A switch expression looks like this:

```csharp
var result = input switch
{
    pattern1 => expression1,
    pattern2 when condition => expression2,
    _ => fallback
};
```

Each arm is checked in order. The first matching arm wins.

### Exhaustiveness and Fallback Arms
Switch expressions are designed to be as exhaustive as practical. If the compiler can see that some inputs are unhandled, it warns you. At runtime, if no arm matches, a `SwitchExpressionException` is thrown.

That is why a final discard arm `_ => ...` is common, especially for open-ended inputs.

> **Warning:** Do not confuse a compiler warning with safety at runtime. A non-exhaustive switch expression can still compile and then throw if an unexpected value arrives.

For enums, closed hierarchies, and small domains, trying to be exhaustive is a strong interview point.

### Guards with `when`
A guard is an extra boolean condition attached to an arm:

```csharp
score switch
{
    int n when n >= 90 => "A",
    int n when n >= 80 => "B",
    _ => "F"
}
```

The pattern must match first, then the guard is evaluated. Guards let you keep pattern structure clean while still expressing more detailed business logic.

### Arm Ordering Matters
Switch-expression arms are checked top to bottom. Because first match wins, order is semantically important.

For example, this is wrong:

```csharp
value switch
{
    int n => "any int",
    int n when n > 0 => "positive" // unreachable
}
```

The broader arm comes first, so the more specific arm never runs. In practice, put the most specific arms first and the broad fallback arms last.

### When Switch Expressions Shine
Switch expressions are especially good for:

- formatting or mapping one value to another
- translating domain states into API responses
- small routing or classification logic
- combining modern patterns such as property or list patterns

They pair naturally with [pattern-matching-overview.md](./pattern-matching-overview.md), [property-and-positional-patterns.md](./property-and-positional-patterns.md), and [list-patterns.md](./list-patterns.md).

### When a Switch Statement Is Still Better
A traditional switch statement is often clearer when:

- each branch performs multiple side effects
- you need long imperative blocks
- you are not really computing a single result

So the interview answer is not "switch expressions are always better." It is "use expressions for mapping, statements for imperative branching."

## Code Example
```csharp
using System;

var order = new Order("Express", 1200m, true);

string shipping = order switch
{
    { IsPriorityCustomer: true, Total: >= 1000m } => "Free priority shipping",
    { DeliveryType: "Express" } when order.Total >= 100m => "Discounted express shipping",
    { DeliveryType: "Standard" } => "Standard shipping",
    _ => "Manual review"
};

Console.WriteLine(shipping);

var httpStatus = 404;
string message = httpStatus switch
{
    200 => "OK",
    400 => "Bad Request",
    404 => "Not Found",
    >= 500 and < 600 => "Server error",
    _ => throw new ArgumentOutOfRangeException(nameof(httpStatus), httpStatus, "Unexpected status")
};

Console.WriteLine(message);

public sealed record Order(string DeliveryType, decimal Total, bool IsPriorityCustomer);
```

## Common Follow-up Questions
- What happens when no switch-expression arm matches at runtime?
- Why is arm ordering important in switch expressions?
- When should you use a guard versus encoding the condition directly in the pattern?
- How do switch expressions help with exhaustiveness compared with `if`/`else` chains?
- When is a traditional switch statement the better choice?

## Common Mistakes / Pitfalls
- Putting a broad arm before a more specific arm and making the specific one unreachable.
- Omitting a fallback arm for open-ended input domains.
- Using switch expressions for complex side-effect-driven logic where a statement is clearer.
- Forgetting that guards run only after the pattern itself matches.
- Assuming the compiler always guarantees exhaustiveness for every possible runtime scenario.

## References
- [The `switch` expression - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/switch-expression)
- [Patterns - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/patterns)
- [Pattern matching overview](https://learn.microsoft.com/dotnet/csharp/fundamentals/functional/pattern-matching)
- [See: pattern-matching-overview.md](./pattern-matching-overview.md)
- [See: property-and-positional-patterns.md](./property-and-positional-patterns.md)
- [See: list-patterns.md](./list-patterns.md)
