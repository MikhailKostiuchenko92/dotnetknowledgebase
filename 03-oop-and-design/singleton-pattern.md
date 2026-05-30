# Singleton Pattern

**Category:** OOP & Design / Creational Patterns
**Difficulty:** 🟢 Junior
**Tags:** `singleton`, `creational`, `thread-safety`, `lazy`

## Question
> What is the Singleton pattern in C#, how do you make it thread-safe, and when would you use `Lazy<T>` or a DI container instead?

## Short Answer
Singleton ensures a class has exactly one shared instance and exposes a global access point to it. In C#, the simplest safe version is usually a `static readonly` instance or `Lazy<T>` when initialization should be deferred. It is useful for truly shared, stateless infrastructure, but in modern .NET apps a DI container often replaces manual singletons because it manages lifetime, composition, and testability better.

## Detailed Explanation
### What the pattern is
Singleton is a creational pattern whose goal is to guarantee that only one instance of a type exists within an application process and that every caller gets the same instance. The usual implementation has a private constructor so callers cannot use `new`, plus a static property such as `Instance` that returns the single object.

That solves two problems at once: controlling the number of instances and providing shared access. Typical interview examples include configuration readers, caches, logging facades, or access to a process-wide resource. In real systems, though, many of those responsibilities are better handled by dependency injection rather than by a manually coded global object.

### Thread-safety variants in C#
The main design issue is concurrency. If two threads call `Instance` at the same time, a naive lazy implementation can accidentally create two objects.

| Variant | Lazy? | Thread-safe? | Notes |
| --- | --- | --- | --- |
| `static readonly` field | No | Yes | Eager creation at type initialization time; simplest correct version. |
| `lock` around creation | Yes | Yes | Correct but adds locking logic and complexity. |
| Double-check locking | Yes | Usually, if done correctly | Easy to get wrong and rarely worth hand-writing today. |
| `Lazy<T>` | Yes | Yes by default | Best built-in option for deferred creation. |

In .NET, type initialization for static fields is thread-safe, so `private static readonly MyType _instance = new();` is already safe. If you need deferred creation because the object is expensive or may never be used, `Lazy<T>` gives you lazy initialization with well-defined threading behavior and less room for mistakes.

> Warning: Singleton solves lifetime, not safety of the object itself. Even if instance creation is thread-safe, the singleton's mutable state may still need locks or concurrent collections.

### Why it matters and trade-offs
Singleton can reduce repeated setup cost and centralize access to an expensive shared dependency. It also makes it explicit that the class represents one process-wide concept.

The trade-off is coupling. Client code often reaches for `MySingleton.Instance`, which hides dependencies, makes unit tests harder, and creates global mutable state. It can also blur scope boundaries: something that should be per request or per tenant can accidentally become application-wide.

Another subtle issue is application boundaries. “Single instance” usually means one per AppDomain or one per process, not one per machine or per distributed system. In cloud deployments with multiple app instances, each process gets its own singleton.

### When DI replaces Singleton
A .NET DI container can register a service as a singleton lifetime. That still gives one shared instance per container, but avoids hard-coded global access. Consumers ask for the dependency through constructors, which is easier to test and swap.

Manual singleton is still reasonable for small utilities, low-level framework code, or when you intentionally want a static, process-wide object with no dependency graph. In application code, prefer DI singletons for services such as serializers, stateless calculators, policies, or shared clients configured at startup.

### When not to use it
Do not use Singleton as a default pattern for “things many classes need.” If the main motivation is convenience, it usually becomes a service locator smell. Avoid it for request-specific state, tenant-specific configuration, or highly mutable business logic. In interviews, a strong answer is: Singleton is easy to explain, but in modern .NET I reach for DI-managed singleton lifetime first.

## Code Example
```csharp
using System;
using System.Threading;

namespace KnowledgeBase.OopDesign;

public sealed class AppClock
{
    // Lazy<T> handles thread-safe deferred creation for us.
    private static readonly Lazy<AppClock> _instance = new(() => new AppClock());

    private AppClock()
    {
        CreatedAtUtc = DateTime.UtcNow;
    }

    public static AppClock Instance => _instance.Value;

    public DateTime CreatedAtUtc { get; }

    public DateTime UtcNow() => DateTime.UtcNow;
}

internal static class Program
{
    private static void Main()
    {
        var first = AppClock.Instance;
        var second = AppClock.Instance;

        Console.WriteLine(ReferenceEquals(first, second)); // True
        Console.WriteLine(first.CreatedAtUtc);

        // Multiple threads still get the same instance.
        Parallel.For(0, 3, _ => Console.WriteLine(AppClock.Instance.UtcNow()));
    }
}
```

## Common Follow-up Questions
- What is the difference between eager and lazy singleton initialization?
- Why is double-check locking controversial or easy to implement incorrectly?
- How is a DI container singleton different from a static singleton?
- Is a singleton instance shared across multiple processes or servers?
- How would you unit test code that currently calls `MySingleton.Instance` directly?

## Common Mistakes / Pitfalls
- Assuming thread-safe creation automatically means thread-safe mutable state inside the singleton.
- Using Singleton as a hidden global dependency instead of explicit constructor injection.
- Treating “singleton” as one instance for the whole distributed system rather than one per process/container.
- Writing custom double-check locking when `static readonly` or `Lazy<T>` would be simpler and safer.
- Storing request-specific or tenant-specific data in a singleton service.

## References
- [Singleton](https://refactoring.guru/design-patterns/singleton)
- [Lazy<T> Class](https://learn.microsoft.com/dotnet/api/system.lazy-1)
- [Dependency injection guidelines - .NET](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection-guidelines)
- [Managed Threading Best Practices - .NET](https://learn.microsoft.com/dotnet/standard/threading/managed-threading-best-practices)
