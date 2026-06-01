# Pipeline Pattern in .NET

**Category:** OOP & Design / Pipelines & Composition
**Difficulty:** 🟡 Middle
**Tags:** `pipeline`, `middleware`, `chain-of-responsibility`, `MediatR`

## Question
> What is the pipeline pattern in .NET, and how does it relate to ASP.NET Core middleware, `IMiddleware`, and generic pipeline behaviors like in MediatR?

## Short Answer
The pipeline pattern composes a request or command flow from small steps that each receive the current context and a `next()` delegate. ASP.NET Core middleware is the most familiar .NET example: each middleware can run code before and after the next component, or short-circuit the request entirely. The pattern is powerful because it centralizes cross-cutting concerns like logging, validation, transactions, and authorization without burying them in business logic.

## Detailed Explanation
### What the pipeline pattern is
A pipeline is an ordered chain of components that process a request one step at a time. Each step can inspect or modify the request, decide whether processing should continue, and optionally inspect or change the response on the way back out.

Conceptually, it is a practical form of Chain of Responsibility. In .NET, it usually appears as a delegate-based composition model where each component gets access to a `next` function. That is why the pattern feels natural in ASP.NET Core middleware and in libraries such as MediatR.

| Variant | Typical shape | Best use |
|---|---|---|
| Conventional ASP.NET middleware | `Invoke(HttpContext, RequestDelegate next)` | HTTP request processing |
| `IMiddleware` | DI-created middleware class | Middleware needing scoped dependencies or better testability |
| Generic pipeline behavior | `Handle(request, next)` | Cross-cutting concerns around commands/queries/events |

### How it works internally
In ASP.NET Core, the framework builds a request delegate by wrapping one middleware around another. The last component handles the terminal action, and each previous component gets a chance to run before and after it. Because middleware wraps the next step, order matters a lot.

A logging middleware might log the incoming request, call `next()`, and then log the response status. An authentication or rate-limiting middleware might short-circuit and never call `next()` if the request should stop there.

`IMiddleware` is an alternative model where the middleware itself is resolved from DI rather than constructed once by the startup pipeline. That is useful when the middleware has scoped dependencies or state that should not live for the whole app lifetime.

A generic pipeline behavior works the same way, just outside HTTP. In MediatR, behaviors wrap command/query handlers so that validation, retries, metrics, transaction scopes, and exception handling do not have to be repeated in every handler.

> Warning: Pipeline order is part of behavior, not just implementation detail. Putting authorization, exception handling, caching, or transactions in the wrong order can create subtle production bugs.

### Why teams use pipelines
The main advantage is separation of concerns. Business handlers stay focused on business logic while reusable behaviors handle technical concerns around them. Pipelines also improve consistency: every request can be logged or validated in the same way.

Another advantage is composability. New behaviors can often be inserted without changing existing handlers, which keeps code more open for extension than editing each endpoint or handler manually.

### Trade-offs and when not to use it
The downside is hidden control flow. If too many behaviors are stacked, it becomes harder to understand what really happens for one request and in what order. Debugging can also become more difficult because the path is distributed across several components.

Use the pipeline pattern when you have cross-cutting behavior applied to many requests. Avoid it when the logic is highly specific to one handler or when the chain becomes so large that the execution model is opaque. In those cases, a direct method call may be simpler and more maintainable.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace InterviewExamples;

public sealed class HttpLikeContext
{
    public string Path { get; init; } = "/";
    public bool IsAuthenticated { get; init; }
}

public delegate Task RequestDelegate(HttpLikeContext context);

public interface IMiddleware
{
    Task InvokeAsync(HttpLikeContext context, RequestDelegate next);
}

public sealed class LoggingMiddleware : IMiddleware
{
    public async Task InvokeAsync(HttpLikeContext context, RequestDelegate next)
    {
        Console.WriteLine($"Before middleware: {context.Path}");
        await next(context);
        Console.WriteLine($"After middleware: {context.Path}");
    }
}

public sealed class AuthMiddleware : IMiddleware
{
    public Task InvokeAsync(HttpLikeContext context, RequestDelegate next)
    {
        if (!context.IsAuthenticated)
        {
            Console.WriteLine("Short-circuited by auth middleware.");
            return Task.CompletedTask;
        }

        return next(context);
    }
}

public interface IPipelineBehavior<TRequest, TResponse>
{
    Task<TResponse> Handle(TRequest request, Func<Task<TResponse>> next);
}

public sealed class LoggingBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
{
    public async Task<TResponse> Handle(TRequest request, Func<Task<TResponse>> next)
    {
        Console.WriteLine($"Before behavior: {typeof(TRequest).Name}");
        var response = await next();
        Console.WriteLine($"After behavior: {typeof(TRequest).Name}");
        return response;
    }
}

public sealed record CreateUserCommand(string Name);

internal static class Program
{
    private static async Task Main()
    {
        IMiddleware[] middlewares = [new LoggingMiddleware(), new AuthMiddleware()];

        RequestDelegate endpoint = context =>
        {
            Console.WriteLine($"Endpoint reached for {context.Path}");
            return Task.CompletedTask;
        };

        RequestDelegate httpPipeline = middlewares
            .Reverse()
            .Aggregate(endpoint, (next, middleware) => context => middleware.InvokeAsync(context, next));

        await httpPipeline(new HttpLikeContext { Path = "/users", IsAuthenticated = true });

        IPipelineBehavior<CreateUserCommand, string>[] behaviors = [new LoggingBehavior<CreateUserCommand, string>()];
        Func<Task<string>> handler = () => Task.FromResult("Created user: Mila");

        Func<Task<string>> requestPipeline = behaviors
            .Reverse()
            .Aggregate(handler, (next, behavior) => () => behavior.Handle(new CreateUserCommand("Mila"), next));

        Console.WriteLine(await requestPipeline());
    }
}
```

## Common Follow-up Questions
- What is the difference between conventional middleware and `IMiddleware`?
- When should a pipeline component short-circuit instead of calling `next()`?
- Why does middleware order matter so much in ASP.NET Core?
- How are MediatR pipeline behaviors similar to HTTP middleware?
- Which concerns belong in a pipeline and which should stay in the handler?

## Common Mistakes / Pitfalls
- Treating middleware or behaviors as if their order does not affect correctness.
- Putting business-specific rules into global pipeline components.
- Swallowing exceptions in a behavior without preserving diagnostics or response semantics.
- Registering too many hidden layers so request flow becomes difficult to understand.
- Using scoped services incorrectly inside singleton-style conventional middleware constructors.

## References
- [ASP.NET Core middleware | Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/?view=aspnetcore-9.0)
- [Factory-based middleware activation in ASP.NET Core | Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/middleware/extensibility?view=aspnetcore-9.0)
- [IMiddleware Interface | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.http.imiddleware)
- [MediatR](https://github.com/jbogard/MediatR)
- [Chain of Responsibility](https://refactoring.guru/design-patterns/chain-of-responsibility)
