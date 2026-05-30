# Static Classes and Members

**Category:** C# / OOP in C#
**Difficulty:** Junior
**Tags:** `static`, `utility`, `lifetime`, `testability`, `static local function`

## Question

> What are static classes and static members in C#, and when should you use them?

Also asked as:
- "Why can't you create an instance of a static class?"
- "What is the lifetime of a static field?"
- "What are the downsides of putting too much logic into static helpers?"

## Short Answer

Static members belong to the type itself, not to an instance, and a static class is just a type that cannot be instantiated or inherited. They are useful for stateless helpers, shared caches, and factory-style functionality, but they also introduce global state and can make testing and lifecycle management harder if overused.

## Detailed Explanation

### What Makes a Class or Member Static

A `static` member exists once per type, while an instance member exists once per object. A `static class` goes further: it can contain only static members, cannot be instantiated, and cannot be inherited.

| Construct | Meaning |
|---|---|
| Static field | One shared field for the type |
| Static method | Callable without an instance |
| Static property | Shared state or computed value on the type |
| Static class | Utility-style type with no instances |

The BCL uses this pattern heavily for types like `Math`, `Convert`, and `Enum`.

### Typical Use Cases

Static members are a good fit when behavior is naturally type-level rather than object-level:

- Pure helper methods such as parsing, math, and formatting.
- Shared immutable configuration.
- Thread-safe caches or counters.
- Factory members like `Create` or `Parse`.

A static class is often appropriate when there is no meaningful object state at all.

### Lifetime of Static Fields

A static field is initialized when the runtime initializes the type, and it lives for the lifetime of that type in the process. In practice, that usually means until the process ends. For generic types, static fields are per closed generic type; see [static-members-in-generic-types.md](./static-members-in-generic-types.md).

> **Warning:** A mutable static field is global shared state. If multiple tests or threads touch it, you can get flaky behavior unless access is synchronized and reset intentionally.

### Testability and Design Concerns

The main drawback of static-heavy design is coupling. A method that directly calls static helpers with hidden global state is harder to replace, fake, or isolate in tests than code depending on an interface.

That does not mean static is bad. It means truly stateless functions are great as static methods, while stateful business logic often belongs in normal services.

### Static Local Functions

C# also supports `static` local functions inside methods. These are useful because they cannot capture locals from the enclosing scope. That prevents accidental closure allocations and makes dependencies explicit.

This is different from a static class, but interviewers sometimes connect the topics because both use `static` to say, "this code does not depend on instance state."

See also [constructors-chaining-and-static.md](./constructors-chaining-and-static.md).

## Code Example

```csharp
using System;
using System.Threading;

Console.WriteLine(IdGenerator.NextId());
Console.WriteLine(IdGenerator.NextId());

int SumSquares(int[] numbers)
{
    return Aggregate(numbers);

    static int Square(int value) => value * value; // Cannot capture outer variables.

    static int Aggregate(int[] items)
    {
        var total = 0;
        foreach (int item in items)
        {
            total += Square(item);
        }

        return total;
    }
}

Console.WriteLine(SumSquares([1, 2, 3])); // 14

static class IdGenerator
{
    private static int _current; // Shared for the whole type.

    public static int NextId() => Interlocked.Increment(ref _current);
}
```

## Common Follow-up Questions

- What is the difference between a static class and a normal class with static members?
- When is mutable static state acceptable, and how do you make it thread-safe?
- Why can static local functions be more efficient than capturing lambdas?
- How do static members behave in generic types?
- Why can excessive static usage hurt testability?

## Common Mistakes / Pitfalls

- Putting business logic with hidden mutable global state into static helpers.
- Assuming static fields are automatically thread-safe.
- Using static methods where dependency injection and explicit collaboration would be clearer.
- Forgetting that static state can leak between tests in the same process.

## References

- [static - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/static)
- [Static Classes and Static Class Members](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/static-classes-and-static-class-members)
- [Local functions - C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/local-functions)
- [See: static-members-in-generic-types.md](./static-members-in-generic-types.md)
