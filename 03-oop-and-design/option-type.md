# Option Type

**Category:** OOP & Design / Functional Patterns
**Difficulty:** 🟡 Middle
**Tags:** `option-type`, `maybe`, `nullable-reference-types`, `null-safety`

## Question
> What is an `Option<T>` or `Maybe<T>` type, and how is it different from nullable reference types in C#?

## Short Answer
An `Option<T>` represents “a value exists” or “no value exists” as an explicit type instead of using `null`. That makes absence part of the API contract and encourages callers to handle both cases through matching or combinators like `Map` and `Bind`. Nullable reference types help the compiler warn about possible null misuse, but they do not replace the modeling benefits of an option type.

## Detailed Explanation
### What an Option type models
`Option<T>` (also called `Maybe<T>`) is a container with two states:
- **Some**: there is a value
- **None**: there is no value

The key idea is that “missing” is not represented by a magic `null`, but by an explicit type. That improves readability because the method signature tells callers that absence is normal and expected.

For example, `Option<User> FindById(...)` communicates intent better than `User? FindById(...)` when you want consumers to actively handle both branches.

### Option type versus nullable reference types
Nullable reference types (NRT) in C# 8+ add compiler analysis. They help detect dangerous null flows and make APIs more honest by distinguishing `string` from `string?`. That is valuable, but it solves a different problem.

| Concern | Nullable reference types | `Option<T>` |
| --- | --- | --- |
| Main purpose | Static warnings and annotations | Explicit domain modeling |
| Runtime representation | Usually still `null` | Usually `Some` / `None` wrapper |
| Caller behavior | Compiler-guided | API-enforced handling patterns |
| Good for | General null-safety | Modeling optional values intentionally |

NRT says, “this might be null.” `Option<T>` says, “absence is a deliberate and expected outcome.” They can coexist.

### Why teams use Option
Option types reduce defensive `if (x == null)` checks scattered through the codebase. Instead, you handle the optional value once via `Match`, `Map`, `Bind`, or `GetValueOrDefault`. That often leads to cleaner pipelines and fewer `NullReferenceException`s.

They are especially useful when:
- a lookup may or may not return a value,
- absence is not an error,
- and you want to avoid ambiguous `null` semantics.

> Warning: if your team is not familiar with functional patterns, introducing `Option<T>` everywhere can hurt readability more than it helps. Use it where the domain meaning is clear.

### Trade-offs and practical guidance
The main trade-off is ergonomics. C# does not have a built-in Option type like F# does, so you either create your own or use libraries such as language-ext. That adds types, method chains, and learning overhead.

Also, not every nullable value needs an Option wrapper. For simple DTOs or framework integration points, normal nullable annotations may be enough. The pattern is most valuable where optionality is part of core domain behavior and you want to force deliberate handling.

### Interview-ready distinction
A strong interview answer is: nullable reference types improve compile-time null-safety, while Option improves domain modeling and composition. NRT reduces mistakes; Option makes absence explicit and easier to transform without repeated null checks.

## Code Example
```csharp
using System;
using System.Collections.Generic;

namespace OopAndDesign.FunctionalPatterns;

public static class Program
{
    public static void Main()
    {
        Option<User> found = UserRepository.FindByEmail("candidate@example.com");
        string message = found.Match(
            some => $"Found user: {some.Email}",
            () => "User was not found.");

        Console.WriteLine(message);
    }
}

public sealed record User(string Email);

public readonly record struct Option<T>(T? Value, bool HasValue)
{
    public static Option<T> Some(T value) => new(value, true);
    public static Option<T> None() => new(default, false);

    public TResult Match<TResult>(Func<T, TResult> some, Func<TResult> none)
        => HasValue ? some(Value!) : none();
}

public static class UserRepository
{
    private static readonly Dictionary<string, User> Users = new()
    {
        ["candidate@example.com"] = new User("candidate@example.com")
    };

    public static Option<User> FindByEmail(string email)
        => Users.TryGetValue(email, out User? user)
            ? Option<User>.Some(user)
            : Option<User>.None();
}
```

## Common Follow-up Questions
- When is `T?` enough, and when is `Option<T>` worth the extra type?
- How do `Map` and `Bind` work for an option type?
- Would you use `Option<T>` in public API contracts or only internally?
- How does Option help avoid `NullReferenceException`?
- What libraries provide Maybe/Option support in .NET?

## Common Mistakes / Pitfalls
- Thinking nullable reference types and Option types are interchangeable.
- Wrapping everything in `Option<T>` even when the value is required by design.
- Exposing both `Option<T>` and `null` from the same API, which creates confusion.
- Calling `.Value`-style accessors without matching first, defeating the safety benefit.
- Using Option for failure cases that actually need a Result type with error details.

## References
- [Nullable reference types](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/null-safety/nullable-reference-types)
- [Null-coalescing operators `??` and `??=`](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/null-coalescing-operator)
- [language-ext](https://github.com/louthy/language-ext)
- [Functional C#: Handling failures, input errors](https://enterprisecraftsmanship.com/posts/functional-c-handling-failures-input-errors/)
