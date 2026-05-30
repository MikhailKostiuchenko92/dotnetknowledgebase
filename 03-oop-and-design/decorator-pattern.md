# Decorator Pattern

**Category:** OOP & Design / Structural Patterns
**Difficulty:** 🟡 Middle
**Tags:** `decorator`, `structural`, `Scrutor`, `OCP`

## Question
> What is the Decorator pattern, how is it different from inheritance, and how is it commonly used in .NET with DI, Scrutor, or the ASP.NET Core pipeline?

## Short Answer
The Decorator pattern adds behavior to an object by wrapping another object that implements the same interface. Unlike inheritance, it composes behavior at runtime, which fits the Open/Closed Principle because you can extend behavior without modifying the original class. In .NET, decorators are common for logging, caching, retries, validation, and pipeline-style composition through DI or middleware.

## Detailed Explanation
### What Decorator does
Decorator is a structural pattern where a wrapper object implements the same contract as the wrapped object and forwards calls to it, optionally adding behavior before or after the call. The key idea is that clients still depend on the same interface, so the extra behavior is transparent to callers.

In real .NET code, decorators are often used around services such as `ICommandHandler<T>`, `INotificationService`, or repository abstractions. Typical cross-cutting concerns include logging, metrics, caching, retry policies, transactions, and authorization checks.

### Decorator vs inheritance
Inheritance extends behavior by creating a subclass. That can work, but it is rigid because behavior is fixed at compile time and combinations tend to explode. If you need logging, caching, retry, and authorization in different combinations, subclassing quickly becomes unmanageable.

| Approach | How behavior is added | Strengths | Weaknesses |
| --- | --- | --- | --- |
| Inheritance | Subclass overrides or extends base methods | Simple for small hierarchies | Rigid, deep hierarchies, class explosion |
| Decorator | Wrapper composes another implementation of the same interface | Runtime composition, flexible combinations, OCP-friendly | More objects and ordering complexity |

Decorator is usually the better choice for cross-cutting concerns because it keeps the core implementation focused and lets you compose only what you need.

### Why it fits the Open/Closed Principle
The Open/Closed Principle says software entities should be open for extension but closed for modification. Decorators support this well: instead of editing `EmailNotifier` every time you need logging or retries, you keep the core service unchanged and layer extra behavior around it.

This is especially valuable in teams. Different concerns can be added independently, tested separately, and reordered when needed.

### How it shows up in .NET
The ASP.NET Core middleware pipeline is decorator-like thinking in practice. Each middleware wraps the next delegate, adding behavior before and after calling it. The same mental model appears when using Scrutor’s `Decorate` API with `IServiceCollection`.

For example, you might register `INotifier` and then decorate it with a logging decorator and a retry decorator. The final object resolved by DI is a chain of wrappers.

> Warning: decorator order matters. Logging outside retry gives different behavior from logging inside retry, and caching before authorization may create security bugs.

### Trade-offs and when not to use it
Decorator improves flexibility, but it also adds indirection. Debugging can be harder because the actual call path goes through multiple wrappers. Too many decorators can also hide the main business flow.

Do not use Decorator when a simple helper method or a single well-named service would be clearer. Also, if the added behavior changes the contract itself rather than extending behavior transparently, you may need a different pattern.

## Code Example
```csharp
namespace OopDesignSamples;

public interface INotifier
{
    Task SendAsync(string message);
}

public sealed class EmailNotifier : INotifier
{
    public Task SendAsync(string message)
    {
        Console.WriteLine($"Email sent: {message}");
        return Task.CompletedTask;
    }
}

public abstract class NotifierDecorator(INotifier inner) : INotifier
{
    protected INotifier Inner { get; } = inner;

    public virtual Task SendAsync(string message) => Inner.SendAsync(message);
}

public sealed class LoggingNotifier(INotifier inner) : NotifierDecorator(inner)
{
    public override async Task SendAsync(string message)
    {
        Console.WriteLine($"[LOG] About to send: {message}");
        await Inner.SendAsync(message);
        Console.WriteLine("[LOG] Send completed");
    }
}

public sealed class RetryNotifier(INotifier inner) : NotifierDecorator(inner)
{
    public override async Task SendAsync(string message)
    {
        for (var attempt = 1; attempt <= 3; attempt++)
        {
            try
            {
                await Inner.SendAsync(message); // Delegate to the wrapped service.
                return;
            }
            catch when (attempt < 3)
            {
                Console.WriteLine($"Retrying attempt {attempt + 1}");
            }
        }
    }
}

public static class Program
{
    public static async Task Main()
    {
        INotifier notifier = new RetryNotifier(new LoggingNotifier(new EmailNotifier()));
        await notifier.SendAsync("Interview at 10:00");
    }
}
```

## Common Follow-up Questions
- How is Decorator different from Proxy and Middleware?
- Why is Decorator usually a better fit than inheritance for cross-cutting concerns?
- How would you register decorators with Scrutor in ASP.NET Core?
- What problems can happen if decorators are applied in the wrong order?
- When would you prefer middleware, MediatR behaviors, or Polly over a decorator?

## Common Mistakes / Pitfalls
- Making the decorator expose new members so it no longer stays substitutable for the original interface.
- Forgetting that the order of decorators changes runtime behavior.
- Mixing core domain logic into decorators that should only handle cross-cutting concerns.
- Creating too many tiny decorators, making the object graph hard to trace.
- Using inheritance and decorators together in a way that duplicates responsibility.

## References
- [Decorator](https://refactoring.guru/design-patterns/decorator)
- [Scrutor](https://github.com/khellang/Scrutor)
- [Dependency injection in .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection/overview)
- [ASP.NET Core Middleware](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/?view=aspnetcore-9.0)
