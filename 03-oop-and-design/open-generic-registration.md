# Open-Generic Registration in .NET DI

**Category:** OOP & Design / Generics & Type-Level Patterns
**Difficulty:** 🔴 Senior
**Tags:** `open-generic`, `DI`, `registration`, `decorator`

## Question
> What is open-generic registration in .NET dependency injection, how does `typeof(IRepository<>)` work, and how do decorators fit into open-generic registrations?

## Short Answer
Open-generic registration means registering a generic type definition such as `IRepository<>` to an implementation like `Repository<>` once, instead of registering every closed pair individually. When the container later needs `IRepository<Order>`, it closes the generic using `Order` and builds that service. This is powerful for validators, repositories, mappers, and pipeline behaviors, but you have to think carefully about lifetimes, constraints, and decorator ordering.

## Detailed Explanation
### What open-generic registration means
An open generic type still has unassigned type parameters. `typeof(IRepository<>)` is not “repository of something specific”; it is the generic type definition itself. In DI, that matters because the container can store the open mapping and later construct closed versions on demand.

So instead of writing one registration for `IRepository<Customer>`, another for `IRepository<Order>`, and so on, you register the open pair once. When resolution happens, the container closes the type using the requested type argument and creates the correct implementation.

| Registration style | Example | When to use |
|---|---|---|
| Closed generic | `IRepository<Order> -> OrderRepository` | Special-case implementation for one type |
| Open generic | `IRepository<> -> Repository<>` | Same pattern applies to many types |
| Open generic + decorator | `IRepository<> -> LoggingRepository<> -> CachingRepository<> -> Repository<>` | Shared cross-cutting behavior around many services |

### How the container resolves open generics
The built-in container stores the registration against the generic type definition. When a request comes in for `IRepository<Customer>`, it checks whether there is an open registration for `IRepository<>`. If there is, it creates the closed implementation `Repository<Customer>` and resolves that object graph as usual.

This works particularly well for patterns that scale with a type argument: `IValidator<T>`, `IOptions<T>`, pipeline behaviors, repositories, and notification handlers. It also works well with constraints, because the closed generic still has to be valid for the requested type argument.

> Warning: Open-generic registration does not remove lifetime rules. A singleton `Repository<T>` still cannot safely capture a scoped dependency such as `DbContext`, no matter how elegant the registration looks.

### Decorator chaining on open generics
A decorator wraps another service implementing the same interface. With open generics, that means a single decorator registration can apply logging, caching, retries, metrics, or authorization to every `IRepository<T>` or every `ICommandHandler<TCommand, TResult>`.

The built-in Microsoft DI container supports open-generic registration directly, but it does not have first-class decorator APIs. Libraries such as Scrutor are commonly used to add `Decorate(typeof(IRepository<>), typeof(LoggingRepository<>))`, then chain more decorators in the desired order.

Decorator order matters. Logging outside caching tells a different story from logging inside caching. Metrics around retries measure something different from metrics inside retries. In senior-level design discussions, understanding order and lifetime interactions matters more than simply knowing the syntax.

### Trade-offs and when not to use it
Open generics reduce repetitive registrations and keep cross-cutting composition consistent. They also make generic architectures practical.

The trade-off is indirection. When everything is generic and decorated, tracing one resolved service becomes harder. Use open-generic registration when behavior is truly uniform across many type arguments. Avoid it when certain types need meaningfully different implementations or when the generic abstraction hides important domain semantics.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using Microsoft.Extensions.DependencyInjection;

namespace InterviewExamples;

public interface IRepository<T>
{
    void Add(T item);
    IReadOnlyList<T> GetAll();
}

public sealed class InMemoryRepository<T> : IRepository<T>
{
    private readonly List<T> _items = [];

    public void Add(T item) => _items.Add(item);
    public IReadOnlyList<T> GetAll() => _items;
}

public sealed class LoggingRepositoryDecorator<T>(IRepository<T> inner) : IRepository<T>
{
    public void Add(T item)
    {
        Console.WriteLine($"[log] adding {typeof(T).Name}");
        inner.Add(item);
    }

    public IReadOnlyList<T> GetAll() => inner.GetAll();
}

public sealed class MetricsRepositoryDecorator<T>(IRepository<T> inner) : IRepository<T>
{
    public void Add(T item)
    {
        var started = DateTime.UtcNow;
        inner.Add(item);
        Console.WriteLine($"[metrics] {(DateTime.UtcNow - started).TotalMilliseconds:N2} ms");
    }

    public IReadOnlyList<T> GetAll() => inner.GetAll();
}

public sealed record Customer(string Name);
public sealed record Order(int Id);

internal static class Program
{
    private static void Main()
    {
        var services = new ServiceCollection();

        services.AddSingleton(typeof(IRepository<>), typeof(InMemoryRepository<>)); // Open-generic registration.

        using var provider = services.BuildServiceProvider();

        var customerRepository = provider.GetRequiredService<IRepository<Customer>>();
        var orderRepository = provider.GetRequiredService<IRepository<Order>>();

        IRepository<Order> decoratedOrderRepository = new MetricsRepositoryDecorator<Order>(
            new LoggingRepositoryDecorator<Order>(orderRepository));

        customerRepository.Add(new Customer("Mila"));
        decoratedOrderRepository.Add(new Order(42));

        Console.WriteLine(customerRepository.GetAll()[0].Name);
        Console.WriteLine(decoratedOrderRepository.GetAll()[0].Id);

        // Scrutor can apply the same decorator chain open-generically to every IRepository<T>.
    }
}
```

## Common Follow-up Questions
- What is the difference between an open generic and a closed generic type?
- Why are validators and pipeline behaviors good candidates for open-generic registration?
- How do lifetime mismatches show up in open-generic registrations?
- Why does the built-in container often need a library like Scrutor for decorators?
- How does decorator order affect behavior and observability?

## Common Mistakes / Pitfalls
- Assuming open-generic registration solves lifetime problems automatically.
- Registering a generic abstraction that is too broad and hides important domain differences.
- Forgetting that some closed types may need special-case implementations instead of the generic default.
- Chaining decorators without deciding the correct order for logging, caching, retries, or transactions.
- Making DI graphs so generic and dynamic that debugging service resolution becomes painful.

## References
- [Dependency injection - .NET | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection)
- [Dependency injection guidelines - .NET | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection-guidelines)
- [Generics in .NET - .NET | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/generics/)
- [Scrutor](https://github.com/khellang/Scrutor)
- [Inversion of Control Containers and the Dependency Injection pattern - Martin Fowler](https://martinfowler.com/articles/injection.html)
