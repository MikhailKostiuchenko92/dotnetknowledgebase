# Types of Polymorphism in C#

**Category:** OOP & Design
**Difficulty:** 🟡 Middle
**Tags:** `polymorphism`, `vtable`, `virtual-dispatch`, `overloading`

## Question
> What types of polymorphism exist in C#, and what is the difference between compile-time and runtime polymorphism?

## Short Answer
In interview terms, C# usually discusses compile-time polymorphism and runtime polymorphism. Compile-time polymorphism is typically method overloading, where the compiler picks the best member based on the static types and arguments. Runtime polymorphism is virtual or interface-based dispatch, where the CLR chooses the implementation based on the actual object type at runtime.

## Detailed Explanation
### Compile-time polymorphism
Compile-time polymorphism is also called static or ad-hoc polymorphism. In C#, the most common example is method overloading. You have several methods with the same name but different parameter signatures, and the compiler resolves the call before the program runs.

This is useful for API convenience. A single concept such as `Render` or `Parse` can accept multiple shapes of input while keeping a clean method name.

The key limitation is that overload resolution is based on what the compiler knows from the variable types at the call site. It does not inspect the runtime type of the object to choose an overload.

### Runtime polymorphism
Runtime polymorphism happens when the program calls a virtual method or an interface member and the CLR decides which implementation to execute based on the actual object instance. This is what most people mean by “polymorphism” in OOP discussions.

Under the hood, the runtime uses metadata and dispatch structures such as method tables to locate the correct implementation. For interface calls, dispatch can be slightly more complex because a type may implement many interfaces.

| Type | Typical feature | Chosen by | Common use |
| --- | --- | --- | --- |
| Compile-time polymorphism | Overloading | Compiler | API ergonomics |
| Runtime polymorphism | `virtual`/`override` | CLR at runtime | Extensible behavior |
| Runtime polymorphism | Interfaces | CLR at runtime | Loose coupling and DI |

### Why the distinction matters
This difference affects design decisions. Overloading makes calling code convenient, but it does not make behavior extensible. Virtual methods and interfaces allow late binding, which is what powers plugin models, framework extension points, dependency injection, and strategy-style design.

It also explains common interview trick questions. If you overload `Render(Shape)` and `Render(Circle)`, then pass a `Circle` stored in a `Shape` variable, the compiler still sees `Shape` when selecting the overload. But if `Shape.Draw()` is virtual, the runtime still dispatches to `Circle.Draw()`.

> Warning: overload resolution is not “smart runtime polymorphism.” It is fixed at compile time unless you are using dynamic features.

### Virtual dispatch tables and interface dispatch
For class-based runtime polymorphism, the runtime can often use a method table entry associated with the actual object type. For interfaces, the runtime needs to map the interface contract to the implementing method on the concrete type. That is why interface dispatch can be a little harder for the JIT to optimize, although modern .NET does a good job here.

### Trade-offs
Compile-time polymorphism is simple and fast, but it is less flexible. Runtime polymorphism is more extensible, but it adds indirection and requires carefully designed contracts. In real systems, both are useful: overloading for clean APIs, overriding and interfaces for behavior variation.

## Code Example
```csharp
namespace OopAndDesignExamples;

public sealed class Renderer
{
    public void Show(object value) => Console.WriteLine($"Object overload: {value}");

    public void Show(string value) => Console.WriteLine($"String overload: {value}");
}

public interface IShape
{
    void Draw();
}

public abstract class Shape : IShape
{
    public abstract void Draw();
}

public sealed class Circle : Shape
{
    public override void Draw() => Console.WriteLine("Drawing a circle.");
}

public static class Program
{
    public static void Main()
    {
        var renderer = new Renderer();

        string text = "hello";
        object boxedText = text;

        renderer.Show(text);      // Compile-time picks Show(string).
        renderer.Show(boxedText); // Compile-time picks Show(object).

        Shape shape = new Circle();
        shape.Draw(); // Runtime picks Circle.Draw via virtual dispatch.

        IShape contract = shape;
        contract.Draw(); // Runtime picks Circle.Draw via interface dispatch.
    }
}
```

## Common Follow-up Questions
- Is method overloading really polymorphism, or just a language convenience?
- How does interface dispatch differ from virtual dispatch internally?
- Why can overload resolution produce unexpected results with base-typed variables?
- What role does `virtual` play in runtime polymorphism?
- How does the JIT optimize polymorphic calls in modern .NET?

## Common Mistakes / Pitfalls
- Assuming overloads are chosen using the object's runtime type.
- Treating `new` method hiding as the same thing as runtime polymorphism.
- Overusing virtual methods where a simple strategy interface would be clearer.
- Forgetting that interface calls may behave polymorphically even without class inheritance.
- Designing overloads that become ambiguous because of optional parameters or implicit conversions.

## References
- [Polymorphism (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/polymorphism)
- [The `virtual` keyword (C# Reference)](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/virtual)
- [The `override` keyword (C# Reference)](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/override)
- [Interfaces (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/interfaces)
