# Local Functions vs Lambdas

**Category:** C# / Misc Language Mechanics
**Difficulty:** Middle
**Tags:** `local-functions`, `lambdas`, `closures`, `allocations`, `recursion`

## Question

> What is the difference between local functions and lambdas in C#, and when should you prefer one over the other?

Also asked as:
- "Why are local functions often better for recursion or iterator helpers?"
- "Do local functions allocate less than lambdas?"
- "What does `static` on a local function buy you in modern C#?"

## Short Answer

Lambdas are great when you need a delegate value, especially for APIs like LINQ, events, or callbacks. Local functions are often better for named helper logic inside a method, especially when you want recursion, `yield return`, generic parameters, or tighter control over captures and allocations. In .NET 8/9 code, `static` local functions are especially useful because they make accidental closure capture impossible.

## Detailed Explanation

### The main conceptual difference

A lambda expression creates delegate-like behavior for passing code around. A local function declares a real nested method inside another method.

| Capability | Local function | Lambda |
|---|---|---|
| Has a name | Yes | Usually anonymous |
| Good for passing as delegate | Yes, via method group conversion | Yes, primary use case |
| Recursion | Straightforward | Awkward self-reference |
| `yield return` | Yes | No |
| `static` form to forbid captures | Yes | Yes, but still delegate-oriented |
| Generic parameters | Yes | No direct generic lambda syntax |

### Recursion and helper logic

Recursive logic is much cleaner with local functions because the function already has a stable name in scope. A recursive lambda usually needs a delegate variable declared first and then assigned later.

That is a common interview point: local functions often express intent better when the logic is an implementation detail of one outer method.

### Allocations, closures, and `static` local functions

Both lambdas and local functions can capture outer variables, and captured state can require a closure object. But a local function that does not capture anything and is not converted to a delegate can often avoid extra allocation entirely.

`static` local functions make this safer by forbidding capture at compile time.

> **Tip:** If an internal helper does not need outer variables, make it a `static` local function. That turns accidental capture into a compiler error instead of a hidden allocation.

### Features lambdas do not cover well

Lambdas cannot use `yield return`, which means iterator helpers inside a method must be local functions. Local functions are also easier for recursive parsing, validation pipelines, or multi-branch internal helpers.

This topic builds directly on [lambda-expressions-and-closures.md](./lambda-expressions-and-closures.md), while also connecting to [yield-return-explained.md](./yield-return-explained.md).

## Code Example

```csharp
using System;
using System.Collections.Generic;

Console.WriteLine(Factorial(5));

Func<int, int>? fibonacci = null;
fibonacci = n => n <= 1 ? n : fibonacci(n - 1) + fibonacci(n - 2); // Recursive lambda needs self-reference plumbing.
Console.WriteLine(fibonacci(6));

Console.WriteLine(string.Join(", ", FilterPositive([3, -1, 5, 0]))); // Collection expression feeds the helper.
Console.WriteLine(string.Join(", ", EnumerateSquares(4)));

static int Factorial(int n)
{
    return MultiplyDown(n);

    static int MultiplyDown(int value) // Static local function cannot capture outer locals.
        => value <= 1 ? 1 : value * MultiplyDown(value - 1);
}

static IEnumerable<int> FilterPositive(int[] numbers)
{
    int threshold = 0;

    bool IsPositive(int value) => value > threshold; // Local function can capture like a lambda.
    return Array.FindAll(numbers, IsPositive);
}

static IEnumerable<int> EnumerateSquares(int count)
{
    return Iterator();

    IEnumerable<int> Iterator()
    {
        for (int i = 0; i < count; i++)
        {
            yield return i * i; // Lambdas cannot contain yield return.
        }
    }
}
```

## Common Follow-up Questions

- Why is recursion usually cleaner with a local function than with a lambda?
- When can a local function avoid allocation more easily than a lambda?
- What compile-time protection does `static` on a local function provide?
- Why can't lambdas use `yield return`?
- When is a lambda still the better choice than a local function?

## Common Mistakes / Pitfalls

- Using a lambda for complex internal helper logic that would read better as a named local function.
- Forgetting that both lambdas and local functions can allocate when they capture state.
- Missing the chance to use `static` local functions to prevent accidental captures.
- Forcing recursive lambdas when a local function would be simpler and clearer.
- Assuming lambdas and local functions are interchangeable in iterator scenarios.

## References

- [Local functions - C# Programming Guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/local-functions)
- [Lambda expressions - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/operators/lambda-expressions)
- [See: lambda-expressions-and-closures.md](./lambda-expressions-and-closures.md)
- [See: yield-return-explained.md](./yield-return-explained.md)
- [See: collection-expressions.md](./collection-expressions.md)
