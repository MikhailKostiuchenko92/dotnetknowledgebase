# Pattern Matching in OOP

**Category:** OOP & Design / Functional Patterns
**Difficulty:** 🟡 Middle
**Tags:** `pattern-matching`, `switch-expression`, `C#8`, `C#12`, `visitor`

## Question
> How does modern C# pattern matching work, and when can it replace classic object-oriented techniques like long `if` chains or even the Visitor pattern?

## Short Answer
Modern C# pattern matching lets you branch on runtime type, value ranges, object shape, and collection shape using `switch` expressions and patterns such as type, relational, property, and list patterns. It often removes casting boilerplate and makes classification logic much clearer. It can replace some Visitor-style scenarios when the set of cases is relatively closed, but it does not replace polymorphism when behavior naturally belongs inside each type.

## Detailed Explanation
### What pattern matching adds to object-oriented C#
Pattern matching started as a small convenience in C# 7 and became a serious design tool in C# 8–12. Instead of writing nested `if`/`else` blocks, explicit casts, and null checks, you can express the shape of the data you expect and let the compiler help with the branching. In practical terms, you can match by runtime type, compare numeric ranges, inspect named properties, and even match list prefixes.

| Pattern kind | Example | Best use |
| --- | --- | --- |
| Type pattern | `shape is Circle c` | Branch by subtype |
| Relational pattern | `score is >= 90` | Range-based rules |
| Property pattern | `order is { IsPaid: true }` | Match object state |
| List pattern | `args is ["run", ..]` | Parse tokens or commands |

This matters in OOP because many real systems need classification logic at boundaries: mapping API requests, interpreting messages, handling domain events, or translating DTOs into richer types. Pattern matching makes those entry points shorter and safer.

### How it works internally and why it reads better
A `switch` expression compiles to decision logic, not reflection magic. The compiler analyzes the order and reachability of arms, inserts tests such as type checks or member reads, and warns about some unreachable cases. Property and list patterns are especially useful because they let you express intent directly instead of forcing the reader to mentally reconstruct a chain of conditions.

For example, compare `if (shape is Circle c && c.Radius > 0)` with a switch arm like `Circle { Radius: > 0 } c => ...`. The second version communicates both the subtype and the validity rule in one place. That tends to reduce mistakes caused by partially duplicated condition logic.

> Warning: pattern matching is strongest when the set of cases is fairly stable. If new variants are added frequently, duplicated switches across the codebase can drift out of sync.

### Pattern matching vs polymorphism vs Visitor
Pattern matching overlaps with classic OOP mechanisms, but the trade-offs are different.

| Approach | Strong when | Weak when |
| --- | --- | --- |
| Virtual members | Behavior belongs to the object | You need many external operations |
| Visitor | Closed hierarchy, many operations, strong compile-time structure | Boilerplate is heavy |
| Pattern matching | External operations over a small or closed set of cases | New subtypes require updating many matches |

Pattern matching can replace Visitor when double dispatch feels too ceremonial for the size of the problem. For example, if you have a handful of AST nodes or message types and you want a few external operations, a `switch` expression is often more readable than interfaces plus `Accept` methods plus visitor classes. But if behavior truly belongs to each object, or you need extensibility through subtype addition, polymorphism may remain the better fit.

### When not to use it
Do not use pattern matching just because it is newer syntax. If a method belongs to the object conceptually, putting the behavior into a central switch can reduce cohesion. Also avoid deeply nested patterns that become clever puzzles. Interviewers usually like the balanced answer: pattern matching is a powerful complement to OOP, especially for boundary logic and closed hierarchies, but it should not become an excuse to pull every behavior out of the model.

## Code Example
```csharp
using System;

namespace InterviewKnowledgeBase.OopAndDesign;

internal static class Program
{
    private static void Main()
    {
        Shape[] shapes =
        [
            new Circle(2),
            new Rectangle(3, 4),
            new Triangle(5, 2)
        ];

        foreach (Shape shape in shapes)
        {
            Console.WriteLine(ShapePrinter.Describe(shape));
        }

        string[] args = ["run", "--verbose"];
        Console.WriteLine(CommandRouter.Route(args));
    }
}

internal abstract record Shape;
internal sealed record Circle(double Radius) : Shape;
internal sealed record Rectangle(double Width, double Height) : Shape;
internal sealed record Triangle(double Base, double Height) : Shape;

internal static class ShapePrinter
{
    public static string Describe(Shape shape) => shape switch
    {
        Circle { Radius: > 0 } c => $"Circle area = {Math.PI * c.Radius * c.Radius:0.00}",
        Rectangle { Width: > 0, Height: > 0 } r => $"Rectangle area = {r.Width * r.Height:0.00}",
        Triangle { Base: > 0, Height: > 0 } t => $"Triangle area = {t.Base * t.Height / 2:0.00}",
        _ => throw new ArgumentOutOfRangeException(nameof(shape), "Unsupported or invalid shape.")
    };
}

internal static class CommandRouter
{
    public static string Route(string[] args) => args switch
    {
        ["run", ..] => "Running application",   // List pattern
        ["build", ..] => "Building project",
        _ => "Unknown command"
    };
}
```

## Common Follow-up Questions
- What is the difference between a type pattern and a property pattern?
- When is polymorphism cleaner than pattern matching?
- Why can pattern matching sometimes replace the Visitor pattern?
- What are list patterns useful for in production code?
- Does C# guarantee exhaustiveness for every hierarchy?

## Common Mistakes / Pitfalls
- Moving behavior into giant `switch` expressions even when the behavior belongs inside the type.
- Duplicating the same match logic in multiple places, which recreates a Visitor problem in a weaker form.
- Assuming all hierarchies are exhaustively checked like in F# or Rust.
- Writing deeply nested property patterns that hurt readability more than they help.
- Forgetting a fallback arm and getting runtime exceptions after adding a new subtype.

## References
- [Pattern matching overview](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/functional/pattern-matching)
- [Patterns - C# reference](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns)
- [switch expression - C# reference](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/switch-expression)
