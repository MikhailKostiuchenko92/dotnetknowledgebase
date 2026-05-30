# Decorator in DI

**Category:** OOP & Design / Structural Patterns
**Difficulty:** 🔴 Senior
**Tags:** `decorator`, `DI`, `Scrutor`, `open-generic`

## Question
> How do you implement the Decorator pattern in a .NET DI container, what does Scrutor’s `Decorate` do, and what pitfalls should you watch for with open-generic decoration?

## Short Answer
Decorating in DI means registering a core service and then wrapping it with one or more services that implement the same interface. Scrutor’s `Decorate` API rewrites the service registration so the container resolves a chain of wrappers around the original implementation. It is powerful for logging, validation, caching, and metrics, but open-generic decoration introduces ordering, lifetime, and generic-constraint pitfalls.

## Detailed Explanation
### What decorating in DI means
In a dependency injection container, a decorator is not created manually by calling `new LoggingService(new CoreService())`. Instead, the container builds that chain for you. The caller still requests the original interface, but receives the outermost decorator, which internally calls the next layer, and so on until the core implementation is reached.

This is especially useful for cross-cutting concerns because the composition is centralized in registration code instead of scattered across constructors.

### How Scrutor’s `Decorate` works
Scrutor extends `IServiceCollection` with methods such as `Decorate<TService, TDecorator>()` and open-generic overloads. Conceptually, it takes the current registration for `TService`, stores it as the “inner” service, and replaces the registration with a factory that constructs the decorator, injecting the stored inner instance.

| Benefit | Why it matters |
| --- | --- |
| Centralized composition | Behavior is added in one place during registration |
| Same interface outwardly | Callers remain unaware of wrappers |
| Easy layering | Logging, validation, caching, metrics can be stacked |
| Works with open generics | Useful for handlers, repositories, validators |

This style is common with abstractions such as `ICommandHandler<T>`, `IQueryHandler<TQuery, TResult>`, and repositories.

### Open-generic decoration
Open-generic decoration means applying a decorator to all closed versions of a generic service. For example, you can decorate every `ICommandHandler<TCommand>` with `LoggingCommandHandler<TCommand>`. That is elegant because one registration covers many handler types.

However, it also raises more design pressure. The decorator must be valid for every closed generic type that may be resolved. If some handlers have additional constraints or rely on specific behavior, the “one decorator fits all” assumption can break.

> Warning: open-generic decorators are easy to over-apply. A logging decorator may be fine for all handlers, but a transaction decorator or validation decorator may only make sense for some of them.

### Common pitfalls
The first pitfall is ordering. If you decorate with validation, then logging, then metrics, the observed behavior differs from metrics, then validation, then logging. Registration order becomes runtime behavior.

The second pitfall is lifetime mismatch. A singleton decorator wrapping a scoped inner service is a classic DI bug. The decorator’s lifetime must be compatible with the wrapped service.

The third pitfall is generic constraints and accidental over-decoration. A decorator on `IRepository<>` may catch read-only repositories, cached repositories, and adapters you did not intend to wrap. Be deliberate about the service type you decorate.

### When to use it and when not to
Use DI decoration when behavior is truly cross-cutting and transparent from the caller’s perspective. It keeps the core implementation focused and works well in layered applications.

Do not use decoration for behavior that changes the business meaning of the interface, or when the container configuration becomes harder to understand than explicit composition. In small systems, a manual wrapper may be clearer.

## Code Example
```csharp
using Microsoft.Extensions.DependencyInjection;
using Scrutor;

namespace OopDesignSamples;

// Requires packages: Microsoft.Extensions.DependencyInjection and Scrutor.
public interface ICommandHandler<in TCommand>
{
    Task HandleAsync(TCommand command);
}

public sealed record CreateInvoice(string Customer, decimal Amount);

public sealed class DefaultCommandHandler<TCommand> : ICommandHandler<TCommand>
{
    public Task HandleAsync(TCommand command)
    {
        Console.WriteLine($"Handled {typeof(TCommand).Name}: {command}");
        return Task.CompletedTask;
    }
}

public sealed class LoggingCommandHandler<TCommand>(ICommandHandler<TCommand> inner) : ICommandHandler<TCommand>
{
    public async Task HandleAsync(TCommand command)
    {
        Console.WriteLine($"[LOG] Starting {typeof(TCommand).Name}");
        await inner.HandleAsync(command); // Delegate to the wrapped handler.
        Console.WriteLine($"[LOG] Finished {typeof(TCommand).Name}");
    }
}

public sealed class MetricsCommandHandler<TCommand>(ICommandHandler<TCommand> inner) : ICommandHandler<TCommand>
{
    public async Task HandleAsync(TCommand command)
    {
        var started = DateTime.UtcNow;
        await inner.HandleAsync(command);
        Console.WriteLine($"[METRICS] Took {(DateTime.UtcNow - started).TotalMilliseconds:N0} ms");
    }
}

public static class Program
{
    public static async Task Main()
    {
        var services = new ServiceCollection();

        services.AddSingleton(typeof(ICommandHandler<>), typeof(DefaultCommandHandler<>));
        services.Decorate(typeof(ICommandHandler<>), typeof(LoggingCommandHandler<>));
        services.Decorate(typeof(ICommandHandler<>), typeof(MetricsCommandHandler<>));

        using var provider = services.BuildServiceProvider();
        var handler = provider.GetRequiredService<ICommandHandler<CreateInvoice>>();

        await handler.HandleAsync(new CreateInvoice("Contoso", 125m));
    }
}
```

## Common Follow-up Questions
- How does Scrutor implement `Decorate` under the hood?
- What happens if decorator lifetimes do not match inner service lifetimes?
- How do you control the order of multiple decorators?
- When should you use middleware or MediatR pipeline behaviors instead of DI decorators?
- What special risks exist when decorating open-generic services?

## Common Mistakes / Pitfalls
- Registering decorators in the wrong order and getting unexpected runtime behavior.
- Decorating a broader open-generic service type than intended.
- Creating lifetime mismatches, such as singleton decorators over scoped services.
- Assuming every open-generic service can safely share the same decorator.
- Hiding too much logic in registration code so the final object graph becomes opaque.

## References
- [Decorator](https://refactoring.guru/design-patterns/decorator)
- [Scrutor](https://github.com/khellang/Scrutor)
- [Dependency injection in .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection/overview)
- [Scrutor on NuGet](https://www.nuget.org/packages/Scrutor)
