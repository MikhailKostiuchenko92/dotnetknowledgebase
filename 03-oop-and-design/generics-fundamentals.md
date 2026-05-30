# Generics Fundamentals in C#

**Category:** OOP & Design / Generics & Type-Level Patterns
**Difficulty:** 🟢 Junior
**Tags:** `generics`, `type-parameters`, `reification`, `CLR`

## Question
> What are generics in C#, how does type inference work, and what does it mean that .NET generics are reified instead of erased?

## Short Answer
Generics let you write type-safe code once and reuse it for many types without casting or duplicating logic. In C#, the compiler can often infer the generic type argument from the method call, so you can write `Max(3, 5)` instead of `Max<int>(3, 5)`. .NET generics are reified, which means the runtime still knows the actual generic type arguments, unlike Java-style erasure.

## Detailed Explanation
### What generics solve
Generics are a language and CLR feature for parameterizing types and methods with type parameters such as `T`, `TKey`, or `TValue`. Instead of writing one stack for `int`, another for `string`, and another for `Customer`, you write `Stack<T>` once and let the compiler enforce that only the correct type goes in and comes out. That gives you reuse, compile-time safety, and cleaner APIs.

Before generics, developers often used `object` plus casting. That works, but it loses type safety and can introduce runtime failures. With generics, `List<int>` guarantees that every element is an `int`, so you avoid repeated casts and many invalid-cast bugs.

| Concept | Example | Why it matters |
|---|---|---|
| Generic type parameter | `List<T>` | Reuses one definition for many types |
| Generic method | `T Max<T>(T a, T b)` | Reuses behavior without tying it to one class |
| Type inference | `Max(1, 2)` | Makes generic APIs easier to call |
| Reification | `typeof(List<int>)` | Runtime still knows `int` is the type argument |

### How type inference and open vs. closed types work
Type inference usually applies to generic methods, not generic classes. In `Swap(ref left, ref right)`, the compiler looks at the argument types and infers `T`. If the compiler cannot infer a valid type, you must specify it explicitly.

It is also important to separate open and closed generic types. An open generic type still has an unassigned type parameter, such as `typeof(List<>)` or `Dictionary<TKey, TValue>`. A closed generic type has concrete type arguments, such as `List<string>` or `Dictionary<int, string>`. You cannot create an instance of an open generic type, but DI containers and reflection APIs often use open generic type definitions to register services or inspect metadata.

### What reification means in .NET
In .NET, generics are reified, meaning type arguments exist at runtime. The CLR and metadata system preserve the closed type, so `List<int>` and `List<string>` are different runtime types with inspectable generic arguments. Reflection can ask a type whether it is generic, whether it is an open generic definition, and what its type arguments are.

> Warning: Reification does **not** mean every closed generic gets a completely separate implementation in the same way. The CLR can share generated code for many reference-type instantiations, while value types often need specialized code because their memory layout differs.

That behavior is a big reason generics in .NET are more powerful than simple compile-time rewriting. Libraries such as serializers, DI containers, ORMs, and mappers can inspect and compose closed generic types at runtime.

### Why it matters, trade-offs, and when not to overuse generics
Generics improve correctness, readability, and performance. They remove many casts, reduce boxing for value types, and let framework authors build flexible abstractions like `IEnumerable<T>`, `Task<T>`, and `IOptions<T>`.

The trade-off is complexity. A well-designed generic API feels natural, but an over-generic API can become hard to read, hard to infer, and hard to debug. If a type parameter does not express a real variation point, it may be better to use a concrete type or a simpler interface.

Use generics when the algorithm is truly type-independent and the type parameter communicates intent. Avoid them when they only add ceremony, when the API becomes cryptic, or when callers constantly need explicit type arguments because inference cannot help.

## Code Example
```csharp
using System;
using System.Collections.Generic;

namespace InterviewExamples;

internal sealed class Box<T>(T value)
{
    public T Value { get; } = value;
}

internal static class Helpers
{
    public static T PickFirst<T>(T left, T right) => left; // T is inferred from arguments.
}

internal static class Program
{
    private static void Main()
    {
        var numberBox = new Box<int>(42);
        var textBox = new Box<string>("hello");

        var chosenNumber = Helpers.PickFirst(10, 20); // Compiler infers T as int.
        var chosenText = Helpers.PickFirst("a", "b"); // Compiler infers T as string.

        var openType = typeof(Dictionary<,>); // Open generic type definition.
        var closedType = typeof(Dictionary<string, int>); // Closed generic type.

        Console.WriteLine($"{numberBox.Value}, {textBox.Value}");
        Console.WriteLine($"Chosen: {chosenNumber}, {chosenText}");
        Console.WriteLine($"Open generic? {openType.IsGenericTypeDefinition}");
        Console.WriteLine($"Closed type args: {string.Join(", ", Array.ConvertAll(closedType.GetGenericArguments(), t => t.Name))}");
    }
}
```

## Common Follow-up Questions
- Why can .NET inspect generic type arguments at runtime while Java often cannot?
- What is the difference between a generic class and a generic method?
- When does the compiler fail to infer a generic type argument?
- How do value types and reference types differ in generic code generation?
- What is the difference between covariance, contravariance, and invariance?

## Common Mistakes / Pitfalls
- Assuming type inference works for generic classes the same way it works for generic methods.
- Thinking `typeof(List<>)` and `typeof(List<int>)` are both instantiable types.
- Believing reification means every generic instantiation always gets unique machine code.
- Replacing simple interfaces with overly abstract generic APIs that are harder to understand.

## References
- [Generic types and methods - C# | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/generics)
- [Generic Type Parameters - C# | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/generics/generic-type-parameters)
- [Generics in the runtime - C# | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/generics/generics-in-the-run-time)
- [Generics in .NET - .NET | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/generics/)
