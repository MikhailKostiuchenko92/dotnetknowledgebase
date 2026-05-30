# `init`-Only Properties

**Category:** C# / Records & Immutability
**Difficulty:** Middle
**Tags:** `init`, `required`, `immutability`, `records`, `object-initializer`

## Question

> What are `init`-only properties in C#, and how do they differ from normal setters?

Also asked as:
- "When should you use `init` instead of `set`?"
- "How do `required` members relate to `init`?"
- "Why do records and `with` expressions often appear together with `init` properties?"

## Short Answer

An `init` accessor lets a property be assigned during object initialization but not mutated freely afterward. It provides a convenient middle ground between constructor-only initialization and fully mutable `set` properties. In modern C#, `init` is commonly paired with `required` members and records to build immutable or mostly immutable models with concise object-initializer syntax.

## Detailed Explanation

### What `init` Changes

A normal `set` accessor allows mutation any time the property is accessible. An `init` accessor restricts assignment to initialization time, such as:

- an object initializer
- a `with` expression
- a constructor in the same type
- attribute-based or serializer-driven construction paths that support init semantics

After initialization, callers cannot assign to the property again through ordinary code.

| Accessor | When assignment is allowed | Typical use |
|---|---|---|
| `set` | Any time | Mutable domain or UI state |
| `init` | Initialization only | Immutable DTOs, options, records |
| `required` | Compile-time requirement to provide a value | Important members that must be initialized |

### Why `init` Exists

Before `init`, developers often had to choose between:

- verbose constructors with many parameters
- mutable public setters that weakened invariants

`init` gives a cleaner option: keep object-initializer readability without opening the object to arbitrary later mutation.

### `required` Members

`required` solves a different problem. It does not make a property immutable; it makes initialization mandatory. In practice, `required` and `init` pair very well:

- `required` says the caller must set it
- `init` says they can set it only during initialization

That combination is a strong fit for request models, configuration objects, and records.

> **Warning:** `init` improves API design, but it is not a security boundary. Reflection and some serializers can still bypass normal compile-time rules, so you should still validate important invariants.

### Records and `with`

Positional record classes generate `init` properties by default, which is why records feel immutable and work naturally with `with` expressions. A `with` expression creates a copy and reinitializes selected `init` members on the new instance.

This topic connects directly to [records-vs-classes.md](./records-vs-classes.md) and [record-struct-vs-record-class.md](./record-struct-vs-record-class.md).

### When to Use and When Not to Use

Use `init` when:

- state should be set once and then stay stable
- object initializers improve readability
- you want lightweight immutable DTOs or value-like models

Avoid relying on `init` alone when:

- invariants require constructor enforcement across many members
- mutation is part of the type's normal lifecycle
- the object must always be valid in partially initialized intermediate states

Sometimes a constructor is still the clearest API.

See also [constructors-chaining-and-static.md](./constructors-chaining-and-static.md).

## Code Example

```csharp
using System;

var options = new ApiOptions
{
    BaseUrl = new Uri("https://api.example.com"),
    ApiKey = "secret-key"
};

var person = new Person("Mikhail", "Kostiuchenko");
var renamed = person with { LastName = "Kost" };

Console.WriteLine(options.BaseUrl);
Console.WriteLine(renamed);

public class ApiOptions
{
    public required Uri BaseUrl { get; init; }
    public required string ApiKey { get; init; }
}

public record Person(string FirstName, string LastName);

// options.ApiKey = "new-key"; // Compile-time error: init-only setter.
```

## Common Follow-up Questions

- How is `init` different from a private setter or constructor-only assignment?
- What problem does `required` solve that `init` does not?
- Why do positional record classes naturally pair with `init`?
- Can a constructor assign an `init` property inside the declaring type?
- When is a constructor still preferable to `init` properties?

## Common Mistakes / Pitfalls

- Thinking `required` and `init` are interchangeable when they solve different problems.
- Using `init` for types that are expected to be mutated throughout their lifecycle.
- Assuming `init` alone guarantees all invariants without additional validation.
- Replacing every constructor with object initializers even when positional construction is clearer.
- Forgetting that `with` on records performs a shallow copy, not a deep clone.

## References

- [init - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/init)
- [required modifier - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/required)
- [Introduction to record types in C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/records)
- [See: records-vs-classes.md](./records-vs-classes.md)
- [See: constructors-chaining-and-static.md](./constructors-chaining-and-static.md)
