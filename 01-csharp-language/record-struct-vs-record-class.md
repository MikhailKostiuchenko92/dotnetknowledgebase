# Record Struct vs Record Class

**Category:** C# / Records & Immutability
**Difficulty:** Middle
**Tags:** `record-struct`, `record-class`, `value-type`, `boxing`, `copying`

## Question

> What is the difference between `record struct` and `record class` in C#, and how do you choose between them?

Also asked as:
- "Are record structs just faster records?"
- "What defaults are different between record classes and record structs?"
- "How do copying and boxing affect record structs in real code?"

## Short Answer

A `record class` is a reference type with record-style generated members, while a `record struct` is a value type with similar record-style syntax and value-based equality. The choice is mainly about value-type versus reference-type semantics: copying cost, mutation model, boxing behavior, and how the type is passed around. Use `record class` for most DTO-like objects, and consider `record struct` only for small, value-like data where copy semantics are desirable and carefully understood.

## Detailed Explanation

### Same Record Syntax, Different Runtime Semantics

Both forms support record-style conveniences such as generated equality, `ToString()`, and deconstruction. But their runtime behavior follows the underlying type category.

| Aspect | `record class` | `record struct` |
|---|---|---|
| Type category | Reference type | Value type |
| Allocation | Usually heap object | Inline / copied as a value |
| Default equality | Value equality | Value equality |
| Default positional properties | `init` | `get; set;` |
| Boxing risk | None from being a reference type | Yes when cast to `object` or interfaces |

That default property mutability difference is easy to forget and frequently comes up in interviews.

### Mutability Defaults Matter

A positional record class encourages immutability because its generated properties are `init`-only. A positional record struct, however, generates read-write properties unless you declare `readonly record struct`.

So if you want small immutable value objects, `readonly record struct` is often a better mental model than plain `record struct`.

### Copying and Passing Behavior

A record struct is copied when passed by value, returned by value, or assigned to another variable. For a tiny type like `Point`, that is fine. For a larger type, copies can become expensive or surprising.

A record class passes references around instead. Multiple variables can point to the same instance, and `with` creates a new copy-like object when needed.

### Boxing and Interfaces

Because record structs are value types, boxing can occur when they are cast to `object`, stored in non-generic collections, or used through interface references. That adds allocation overhead and can partially erase the benefit of choosing a struct in the first place.

> **Warning:** Do not pick `record struct` only because "structs are faster." Small immutable value-like types may benefit, but larger or heavily boxed structs can perform worse and be harder to reason about.

### When to Choose Which

Choose **record class** when:

- the type is a normal DTO, message, command, or projection
- you want reference-type behavior
- the object may be moderately sized
- you prefer easier framework integration and fewer copy concerns

Choose **record struct** when:

- the type is small and truly value-like
- copying is cheap and semantically correct
- you want to avoid separate object allocation in hot paths
- boxing can be avoided or minimized

This topic connects directly to [records-vs-classes.md](./records-vs-classes.md), [readonly-struct.md](./readonly-struct.md), and [class-vs-struct.md](./class-vs-struct.md).

## Code Example

```csharp
using System;

OrderDto dto1 = new(1001, "Created");
OrderDto dto2 = dto1 with { Status = "Paid" }; // New reference-type record instance.
Console.WriteLine(dto1);
Console.WriteLine(dto2);

readonly record struct Money(decimal Amount, string Currency);
Money price1 = new(19.99m, "USD");
Money price2 = price1; // Value copy.
object boxed = price1; // Boxing because Money is a value type.

Console.WriteLine(price1 == price2);          // True
Console.WriteLine(boxed.GetType().Name);      // Money

public record class OrderDto(int Id, string Status);
```

## Common Follow-up Questions

- Why are positional `record struct` properties mutable by default?
- When should you prefer `readonly record struct` over plain `record struct`?
- What kinds of code cause boxing for a record struct?
- Why can a large struct be slower despite avoiding a separate heap object?
- How does `with` behave for record classes versus record structs?

## Common Mistakes / Pitfalls

- Assuming `record struct` is automatically immutable.
- Choosing a record struct for a large type that gets copied frequently.
- Ignoring boxing when value-type records are used through `object` or interfaces.
- Treating `record class` and `record struct` as interchangeable because the syntax looks similar.
- Forgetting that value-type semantics affect assignment, parameter passing, and mutation.

## References

- [record - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/record)
- [Introduction to record types in C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/records)
- [See: records-vs-classes.md](./records-vs-classes.md)
- [See: readonly-struct.md](./readonly-struct.md)
- [See: class-vs-struct.md](./class-vs-struct.md)
