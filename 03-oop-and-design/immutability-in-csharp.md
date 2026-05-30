# Immutability in C#

**Category:** OOP & Design / Functional Patterns
**Difficulty:** 🟢 Junior
**Tags:** `immutability`, `records`, `readonly`, `concurrency`, `ImmutableList`

## Question
> What does immutability mean in C#, and how do features like `readonly`, `init`, records, and `ImmutableList<T>` help implement it?

## Short Answer
Immutability means an object does not change after it is created. In C#, you can move toward that with `readonly` fields, `init`-only properties, record types, and immutable collections like `ImmutableList<T>`. Immutable data is easier to reason about, safer to share between threads, and simpler to test, but you must watch out for shallow immutability and extra allocations.

## Detailed Explanation
### What immutability means in practice
An immutable object exposes state that cannot be changed after construction. Once created, the same instance always represents the same value. That is very useful in business logic because the object cannot silently drift into an invalid state after other code gets a reference to it.

In C#, immutability exists on a spectrum:
- **`readonly` fields** stop reassignment after construction.
- **`init`-only properties** allow setting values only during object initialization.
- **records** make value-oriented immutable models ergonomic.
- **immutable collections** return new collections instead of mutating the old one.

| Feature | What it protects | Important limitation |
| --- | --- | --- |
| `readonly` field | Field reference/value reassignment | Object referenced by the field may still mutate |
| `init` property | Property assignment after initialization | Referenced object may still be mutable |
| `record` | Value-style modeling and non-destructive updates | Not automatically deeply immutable |
| `ImmutableList<T>` | Collection contents | Adds allocation/copy overhead |

### Why immutability helps concurrency
Shared mutable state is one of the biggest causes of concurrency bugs. If multiple threads can update the same object, you need locking or other synchronization. Immutable objects remove that category of bug because no thread can modify the shared instance.

That does not automatically solve all concurrency problems, but it makes data sharing much safer. Configuration snapshots, domain events, DTOs, and value objects are especially good candidates for immutability.

> Warning: a `readonly List<string>` field is **not** an immutable list. The field cannot point to a different list, but the list’s contents can still change.

### Important C# building blocks
`readonly` is the oldest building block. It is useful for constructor-initialized dependencies and values. `init`-only properties make object initialization syntax work nicely while preventing later mutation. Records then build on top of that by giving you value equality and `with` expressions for non-destructive updates.

For collections, prefer `System.Collections.Immutable` when you want true immutable semantics. `ImmutableList<T>.Add()` returns a new list and leaves the original unchanged. That is exactly what you want in many functional-style pipelines.

### Trade-offs and when not to use it everywhere
Immutability improves predictability, but it is not free. Creating new objects on each update can increase allocations and GC pressure. In very hot loops or low-level performance-sensitive code, controlled mutation may be faster and simpler.

Also, developers sometimes think records automatically solve everything. They do not. If a record property contains a mutable list, the record is only **shallowly** immutable. True immutability requires thinking about the whole object graph.

A practical C# approach is:
- Use immutable models for value objects, DTOs, configuration snapshots, and domain messages.
- Use mutable objects where in-place updates are natural and performance matters.
- Be explicit about where mutation is allowed.

### Interview-ready takeaway
In interviews, the strong answer is that immutability reduces accidental state changes, makes code more thread-friendly, and pairs well with modern C# features. But the best engineers also mention trade-offs: extra allocations, shallow-vs-deep immutability, and the fact that mutation is still reasonable in performance-critical or stateful parts of a system.

## Code Example
```csharp
using System;
using System.Collections.Immutable;

namespace OopAndDesign.FunctionalPatterns;

public static class Program
{
    public static void Main()
    {
        var original = new ShoppingCart(
            CustomerName: "Mikhail",
            Items: ImmutableList.Create("Keyboard", "Mouse"));

        // with-expression creates a new record instead of mutating the old one.
        var updated = original with { Items = original.Items.Add("Monitor") };

        Console.WriteLine($"Original count: {original.Items.Count}");
        Console.WriteLine($"Updated count: {updated.Items.Count}");
    }
}

public sealed record ShoppingCart
{
    public required string CustomerName { get; init; }
    public required ImmutableList<string> Items { get; init; }

    public ShoppingCart(string CustomerName, ImmutableList<string> Items)
    {
        this.CustomerName = CustomerName;
        this.Items = Items;
    }
}
```

## Common Follow-up Questions
- What is the difference between shallow and deep immutability?
- Why are records a good fit for value objects?
- How does immutability reduce the need for locks in multithreaded code?
- When would mutable collections still be the better choice?
- Does `readonly` make an object fully immutable?

## Common Mistakes / Pitfalls
- Assuming `readonly` makes the referenced object immutable.
- Using `List<T>` inside a record and calling the whole model immutable.
- Replacing every mutable object with immutable ones without measuring allocation costs.
- Forgetting that `with` expressions copy references, not deep clone entire graphs.
- Exposing mutable collections through read-only-looking properties.

## References
- [The readonly keyword - C# reference](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/readonly)
- [The init keyword - C# reference](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/init)
- [C# record types](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/records)
- [ImmutableList<T> Class](https://learn.microsoft.com/en-us/dotnet/api/system.collections.immutable.immutablelist-1)
