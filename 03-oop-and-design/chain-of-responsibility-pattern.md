# Chain of Responsibility Pattern

**Category:** OOP & Design / Behavioral Patterns
**Difficulty:** 🟡 Middle
**Tags:** `chain-of-responsibility`, `behavioral`, `middleware`, `pipeline`

## Question
> What is the Chain of Responsibility pattern, and how is it similar to middleware pipelines like ASP.NET Core?

## Short Answer
Chain of Responsibility passes a request through a sequence of handlers, where each handler can process it, pass it on, or stop the chain. It is useful when you want flexible request processing without hard-coding one large `if`/`switch` block or tightly coupling the sender to one concrete handler. ASP.NET Core middleware is a practical example: each middleware can do work before and after calling the next component, or short-circuit the request entirely.

## Detailed Explanation
### What the pattern is solving
Chain of Responsibility decouples the **sender of a request** from the **logic that handles it**. Instead of one object needing to know every possible rule, you build a pipeline of handlers. Each handler gets a chance to inspect the request and decide what to do next.

That makes the pattern a good fit when processing is naturally sequential: validation, authorization, enrichment, logging, retry logic, or fallback behavior.

| Without chain | With chain |
| --- | --- |
| One large coordinator knows every step | Each step has one responsibility |
| Harder to reorder or insert behavior | Easy to compose and reorder |
| Sender often depends on concrete logic | Sender talks to a pipeline abstraction |

### How it works internally
The classic implementation has a handler abstraction with a reference to the “next” handler. Each handler can:

1. handle the request completely;
2. partially process it and then call the next handler;
3. stop the chain.

That last option is important. Unlike a plain “do these steps in order” algorithm, Chain of Responsibility supports **short-circuiting**. For example, an authorization handler may reject the request early so expensive downstream work never runs.

In modern C#, many teams implement the pattern with delegates rather than linked objects. Conceptually it is still the same pattern: a request flows through composable handlers.

### Why ASP.NET Core middleware is the best analogy
ASP.NET Core middleware is essentially a chain. Each middleware receives `HttpContext` and a `RequestDelegate next`. It can run code before the next middleware, await `next(context)`, run code after it, or return early.

That gives you cross-cutting behavior such as:

- exception handling;
- authentication/authorization;
- logging and tracing;
- response compression;
- endpoint execution.

> A useful interview insight: middleware is not just “similar” to Chain of Responsibility — it is one of the clearest real-world .NET examples of the pattern.

### Trade-offs and when not to use it
The pattern improves composability, but it can make the final flow harder to trace. If ten handlers can all short-circuit, debugging may require stepping through the full pipeline. Ordering also becomes part of correctness: authentication before authorization is sensible; the reverse is usually a bug.

| Benefit | Trade-off |
| --- | --- |
| Easy to add/remove handlers | Execution order becomes critical |
| Encourages single-responsibility handlers | Control flow can be less obvious |
| Supports short-circuiting and cross-cutting logic | Too many tiny handlers can fragment logic |

Use the pattern when request processing is extensible and order-dependent. Do not use it for a tiny two-branch decision where a simple method is clearer. If every handler must always run and no one can stop or reroute the flow, a simple pipeline or template method may be easier to understand.

## Code Example
```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace OopAndDesign.ChainOfResponsibilityPattern;

public sealed class AppContext
{
    public required string User { get; init; }
    public bool IsAuthenticated { get; set; }
}

public delegate ValueTask RequestDelegate(AppContext context);

public interface IMiddleware
{
    ValueTask InvokeAsync(AppContext context, RequestDelegate next);
}

public sealed class AuthenticationMiddleware : IMiddleware
{
    public async ValueTask InvokeAsync(AppContext context, RequestDelegate next)
    {
        context.IsAuthenticated = !string.IsNullOrWhiteSpace(context.User);
        Console.WriteLine("Authentication checked");

        if (!context.IsAuthenticated)
        {
            Console.WriteLine("Request short-circuited");
            return;
        }

        await next(context);
    }
}

public sealed class LoggingMiddleware : IMiddleware
{
    public async ValueTask InvokeAsync(AppContext context, RequestDelegate next)
    {
        Console.WriteLine("Before next");
        await next(context);
        Console.WriteLine("After next");
    }
}

public static class Program
{
    public static async Task Main()
    {
        var middlewares = new List<IMiddleware>
        {
            new LoggingMiddleware(),
            new AuthenticationMiddleware()
        };

        RequestDelegate terminal = context =>
        {
            Console.WriteLine($"Endpoint executed for {context.User}");
            return ValueTask.CompletedTask;
        };

        foreach (var middleware in middlewares.AsReadOnly().Reverse())
        {
            var next = terminal;
            terminal = context => middleware.InvokeAsync(context, next); // Compose the chain.
        }

        await terminal(new AppContext { User = "Mikhail" });
    }
}
```

## Common Follow-up Questions
- How is Chain of Responsibility different from a simple pipeline?
- When should a handler short-circuit instead of calling the next handler?
- Why is middleware in ASP.NET Core considered a chain?
- What bugs can appear if handler order is wrong?
- How would you unit test one handler in isolation?
- How does this pattern compare with the Decorator pattern?

## Common Mistakes / Pitfalls
- Turning the chain into a hidden “magic” flow that is hard to debug.
- Putting too much unrelated logic into one handler, defeating the point of the pattern.
- Forgetting that order matters, especially for security and validation handlers.
- Assuming every handler must always call the next one.
- Using the pattern for trivial logic where a normal method is simpler.

## References
- [Chain of Responsibility](https://refactoring.guru/design-patterns/chain-of-responsibility)
- [ASP.NET Core middleware](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/)
- [RequestDelegate Class](https://learn.microsoft.com/dotnet/api/microsoft.aspnetcore.http.requestdelegate)
