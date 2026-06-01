# Generic Patterns in .NET Design

**Category:** OOP & Design / Generics & Type-Level Patterns
**Difficulty:** 🟡 Middle
**Tags:** `generics`, `repository`, `CRTP`, `DI`

## Question
> What are some useful generic design patterns in .NET, such as a generic repository, a generic result type, open-generic DI registration, and the CRTP pattern?

## Short Answer
Generic patterns help you move reusable design ideas from one concrete type to many types without losing compile-time safety. In .NET, common examples include `Result<T>` for success/failure flows, open-generic service registrations, and base classes that use CRTP for fluent APIs. The catch is that generic patterns are powerful only when the abstraction is real—otherwise they become leaky or overengineered.

## Detailed Explanation
### What these patterns try to solve
Generic patterns are useful when the same structure repeats across many types. Instead of hand-writing a repository for every entity or a result wrapper for every use case, you define the pattern once and supply the varying type as a type argument.

That can dramatically reduce duplication, but it also raises the bar for design quality. A generic abstraction should capture a stable, meaningful concept. If it only hides differences you still need later, it becomes a leaky wrapper.

| Pattern | Example | Best use | Main risk |
|---|---|---|---|
| Generic repository | `IRepository<T>` | Simple CRUD abstractions over many aggregates | Hiding important data-access details |
| Generic result | `Result<T>` | Returning value + error without exceptions for expected failures | Turning every flow into manual branching |
| Open-generic DI | `IValidator<T>` | Registering one rule for many closed types | Hard-to-trace registrations |
| CRTP | `Builder<TSelf>` | Fluent base APIs returning the concrete subtype | Confusing type signatures |

### Generic repository and generic result
A generic repository usually exposes operations like `GetByIdAsync`, `AddAsync`, or `Remove`. It can work well when your domain genuinely needs a small common data-access surface. However, over EF Core it is often criticized because `DbContext` already behaves like a repository/unit of work, and a too-generic repository may hide useful concepts such as includes, projections, specifications, or batching.

A generic `Result<T>` or `OperationResult<T>` is often more valuable. It captures a successful value or a failure reason in one type, making expected business failures explicit. For example, `Result<Order>` is clearer than returning `null` or throwing exceptions for validation problems.

> Warning: A generic repository is not automatically good design. If every query still needs custom methods, specifications, or IQueryable escape hatches, the abstraction may be too generic to help.

### Open-generic registration and CRTP
Open-generic DI registration means registering a type definition such as `IValidator<>` to `DefaultValidator<>`. The container then closes it at resolution time for `IValidator<CreateOrder>` or `IValidator<CancelOrder>`. This is a natural fit for validators, repositories, pipeline behaviors, mappers, and handlers.

CRTP, or Curiously Recurring Template Pattern, looks like `abstract class Builder<TSelf> where TSelf : Builder<TSelf>`. The derived type passes itself as the generic argument. That lets the base class return the concrete subtype from fluent methods without runtime casts. In C#, CRTP is most common in fluent builders, copy methods, and strongly typed base APIs.

### Why these patterns matter and when not to use them
The main benefit is reuse with strong typing. Generic patterns help teams build consistent APIs and reduce boilerplate. They also pair well with the CLR’s reified generics, because closed types such as `Result<Customer>` or `IRepository<Order>` remain visible to DI, reflection, and tooling.

The trade-off is abstraction cost. If your generic pattern is too broad, every edge case leaks through. If your type signatures become difficult to read, the pattern may save lines of code while making the system harder to reason about.

Use these patterns when the repeated shape is stable and shared across many types. Avoid them when each concrete type has different behavior, different invariants, or different performance requirements that the generic layer would only obscure.

## Code Example
```csharp
using System;
using System.Collections.Concurrent;
using Microsoft.Extensions.DependencyInjection;

namespace InterviewExamples;

public readonly record struct Result<T>(bool IsSuccess, T? Value, string? Error)
{
    public static Result<T> Success(T value) => new(true, value, null);
    public static Result<T> Failure(string error) => new(false, default, error);
}

public interface IRepository<T>
{
    Result<T> Add(T item);
}

public sealed class InMemoryRepository<T> : IRepository<T>
{
    private readonly ConcurrentBag<T> _items = [];

    public Result<T> Add(T item)
    {
        _items.Add(item);
        return Result<T>.Success(item);
    }
}

public abstract class Builder<TSelf> where TSelf : Builder<TSelf>
{
    protected string Name { get; private set; } = "Unnamed";

    public TSelf WithName(string name)
    {
        Name = name;
        return (TSelf)this; // CRTP keeps the fluent API strongly typed.
    }
}

public sealed class UserBuilder : Builder<UserBuilder>
{
    public User Build() => new(Name);
}

public sealed record User(string Name);

internal static class Program
{
    private static void Main()
    {
        var services = new ServiceCollection();

        // One open-generic registration handles IRepository<User>, IRepository<Order>, etc.
        services.AddSingleton(typeof(IRepository<>), typeof(InMemoryRepository<>));

        using var provider = services.BuildServiceProvider();

        var repository = provider.GetRequiredService<IRepository<User>>();
        var user = new UserBuilder().WithName("Mila").Build();
        var result = repository.Add(user);

        Console.WriteLine(result.IsSuccess ? result.Value : result.Error);
    }
}
```

## Common Follow-up Questions
- Why is a generic repository often controversial with EF Core?
- When is `Result<T>` better than throwing an exception?
- How does CRTP improve fluent APIs in C#?
- Which kinds of services are a good fit for open-generic DI registration?
- How do you know a generic abstraction is too broad?

## Common Mistakes / Pitfalls
- Building a generic repository that immediately leaks `IQueryable`, includes, and provider-specific concerns.
- Returning `Result<T>` for every possible case, including exceptional failures that should still use exceptions.
- Using CRTP without clear naming, making the inheritance chain hard to understand.
- Creating generic base types only to avoid a little duplication, even when the domain concepts differ.
- Hiding important dependencies behind overly generic service names like `IManager<T>`.

## References
- [Generic types and methods - C# | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/types/generics)
- [Dependency injection - .NET | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection)
- [Inversion of Control Containers and the Dependency Injection pattern - Martin Fowler](https://martinfowler.com/articles/injection.html)
- [Curiously Recurring Template Pattern in C# - Zp Bappi](https://zpbappi.com/curiously-recurring-template-pattern-in-csharp/)
