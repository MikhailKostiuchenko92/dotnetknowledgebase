# Covariance and Contravariance

**Category:** OOP & Design / OOP Fundamentals
**Difficulty:** 🔴 Senior
**Tags:** `generics`, `covariance`, `contravariance`, `variance`

## Question
> Can you explain covariance and contravariance in C#, including why `IEnumerable<T>` is covariant, `Action<T>` is contravariant, and why array covariance is considered a gotcha?

## Short Answer
Variance describes whether a generic type can be substituted with a more derived or less derived type argument. Covariance (`out`) works for producers, so `IEnumerable<string>` can be used where `IEnumerable<object>` is expected; contravariance (`in`) works for consumers, so an `Action<object>` can be used where `Action<string>` is expected. The important catch is that variance in generics is type-safe and restricted, while array covariance is a legacy runtime feature that can compile and then fail with `ArrayTypeMismatchException`.

## Detailed Explanation
### What variance means
Variance answers a substitution question: if `Dog : Animal`, can a generic type involving `Dog` stand in for one involving `Animal`? In C#, the answer depends on **how the type parameter is used**.

- **Covariance** means “more specific is acceptable.”
- **Contravariance** means “less specific is acceptable.”
- **Invariance** means no substitution is allowed.

The classic rule is simple: if a type parameter is only **produced**, it can often be covariant; if it is only **consumed**, it can often be contravariant.

| Variance | Keyword | Mental model | Example |
| --- | --- | --- | --- |
| Covariance | `out` | “I only return `T`.” | `IEnumerable<out T>` |
| Contravariance | `in` | “I only accept `T`.” | `Action<in T>` |
| Invariance | none | “I both read and write `T`.” | `List<T>` |

### How the CLR and C# keep it type-safe
Variance in .NET is supported for **interfaces and delegates**, not arbitrary generic classes, and only for **reference-type substitutions**. The compiler and CLR enforce rules around the generic parameter.

`IEnumerable<out T>` is covariant because it only exposes `T` as output. Reading a `string` sequence through an `IEnumerable<object>` view is safe because every string is also an object.

`Action<in T>` is contravariant because it consumes `T`. If a method can handle any `object`, then it can definitely handle a `string`, so an `Action<object>` can be assigned to an `Action<string>` variable.

`List<T>` is invariant because it both produces and consumes `T`. If `List<string>` were assignable to `List<object>`, someone could add an `int`, corrupting the list.

> Variance is not “generic inheritance.” It is a carefully restricted substitution rule based on read-only vs write-only usage of the type parameter.

### Why arrays are the famous gotcha
Arrays are covariant in .NET for historical compatibility. That means `string[]` can be treated as `object[]`. Unlike generic variance, this is **not fully compile-time safe**. The runtime has to insert checks on writes.

That is why this compiles:

- `object[] values = new string[1];`

But this fails at runtime:

- `values[0] = 42;`

The CLR sees that the actual array stores `string`, not arbitrary `object`, and throws `ArrayTypeMismatchException`.

This is the key interview contrast:

| Feature | Allowed? | Safety model |
| --- | --- | --- |
| Generic covariance/contravariance | Yes, with `out` / `in` | Compile-time rules + CLR support |
| Array covariance | Yes | Runtime write checks |

### Why it matters in real design
Variance makes APIs more flexible without giving up type safety. Returning `IEnumerable<T>` instead of `List<T>` gives callers a more reusable contract. Accepting delegates like `Action<T>` or `IComparer<T>` also benefits from contravariant behavior.

However, you should not force variance everywhere. If a type both consumes and produces `T`, keep it invariant. Over-designing around variance can make APIs harder to read.

Use variance when you want **substitutability on abstractions**. Avoid relying on array covariance in new designs; generic collections are clearer and safer.

## Code Example
```csharp
using System;
using System.Collections.Generic;

namespace OopAndDesign.CovarianceAndContravariance;

public static class Program
{
    public static void Main()
    {
        IEnumerable<string> names = new List<string> { "Mikhail", "Ada" };
        IEnumerable<object> objects = names; // Covariance: IEnumerable<out T>

        foreach (var item in objects)
        {
            Console.WriteLine($"Covariant read: {item}");
        }

        Action<object> printAny = value => Console.WriteLine($"Contravariant write: {value}");
        Action<string> printText = printAny; // Contravariance: Action<in T>
        printText("Hello from Action<string>");

        try
        {
            object[] boxed = new string[1]; // Array covariance.
            boxed[0] = 42; // Runtime check throws.
        }
        catch (ArrayTypeMismatchException ex)
        {
            Console.WriteLine($"Array covariance gotcha: {ex.GetType().Name}");
        }
    }
}
```

## Common Follow-up Questions
- Why is `List<T>` invariant even though `IEnumerable<T>` is covariant?
- Why does variance apply only to reference types in .NET?
- Which built-in delegates besides `Action<T>` are variant?
- How would you design your own covariant or contravariant interface?
- Why does array covariance exist at all if it is unsafe?
- How does variance affect API design for repositories or collections?

## Common Mistakes / Pitfalls
- Assuming `List<Dog>` can be assigned to `List<Animal>` because `Dog : Animal`.
- Forgetting that variance works only on interfaces and delegates marked with `in` or `out`.
- Mixing input and output positions on a variant type parameter and expecting the compiler to allow it.
- Using arrays where generic collections would avoid runtime type-check failures.
- Believing covariance creates a copy; it only changes the view of the same object.

## References
- [Covariance and contravariance in generics](https://learn.microsoft.com/dotnet/standard/generics/covariance-and-contravariance)
- [Variance in generic interfaces (C#)](https://learn.microsoft.com/dotnet/csharp/programming-guide/concepts/covariance-contravariance/variance-in-generic-interfaces)
- [Variance in delegates (C#)](https://learn.microsoft.com/dotnet/csharp/programming-guide/concepts/covariance-contravariance/variance-in-delegates)
