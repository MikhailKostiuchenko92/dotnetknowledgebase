# Value Equality in Records

**Category:** C# / Records & Immutability
**Difficulty:** Middle
**Tags:** `records`, `equality`, `gethashcode`, `operator-overloading`, `value-objects`

## Question
> How does value equality work in C# records?

Related phrasings:
- "What equality members does the compiler generate for records?"
- "Why are two records with the same data usually equal, but a base record and derived record are not?"
- "How should you customize record equality when the default semantics are not enough?"

## Short Answer
Records use value-based equality by default: two records of the same runtime type are equal when their equality-participating data is equal. In .NET 8/9 and C# 12/13, the compiler typically synthesizes `Equals`, `GetHashCode`, `==`, and `!=` so records behave like value objects instead of identity-based objects. That is powerful for immutable models, but you still need to understand runtime-type checks, hashing rules, and when custom equality is a sign that a plain class may be a better fit.

## Detailed Explanation

### What Record Equality Gives You by Default
A normal class uses reference equality unless you override it. A record flips that default: equality is based on the record's data rather than object identity.

That means this is usually true:

- two separately created records with the same values compare equal
- their hash codes also match
- `==` and `!=` follow the same logical equality

This behavior is one of the main reasons records are useful for DTOs, commands, responses, and value-object-style models alongside [with-expressions-and-non-destructive-mutation.md](./with-expressions-and-non-destructive-mutation.md).

| Type | Default equality style |
|---|---|
| `class` | Reference equality unless overridden |
| `record class` | Value equality |
| `struct` | Value equality via `ValueType`, often slower and less explicit |
| `record struct` | Value equality with record-friendly generated members |

### What the Compiler Generates
For records, the compiler synthesizes equality-related members so you do not have to write the repetitive plumbing yourself. The exact generated set depends on whether the record is positional and whether it is a class or struct, but the key interview members are:

- strongly typed `Equals`
- `override bool Equals(object?)`
- `override int GetHashCode()`
- `operator ==`
- `operator !=`

For positional records, the primary constructor data is central to the generated shape, and the resulting code is concise and predictable in C# 12/13.

### Same Values Are Not Enough: Runtime Type Matters
A subtle but important point is that record equality also respects the runtime type. Two record instances are not equal just because a base slice of their data looks the same.

For example, a `Person` record and an `Employee : Person` record with the same `FirstName` and `LastName` are still not equal, because they represent different logical types.

> **Tip:** In interviews, mention both parts of the rule: records compare by value **and** by compatible runtime type. Saying only "records compare properties" is incomplete.

This prevents accidental equality between different concepts in an inheritance hierarchy.

### Positional Record Equality
Positional records are especially easy to reason about. The constructor parameters define the public data shape, and that shape participates naturally in synthesized equality.

```csharp
public record Person(string FirstName, string LastName);
```

Two `Person` values with the same names are equal, even if created separately. That makes positional records convenient for small immutable value objects.

### Customizing Equality
Sometimes the default semantics are close, but not exactly right. Common examples include:

- case-insensitive identifiers
- normalized email addresses
- domain values where only part of the state should matter

You can customize equality by overriding the synthesized members consistently, especially `Equals` and `GetHashCode`. But that is the key warning: if you customize one and not the other, hashed collections such as `Dictionary<TKey, TValue>` and `HashSet<T>` become incorrect.

| Customization need | Better approach |
|---|---|
| Data can be normalized once | Normalize during construction and keep default record equality |
| Only special collection semantics are needed | Keep record equality, supply a custom `IEqualityComparer<T>` |
| The type's natural equality is truly custom | Override equality members carefully |
| Identity matters more than value | Use a class instead of a record |

In practice, normalization is often simpler than overriding equality. For example, storing email values already trimmed and lowercased makes the default generated equality good enough.

### When Records Are a Great Equality Fit
Records shine when the instance represents a value, snapshot, or immutable message. They are often a poorer fit for mutable entities tracked by identity, such as ORM entities with lifecycle and persistence concerns. That distinction connects directly to [records-vs-classes.md](./records-vs-classes.md).

## Code Example
```csharp
using System;

var left = new Person("Mikhail", "Kostiuchenko");
var right = new Person("Mikhail", "Kostiuchenko");

Console.WriteLine(left == right);              // True: same runtime type and same data.
Console.WriteLine(left.Equals(right));         // True
Console.WriteLine(left.GetHashCode() == right.GetHashCode()); // Usually True for equal values.

Person employeeAsPerson = new Employee("Mikhail", "Kostiuchenko", 42);
Console.WriteLine(left == employeeAsPerson);   // False: runtime type differs.

var email1 = new EmailAddress(" Dev@Example.com ");
var email2 = new EmailAddress("dev@example.com");
Console.WriteLine(email1 == email2);           // True: custom normalized equality.

public record Person(string FirstName, string LastName);

public record Employee(string FirstName, string LastName, int EmployeeId)
    : Person(FirstName, LastName);

public sealed record EmailAddress(string Value)
{
    private static string Normalize(string value) => value.Trim().ToUpperInvariant();

    public bool Equals(EmailAddress? other) =>
        other is not null && Normalize(Value) == Normalize(other.Value);

    public override int GetHashCode() => Normalize(Value).GetHashCode();
}
```

## Common Follow-up Questions
- What equality members are synthesized for a record class versus a record struct?
- Why does record equality consider runtime type in inheritance scenarios?
- When is a custom `IEqualityComparer<T>` better than overriding record equality?
- How does record equality interact with `with` expressions and immutable updates?
- Why can mutability break the usefulness of value equality in records?

## Common Mistakes / Pitfalls
- Assuming records compare equal even when one instance is a derived record type.
- Overriding `Equals` without updating `GetHashCode` consistently.
- Using mutable fields or collections and expecting hash-based collections to behave predictably.
- Choosing records for identity-based entities just because the syntax is short.
- Forgetting that normalization at construction time is often simpler than custom equality code.

## References
- [Introduction to record types in C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/records)
- [record - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/record)
- [Object.Equals Method](https://learn.microsoft.com/dotnet/api/system.object.equals)
- [See: records-vs-classes.md](./records-vs-classes.md)
- [See: with-expressions-and-non-destructive-mutation.md](./with-expressions-and-non-destructive-mutation.md)
