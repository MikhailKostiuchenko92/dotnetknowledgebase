# Visitor Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🔴 Senior
**Tags:** `visitor`, `behavioral`, `double-dispatch`, `expression-trees`, `pattern-matching`

## Question
> What is the Visitor pattern, how does double dispatch work, and when would you choose it over modern C# pattern matching?

## Short Answer
Visitor lets you add new operations to an object hierarchy without modifying the element classes every time. It works through double dispatch: first the runtime picks the element’s `Accept` override, then that method calls the correctly overloaded `Visit` method on the visitor. It is powerful for stable hierarchies with many operations, but for small or frequently changing hierarchies, modern C# pattern matching is often simpler and easier to read.

## Detailed Explanation
### What problem Visitor solves
Suppose you have a fixed hierarchy such as expression nodes, shapes, or document elements. If new operations keep appearing—rendering, validation, pricing, serialization, diagnostics—putting every operation directly on each node can make the model bloated. Visitor moves operations out into separate visitor types.

This shifts the design trade-off:

| Change you make often | Better fit |
| --- | --- |
| Add new operations | Visitor |
| Add new element types | Pattern matching / direct methods |

Visitor is strongest when the hierarchy is relatively stable but the operations are numerous and evolving.

### How double dispatch works
C# method overloading is normally resolved from compile-time types. Visitor adds a second step so the operation can depend on the runtime type of the visited element.

1. You call `node.Accept(visitor)`.
2. Because `Accept` is virtual/overridden, the runtime picks the correct element implementation.
3. Inside that override, the element calls `visitor.Visit(this)`.
4. Now the correct overloaded `Visit` method is selected for the concrete element type.

That two-step process is why interviewers call it **double dispatch**.

### Why expression trees are a useful analogy
`System.Linq.Expressions` is not a textbook GoF visitor implementation everywhere, but it is a great analogy. An expression tree is a closed node hierarchy, and visitors such as `ExpressionVisitor` let you traverse and transform nodes without stuffing every algorithm into each node class.

That is the core value of Visitor in real .NET code: traversal plus operation extensibility across a known set of node shapes.

> Visitor improves openness for **new operations**, but it makes **new element types** expensive because every visitor interface and implementation may need updates.

### Visitor vs pattern matching
Modern C# pattern matching competes with Visitor for many use cases. A `switch` expression over a sealed hierarchy can be very readable. For small hierarchies, that is often the better choice.

| Concern | Visitor | Pattern matching |
| --- | --- | --- |
| Many operations over stable hierarchy | Strong | Can become repetitive |
| Frequent new node types | Weak | Usually simpler |
| Extensibility via plugins/classes | Strong | Limited |
| Boilerplate | Higher | Lower |

Pattern matching keeps control flow local and direct. Visitor centralizes an operation in one type and can support reusable traversal behavior. Choose based on which axis changes more.

### When not to use it
Do not use Visitor just because it is a classic pattern. If the hierarchy is tiny, or if you are adding node types regularly, the boilerplate may outweigh the benefit. Likewise, if each element naturally owns the behavior, placing logic directly on the type can be clearer.

## Code Example
```csharp
using System;

namespace OopAndDesign.VisitorPattern;

public interface IShapeVisitor<out TResult>
{
    TResult VisitCircle(Circle circle);
    TResult VisitRectangle(Rectangle rectangle);
}

public abstract record Shape
{
    public abstract T Accept<T>(IShapeVisitor<T> visitor);
}

public sealed record Circle(double Radius) : Shape
{
    public override T Accept<T>(IShapeVisitor<T> visitor) => visitor.VisitCircle(this); // First dispatch chooses Circle.
}

public sealed record Rectangle(double Width, double Height) : Shape
{
    public override T Accept<T>(IShapeVisitor<T> visitor) => visitor.VisitRectangle(this); // Then overload picks VisitRectangle.
}

public sealed class AreaVisitor : IShapeVisitor<double>
{
    public double VisitCircle(Circle circle) => Math.PI * circle.Radius * circle.Radius;
    public double VisitRectangle(Rectangle rectangle) => rectangle.Width * rectangle.Height;
}

public static class Program
{
    public static void Main()
    {
        Shape[] shapes = [new Circle(2), new Rectangle(3, 4)];
        var visitor = new AreaVisitor();

        foreach (var shape in shapes)
        {
            Console.WriteLine(shape.Accept(visitor));
        }
    }
}
```

## Common Follow-up Questions
- Why is Visitor considered good for adding operations but bad for adding new element types?
- What exactly are the two dispatch steps in double dispatch?
- How does Visitor compare with a `switch` expression over a sealed hierarchy?
- Why are expression trees often used as a Visitor example in .NET?
- When would `ExpressionVisitor`-style traversal be better than putting logic on the nodes?
- How would you handle versioning if the hierarchy must grow later?

## Common Mistakes / Pitfalls
- Using Visitor on a hierarchy that changes element types frequently.
- Confusing method overloading alone with double dispatch.
- Adding a visitor layer when pattern matching would be shorter and clearer.
- Letting the visitor abstraction leak too much domain knowledge into every node.
- Forgetting that every new concrete element can force changes across all visitors.

## References
- [Visitor](https://refactoring.guru/design-patterns/visitor)
- [Expression Trees in C#](https://learn.microsoft.com/dotnet/csharp/advanced-topics/expression-trees/)
- [Pattern matching overview](https://learn.microsoft.com/dotnet/csharp/fundamentals/functional/pattern-matching)
