# Enumerator vs Enumerable

**Category:** C# / Iteration
**Difficulty:** Middle
**Tags:** `ienumerable`, `ienumerator`, `foreach`, `collections`

## Question
> What is the difference between `IEnumerable<T>` and `IEnumerator<T>` in C#?
>
> Why is one usually described as the sequence and the other as the cursor?
>
> How should you implement `IEnumerable<T>`, and what should you know about `Reset()` semantics?

## Short Answer
`IEnumerable<T>` represents something that can produce an enumerator, while `IEnumerator<T>` is the active cursor moving through one enumeration. A useful interview summary is: enumerable = factory for traversal, enumerator = current traversal state.

## Detailed Explanation
### Factory vs cursor mental model
These two interfaces are tightly connected but have different responsibilities.

| Abstraction | Role | Typical method/property |
| --- | --- | --- |
| `IEnumerable<T>` | Represents a sequence that can be iterated | `GetEnumerator()` |
| `IEnumerator<T>` | Represents one in-progress iteration over that sequence | `MoveNext()`, `Current` |

Calling `GetEnumerator()` should usually create a fresh traversal. That is why the same enumerable can often be iterated multiple times, but a single enumerator is a one-pass object with mutable state.

> Tip: in interviews, “factory vs cursor” is the fastest accurate explanation and is easy to remember.

See [Custom Iterators](./custom-iterators.md) and [`yield return` Explained](./yield-return-explained.md).

### How `foreach` uses them
`foreach` roughly does this:
1. Ask the enumerable for an enumerator
2. Repeatedly call `MoveNext()`
3. Read `Current`
4. Dispose the enumerator if needed

That explains why `Current` is invalid before the first `MoveNext()` and after enumeration finishes.

### Implementing `IEnumerable<T>` and `Reset()`
A custom collection should usually implement `IEnumerable<T>` and the non-generic `IEnumerable` for compatibility. You may write the enumerator manually or use `yield return`.

`IEnumerator.Reset()` exists on the non-generic interface for historical COM compatibility. In modern .NET code it is rarely used, and many framework enumerators throw `NotSupportedException`.

> Warning: do not design APIs that depend on `Reset()` working. The usual pattern is to ask the enumerable for a new enumerator instead.

## Code Example
```csharp
using System;
using System.Collections;
using System.Collections.Generic;

var collection = new CountdownCollection(3);

foreach (var value in collection)
{
    Console.WriteLine(value);
}

sealed class CountdownCollection : IEnumerable<int>
{
    private readonly int _start;

    public CountdownCollection(int start)
    {
        _start = start;
    }

    public IEnumerator<int> GetEnumerator()
    {
        for (var value = _start; value >= 1; value--)
        {
            yield return value; // Compiler provides the enumerator implementation.
        }
    }

    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
}
```

## Common Follow-up Questions
- Why can the same enumerable usually be iterated more than once?
- Why is an enumerator stateful but an enumerable usually not?
- What does `foreach` expand to conceptually?
- Why is `Reset()` rarely important in modern .NET code?
- When would you return a fresh enumerator versus reusing one?

## Common Mistakes / Pitfalls
- Treating `IEnumerable<T>` and `IEnumerator<T>` as interchangeable.
- Reusing the same enumerator instance for multiple independent traversals.
- Reading `Current` before `MoveNext()` succeeds.
- Depending on `Reset()` instead of creating a new enumerator.
- Forgetting to implement the non-generic `IEnumerable` on public collection types.

## References
- [Microsoft Docs: IEnumerable<T>](https://learn.microsoft.com/dotnet/api/system.collections.generic.ienumerable-1)
- [Microsoft Docs: IEnumerator<T>](https://learn.microsoft.com/dotnet/api/system.collections.generic.ienumerator-1)
- [See: Custom Iterators](./custom-iterators.md)
- [See: `yield return` Explained](./yield-return-explained.md)
- [See: Range and Index Operators](./range-and-index-operators.md)
