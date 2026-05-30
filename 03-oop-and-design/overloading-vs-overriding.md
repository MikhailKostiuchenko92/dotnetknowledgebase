# Method Overloading vs Overriding

**Category:** OOP & Design
**Difficulty:** 🟢 Junior
**Tags:** `overloading`, `overriding`, `virtual`, `polymorphism`

## Question
> What is the difference between method overloading and method overriding in C#, and how do `new` and `override` differ?

## Short Answer
Overloading means multiple methods share the same name but have different parameter lists, and the compiler chooses the best match at compile time. Overriding means a derived class replaces a `virtual` or `abstract` base implementation, and the runtime chooses the method based on the actual object type. The `new` keyword does not override; it hides a base member and uses the reference's compile-time type instead of true polymorphism.

## Detailed Explanation
### Overloading: compile-time selection
Method overloading happens inside the same type hierarchy when methods have the same name but different signatures. The signature includes the parameter types and order, not the return type. The compiler picks the best overload based on the arguments it sees at compile time.

That makes overloading useful when the operation is conceptually the same but the inputs differ, such as `Print(string)` and `Print(int)`, or several constructors that initialize an object in different ways.

### Overriding: runtime polymorphism
Overriding is different. A base class marks a member as `virtual` or `abstract`, and a derived class uses `override` to provide a more specific implementation. When code calls that member through a base reference, the CLR dispatches to the override belonging to the actual runtime type.

This is classic runtime polymorphism. It lets calling code depend on a base contract while concrete types customize behavior.

| Topic | Overloading | Overriding |
| --- | --- | --- |
| Decided by | Compiler | Runtime |
| Requires inheritance | No | Yes |
| Signature changes | Yes | No, must match base member |
| Main purpose | Convenience and API design | Polymorphic behavior |
| Keywords involved | None required | `virtual`, `abstract`, `override` |

### `new` hides, `override` replaces
The `new` modifier is often confused with overriding. It tells the compiler that a derived member intentionally hides a base member with the same name. This suppresses the warning, but the behavior is still based on the reference's compile-time type.

With `override`, a base reference calling the method reaches the derived implementation. With `new`, a base reference still calls the base version. That is why `new` is member hiding, not polymorphism.

> Warning: if an interviewer asks about `new` vs `override`, the key phrase is “`new` hides; `override` participates in virtual dispatch.”

### Why the distinction matters
This difference affects correctness, not just syntax. If you expect a hidden method to be called polymorphically, you can get surprising behavior in production. This is especially common when a variable is typed as the base class or an interface.

Overloading also has its own traps. Implicit conversions, `null`, optional parameters, and generics can make overload resolution less obvious than it first looks. Good overload sets feel natural to the caller; bad overload sets create ambiguity.

### When to use each
Use overloading when you want a single conceptual operation to support multiple input shapes. Use overriding when you want derived types to customize behavior behind a stable base contract. Use `new` rarely, typically when adapting legacy APIs or intentionally hiding an unsuitable base member.

In practice, `override` is about substitutability, while overloading is about API ergonomics. They solve different problems even though both involve methods with the same name.

## Code Example
```csharp
namespace OopAndDesignExamples;

public class Printer
{
    public void Print(string text) => Console.WriteLine($"Text: {text}"); // Overload 1.

    public void Print(int number) => Console.WriteLine($"Number: {number}"); // Overload 2.
}

public class Animal
{
    public virtual void Speak() => Console.WriteLine("Animal sound");
}

public class Dog : Animal
{
    public override void Speak() => Console.WriteLine("Woof"); // Runtime polymorphism.
}

public class LoudDog : Dog
{
    public new void Speak() => Console.WriteLine("WOOF!"); // Hides Dog.Speak, does not override it.
}

public static class Program
{
    public static void Main()
    {
        var printer = new Printer();
        printer.Print("hello");
        printer.Print(42);

        Animal animal = new Dog();
        animal.Speak(); // Calls Dog.Speak because of override.

        Dog dogReference = new LoudDog();
        dogReference.Speak(); // Calls Dog.Speak because LoudDog used new, not override.

        LoudDog loudDog = new();
        loudDog.Speak(); // Calls LoudDog.Speak because the variable type is LoudDog.
    }
}
```

## Common Follow-up Questions
- Can you overload methods only by changing the return type?
- What happens if a base method is not marked `virtual`?
- Why might `new` cause surprising behavior with base references?
- How does overload resolution work with optional parameters or `null`?
- Can constructors be overloaded and overridden?

## Common Mistakes / Pitfalls
- Thinking overloads are chosen at runtime based on the object's actual type.
- Forgetting that overriding requires the exact same signature as the base member.
- Using `new` when the intent was true polymorphism.
- Designing overload sets that become ambiguous because of implicit conversions.
- Assuming a hidden member will be called through a base reference.

## References
- [Polymorphism (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/object-oriented/polymorphism)
- [The `override` keyword (C# Reference)](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/override)
- [The `new` modifier (C# Reference)](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/new-modifier)
- [Methods (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/methods)
