# Object Equality and Identity

**Category:** OOP & Design
**Difficulty:** 🟡 Middle
**Tags:** `equality`, `IEquatable`, `GetHashCode`, `records`

## Question
> In C#, what is the difference between `==`, `Equals`, and `ReferenceEquals`, and how should you implement value equality correctly?

## Short Answer
`ReferenceEquals` checks whether two references point to the exact same object instance. `Equals` is the main API for semantic equality and can be overridden for value-based comparison, while `==` depends on operator overloads and otherwise often behaves like reference comparison for classes. If you implement value equality, you should usually implement `IEquatable<T>` and ensure `GetHashCode` stays consistent with `Equals`.

## Detailed Explanation
### Identity vs value equality
The first distinction is identity versus equality. Identity asks, “Are these the exact same object in memory?” Equality asks, “Should these two values be considered equivalent for business purposes?”

In C#, `ReferenceEquals(a, b)` always answers the identity question for reference types. `Equals` and `==` may answer the value question, depending on the type.

| API | Main meaning | Typical behavior |
| --- | --- | --- |
| `ReferenceEquals(a, b)` | Identity | Same object instance? |
| `a.Equals(b)` | Semantic equality | Can be overridden for value equality |
| `a == b` | Operator-based equality | Reference equality for many classes unless overloaded |

### Why `Equals` is usually the core contract
For custom types, overriding `Equals(object?)` defines what equality means. If two `Money`, `CustomerId`, or `DateRange` objects represent the same value, `Equals` should return `true` even if they are different instances.

Implementing `IEquatable<T>` improves performance and type safety because generic collections can call the strongly typed `Equals(T?)` instead of boxing or using slower fallback logic.

### The `GetHashCode` contract matters
If two objects are equal according to `Equals`, they must return the same hash code. Otherwise hash-based collections such as `Dictionary<TKey, TValue>` and `HashSet<T>` behave incorrectly. The reverse is not required: two different objects can share a hash code.

This is why `Equals` and `GetHashCode` must be implemented together. In modern C#, `HashCode.Combine(...)` makes this easier and less error-prone.

> Warning: never base `GetHashCode` on mutable fields if the object will be used as a dictionary key. If the value changes after insertion, the collection may no longer find the key.

### How records change the picture
Records are designed for value-like data. C# record types generate value-based equality members automatically, including `Equals`, `==`, and `GetHashCode`. That makes them a great fit for immutable data carriers where value equality is the intent.

Regular classes, by contrast, default to reference-based behavior unless you override it. That is why two separate class instances containing the same data are not equal by default.

### Operator `==` can be convenient or misleading
A senior-level nuance is that `==` is syntax, not a universal semantic rule. For strings and records, `==` already means value equality. For many ordinary classes, it means reference comparison unless you overload the operator. That is why interviewers often want you to say: always know the equality semantics of the specific type you are using.

This also means API consistency matters. If you overload `==`, callers expect it to agree with `Equals`; otherwise comparisons become surprising and collection behavior becomes harder to reason about.

### Practical guidance
Use reference equality when identity itself matters, such as tracking entity instances in memory. Use value equality for concepts that are defined by their contents, such as money amounts, coordinates, or identifiers.

A strong interview answer also mentions collections: equality affects lookup, deduplication, grouping, and joins. If equality is wrong, bugs appear far away from the original type design.

## Code Example
```csharp
namespace OopAndDesignExamples;

public sealed class CustomerId(string value) : IEquatable<CustomerId>
{
    public string Value { get; } = value;

    public bool Equals(CustomerId? other)
        => other is not null && StringComparer.Ordinal.Equals(Value, other.Value);

    public override bool Equals(object? obj) => obj is CustomerId other && Equals(other);

    public override int GetHashCode() => StringComparer.Ordinal.GetHashCode(Value);
}

public sealed record ProductCode(string Value); // Records generate value equality automatically.

public static class Program
{
    public static void Main()
    {
        var first = new CustomerId("C-42");
        var second = new CustomerId("C-42");

        Console.WriteLine(first == second);                    // False: class operator not overloaded.
        Console.WriteLine(first.Equals(second));               // True: value equality.
        Console.WriteLine(ReferenceEquals(first, second));     // False: different instances.

        var code1 = new ProductCode("P-99");
        var code2 = new ProductCode("P-99");

        Console.WriteLine(code1 == code2);                    // True: records overload == for value equality.
        Console.WriteLine(code1.Equals(code2));               // True.
    }
}
```

## Common Follow-up Questions
- Why should `IEquatable<T>` usually be implemented together with `Equals(object)`?
- What happens if `Equals` returns true but `GetHashCode` differs?
- Why are records often a good fit for value equality?
- When would reference equality be the correct business choice?
- How do dictionaries and hash sets depend on equality semantics?

## Common Mistakes / Pitfalls
- Overriding `Equals` without also overriding `GetHashCode`.
- Using mutable properties in equality and then mutating objects after inserting them into a `HashSet<T>` or `Dictionary<TKey, TValue>`.
- Assuming `==` always means the same thing across all C# types.
- Forgetting to handle `null` consistently in equality implementations.
- Using reference equality for value objects such as money, coordinates, or strongly typed IDs.

## References
- [Equality comparisons (C# Programming Guide)](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/statements-expressions-operators/equality-comparisons)
- [IEquatable<T> API](https://learn.microsoft.com/en-us/dotnet/api/system.iequatable-1)
- [Object.GetHashCode Method](https://learn.microsoft.com/en-us/dotnet/api/system.object.gethashcode)
- [Introduction to record types in C#](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/records)
