# Iterator Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🟡 Middle
**Tags:** `iterator`, `behavioral`, `IEnumerable`, `yield`, `lazy-evaluation`

## Question
> How does the Iterator pattern appear in .NET through `IEnumerable<T>`, `IEnumerator<T>`, and `yield return`?

## Short Answer
Iterator provides a standard way to traverse a collection without exposing its internal structure. In .NET, `IEnumerable<T>` and `IEnumerator<T>` are the core iterator abstractions, and `yield return` lets the compiler generate the iterator state machine for you. This enables lazy evaluation, streaming, and custom traversal logic with minimal boilerplate.

## Detailed Explanation
### What it is
Iterator separates **how to traverse** from **what is being traversed**. A caller can walk through items one by one without caring whether the source is an array, tree, linked list, database-backed stream, or generated sequence.

That abstraction is everywhere in .NET. `foreach` works because the collection exposes an enumerator. LINQ composes over that same model.

### How it works internally
The classic iterator contract in .NET is:

- `IEnumerable<T>` – “I can produce an enumerator.”
- `IEnumerator<T>` – “I can move through items one at a time.”

`foreach` roughly translates to obtaining an enumerator, calling `MoveNext()`, reading `Current`, and disposing the enumerator when done.

When you use `yield return`, the compiler generates the enumerator implementation for you. It transforms the method into a state machine that remembers where execution paused between iterations. That is why code that looks linear can produce one item at a time.

| Technique | Benefit | Trade-off |
| --- | --- | --- |
| Manual enumerator | Full control | Verbose, error-prone |
| `yield return` | Simple, readable | Less explicit control |
| Materialized list | Reusable, predictable | Higher memory cost |

### Why lazy evaluation matters
An iterator often produces values only when requested. That is lazy evaluation. Instead of building the entire result up front, the sequence can stream data item by item. This reduces memory usage and can improve responsiveness for large or infinite sequences.

However, laziness changes behavior. If the source changes between enumerations, repeated iteration may produce different results. Expensive work may also repeat on every enumeration unless you materialize with `ToList()` or `ToArray()`.

> `IEnumerable<T>` does not mean “cheap collection.” It only means “enumerable sequence.” The underlying work may be deferred, expensive, or stateful.

### When to use custom iterators
Custom iterators are useful when you need domain-specific traversal, such as tree walks, graph traversals, pagination, filtering, or generated sequences like Fibonacci numbers. They keep traversal logic out of callers and make APIs more composable with LINQ.

Avoid exposing internal mutable collections directly just because they are enumerable. You may still want to return a read-only projection or snapshot depending on lifetime and mutation concerns.

### Trade-offs and common interview angle
In interviews, it is good to mention that Iterator is both a design pattern and a language/runtime feature in .NET. The pattern gives a common traversal abstraction; the language (`foreach`, `yield return`) makes it practical.

Also mention the internal state machine generated for `yield return`, and the common pitfalls around multiple enumeration, deferred exceptions, and hidden performance costs.

## Code Example
```csharp
using System;
using System.Collections.Generic;

namespace OopAndDesign.IteratorPattern;

public sealed class FibonacciSequence(int count) : IEnumerable<int>
{
    public IEnumerator<int> GetEnumerator()
    {
        var previous = 0;
        var current = 1;

        for (var index = 0; index < count; index++)
        {
            yield return previous; // Compiler turns this into an iterator state machine.
            (previous, current) = (current, previous + current);
        }
    }

    System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator() => GetEnumerator();
}

public static class Program
{
    public static void Main()
    {
        var sequence = new FibonacciSequence(7);

        foreach (var value in sequence)
        {
            Console.WriteLine(value);
        }
    }
}
```

## Common Follow-up Questions
- What does the compiler generate for `yield return`?
- How does `foreach` work under the hood?
- What problems can lazy evaluation cause?
- When would you call `ToList()` to materialize a sequence?
- What is the difference between `IEnumerable<T>` and `IQueryable<T>`?
- How would you write a custom tree iterator?

## Common Mistakes / Pitfalls
- Enumerating the same deferred sequence multiple times and repeating expensive work.
- Assuming `IEnumerable<T>` always represents an in-memory collection.
- Modifying a collection while iterating it and hitting invalid enumeration behavior.
- Throwing exceptions deep inside deferred execution and being surprised they occur later.

## References
- [Iterator pattern - Refactoring.Guru](https://refactoring.guru/design-patterns/iterator)
- [The `yield` statement - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/yield)
- [IEnumerable<T> Interface](https://learn.microsoft.com/dotnet/api/system.collections.generic.ienumerable-1)
- [foreach statement - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/iteration-statements)
