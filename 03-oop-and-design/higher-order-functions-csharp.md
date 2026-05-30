# Higher-Order Functions in C#

**Category:** OOP & Design / Functional Patterns
**Difficulty:** 🔴 Senior
**Tags:** `higher-order-functions`, `currying`, `partial-application`, `delegates`, `functional`

## Question
> What are higher-order functions in C#, and how do delegates, lambdas, currying, and partial application enable functional-style design?

## Short Answer
A higher-order function is a function that takes another function as an argument, returns a function, or both. In C#, delegates such as `Func<>` and `Action<>` make behavior first-class enough to support strategies, callbacks, pipelines, currying, and partial application. They are great for concise reusable behavior, but if overused they can hide intent and make debugging harder than an explicit object-oriented design.

## Detailed Explanation
### What “higher-order” means in C#
C# is not a pure functional language, but it has strong support for higher-order programming through delegates, lambdas, local functions, and method groups. The concept is simple: if a method accepts a function, returns a function, or both, it is higher-order.

| Form | Example | Why it matters |
| --- | --- | --- |
| Takes a function | `Where(predicate)` | Injects behavior from outside |
| Returns a function | `CreateFormatter(prefix)` | Builds reusable specialized behavior |
| Does both | `Compose(f, g)` | Enables pipelines and reuse |

This matters because behavior becomes data. Instead of hard-coding one algorithm, you can pass the behavior that should be used at runtime. That is why higher-order functions appear throughout LINQ, async APIs, retry libraries, middleware, and validation pipelines.

### Strategy via delegates
A practical OOP connection is that delegates can act as a lightweight Strategy pattern. If the behavior is small and stateless, a `Func<decimal, decimal>` is often simpler than creating an interface plus one class per variation. That reduces ceremony and makes call sites more flexible.

However, delegates are not a universal replacement for objects. If the strategy has state, multiple related operations, lifecycle concerns, or domain significance, a named type is usually clearer than a raw `Func<>`. The senior answer is not “always use delegates”; it is “use delegates when behavior is small, composable, and does not need object identity.”

> Warning: closures capture outer variables, not just values. If the captured variable changes later, the delegate may observe the changed value and produce surprising bugs.

### Currying and partial application
These terms are related but not identical:
- **Currying** transforms a multi-argument function into a chain of one-argument functions.
- **Partial application** fixes some arguments now and returns a new function that needs the rest later.

For example, a tax calculator `(rate, amount) => ...` can be partially applied with a VAT rate to produce a reusable amount-only function. That is handy when you want configurable behavior without creating another object just to hold one parameter.

### Composition and trade-offs
Higher-order functions also enable composition. A normalizer, validator, and formatter can be combined into one reusable pipeline. This often leads to APIs that are compact and expressive.

The trade-offs are readability and tooling friction. Deeply nested `Func<>` signatures are harder to read than named interfaces. Stack traces can be less descriptive. Allocations from closures and delegate creation may matter in extremely hot paths. In most business systems those costs are fine, but senior engineers should at least know they exist.

A strong interview answer is that higher-order functions let C# treat behavior as a value. That enables flexible composition, lightweight strategy injection, currying, and partial application, while still requiring judgment about when explicit object models communicate intent better.

## Code Example
```csharp
using System;

namespace InterviewKnowledgeBase.OopAndDesign;

internal static class Program
{
    private static void Main()
    {
        Func<decimal, decimal, decimal> applyTax = (rate, amount) => amount * (1 + rate);

        Func<decimal, decimal> applyVat = Functional.Partial(applyTax, 0.20m); // Fix the first argument.
        Console.WriteLine(applyVat(100m));

        Func<int, Func<int, int>> add = Functional.Curry((x, y) => x + y);
        Console.WriteLine(add(10)(5));

        decimal finalPrice = Pricing.Calculate(100m, amount => amount * 0.9m); // Delegate-based strategy.
        Console.WriteLine(finalPrice);
    }
}

internal static class Functional
{
    public static Func<T2, TResult> Partial<T1, T2, TResult>(Func<T1, T2, TResult> func, T1 arg1)
        => arg2 => func(arg1, arg2);

    public static Func<T1, Func<T2, TResult>> Curry<T1, T2, TResult>(Func<T1, T2, TResult> func)
        => arg1 => arg2 => func(arg1, arg2);
}

internal static class Pricing
{
    public static decimal Calculate(decimal amount, Func<decimal, decimal> strategy)
        => strategy(amount);
}
```

## Common Follow-up Questions
- What is the difference between currying and partial application?
- When is a delegate-based strategy better than an interface-based strategy?
- What are closures, and why do they sometimes cause bugs?
- How does LINQ demonstrate higher-order functions in everyday C#?
- What are the performance costs of heavy delegate usage?

## Common Mistakes / Pitfalls
- Confusing currying with partial application as if they were the same technique.
- Capturing mutable outer state in lambdas and getting unpredictable behavior later.
- Replacing meaningful domain abstractions with anonymous delegates just to reduce boilerplate.
- Building APIs around nested `Func<>` types that are harder to understand than named interfaces.
- Ignoring delegate and closure allocations in hot paths without profiling.

## References
- [Work with delegate types in C#](https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/delegates/)
- [Lambda expressions - C# reference](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/lambda-expressions)
- [Func<T,TResult> Delegate](https://learn.microsoft.com/en-us/dotnet/api/system.func-2)
- [Enumerable.Where Method](https://learn.microsoft.com/en-us/dotnet/api/system.linq.enumerable.where)
