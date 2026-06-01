# Scrutor — Decorator Pattern and Assembly Scanning

**Category:** ASP.NET Core / Dependency Injection
**Difficulty:** 🔴 Senior
**Tags:** `Scrutor`, `decorator`, `assembly-scanning`, `DI`, `open-generic-decoration`

## Question

> What is Scrutor, how does its `Decorate` method implement the Decorator pattern via DI, and how does `Scan` simplify large service registration?

## Short Answer

Scrutor is a NuGet library that extends `IServiceCollection` with two main features: `Scan` — which auto-registers services by scanning assemblies and applying naming/interface conventions — and `Decorate` — which wraps an existing registration with a decorator class without requiring the consumer to change. Both work with open generics. Scrutor is especially useful in large codebases where manual `AddScoped<IFoo, FooImpl>()` calls become unmaintainable.

## Detailed Explanation

### The Decorator pattern recap

The Decorator pattern wraps an object with another that has the same interface, adding behavior transparently:

```
IOrderRepository
  └── CachingOrderRepository (decorator)
        └── EfOrderRepository (real implementation)
```

Without Scrutor, wiring this up in DI requires manual three-step registration:

```csharp
services.AddScoped<EfOrderRepository>();  // register concrete
services.AddScoped<IOrderRepository>(sp => // register decorator, inject concrete
    new CachingOrderRepository(sp.GetRequiredService<EfOrderRepository>(), ...));
```

This breaks Open/Closed principle for the DI setup and leaks `EfOrderRepository` as a resolvable type.

### `Decorate<TInterface, TDecorator>()`

```csharp
// Step 1: register the real implementation
services.AddScoped<IOrderRepository, EfOrderRepository>();

// Step 2: wrap it with a decorator — Scrutor handles the wiring
services.Decorate<IOrderRepository, CachingOrderRepository>();
```

Scrutor internally:
1. Takes the existing `IOrderRepository` registration.
2. Re-registers `EfOrderRepository` as itself (inner service).
3. Registers `CachingOrderRepository` as `IOrderRepository`, injecting the inner `EfOrderRepository`.

The decorator receives the inner implementation via its constructor:

```csharp
public sealed class CachingOrderRepository(
    IOrderRepository inner,    // ← Scrutor injects the original implementation here
    IMemoryCache cache) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(int id, CancellationToken ct)
    {
        return await cache.GetOrCreateAsync($"order:{id}", async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5);
            return await inner.GetByIdAsync(id, ct);
        });
    }
}
```

### Open-generic decoration

```csharp
services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
services.Decorate(typeof(IRepository<>), typeof(LoggingRepository<>));
// All IRepository<T> now use LoggingRepository<T> wrapping EfRepository<T>
```

### Multiple decorators (stacked)

```csharp
services.AddScoped<IOrderRepository, EfOrderRepository>();
services.Decorate<IOrderRepository, LoggingOrderRepository>();   // outer
services.Decorate<IOrderRepository, CachingOrderRepository>();   // outermost

// Resolution order: Caching → Logging → EfOrderRepository
```

### `Scan` — assembly scanning

```csharp
services.Scan(scan => scan
    .FromAssemblyOf<Program>()                    // scan this assembly
    .AddClasses(classes => classes                // filter classes
        .AssignableTo<IRepository>()
        .NotInNamespace("MyApp.Tests"))
    .AsImplementedInterfaces()                    // register as all interfaces they implement
    .WithScopedLifetime());                       // Scoped lifetime
```

Common conventions:
| `AsX` method | Registers as |
|---|---|
| `AsImplementedInterfaces()` | All non-generic interfaces the class implements |
| `AsSelf()` | The concrete class itself |
| `As<T>()` | A specific interface/base type |
| `AsMatchingInterface()` | Interface with same name (e.g., `IFoo` for `Foo`) |

### Combining Scan + Decorate

```csharp
// Auto-register all repositories, then wrap all in caching decorator
services.Scan(scan => scan
    .FromAssemblyOf<Program>()
    .AddClasses(c => c.AssignableTo(typeof(IRepository<>)))
    .AsImplementedInterfaces()
    .WithScopedLifetime());

services.Decorate(typeof(IRepository<>), typeof(CachingRepository<>));
```

## Code Example

```csharp
// IOrderRepository.cs
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(int id, CancellationToken ct = default);
    Task SaveAsync(Order order, CancellationToken ct = default);
}

// EfOrderRepository.cs (real implementation)
public sealed class EfOrderRepository(AppDbContext db) : IOrderRepository
{
    public Task<Order?> GetByIdAsync(int id, CancellationToken ct)
        => db.Orders.FindAsync([id], ct).AsTask();

    public async Task SaveAsync(Order order, CancellationToken ct)
    {
        db.Orders.Update(order);
        await db.SaveChangesAsync(ct);
    }
}

// LoggingOrderRepository.cs (decorator)
public sealed class LoggingOrderRepository(
    IOrderRepository inner,
    ILogger<LoggingOrderRepository> logger) : IOrderRepository
{
    public async Task<Order?> GetByIdAsync(int id, CancellationToken ct)
    {
        logger.LogDebug("Getting order {Id}", id);
        var result = await inner.GetByIdAsync(id, ct);
        logger.LogDebug("Got order {Id}: {Found}", id, result is not null);
        return result;
    }

    public async Task SaveAsync(Order order, CancellationToken ct)
    {
        logger.LogDebug("Saving order {Id}", order.Id);
        await inner.SaveAsync(order, ct);
        logger.LogDebug("Saved order {Id}", order.Id);
    }
}
```

```csharp
// Program.cs
// Using Scrutor assembly scanning
builder.Services.Scan(scan => scan
    .FromAssemblyOf<Program>()
    .AddClasses(classes => classes
        .AssignableTo<IOrderRepository>()
        .Where(t => !t.Name.StartsWith("Logging"))) // exclude decorators from auto-scan
    .AsImplementedInterfaces()
    .WithScopedLifetime());

// Wrap all IOrderRepository implementations with logging
builder.Services.Decorate<IOrderRepository, LoggingOrderRepository>();
```

```csharp
// Alternative: explicit registration + Scrutor Decorate
builder.Services.AddScoped<IOrderRepository, EfOrderRepository>();
builder.Services.Decorate<IOrderRepository, LoggingOrderRepository>();

// Verify: IOrderRepository resolves to LoggingOrderRepository wrapping EfOrderRepository
```

## Common Follow-up Questions

- How does Scrutor's `Decorate` work under the hood — how does it rewire the existing registration?
- Can you apply the same decorator type multiple times (stacking)?
- How do you test a class that depends on a Scrutor-decorated service?
- What is the difference between `AsImplementedInterfaces()` and `AsMatchingInterface()` in `Scan`?
- How do you handle the case where a decorator should only be applied conditionally (e.g., only in Production)?

## Common Mistakes / Pitfalls

- **Decorating before the base registration exists** — Scrutor's `Decorate` expects the service to already be registered; calling it before `AddScoped` throws.
- **Including decorator classes in `Scan` auto-registration** — if `LoggingOrderRepository` is included in the scan and registered as `IOrderRepository`, it breaks the decoration chain. Use `Where` to exclude decorator types.
- **Stacking decorators in the wrong order** — decorators are applied outermost-last; the last `Decorate` call becomes the outermost wrapper.
- **Open-generic decoration with unconstrained generics** — if the decorator's type parameter has constraints that the registered generic doesn't satisfy for some types, resolution throws at runtime.
- **Using `Scan` in tests without filtering test assemblies** — scanning the whole solution can pick up test-only implementations and pollute the test DI container.

## References

- [Scrutor GitHub — khellang/Scrutor](https://github.com/khellang/Scrutor)
- [Andrew Lock — Using Scrutor for decorator pattern](https://andrewlock.net/using-scrutor-to-automatically-register-your-services-with-the-asp-net-core-di-container/) (verify URL)
- [Microsoft — Decorator pattern in DI](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection-guidelines)
- [Mark Seemann — Decorator pattern](https://blog.ploeh.dk/2010/04/07/DependencyInjectionisLooseCoupling/) (verify URL)
