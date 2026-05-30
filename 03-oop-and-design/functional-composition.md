# Functional Composition

**Category:** OOP & Design / Functional Patterns
**Difficulty:** 🟡 Middle
**Tags:** `functional-composition`, `LINQ`, `pipeline`, `monad`

## Question
> What is functional composition in C#, and how do method chaining, LINQ, and helper functions let you build pipelines of behavior?

## Short Answer
Functional composition means building larger behavior by connecting small functions so the output of one becomes the input of the next. In C#, the most familiar example is a LINQ pipeline such as `Where(...).Select(...).OrderBy(...)`, but the same idea appears in `Pipe`, `Compose`, `Map`, and `Bind` helpers. It improves reuse and readability when each step is focused, although over-abstracted pipelines can become harder to debug than simple imperative code.

## Detailed Explanation
### What composition means in practice
Composition is the opposite of putting every step into one large method. Instead of parsing, validating, transforming, and formatting in one block, you create small operations with clear inputs and outputs, then connect them. That style is functional in spirit, but it works very naturally in modern C# because delegates, lambdas, extension methods, and LINQ all support it.

| Style | Typical shape | Main trade-off |
| --- | --- | --- |
| Imperative block | One method with many steps | Easy to start, harder to reuse |
| Chained composition | Small functions in sequence | Cleaner flow, more indirection |
| Monadic composition | Wrapped values with `Map`/`Bind` | Great for failure/null flows, more abstraction |

The design benefit is that each step becomes independently testable and reusable. A sanitizer can be reused in an API, a batch import, and a background job without duplicating logic.

### LINQ is the most common form of composition in C#
Most developers already use functional composition daily through LINQ. A query like `customers.Where(...).Select(...).OrderBy(...)` is a pipeline: each operator takes a sequence and returns a new sequence abstraction for the next operator. That is why LINQ feels declarative. You describe the flow of data rather than writing loops, counters, and temporary variables yourself.

Internally, LINQ often relies on higher-order functions and deferred execution. The operators store the transformation logic and apply it only when the sequence is enumerated. That is powerful, but it also means timing matters: a query may run later than you think, and it may run more than once if you enumerate it repeatedly.

> Warning: deferred execution is a feature, not a free optimization. If the underlying data changes or the pipeline is enumerated multiple times, results and performance can surprise you.

### Compose, Pipe, and monad-like patterns
Outside LINQ, teams often use small helpers such as `Compose` and `Pipe`. `Compose(f, g)` creates a new function that runs `f` and then `g`. `Pipe(value, f)` makes data flow left-to-right, which some people find easier to read.

Monad-like patterns appear when the value is wrapped in another type, such as `Result<T>`, `Option<T>`, or `Task<T>`. In those cases:
- `Map` transforms the inner success value.
- `Bind` chains another operation that also returns the wrapped type.

That avoids repeated “unwrap, check, rewrap” code. The concept sounds academic, but in day-to-day C# it simply means you can build workflows that handle absence, failure, or asynchrony in a consistent pipeline.

### When composition helps and when it does not
Composition shines for transformations, validation chains, parsing flows, sequence processing, and stateless business rules. It is less useful when the logic is very stateful, highly imperative, or dominated by side effects like I/O. In those cases, a straightforward method may be easier to understand.

The interview-safe conclusion is: composition is about building behavior from small, focused pieces. LINQ is the most common example, `Compose` and `Pipe` make the pattern explicit, and monad-like wrappers extend the same idea to failure-aware or async workflows.

## Code Example
```csharp
using System;
using System.Linq;

namespace InterviewKnowledgeBase.OopAndDesign;

internal static class Program
{
    private static void Main()
    {
        string[] rawNames = ["  alice ", "BOB", "", "charlie  "];

        string[] normalized = rawNames
            .Where(name => !string.IsNullOrWhiteSpace(name))
            .Select(Text.Normalize)     // Each LINQ step is part of the pipeline.
            .Select(Text.ToDisplayName)
            .ToArray();

        Console.WriteLine(string.Join(", ", normalized));

        Func<string, string> greeting = Functional.Compose(Text.Normalize, Text.AddGreeting);
        Console.WriteLine(greeting("  mIkHaIl "));

        Result<string> email = Result.Success(" person@example.com ")
            .Map(Text.Normalize)
            .Bind(Validators.RequireAtSign);

        Console.WriteLine(email);
    }
}

internal static class Functional
{
    public static Func<TIn, TOut> Compose<TIn, TMiddle, TOut>(Func<TIn, TMiddle> first, Func<TMiddle, TOut> second)
        => input => second(first(input));
}

internal static class Text
{
    public static string Normalize(string value) => value.Trim().ToLowerInvariant();
    public static string ToDisplayName(string value) => char.ToUpperInvariant(value[0]) + value[1..];
    public static string AddGreeting(string value) => $"Hello, {value}!";
}

internal static class Validators
{
    public static Result<string> RequireAtSign(string value)
        => value.Contains('@') ? Result.Success(value) : Result.Failure<string>("Missing @ symbol.");
}

internal readonly record struct Result<T>(bool IsSuccess, T? Value, string? Error)
{
    public Result<TNext> Map<TNext>(Func<T, TNext> mapper)
        => IsSuccess ? Result.Success(mapper(Value!)) : Result.Failure<TNext>(Error!);

    public Result<TNext> Bind<TNext>(Func<T, Result<TNext>> binder)
        => IsSuccess ? binder(Value!) : Result.Failure<TNext>(Error!);

    public override string ToString() => IsSuccess ? $"Success: {Value}" : $"Failure: {Error}";
}

internal static class Result
{
    public static Result<T> Success<T>(T value) => new(true, value, null);
    public static Result<T> Failure<T>(string error) => new(false, default, error);
}
```

## Common Follow-up Questions
- How is LINQ an example of functional composition?
- What is the difference between `Map` and `Bind`?
- Why can deferred execution make a pipeline behave unexpectedly?
- When is composition less readable than imperative code?
- How do `Task<T>` and async workflows fit into compositional design?

## Common Mistakes / Pitfalls
- Inventing too many custom helpers so simple rules look academic and hard to maintain.
- Forgetting that LINQ often executes later, not where the pipeline is declared.
- Mixing heavy side effects into a chain that should stay mostly transformational.
- Re-enumerating an expensive sequence because the pipeline result was never materialized.
- Treating every method chain as good composition even when the steps are tightly coupled and unclear.

## References
- [Projection operations](https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/projection-operations)
- [Deferred execution and lazy evaluation](https://learn.microsoft.com/en-us/dotnet/standard/linq/deferred-execution-lazy-evaluation)
- [Lambda expressions - C# reference](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/lambda-expressions)
- [Enumerable Class](https://learn.microsoft.com/en-us/dotnet/api/system.linq.enumerable)
