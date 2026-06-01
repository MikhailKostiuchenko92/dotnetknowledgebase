# Middleware Pipeline Internals

**Category:** ASP.NET Core / Middleware
**Difficulty:** 🔴 Senior
**Tags:** `middleware`, `RequestDelegate`, `ApplicationBuilder`, `pipeline-compilation`, `branching-cost`, `internals`

## Question

> How does the ASP.NET Core middleware pipeline compile into a `RequestDelegate` chain internally? What is the performance cost of branching (`Map`/`MapWhen`)?

## Short Answer

`ApplicationBuilder.Build()` compiles the registered middleware stack into a single nested `RequestDelegate` by iterating the component list in reverse and wrapping each component around the next. The result is a chain of closures — identical to manually nested `async` functions. `Map`/`MapWhen` branching creates a separate `ApplicationBuilder` and compiles its own `RequestDelegate`, then wraps it in a predicate check — a small per-request overhead (one branch check) that is negligible compared to I/O.

## Detailed Explanation

### `ApplicationBuilder` internals

`ApplicationBuilder` maintains an internal list of middleware factories:

```csharp
// Simplified source representation
private readonly IList<Func<RequestDelegate, RequestDelegate>> _components = new List<...>();

public IApplicationBuilder Use(Func<RequestDelegate, RequestDelegate> middleware)
{
    _components.Add(middleware);
    return this;
}

public RequestDelegate Build()
{
    // Start with a 404 terminal delegate
    RequestDelegate app = context =>
    {
        if (!context.Response.HasStarted)
            context.Response.StatusCode = StatusCodes.Status404NotFound;
        return Task.CompletedTask;
    };

    // Chain in reverse so first-registered is outermost (runs first)
    for (int i = _components.Count - 1; i >= 0; i--)
        app = _components[i](app);

    return app;
}
```

Each `Func<RequestDelegate, RequestDelegate>` is a factory that takes the "rest of the pipeline" and returns a new `RequestDelegate` that wraps it.

### How `app.Use(async (ctx, next) => ...)` maps to this

`UseExtensions.Use(Action<HttpContext, Func<Task>>)` compiles the lambda into the factory pattern:

```csharp
// What the framework does internally
_components.Add(next => async context =>
{
    await userLambda(context, () => next(context));
});
```

So the final compiled delegate for a 3-middleware pipeline looks like:

```
context =>
  MW1.before
  await (context =>
    MW2.before
    await (context =>
      MW3.before
      await terminal(context)
      MW3.after
    )(context)
    MW2.after
  )(context)
  MW1.after
```

### `Map` / `MapWhen` branching

`Map` creates a cloned `IApplicationBuilder`, builds a sub-pipeline from it, and inserts a routing middleware that checks the path prefix:

```csharp
// Conceptual implementation of Map
app.Use(next =>
{
    var branchPipeline = app.New(); // clone builder
    configure(branchPipeline);      // user registers branch middleware
    var branch = branchPipeline.Build(); // compile branch

    return async context =>
    {
        if (context.Request.Path.StartsWithSegments(pathMatch, out var remaining))
        {
            context.Request.PathBase = context.Request.PathBase.Add(pathMatch);
            context.Request.Path = remaining;
            await branch(context);  // run branch; never call next
        }
        else
        {
            await next(context);    // main pipeline
        }
    };
});
```

Performance implications:
- One `string.StartsWith` comparison per request per `Map` call — effectively free.
- Each branch pipeline is compiled once at startup, not per request.
- The branch `RequestDelegate` is a closure; no heap allocation per request (closures compiled by compiler capture only outer variables from startup).

### `UseWhen` vs `MapWhen` internals

`UseWhen` is implemented by building the branch pipeline and **also calling `next`** after the branch:

```csharp
app.Use(next =>
{
    var branch = branchApp.Build();
    return async context =>
    {
        if (predicate(context))
            await branch(context);  // may or may not call next internally
        else
            await next(context);
    };
});
```

The branch built by `UseWhen` has `next` injected as its terminal, so after the branch completes (without short-circuiting), it calls `next` automatically.

### Middleware compilation vs conventional routing

| | Middleware pipeline | Endpoint routing |
|---|---|---|
| Compiled at | `host.Build()` / `app.Build()` | `WebApplication.Build()` |
| Per-request dispatch cost | Near zero (pre-compiled closures) | Trie-based route match (also very fast) |
| Branching cost | O(1) per `Map` | O(log N) per endpoint match |
| Dynamic modification | Not possible after Build() | `IEndpointRouteBuilder` (extensions only) |

### Inspecting the pipeline (diagnostics)

```csharp
// ASP.NET Core includes a middleware analysis package (dev only)
builder.Services.AddMiddlewareAnalysis();
// Emits DiagnosticSource events: Microsoft.AspNetCore.MiddlewareAnalysis.*
```

## Code Example

```csharp
// Demonstrating the factory pattern directly (rarely done in app code)

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// Low-level: add middleware via the Func<RequestDelegate, RequestDelegate> factory
((IApplicationBuilder)app).Use(next => async context =>
{
    Console.WriteLine($"[Direct factory] Before — {context.Request.Path}");
    await next(context);
    Console.WriteLine($"[Direct factory] After  — {context.Response.StatusCode}");
});

// Equivalent using the UseExtensions helper (what everyone normally uses)
app.Use(async (context, next) =>
{
    Console.WriteLine($"[UseExtensions] Before — {context.Request.Path}");
    await next(context);
    Console.WriteLine($"[UseExtensions] After  — {context.Response.StatusCode}");
});

app.MapGet("/", () => "Hello!");
app.Run();
```

```csharp
// Visualizing the compiled pipeline (debug helper)
public static void PrintPipeline(IApplicationBuilder app)
{
    var components = (IList<Func<RequestDelegate, RequestDelegate>>)
        app.GetType()
           .GetField("_components", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)!
           .GetValue(app)!;

    Console.WriteLine($"Middleware count: {components.Count}");
    // Each component is an anonymous closure; names come from DebuggerDisplay or ToString()
}
```

## Common Follow-up Questions

- What happens at runtime if you modify `IApplicationBuilder` after `Build()` has been called?
- How does `IMiddlewareFactory` participate in the pipeline compilation?
- How does the compiled `RequestDelegate` chain compare to a manual `if/else` dispatch in terms of IL?
- How does the branching cost of `Map` compare to endpoint routing for a high-throughput API?
- What is `MiddlewareAnalysisDiagnosticObserver` and how would you use it to profile the pipeline?

## Common Mistakes / Pitfalls

- **Thinking the pipeline is rebuilt per request** — it is compiled once at startup into a static delegate chain. Middleware components are activated per-request only when using `IMiddlewareFactory` (`IMiddleware`).
- **Attempting to add middleware after `app.Build()` / `app.Run()`** — the factory list is frozen; the new component is never part of the compiled chain.
- **Confusing `ApplicationBuilder.New()` (clone) with `ApplicationBuilder.Build()`** — `New()` creates a child builder sharing the same `IServiceProvider` but with an empty component list, used by `Map` to build sub-pipelines.
- **Assuming `Map` branches share the same `RequestDelegate` terminal** — each branch compiles independently with its own 404-terminal unless `next` is explicitly passed.
- **Using reflection to inspect `_components` in production** — it's an implementation detail that can change between ASP.NET Core versions.

## References

- [Microsoft — ApplicationBuilder source (GitHub)](https://github.com/dotnet/aspnetcore/blob/main/src/Http/Http/src/Builder/ApplicationBuilder.cs)
- [Microsoft — UseExtensions source (GitHub)](https://github.com/dotnet/aspnetcore/blob/main/src/Http/Http/src/Builder/UseExtensions.cs)
- [Microsoft Learn — ASP.NET Core middleware](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/?view=aspnetcore-8.0)
- [Andrew Lock — How ASP.NET Core builds the middleware pipeline](https://andrewlock.net/tag/middleware/) (verify URL)
- [Stephen Halter — Inside the ASP.NET Core middleware pipeline (NDC talk)](https://www.youtube.com/watch?v=) (verify URL — search "Stephen Halter NDC middleware")
