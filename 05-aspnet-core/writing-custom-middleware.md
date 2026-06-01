# Writing Custom Middleware

**Category:** ASP.NET Core / Middleware
**Difficulty:** 🟡 Middle
**Tags:** `middleware`, `IMiddleware`, `convention-based`, `InvokeAsync`, `DI`, `custom-middleware`

## Question

> What are the two ways to write custom middleware in ASP.NET Core (`IMiddleware` vs convention-based), and how do you inject services into middleware?

## Short Answer

Convention-based middleware is a class with an `InvokeAsync(HttpContext, RequestDelegate)` method — it's instantiated once (effectively Singleton) and services are injected per-invocation via method parameters. `IMiddleware`-based middleware is registered in the DI container itself, giving it proper lifetime support (Scoped or Transient), and is activated by `IMiddlewareFactory`. For Scoped service injection, prefer `IMiddleware`; for simple stateless middleware, convention-based is fine.

## Detailed Explanation

### Convention-based middleware

The framework looks for a class with:
1. A constructor that accepts `RequestDelegate next` (and optionally Singleton services).
2. A public method named `Invoke` or `InvokeAsync` that accepts `HttpContext` as its first parameter (and optionally Scoped/Transient services as additional parameters).

```csharp
public sealed class TimingMiddleware(RequestDelegate next, ILogger<TimingMiddleware> logger)
{
    // 'logger' injected via constructor — must be Singleton lifetime
    public async Task InvokeAsync(HttpContext context,
        IMetricsRecorder metrics)  // ← Scoped service injected per-invocation
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        await next(context);
        sw.Stop();
        metrics.RecordRequest(context.Request.Path, sw.ElapsedMilliseconds);
        logger.LogInformation("Request took {Ms}ms", sw.ElapsedMilliseconds);
    }
}
```

Registration:
```csharp
app.UseMiddleware<TimingMiddleware>();
// or via extension method (preferred for published middleware):
app.UseTimingMiddleware();
```

**Lifetime gotcha:** The middleware instance is created once by the DI container. Constructor-injected services must be **Singleton**. Scoped/Transient services must be injected as additional `InvokeAsync` parameters.

### `IMiddleware` — factory-activated middleware

```csharp
public interface IMiddleware
{
    Task InvokeAsync(HttpContext context, RequestDelegate next);
}
```

The middleware is resolved from DI on every request via `IMiddlewareFactory`, meaning it **can be Scoped** and all its constructor dependencies can also be Scoped.

```csharp
public sealed class TenantMiddleware(ITenantResolver resolver) : IMiddleware
{
    // resolver can be Scoped — new instance per request
    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        var tenant = await resolver.ResolveAsync(context);
        context.Items["Tenant"] = tenant;
        await next(context);
    }
}
```

Registration:
```csharp
// Must register in DI (unlike convention-based)
builder.Services.AddScoped<TenantMiddleware>();
// or Transient:
builder.Services.AddTransient<TenantMiddleware>();

// Then add to pipeline
app.UseMiddleware<TenantMiddleware>();
```

### Comparison table

| Aspect | Convention-based | `IMiddleware` |
|---|---|---|
| DI registration required | ❌ No | ✅ Yes |
| Lifetime | Effectively Singleton | Any (Scoped, Transient) |
| Scoped services | Via `InvokeAsync` params only | Via constructor |
| Performance | Slightly faster (no factory overhead) | Factory overhead per request |
| Testability | Harder to mock constructor deps | Standard DI mock |
| Recommended for | Simple, stateless, high-throughput | Scoped-dependent middleware |

### Extension method pattern (for publishable middleware)

```csharp
// TimingMiddlewareExtensions.cs
public static class TimingMiddlewareExtensions
{
    public static IApplicationBuilder UseRequestTiming(this IApplicationBuilder app)
        => app.UseMiddleware<TimingMiddleware>();
}
```

This is the pattern used by all built-in ASP.NET Core middleware (`UseAuthentication()`, `UseRouting()`, etc.).

## Code Example

```csharp
// CorrelationIdMiddleware.cs — IMiddleware with Scoped dependency
namespace MyApp.Middleware;

public sealed class CorrelationIdMiddleware(
    ICorrelationIdAccessor accessor,   // Scoped service
    ILogger<CorrelationIdMiddleware> logger) : IMiddleware
{
    private const string HeaderName = "X-Correlation-Id";

    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        // Read or generate correlation ID
        var correlationId = context.Request.Headers.TryGetValue(HeaderName, out var header)
            ? header.ToString()
            : Guid.NewGuid().ToString("N");

        // Store in scoped accessor so other services can read it
        accessor.CorrelationId = correlationId;

        // Echo back in response headers
        context.Response.Headers[HeaderName] = correlationId;

        using (logger.BeginScope(new Dictionary<string, object>
               { ["CorrelationId"] = correlationId }))
        {
            await next(context);
        }
    }
}

// ICorrelationIdAccessor.cs
public interface ICorrelationIdAccessor
{
    string? CorrelationId { get; set; }
}

public sealed class CorrelationIdAccessor : ICorrelationIdAccessor
{
    public string? CorrelationId { get; set; }
}
```

```csharp
// Program.cs
builder.Services.AddScoped<ICorrelationIdAccessor, CorrelationIdAccessor>();
builder.Services.AddScoped<CorrelationIdMiddleware>(); // IMiddleware must be registered

var app = builder.Build();
app.UseMiddleware<CorrelationIdMiddleware>();
app.MapControllers();
app.Run();
```

### Convention-based alternative (no IMiddleware)

```csharp
public sealed class CorrelationIdMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(
        HttpContext context,
        ICorrelationIdAccessor accessor) // Scoped — injected per invocation
    {
        accessor.CorrelationId = context.Request.Headers.TryGetValue("X-Correlation-Id", out var v)
            ? v.ToString()
            : Guid.NewGuid().ToString("N");

        context.Response.Headers["X-Correlation-Id"] = accessor.CorrelationId;
        await next(context);
    }
}
// No DI registration needed — UseMiddleware<> activates it
```

## Common Follow-up Questions

- How would you unit-test a middleware that injects a Scoped service via `InvokeAsync` parameters?
- When should you use `IMiddleware` vs a filter (`IActionFilter`)? What can each access that the other cannot?
- How do you conditionally apply a middleware only for specific routes without using `Map`?
- Can middleware access the matched endpoint metadata (e.g., route data, attributes)?
- How does `IMiddlewareFactory` work internally, and how can you replace it?

## Common Mistakes / Pitfalls

- **Injecting a Scoped service in the constructor of convention-based middleware** — the middleware is Singleton; the Scoped service becomes a captive dependency, causing stale data or thread-safety issues. Use `InvokeAsync` parameter injection.
- **Forgetting to register `IMiddleware` in DI** — `app.UseMiddleware<TenantMiddleware>()` will throw `InvalidOperationException` at runtime if the type is not in the DI container.
- **Not calling `await next(context)`** — accidentally short-circuits the rest of the pipeline, silently breaking all downstream middleware and endpoints.
- **Writing to the response body after calling `next(context)`** — if downstream middleware already wrote the body, the response headers are sealed and `context.Response.HasStarted` is true; additional writes throw.
- **Naming the method `Invoke` vs `InvokeAsync`** — both work for convention-based middleware, but mixing them up causes a compile warning; `InvokeAsync` is preferred per .NET conventions.

## References

- [Microsoft Learn — Write custom middleware](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/write?view=aspnetcore-8.0)
- [Microsoft Learn — Factory-based middleware activation (IMiddleware)](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/extensibility?view=aspnetcore-8.0)
- [Andrew Lock — The difference between IMiddleware and convention-based middleware](https://andrewlock.net/tag/middleware/) (verify URL)
- [Microsoft — IMiddlewareFactory source](https://github.com/dotnet/aspnetcore/blob/main/src/Http/Http/src/MiddlewareFactory.cs)
