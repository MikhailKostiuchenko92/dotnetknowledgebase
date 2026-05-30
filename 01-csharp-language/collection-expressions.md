# Collection Expressions

**Category:** C# / Modern C# Features
**Difficulty:** Middle
**Tags:** `collection-expressions`, `spread`, `target-typing`, `CollectionBuilder`, `csharp-12`

## Question

> What are collection expressions in C# 12, and how are they different from collection initializers?

Also asked as:
- "What does `[1, 2, 3]` mean in C# 12?"
- "How does the spread operator `..` work inside a collection expression?"
- "Which target types support collection expressions, including custom builder-based types?"

## Short Answer

Collection expressions are the C# 12 feature that lets you write values like `[1, 2, 3]` and spreads like `[..otherValues, 4]`. They are target-typed, so the compiler decides how to materialize the expression based on the expected destination type, such as an array, `List<T>`, span, or a custom type that uses `CollectionBuilderAttribute`. In .NET 8/9 they improve readability, but you still need to understand the target type because allocation behavior and mutability depend on what the expression becomes.

## Detailed Explanation

### What the syntax means

A collection expression is an expression form, not a standalone collection type. `[1, 2, 3]` has no natural runtime type by itself. The compiler needs a target such as `int[]`, `List<int>`, `ReadOnlySpan<int>`, or another supported collection shape.

That is why this is valid:

```csharp
int[] values = [1, 2, 3];
```

but this is not:

```csharp
// var values = [1, 2, 3]; // No target type.
```

### Spread elements and target typing

The `..` spread element expands another sequence inside the expression. It is conceptually similar to "insert these items here," but the compiler can often optimize materialization better than hand-written concatenation code.

| Form | Meaning | Example |
|---|---|---|
| `[1, 2, 3]` | Create a target-typed collection with those elements | `int[] a = [1, 2, 3];` |
| `[..existing, 4]` | Expand another sequence, then append | `List<int> b = [..a, 4];` |
| `[]` | Empty collection expression | `int[] empty = [];` |

> **Tip:** Think of collection expressions as *syntax plus target typing*, not as a replacement for every collection initializer or LINQ projection.

### Supported targets

In .NET 8/9, collection expressions work well with built-in targets such as arrays, spans, and many collection types that support collection-initializer-like patterns. They also support custom types through `CollectionBuilderAttribute`, where the compiler calls a designated builder method.

That matters in interviews because `[1, 2, 3]` can become a mutable `List<int>`, a fixed-size array, or a stack-friendly span, depending on the target. The same source syntax does not imply the same runtime behavior.

### Collection expressions vs collection initializers

Traditional collection initializers depend on constructing a type and then calling `Add`. Collection expressions are more general and often enable better lowering because the compiler sees the full element list at once.

Use collection expressions when they improve clarity, especially for literals, empty collections, and simple composition. Prefer more explicit construction when mutability, capacity, or builder behavior needs to be obvious.

This topic pairs naturally with [target-typed-new.md](./target-typed-new.md) and [params-collections-csharp-13.md](./params-collections-csharp-13.md).

## Code Example

```csharp
using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.CompilerServices;

namespace Demo;

int[] numbers = [1, 2, 3];
List<int> withExtra = [..numbers, 4, 5];
ReadOnlySpan<int> window = [10, 20, 30];
TagList tags = ["csharp", "dotnet", "interview"];

Console.WriteLine(string.Join(", ", withExtra));
Console.WriteLine(window[1]);
Console.WriteLine(tags);

[CollectionBuilder(typeof(TagListBuilder), nameof(TagListBuilder.Create))]
public sealed class TagList : IEnumerable<string>
{
    private readonly string[] _items;

    public TagList(string[] items)
    {
        _items = items;
    }

    public IEnumerator<string> GetEnumerator() => ((IEnumerable<string>)_items).GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
    public override string ToString() => string.Join(" | ", _items);
}

public static class TagListBuilder
{
    public static TagList Create(ReadOnlySpan<string> items)
        => new(items.ToArray()); // Builder decides how the custom collection is created.
}
```

## Common Follow-up Questions

- Why does `var values = [1, 2, 3];` fail while `int[] values = [1, 2, 3];` works?
- How are collection expressions different from classic collection initializers that call `Add`?
- What runtime behavior changes when the target type is an array versus `List<T>` versus `ReadOnlySpan<T>`?
- How does `CollectionBuilderAttribute` enable custom target types?
- When should you avoid collection expressions even though the syntax is shorter?

## Common Mistakes / Pitfalls

- Forgetting that collection expressions are target-typed and therefore do not work with plain `var`.
- Assuming the same expression always produces the same allocation or mutability characteristics.
- Using spread with expensive enumerables without thinking about materialization cost.
- Confusing collection expressions with list patterns because both use bracket-like syntax.
- Hiding important construction details when an explicit constructor would communicate intent better.

## References

- [Collection expressions (Collection literals) - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/collection-expressions)
- [CollectionBuilderAttribute Class](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.collectionbuilderattribute)
- [See: target-typed-new.md](./target-typed-new.md)
- [See: list-patterns.md](./list-patterns.md)
- [See: params-collections-csharp-13.md](./params-collections-csharp-13.md)
