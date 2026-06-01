# IStartupFilter — Middleware Ordering at Startup

**Category:** ASP.NET Core / Hosting
**Difficulty:** 🔴 Senior
**Tags:** `IStartupFilter`, `middleware`, `pipeline-ordering`, `startup`, `library-extensibility`

## Question

> What is `IStartupFilter`, when would you use it, and how does it differ from registering middleware directly in `Program.cs`?

## Short Answer

`IStartupFilter` lets library or infrastructure code inject middleware at the **beginning** or **end** of the pipeline unconditionally, without requiring the app developer to call `Use*()` in `Program.cs`. It is primarily a library author's extensibility hook — consumer code configures services, and `IStartupFilter` implementations ensure required middleware is always in the right position. For application-level middleware, registering directly in `Program.cs` is clearer and preferred.

## Detailed Explanation

### The `IStartupFilter` interface

```csharp
public interface IStartupFilter
{
    Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next);
}
```

The `Configure` method receives the **rest of the pipeline** as `next` and returns a new `Action<IApplicationBuilder>` that wraps it. This gives the filter control to prepend (before `next(app)`) or append (after `next(app)`) middleware.

### Execution order

All `IStartupFilter` implementations registered in DI run in **reverse registration order** to form a chain, and they all run **before** the user's pipeline (the `Configure` method in the old model, or the `app.Use*()` calls in minimal hosting).

```
IStartupFilter A (registered first)  → wraps outer pipeline
IStartupFilter B (registered second) → wraps inner pipeline
User pipeline (app.Use* calls)
```

Execution order when a request arrives:
```
A's pre-next code → B's pre-next code → User pipeline → B's post-next code → A's post-next code
```

### When to use `IStartupFilter`

| Use case | Example |
|---|---|
| Guarantee middleware runs before user code | Security headers library that must precede all user middleware |
| Auto-register middleware when a service is added | `AddMyLibrary()` + `IStartupFilter` that calls `UseMyLibrary()` |
| Wrap the entire pipeline | Request/response logging, correlation ID injection |
| Conditional middleware without touching `Program.cs` | Multi-tenant routing filter that activates based on config |

### `IStartupFilter` vs direct middleware registration

| Aspect | `IStartupFilter` | Direct `app.Use*()` |
|---|---|---|
| Author | Library/infrastructure author | App developer |
| Registration | `services.AddTransient<IStartupFilter, MyFilter>()` | `app.UseMyMiddleware()` |
| Visibility | Implicit — app dev may not know it's there | Explicit — visible in `Program.cs` |
| Ordering control | Relative to other filters only | Full control over position |
| Testability | Harder to isolate | Easy to comment out / reorder |

> **Warning:** Use `IStartupFilter` sparingly in application code. Hiding middleware registrations in DI makes the pipeline harder to reason about. Prefer explicit `app.Use*()` calls in application code and reserve `IStartupFilter` for libraries.

### `IStartupFilter` in the minimal hosting model

In `.NET 6+` with `WebApplication`, `IStartupFilter` implementations are still supported and run before the middlewares added to `WebApplication`. They are invoked inside `WebApplication.Build()` → `WebApplication.Run()`.

### Alternative: `IHostingStartup`

For even more decoupled library integration (activated via assembly attributes, no service registration required), `IHostingStartup` is an option — but it runs even earlier, before `Program.cs`, and has limited visibility into the DI container.

## Code Example

```csharp
// RequestLoggingStartupFilter.cs — library that auto-injects logging middleware
namespace MyLibrary;

public sealed class RequestLoggingStartupFilter : IStartupFilter
{
    public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next)
    {
        return app =>
        {
            // Prepend our middleware BEFORE the user's pipeline
            app.UseMiddleware<RequestTimingMiddleware>();

            // Call the rest of the pipeline (user's app.Use* + other filters)
            next(app);

            // Nothing after next() here — we only want to prepend
        };
    }
}

public sealed class RequestTimingMiddleware(RequestDelegate nextDelegate,
    ILogger<RequestTimingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        try
        {
            await nextDelegate(context);
        }
        finally
        {
            sw.Stop();
            logger.LogInformation("{Method} {Path} → {Status} in {Elapsed}ms",
                context.Request.Method,
                context.Request.Path,
                context.Response.StatusCode,
                sw.ElapsedMilliseconds);
        }
    }
}
```

```csharp
// MyLibraryServiceCollectionExtensions.cs
public static class MyLibraryServiceCollectionExtensions
{
    public static IServiceCollection AddMyLibrary(this IServiceCollection services)
    {
        // Auto-wire the startup filter — consumer only calls AddMyLibrary()
        services.AddTransient<IStartupFilter, RequestLoggingStartupFilter>();
        return services;
    }
}
```

```csharp
// Program.cs (consumer) — no explicit UseMyLibrary() needed
builder.Services.AddMyLibrary(); // ← filter registered here

var app = builder.Build();

// User's pipeline — RequestTimingMiddleware already prepended by the filter
app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

### Verify the ordering

To see the full resolved middleware pipeline order (useful for debugging), you can inspect `IApplicationBuilder.Properties` in development or use the ASP.NET Core diagnostics middleware:

```csharp
if (app.Environment.IsDevelopment())
    app.Use(async (ctx, next) =>
    {
        Console.WriteLine($"→ {ctx.Request.Path}");
        await next(ctx);
    });
```

## Common Follow-up Questions

- Can `IStartupFilter` access the DI container (inject services)? What lifetime should the filter itself be?
- How do you control the relative ordering of two `IStartupFilter` implementations?
- How does `IStartupFilter` interact with `IApplicationBuilder.UseRouting()` — can you safely add endpoint middleware before or after routing?
- What is `IHostingStartup` and how does it differ from `IStartupFilter`?
- How would you test that a library's `IStartupFilter` correctly wraps the pipeline?

## Common Mistakes / Pitfalls

- **Forgetting to call `next(app)`** — if you omit the `next(app)` call, the entire rest of the pipeline (including user middleware and MVC) is dropped. Always call it unless you intentionally want to replace the full pipeline.
- **Doing heavy work in `Configure()` (the filter method)** — `Configure` runs once at startup; it should only call `app.Use*()`. Any runtime work belongs in the middleware's `InvokeAsync`.
- **Using `IStartupFilter` in application code** — it obscures pipeline ordering. Use it only for library/infrastructure code; app developers should register middleware explicitly.
- **Registration order confusion** — `IStartupFilter` implementations run in reverse DI registration order. If filter A must run before filter B, register B first.
- **Assuming `IStartupFilter` runs after `UseRouting()`** — filters run before all user middleware, so if you add endpoint-aware middleware (e.g., authorization) inside a filter, routing hasn't executed yet.

## References

- [Microsoft Learn — IStartupFilter](https://learn.microsoft.com/aspnet/core/fundamentals/startup?view=aspnetcore-8.0#the-istartupfilter-interface)
- [Andrew Lock — Using IStartupFilter to add middleware automatically](https://andrewlock.net/exploring-istartupfilter-in-aspnetcore/) (verify URL)
- [Microsoft — ApplicationBuilder source (GitHub)](https://github.com/dotnet/aspnetcore/blob/main/src/Http/Http/src/Builder/ApplicationBuilder.cs)
- [Microsoft Learn — ASP.NET Core middleware fundamentals](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/?view=aspnetcore-8.0)
