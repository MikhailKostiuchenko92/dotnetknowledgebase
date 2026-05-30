# Generic Constraints in C#

**Category:** OOP & Design / Generics & Type-Level Patterns
**Difficulty:** 🟡 Middle
**Tags:** `generics`, `constraints`, `where`, `type-safety`

## Question
> When would you use generic constraints like `where T : new()`, `struct`, `class`, `unmanaged`, an interface, or a base class in C#?

## Short Answer
Generic constraints tell the compiler what a type argument must be able to do, so your generic code can safely construct, compare, or call members on `T`. They move failures from runtime to compile time and make the API contract explicit. The key is to use the narrowest constraint that enables the behavior you actually need.

## Detailed Explanation
### What constraints are for
A generic type parameter is intentionally vague until you add constraints. Without constraints, the compiler cannot assume that `T` has a parameterless constructor, implements an interface, or is even a reference type. The `where` clause gives the compiler those guarantees.

That matters because generic code often needs capabilities, not just types. For example, if your method must call `SaveChanges()`, the type parameter should be constrained to an interface or base class that exposes that method. If the code needs to allocate `T`, it needs `new()`.

| Constraint | Guarantee | Typical use |
|---|---|---|
| `where T : class` | `T` is a reference type | Null semantics, caching reference objects |
| `where T : struct` | `T` is a non-nullable value type | Numeric/value wrappers, avoiding null |
| `where T : unmanaged` | `T` is a value type with no managed references | Interop, buffers, hashing raw bytes |
| `where T : new()` | `T` has a public parameterless constructor | Factories, activators, test data builders |
| `where T : IFoo` | `T` implements an interface | Capability-based design |
| `where T : BaseType` | `T` inherits from a base class | Shared base behavior/state |

### How each common constraint works
`class` says the type argument must be a reference type. That is useful when identity and nullable-reference semantics matter, but it does **not** mean you can instantiate `T` or call arbitrary members on it.

`struct` means a non-nullable value type. It implicitly includes an accessible parameterless constructor, but its real value is that it excludes reference types and nullable value types like `int?`.

`unmanaged` is stricter than `struct`. It means the value type contains no managed references anywhere in its fields. That is important for low-level memory operations, `sizeof(T)`, and interop scenarios.

`new()` means `T` has a public parameterless constructor and is not abstract. It is often used in generic factories, but it can be a smell if object creation should really be delegated to DI or a specialized factory.

Interface constraints are usually the most expressive. `where T : IEntity` tells readers exactly which capability the generic algorithm needs. Base-class constraints are similar, but they couple the algorithm to inheritance instead of a smaller behavioral contract.

> Warning: `new()` must appear last in the constraint list. Also, do not confuse `struct` with `unmanaged`—many structs still contain references and therefore are not unmanaged.

### Why constraints improve design
Constraints make APIs self-documenting and safer. They allow IntelliSense and the compiler to reason about valid operations on `T`, and they prevent invalid combinations from ever compiling. In interview terms, constraints are one of the biggest reasons generics remain practical instead of becoming "compile now, fail later" abstractions.

They also influence performance and architecture. `unmanaged` can unlock low-level optimizations. Interface constraints encourage composition. Base-class constraints may be fine in frameworks, but in business code they can become too rigid.

### Trade-offs and when not to use certain constraints
The main trade-off is flexibility. Every extra constraint excludes more possible type arguments. If you constrain a method to `class` and `new()` just because it felt convenient, you may block valid immutable types or types created by DI.

Prefer interface constraints when you need behavior, base-class constraints when shared inheritance is truly essential, `new()` only when you genuinely construct `T`, and `unmanaged` only for memory-oriented scenarios. Avoid adding constraints "just in case"—they should reflect a real requirement of the algorithm.

## Code Example
```csharp
using System;
using System.Runtime.InteropServices;

namespace InterviewExamples;

public interface IInitializable
{
    void Initialize();
}

public sealed class Worker : IInitializable
{
    public string Name { get; private set; } = "new worker";

    public void Initialize() => Name = "initialized worker";
}

public readonly struct Pixel(byte red, byte green, byte blue)
{
    public byte Red { get; } = red;
    public byte Green { get; } = green;
    public byte Blue { get; } = blue;
}

internal static class Factory
{
    public static T CreateInitialized<T>() where T : class, IInitializable, new()
    {
        var instance = new T(); // Safe because of new().
        instance.Initialize();
        return instance;
    }

    public static int SizeOf<T>() where T : unmanaged => sizeof(T); // Safe for unmanaged only.
}

internal static class Program
{
    private static void Main()
    {
        var worker = Factory.CreateInitialized<Worker>();
        Console.WriteLine(worker.Name);

        Console.WriteLine($"Pixel size: {Factory.SizeOf<Pixel>()}");
        Console.WriteLine($"Marshal size: {Marshal.SizeOf<Pixel>()}");
    }
}
```

## Common Follow-up Questions
- What is the difference between `struct` and `unmanaged` constraints?
- Why is `new()` often considered less flexible than using DI?
- When would you choose an interface constraint over a base-class constraint?
- Can you combine multiple constraints, and are there ordering rules?
- How do nullable reference types affect `class` constraints?

## Common Mistakes / Pitfalls
- Using `new()` when object creation should come from dependency injection or a factory abstraction.
- Assuming `struct` means the type can be treated as raw unmanaged memory.
- Overconstraining a generic API so valid types can no longer be used.
- Choosing a base-class constraint when a small interface would have reduced coupling.
- Forgetting that `class` does not guarantee any members or a public constructor.

## References
- [Constraints on type parameters - C# | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/generics/constraints-on-type-parameters)
- [where (generic type constraint) - C# reference | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/where-generic-type-constraint)
- [new constraint - C# reference | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/new-constraint)
- [Unmanaged types - C# reference | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/unmanaged-types)
