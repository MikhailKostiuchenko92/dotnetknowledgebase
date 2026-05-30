# Custom Iterators

**Category:** C# / Iteration
**Difficulty:** Middle
**Tags:** `iterators`, `ienumerable`, `yield`, `performance`

## Question
> How do you implement a custom iterator in C#, and when should you use `yield return` versus a manual enumerator?
>
> What is the difference between implementing `IEnumerable<T>` yourself and letting the compiler generate the iterator machinery?
>
> When do struct enumerators and pattern-based `GetEnumerator` matter for performance?

## Short Answer
For most custom sequences, `yield return` is the easiest and clearest choice. Manual iterator implementations are useful when you need exact control over allocations, state, or performance characteristics, especially when exposing a custom `GetEnumerator` that returns a struct enumerator to avoid heap allocations in hot paths.

## Detailed Explanation
### `yield return` vs manual implementation
Both approaches expose a sequence, but they optimize for different things.

| Approach | Strengths | Trade-offs |
| --- | --- | --- |
| `yield return` | Minimal code, readable, compiler-generated state machine | Usually allocates an iterator object; less explicit control |
| Manual `IEnumerable<T>` / `IEnumerator<T>` | Full control over state, reuse, pooling, custom behavior | More code and easier to get wrong |
| Pattern-based `GetEnumerator` returning a struct | Can avoid interface boxing and heap allocations in `foreach` | More advanced; generic consumers may still box via interfaces |

For application code, `yield return` is usually enough. Manual iterators are mainly a library and performance-oriented technique.

> Tip: start with `yield return`, measure, and only move to a manual or struct enumerator if profiling shows enumeration overhead actually matters.

See [Yield Return Explained](./yield-return-explained.md) and [Enumerator vs Enumerable](./enumerator-vs-enumerable.md).

### The `GetEnumerator` pattern
`foreach` does not require `IEnumerable<T>` specifically. It looks for a compatible `GetEnumerator` pattern:
- `GetEnumerator()` method
- Enumerator with `MoveNext()` and `Current`
- Optional `Dispose()`

That is why `Span<T>` can participate in `foreach` efficiently without implementing the classic interfaces. A custom collection can do the same and return a struct enumerator.

### Zero-allocation considerations
A struct enumerator can eliminate an allocation when `foreach` binds directly to the pattern-based enumerator. However, if the value is cast to `IEnumerable<T>` or `IEnumerator<T>`, boxing may still happen.

> Warning: hand-written enumerators are easy to break. Common bugs include incorrect `Current` behavior, invalid initial position handling, and failing to reset or dispose state consistently.

## Code Example
```csharp
using System;
using System.Collections;
using System.Collections.Generic;

var numbers = new NumberWindow(3, 6);

foreach (var value in numbers)
{
    Console.WriteLine(value); // Uses the struct enumerator directly.
}

sealed class SquaresWithYield
{
    public IEnumerable<int> GetValues(int count)
    {
        for (var i = 0; i < count; i++)
        {
            yield return i * i; // Easiest custom iterator form.
        }
    }
}

readonly struct NumberWindow
{
    private readonly int _start;
    private readonly int _count;

    public NumberWindow(int start, int count)
    {
        _start = start;
        _count = count;
    }

    public Enumerator GetEnumerator() => new(_start, _count);

    public struct Enumerator
    {
        private readonly int _endExclusive;
        private int _current;
        private bool _started;

        public Enumerator(int start, int count)
        {
            _current = start - 1; // foreach expects to call MoveNext first.
            _endExclusive = start + count;
            _started = false;
        }

        public int Current => _current;

        public bool MoveNext()
        {
            if (!_started)
            {
                _started = true;
            }

            if (_current + 1 >= _endExclusive)
            {
                return false;
            }

            _current++;
            return true;
        }
    }
}
```

## Common Follow-up Questions
- When is `yield return` good enough, and when should I write a manual enumerator?
- How does the `GetEnumerator` pattern differ from implementing `IEnumerable<T>`?
- Why can a struct enumerator reduce allocations in `foreach`?
- When does boxing still happen even if the enumerator is a struct?
- Why is writing a correct manual enumerator harder than it looks?

## Common Mistakes / Pitfalls
- Replacing clear `yield return` code with a manual iterator before measuring performance.
- Assuming a struct enumerator is always allocation-free, even after interface casts.
- Forgetting that `foreach` expects the enumerator to start before the first element.
- Implementing `Current` or `MoveNext` with invalid state transitions.
- Exposing a pattern-based enumerator but forgetting compatibility with generic consumers that expect `IEnumerable<T>`.

## References
- [Microsoft Docs: IEnumerable<T>](https://learn.microsoft.com/dotnet/api/system.collections.generic.ienumerable-1)
- [Microsoft Docs: IEnumerator<T>](https://learn.microsoft.com/dotnet/api/system.collections.generic.ienumerator-1)
- [Microsoft Docs: The `yield` statement](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/yield)
- [See: `yield return` Explained](./yield-return-explained.md)
- [See: Enumerator vs Enumerable](./enumerator-vs-enumerable.md)
