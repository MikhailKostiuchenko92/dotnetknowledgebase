# Nullable Annotations in Generics

**Category:** C# / Generics
**Difficulty:** Senior
**Tags:** `generics`, `nullability`, `constraints`, `default`

## Question
> What does `T?` mean in generic code, and how does it differ for value types versus reference types?
>
> How should I think about nullability, `default(T)`, and the `notnull` constraint when designing generic APIs?
>
> Why does nullable analysis in generic code sometimes feel less intuitive than in non-generic code?

## Short Answer
In generic code, `T?` is context-dependent. For a value type it represents `Nullable<T>`, while for a reference type it represents a nullable reference annotation; because `T` can stand for either family, the compiler often needs constraints or nullable analysis attributes to understand your intent precisely.

## Detailed Explanation
### Why generic nullability is tricky
A concrete type like `string?` is straightforward, but `T?` is more subtle because `T` might become `string`, `Customer`, `int`, or `DateTime`. Generic APIs therefore need more explicit contracts.

| Generic form | If `T` is a reference type | If `T` is a value type |
| --- | --- | --- |
| `T` | Non-nullable reference intent | Plain value type |
| `T?` | Nullable reference intent | `Nullable<T>` |
| `default(T)` | Often `null` | Zero-initialized value |
| `where T : notnull` | Rejects nullable reference substitutions | Rejects nullable value substitutions like `int?` |

This is why generic APIs often combine constraints, attributes, and careful naming.

> Tip: if your API meaning depends on “missing value,” consider whether a `TryGet` pattern or an option/result type communicates intent better than returning `default`.

See also [Generic Constraints](./generic-constraints.md), [Nullable Analysis Attributes](./nullability-attributes.md), and [Nullable Reference Types](./nullable-reference-types.md).

### `default(T)` and API design
`default(T)` is not “null” in the general sense; it is the default value of whatever type closes `T`.

- `default(string)` is `null`
- `default(int)` is `0`
- `default(DateTime)` is `0001-01-01`
- `default(Guid)` is `Guid.Empty`

That means returning `default(T)` as a “not found” marker is often ambiguous in generic code. A caller cannot always distinguish “missing” from “present with the default value.”

The safer alternatives are:
- `bool TryGet(..., out T value)`
- Returning `T?` with an appropriate constraint and clear semantics
- Using `[MaybeNull]` or `[MaybeNullWhen(false)]` when the type surface alone is not enough

### Where `notnull` helps
`where T : notnull` tells the compiler and callers that `T` cannot be instantiated with a nullable reference type or nullable value type. It does not mean the runtime value can never be invalid, but it sharply improves API intent.

It is useful when your code depends on keys, dictionary lookups, or identities that must be non-null. Without it, callers might supply `string?` or `int?`, forcing extra analysis noise.

> Warning: `notnull` is a compile-time contract, not a runtime guard. External callers, reflection, or deserialization can still violate assumptions, so validate public boundaries when needed.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;

var cache = new Cache<string, int>();
cache.Set("users", 42);

if (cache.TryGet("users", out var count))
{
    Console.WriteLine(count); // Safe: count is definitely assigned.
}

Console.WriteLine(GenericHelpers.FirstOrDefault(new[] { "A", "B" }) ?? "missing");
Console.WriteLine(GenericHelpers.FirstOrDefault(new[] { 10, 20 }));

sealed class Cache<TKey, TValue> where TKey : notnull
{
    private readonly Dictionary<TKey, TValue> _items = new();

    public void Set(TKey key, TValue value)
    {
        _items[key] = value;
    }

    public bool TryGet(TKey key, [MaybeNullWhen(false)] out TValue value)
    {
        return _items.TryGetValue(key, out value);
    }
}

static class GenericHelpers
{
    [return: MaybeNull]
    public static T FirstOrDefault<T>(IReadOnlyList<T> items)
    {
        if (items.Count > 0)
        {
            return items[0];
        }

        return default;
    }

    public static string Describe<T>(T? value)
    {
        // For reference types, T? means nullable reference.
        // For value types, T? means Nullable<T> when allowed by the closed type.
        return value is null ? "null" : value.ToString()!;
    }
}
```

## Common Follow-up Questions
- Why is returning `default(T)` often a poor “not found” contract?
- What is the difference between `where T : class`, `where T : struct`, and `where T : notnull`?
- When should I use `[MaybeNull]` or `[MaybeNullWhen(false)]` in generic methods?
- Can `T?` be used freely without constraints in every generic scenario?
- Why do dictionary key APIs commonly use `notnull`?

## Common Mistakes / Pitfalls
- Treating `default(T)` as if it always meant `null`.
- Using `T?` without understanding that its meaning changes between reference and value types.
- Forgetting to constrain key-like generic parameters with `notnull`.
- Designing a generic API where callers cannot distinguish “missing” from “default value.”
- Assuming compile-time nullability constraints remove the need for runtime validation in public APIs.

## References
- [Microsoft Docs: Generics in C#](https://learn.microsoft.com/dotnet/csharp/fundamentals/types/generics)
- [Microsoft Docs: Constraints on type parameters](https://learn.microsoft.com/dotnet/csharp/programming-guide/generics/constraints-on-type-parameters)
- [Microsoft Docs: Nullable static analysis attributes](https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/nullable-analysis)
- [See: Generic Constraints](./generic-constraints.md)
- [See: Nullable Analysis Attributes](./nullability-attributes.md)
- [See: Nullable Reference Types](./nullable-reference-types.md)
