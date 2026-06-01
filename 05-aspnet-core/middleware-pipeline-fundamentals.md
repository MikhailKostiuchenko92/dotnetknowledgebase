# Middleware Pipeline Fundamentals

**Category:** ASP.NET Core / Middleware
**Difficulty:** 🟢 Junior
**Tags:** `middleware`, `pipeline`, `Use`, `Run`, `Map`, `request-delegate`, `short-circuit`

## Question

> How does the ASP.NET Core middleware pipeline work? What is the difference between `Use`, `Run`, and `Map`?

## Short Answer

The ASP.NET Core middleware pipeline is a chain of request delegates (`Func<HttpContext, Task>`) where each component either handles the request itself, passes it to the next component, or both. `Use` adds a component that can call the next delegate; `Run` adds a terminal component that ends the chain; `Map` branches the pipeline based on the request path. Order of registration in `Program.cs` is the execution order.

## Detailed Explanation

### The request delegate chain

Each middleware is a function with the signature:
```csharp
async Task (HttpContext context, RequestDelegate next) => { ... }
```

`ApplicationBuilder.Build()` compiles all registered delegates into a single `RequestDelegate` by chaining them — each wraps the next. The result is a nested structure similar to a Russian doll.

```
Request →  MW1.pre  →  MW2.pre  →  MW3.pre  →  (terminal)
Response ← MW1.post ← MW2.post ← MW3.post ← 
```

### `Use` — passthrough middleware

```csharp
app.Use(async (context, next) =>
{
    // Pre-processing (runs on the way IN)
    context.Response.Headers["X-RequestId"] = Guid.NewGuid().ToString();

    await next(context);  // ← call the next middleware

    // Post-processing (runs on the way OUT, after downstream writes)
    // Note: you CANNOT write to the response body here if downstream already started it
});
```

> **Warning:** After calling `next()`, do not attempt to modify `context.Response.StatusCode` or headers if the response has already started (`context.Response.HasStarted == true`). Headers are sent once the first byte of the body is written.

### `Run` — terminal middleware (short-circuit)

```csharp
app.Run(async context =>
{
    // No 'next' parameter — this is the end of the chain
    await context.Response.WriteAsync("Hello from terminal middleware");
});
```

Adding middleware after `app.Run()` is legal but those components are **never executed**.

### `Map` — path-based branching

```csharp
app.Map("/admin", adminApp =>
{
    // Separate mini-pipeline for /admin/*
    adminApp.Use(async (ctx, next) => { /* admin auth */ await next(ctx); });
    adminApp.Run(async ctx => await ctx.Response.WriteAsync("Admin area"));
});

// Requests NOT starting with /admin fall through to here
app.Run(async ctx => await ctx.Response.WriteAsync("Main app"));
```

`Map` creates a **branch** — requests that match the path prefix are diverted; unmatched requests continue on the main pipeline.

### `MapWhen` and `UseWhen`

| Method | Condition | Rejoins main pipeline? |
|---|---|---|
| `Map` | Path prefix | ❌ No |
| `MapWhen` | Arbitrary predicate | ❌ No |
| `UseWhen` | Arbitrary predicate | ✅ Yes |

See [use-when-map-branching.md](use-when-map-branching.md) for detail.

### Short-circuiting

A middleware short-circuits the pipeline by **not calling `next`**:

```csharp
app.Use(async (context, next) =>
{
    if (!context.Request.Headers.ContainsKey("X-Api-Key"))
    {
        context.Response.StatusCode = 401;
        await context.Response.WriteAsync("Unauthorized");
        return;  // ← does NOT call next
    }
    await next(context);
});
```

### Ordering matters — practical order

```csharp
app.UseExceptionHandler("/error");   // catch all downstream exceptions
app.UseHsts();
app.UseHttpsRedirection();
app.UseStaticFiles();                // short-circuit for static files
app.UseRouting();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.UseOutputCache();                // .NET 7+
app.MapControllers();                // endpoint middleware (terminal per route)
```

## Code Example

```csharp
// Program.cs — demonstrating Use, Run, Map

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// MW 1: timing (Use — passthrough)
app.Use(async (ctx, next) =>
{
    var sw = System.Diagnostics.Stopwatch.StartNew();
    await next(ctx);
    sw.Stop();
    app.Logger.LogInformation("Request took {ElapsedMs}ms", sw.ElapsedMilliseconds);
});

// MW 2: path branch (Map)
app.Map("/ping", pingApp =>
{
    pingApp.Run(async ctx =>
    {
        ctx.Response.ContentType = "text/plain";
        await ctx.Response.WriteAsync("pong");
    });
});

// MW 3: auth guard (Use — short-circuits on failure)
app.Use(async (ctx, next) =>
{
    if (!ctx.Request.Headers.TryGetValue("Authorization", out _))
    {
        ctx.Response.StatusCode = 401;
        return; // short-circuit
    }
    await next(ctx);
});

// MW 4: terminal for all other requests (Run)
app.Run(async ctx =>
{
    await ctx.Response.WriteAsync("Hello, authenticated user!");
});

app.Run(); // start the host (different overload — starts Kestrel)
```

## Common Follow-up Questions

- Why is middleware order critical? Give an example where wrong order causes a security vulnerability.
- How does `app.UseRouting()` and `app.UseEndpoints()` relate to `app.MapControllers()` in .NET 6+?
- What happens if you call `next()` multiple times in a `Use` middleware?
- How do you unit-test a custom middleware in isolation?
- What is the difference between `IMiddleware` (interface-based) and convention-based middleware?

## Common Mistakes / Pitfalls

- **Placing `UseAuthorization` before `UseAuthentication`** — the auth principal isn't populated yet, so all authorization checks fail.
- **Modifying response headers after `next()` when the response has started** — throws `InvalidOperationException`. Check `context.Response.HasStarted` first.
- **Putting `UseStaticFiles` after routing** — static files will never be served; the router matches a route and short-circuits before reaching static files.
- **Adding middleware after `app.Run()`** — it registers in DI but is never called; the terminal middleware ends the chain.
- **Confusing `app.Run()` (host start) with `app.Run(delegate)` (terminal middleware)** — same method name, different overloads.

## References

- [Microsoft Learn — ASP.NET Core Middleware](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/?view=aspnetcore-8.0)
- [Microsoft Learn — Write custom ASP.NET Core middleware](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/write?view=aspnetcore-8.0)
- [Andrew Lock — Understanding your middleware pipeline with the Middleware Analysis package](https://andrewlock.net/understanding-your-middleware-pipeline-with-the-middleware-analysis-package/) (verify URL)
- [Microsoft — ApplicationBuilder source (GitHub)](https://github.com/dotnet/aspnetcore/blob/main/src/Http/Http/src/Builder/ApplicationBuilder.cs)
