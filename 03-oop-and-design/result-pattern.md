# Result Pattern

**Category:** OOP & Design / Functional Patterns
**Difficulty:** 🟡 Middle
**Tags:** `result-pattern`, `railway-oriented`, `error-handling`, `FluentResults`

## Question
> What is the Result pattern, and when would you return `Result<T>` instead of throwing exceptions in C#?

## Short Answer
The Result pattern represents success or failure as a normal return value, usually with either a value or an error. It works well when failure is expected business flow, like validation or missing data, because callers must handle the outcome explicitly. Exceptions are still appropriate for truly exceptional situations such as infrastructure failures or broken invariants.

## Detailed Explanation
### What the Result pattern is
A `Result<T>` type usually models two outcomes:
- **Success** with a value of `T`
- **Failure** with one or more errors

That makes failure explicit in the method signature. Instead of guessing whether a method can throw or return `null`, the caller sees that success and failure are both first-class outcomes.

This style is often linked to **railway-oriented programming**: each step in a workflow continues on the success track or switches to the failure track. Once a step fails, later steps are skipped unless you explicitly recover.

| Approach | How failure is represented | Best fit |
| --- | --- | --- |
| Exception | Thrown control flow | Unexpected or exceptional failures |
| `null` | Missing value with weak intent | Simple legacy APIs, but error-prone |
| `Result<T>` | Explicit success/failure value | Validation, business rules, workflows |

### Why teams use it
The biggest benefit is clarity. A method like `CreateOrder(...)` returning `Result<Order>` tells you failure is expected and must be handled. That often leads to cleaner application services, especially in command handlers, validation pipelines, and domain workflows.

It also reduces exception-driven control flow. Exceptions are relatively expensive, produce noisier traces, and are easy to forget to handle consistently. For expected outcomes like “email is invalid” or “customer already exists,” a result type is often a better fit.

### Result versus exceptions
This is where interview nuance matters. The Result pattern is **not** a replacement for every exception. If the database is down, a network timeout occurs, or an invariant is broken in a way that should never happen, throwing is still reasonable.

A practical rule is:
- Use **Result** for expected failures the caller can recover from.
- Use **exceptions** for unexpected failures that indicate something abnormal or unrecoverable at that level.

> Warning: returning `Result<T>` from every method can turn code into noisy plumbing. Apply it where failure is part of the normal domain flow, not for every private helper.

### Railway-style composition
Result types become more powerful when combined with `Map`, `Bind`, or `Then` methods. `Map` transforms a successful value. `Bind` chains another operation that itself returns a result. That allows workflows like “parse input -> validate business rule -> save entity” without nested `if` statements.

In C#, libraries like **FluentResults** provide this infrastructure so you do not have to reinvent it. But the concept matters more than the specific package: model failure explicitly and compose it predictably.

### Trade-offs
The downsides are extra types, more generic plumbing, and possible overuse. Some developers also find Result-heavy code less idiomatic if the codebase already relies heavily on exceptions. That is why consistency matters: use the pattern deliberately, especially at application or domain boundaries.

A balanced interview answer is that `Result<T>` improves explicitness and makes expected failures safer to compose, while exceptions remain the right tool for exceptional conditions.

## Code Example
```csharp
using System;

namespace OopAndDesign.FunctionalPatterns;

public static class Program
{
    public static void Main()
    {
        Result<string> emailResult = Registration.ValidateEmail("candidate@example.com");
        Result<User> userResult = emailResult.Bind(Registration.CreateUser);

        Console.WriteLine(userResult.IsSuccess
            ? $"Created user: {userResult.Value!.Email}"
            : $"Failed: {userResult.Error}");
    }
}

public sealed record User(string Email);

public sealed record Result<T>(bool IsSuccess, T? Value, string? Error)
{
    public static Result<T> Success(T value) => new(true, value, null);
    public static Result<T> Failure(string error) => new(false, default, error);

    public Result<TNext> Bind<TNext>(Func<T, Result<TNext>> next)
        => IsSuccess ? next(Value!) : Result<TNext>.Failure(Error!);
}

public static class Registration
{
    public static Result<string> ValidateEmail(string email)
    {
        if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
        {
            return Result<string>.Failure("Email format is invalid.");
        }

        return Result<string>.Success(email);
    }

    public static Result<User> CreateUser(string email)
        => Result<User>.Success(new User(email));
}
```

## Common Follow-up Questions
- When is an exception still the better choice than `Result<T>`?
- What is the difference between `Map` and `Bind` on a result type?
- How would you return multiple validation errors in a result object?
- Where in a layered architecture would you introduce the Result pattern?
- What are the pros and cons of using a library like FluentResults instead of a custom result type?

## Common Mistakes / Pitfalls
- Replacing all exceptions with results, including infrastructure failures that should still throw.
- Returning both a result object and throwing exceptions from the same method for the same expected failure mode.
- Creating weak result types with only `bool Success` and no structured error information.
- Overusing the pattern in trivial private methods, which adds ceremony without much value.
- Forgetting to propagate or log unexpected exceptions at system boundaries.

## References
- [Best practices for exceptions](https://learn.microsoft.com/en-us/dotnet/standard/exceptions/best-practices-for-exceptions)
- [Exception handling statements](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/statements/exception-handling-statements)
- [FluentResults](https://github.com/altmann/FluentResults)
- [Railway Oriented Programming](https://fsharpforfunandprofit.com/posts/recipe-part2/)
