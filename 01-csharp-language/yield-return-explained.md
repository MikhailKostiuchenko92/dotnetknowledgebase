# `yield return` Explained

**Category:** C# / Iteration
**Difficulty:** Middle
**Tags:** `yield`, `iterators`, `deferred-execution`, `state-machine`

## Question
> What does `yield return` do in C#, and how does it work under the hood?
>
> Why are iterator methods deferred, and what rules apply inside an iterator block?
>
> How does the compiler transform a method that uses `yield return` or `yield break`?

## Short Answer
`yield return` turns a method into an iterator block. Instead of producing the whole sequence immediately, the compiler generates a hidden state machine that resumes execution each time the caller asks for the next element, which is why iterator methods are naturally deferred.

## Detailed Explanation
### What `yield return` changes
A normal method runs top to bottom and returns once. An iterator block pauses and resumes.

| Normal method | Iterator method with `yield return` |
| --- | --- |
| Executes completely before returning | Produces values one at a time |
| Returns a final result | Returns an enumerable/enumerator object |
| Local variables disappear after return | Local state is lifted into a compiler-generated state machine |
| Work is immediate | Work is deferred until enumeration starts |

When you write `yield return item;`, the compiler emits machinery roughly equivalent to a class that stores the current state, current value, and lifted locals.

> Tip: if a sequence is expensive or potentially large, `yield return` is often the simplest way to stream results instead of materializing a list first.

See also [Custom Iterators](./custom-iterators.md), [Enumerator vs Enumerable](./enumerator-vs-enumerable.md), and [Deferred vs Immediate Execution](./deferred-vs-immediate-execution.md).

### Deferred execution and state machines
The body of an iterator method does not execute when the method is called. It starts when enumeration begins, typically through `foreach`.

That has several consequences:
- Exceptions inside the iterator often occur during enumeration, not method call
- Multiple enumerations rerun the iterator from the beginning
- External mutable state can change between method creation and consumption
- Resources must be handled carefully because execution is spread over time

The compiler-generated state machine implements the enumeration protocol and remembers where execution should resume after each `yield return`.

### Iterator block rules and limitations
Common rules:
- The method must return `IEnumerable`, `IEnumerable<T>`, `IEnumerator`, or `IEnumerator<T>`
- You can use `yield return` to produce a value and `yield break` to stop early
- `return value;` is not allowed inside an iterator block
- `yield return` cannot appear in `catch` or `finally` blocks
- `using` works because it becomes a `try/finally` without yielding from the `finally`

In modern C#, iterator support keeps improving. For example, C# 13 relaxes some interactions with `unsafe` code, but the core state-machine model is unchanged.

> Warning: because execution is deferred, debugging iterator bugs can feel surprising. A method may look harmless at call time yet throw only later when the sequence is actually consumed.

## Code Example
```csharp
using System;
using System.Collections.Generic;

foreach (var number in CountEvenNumbers(1, 10))
{
    Console.WriteLine(number);
}

static IEnumerable<int> CountEvenNumbers(int start, int end)
{
    Console.WriteLine("Iterator started"); // Runs only when enumeration begins.

    for (var value = start; value <= end; value++)
    {
        if (value % 2 != 0)
        {
            continue;
        }

        yield return value; // Compiler stores state here and resumes later.
    }

    Console.WriteLine("Iterator finished");
}
```

## Common Follow-up Questions
- Why does an iterator method usually not execute at the call site?
- What hidden type does the compiler generate for an iterator block?
- When should I use `yield return` instead of building a `List<T>`?
- Why can exceptions from iterators appear later than expected?
- What is the difference between `yield return` and `yield break`?

## Common Mistakes / Pitfalls
- Assuming the iterator body runs immediately when the method is called.
- Forgetting that multiple enumerations rerun the iterator logic.
- Capturing mutable external state and being surprised when later values differ.
- Trying to `return someValue;` from an iterator block.
- Yielding from places where the language disallows it, such as `catch` or `finally` blocks.

## References
- [Microsoft Docs: The `yield` statement](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/yield)
- [Microsoft Docs: IEnumerable<T>](https://learn.microsoft.com/dotnet/api/system.collections.generic.ienumerable-1)
- [See: Custom Iterators](./custom-iterators.md)
- [See: Iterator vs Async Iterator](./iterator-vs-async-iterator.md)
- [See: Deferred vs Immediate Execution](./deferred-vs-immediate-execution.md)
