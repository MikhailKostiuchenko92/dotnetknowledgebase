# `readonly` vs `const`

**Category:** C# / Language Mechanics
**Difficulty:** Junior
**Tags:** `readonly`, `const`, `static-readonly`, `versioning`, `immutability`

## Question

> What is the difference between `const`, `readonly`, and `static readonly` in C#?

Also asked as:
- "When should I use `const` instead of `readonly`?"
- "Why can `const` create versioning problems across assemblies?"
- "Why is `static readonly` often better for values like `TimeSpan` or GUIDs?"

## Short Answer

`const` values are compile-time constants and get inlined into consuming code, while `readonly` fields are runtime values that can be assigned only during declaration or construction. `static readonly` is the usual choice for shared immutable values that are not valid compile-time constants, such as `TimeSpan`, `DateTime`, or values loaded from helper methods. In .NET 8/9 code, use `const` only for true universal constants, not for values that might change in a library later.

## Detailed Explanation

### Compile-time constant vs runtime readonly value

The key distinction is **when the value is fixed**.

| Option | Assigned when | Allowed types | Versioning behavior |
|---|---|---|---|
| `const` | Compile time | Primitive constants, `string`, `null`, enum values | Inlined into consuming assemblies |
| `readonly` | Construction time | Any field type | Resolved at runtime |
| `static readonly` | Type initialization time | Any field type | Resolved at runtime |

A `const` is implicitly static. You cannot make a per-instance const field.

### Why versioning matters

If a library publishes `public const int DefaultTimeoutSeconds = 30;`, consuming assemblies may inline `30` at compile time. If the library later changes it to `60` and only the library is redeployed, old consumers may still behave as if the value were `30` until they are rebuilt.

That is the famous assembly-versioning gotcha and one of the most common interview follow-ups.

> **Warning:** Avoid public `const` values in reusable libraries unless the value is a true mathematical or protocol constant that will never change.

### When `readonly` or `static readonly` is better

Use instance `readonly` when each object has a value assigned during construction and then kept immutable. Use `static readonly` for shared values that are not compile-time constants, such as `TimeSpan.FromSeconds(30)`, regexes, GUIDs, or configuration-derived defaults.

### Practical guidance

Good `const` candidates:
- unit conversion factors that truly never change
- internal sentinel strings or numeric values with universal meaning
- enum-like compile-time literals

Good `static readonly` candidates:
- `TimeSpan`, `Uri`, `Guid`, `DateTime`, or complex value objects
- default options that might evolve between library versions
- values computed by helper methods

This topic pairs well with [readonly-struct.md](./readonly-struct.md) and [init-only-properties.md](./init-only-properties.md): all discuss immutability, but at different language levels.

## Code Example

```csharp
using System;

namespace Demo;

Console.WriteLine(ApiDefaults.HttpPort);          // Compile-time constant.
Console.WriteLine(ApiDefaults.DefaultTimeout);    // Runtime-initialized immutable value.
Console.WriteLine(new UserProfile("Mikhail").DisplayName);

public static class ApiDefaults
{
    public const int HttpPort = 80;
    public static readonly TimeSpan DefaultTimeout = TimeSpan.FromSeconds(30);
}

public sealed class UserProfile
{
    public UserProfile(string displayName)
    {
        DisplayName = displayName; // Instance readonly can be set during construction.
    }

    public readonly string DisplayName;
}
```

## Common Follow-up Questions

- Why is `const` effectively static in C#?
- Why can changing a public const break expectations across assembly boundaries?
- Why can `TimeSpan.FromSeconds(30)` not be a `const`?
- When should you use instance `readonly` versus `static readonly`?
- Why does readonly help with immutability but not automatically make a referenced object deeply immutable?

## Common Mistakes / Pitfalls

- Using public `const` for values that may change and then forgetting consumers must rebuild.
- Assuming `readonly` means the referenced object graph is deeply immutable.
- Trying to use `const` with values that are only known at runtime or require method calls.
- Choosing `const` just because it looks simpler when `static readonly` would be safer for libraries.

## References

- [const keyword - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/const)
- [readonly keyword - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/readonly)
- [See: readonly-struct.md](./readonly-struct.md)
- [See: init-only-properties.md](./init-only-properties.md)
- [See: constructors-chaining-and-static.md](./constructors-chaining-and-static.md)
