# Extension Methods

**Category:** OOP & Design / Functional Patterns
**Difficulty:** 🟢 Junior
**Tags:** `extension-methods`, `LINQ`, `OCP`, `C#`

## Question
> How do extension methods work in C#, and when are they a good way to extend behavior without modifying a type?

## Short Answer
An extension method is a static method that the compiler lets you call with instance-method syntax by marking the first parameter with `this`. They are useful when you want to add convenience behavior to a type you cannot or should not modify, which is why LINQ uses them heavily on `IEnumerable<T>`. They support the Open/Closed Principle well, but they are still just static methods, so they cannot access private state and can create confusion when overused.

## Detailed Explanation
### How extension methods work under the hood
An extension method lives in a **static class** and is itself **static**. Its first parameter is prefixed with `this`, for example `this string value`. The compiler rewrites a call like `name.ToSlug()` into a static method call like `StringExtensions.ToSlug(name)`.

So extension methods are mostly syntax sugar. They do not actually modify the original type, and they do not participate in runtime polymorphism the way virtual instance methods do.

| Aspect | Instance method | Extension method |
| --- | --- | --- |
| Where defined | Inside the type | In a separate static class |
| Access to private members | Yes | No |
| Dispatch | Normal instance dispatch | Compile-time method resolution |
| Good for | Core behavior of the type | Add-on behavior or helpers |

### Why they are useful for OCP
The Open/Closed Principle says code should be open for extension but closed for modification. Extension methods are a lightweight way to extend a type when:
- the type is in the BCL or a third-party library,
- changing the original class is not possible,
- or the extra behavior is optional and domain-specific.

For example, you would not modify `string` to add `ToSlug()`, and you would not change `IEnumerable<T>` to add every project-specific helper. An extension method lets you add that behavior in your own assembly.

### LINQ as the canonical extension-method pattern
LINQ is the best-known example. Methods like `Where`, `Select`, and `OrderBy` are extension methods over `IEnumerable<T>` and `IQueryable<T>`. That design makes queries readable and chainable without changing collection classes themselves.

This is an elegant design pattern in C#: attach composable behavior to abstractions. Instead of inheritance or giant utility classes, you get fluent APIs.

> Warning: extension methods can look like native members in IntelliSense, so teams sometimes overuse them and hide important logic in unexpected namespaces.

### Key limitations and trade-offs
Because extension methods are static methods, they cannot access private fields or override existing behavior. If an instance method and an extension method have the same signature, the real instance method wins. That is good for safety, but it can also surprise people when an extension “is not being called.”

Visibility is another issue. Extension methods only appear when the namespace is imported. Two different namespaces can expose similarly named extensions, which can create ambiguity or accidental overload selection.

Extension methods are best for:
- convenience helpers,
- fluent APIs,
- cross-cutting utility behavior on abstractions,
- and domain-specific query composition.

They are a poor choice when the method really belongs to the type’s core invariants, when it needs internal state, or when discoverability becomes a problem.

### Interview-ready answer
A strong answer is: extension methods are compile-time sugar over static methods. They are great for adding fluent, reusable behavior to types you cannot change, especially abstractions like `IEnumerable<T>`, but they should not be used to fake real object-oriented behavior.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

namespace OopAndDesign.FunctionalPatterns;

public static class Program
{
    public static void Main()
    {
        string title = "  Extension Methods in C#  ";
        Console.WriteLine(title.ToSlug());

        IEnumerable<int> numbers = [1, 2, 3, 4, 5, 6];

        // LINQ itself is built on extension methods over IEnumerable<T>.
        int evenSum = numbers.Where(n => n % 2 == 0).Sum();
        Console.WriteLine($"Even sum: {evenSum}");
    }
}

public static class StringExtensions
{
    public static string ToSlug(this string value)
    {
        string trimmed = value.Trim().ToLowerInvariant();
        return trimmed.Replace(" ", "-");
    }
}
```

## Common Follow-up Questions
- Why must extension methods be declared in a static class?
- What happens if both an instance method and an extension method match the call?
- Why does LINQ expose methods as extensions instead of instance methods on collections?
- Can extension methods access private or protected members of the extended type?
- When would a normal service or helper class be better than an extension method?

## Common Mistakes / Pitfalls
- Treating extension methods like true object-oriented polymorphism.
- Putting business-critical behavior into obscure extension namespaces, which hurts discoverability.
- Creating ambiguous overloads across multiple imported namespaces.
- Using extension methods to bypass proper abstractions or dependency injection.
- Forgetting that extension methods cannot maintain per-instance state.

## References
- [Extension members - C#](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/extension-methods)
- [How to: Extend LINQ](https://learn.microsoft.com/en-us/dotnet/csharp/linq/how-to-extend-linq)
- [Enumerable Class](https://learn.microsoft.com/en-us/dotnet/api/system.linq.enumerable)
- [Open/Closed Principle](https://martinfowler.com/bliki/OpenClosedPrinciple.html)
