# UseWhen, MapWhen, and Map — Conditional Pipeline Branching

**Category:** ASP.NET Core / Middleware
**Difficulty:** 🟡 Middle
**Tags:** `middleware`, `Map`, `MapWhen`, `UseWhen`, `branching`, `pipeline`

## Question

> What is the difference between `Map`, `MapWhen`, and `UseWhen` in ASP.NET Core middleware? When does a branch rejoin the main pipeline?

## Short Answer

`Map` branches on a path prefix and creates a completely separate pipeline that does not rejoin the main one. `MapWhen` branches on an arbitrary predicate (any `HttpContext` property) and also does not rejoin. `UseWhen` similarly branches on a predicate but **does rejoin** the main pipeline after the branch completes (unless the branch short-circuits). The key distinction is whether matched requests continue down the main pipeline after the branch.

## Detailed Explanation

### `Map` — path-prefix branching (does NOT rejoin)

```
/admin/* → [admin pipeline] → terminal
other    → [main pipeline] → terminal
```

- Strips the matched prefix from `HttpContext.Request.Path`.
- Requests matched to the branch never continue to the main pipeline.
- Useful for mounting sub-apps: admin UI, API version segments, health check handlers.

### `MapWhen` — predicate branching (does NOT rejoin)

Same as `Map` but the condition is any `Func<HttpContext, bool>`:

```csharp
app.MapWhen(
    ctx => ctx.Request.Headers.ContainsKey("X-Special"),
    specialApp =>
    {
        specialApp.UseMiddleware<SpecialHandlerMiddleware>();
        specialApp.Run(async ctx => await ctx.Response.WriteAsync("special!"));
    });
```

- Path is **not** modified (unlike `Map`).
- Branched requests **do not** see the rest of the main pipeline.

### `UseWhen` — predicate branching (DOES rejoin)

```csharp
app.UseWhen(
    ctx => ctx.Request.Path.StartsWithSegments("/api"),
    apiApp =>
    {
        apiApp.UseMiddleware<ApiKeyMiddleware>(); // only for /api paths
        // No Run() here — the request will rejoin the main pipeline
    });

// Both /api/* AND other paths reach this point
app.UseRouting();
app.MapControllers();
```

- If the branch does **not** short-circuit, the request continues to the next middleware in the main pipeline after the branch finishes.
- Ideal for conditionally applying a middleware (e.g., only authenticate API paths, not static files).

### Comparison table

| Method | Condition type | Rejoins main pipeline | Path stripped |
|---|---|---|---|
| `Map` | Path prefix | ❌ No | ✅ Yes |
| `MapWhen` | Predicate | ❌ No | ❌ No |
| `UseWhen` | Predicate | ✅ Yes (if no short-circuit) | ❌ No |

### Branching and routing interaction

`Map` and `MapWhen` create isolated sub-pipelines. If you call `app.UseRouting()` only in the main pipeline, the branch won't have routing. You must call `UseRouting()` / `MapControllers()` inside the branch if you need MVC endpoints there.

### Nesting

Branches can be nested:

```csharp
app.Map("/api", apiApp =>
{
    apiApp.UseWhen(
        ctx => ctx.Request.Method == "GET",
        getApp => getApp.UseMiddleware<CacheMiddleware>()
    );
    apiApp.MapControllers();
});
```

## Code Example

```csharp
// Program.cs — demonstrating all three

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();

var app = builder.Build();

// 1. UseWhen — add timing middleware for /api/* only; rejoins main pipeline
app.UseWhen(
    ctx => ctx.Request.Path.StartsWithSegments("/api"),
    apiApp => apiApp.UseMiddleware<ApiTimingMiddleware>());

// 2. MapWhen — gRPC requests get their own pipeline (no rejoin)
app.MapWhen(
    ctx => ctx.Request.ContentType?.StartsWith("application/grpc") == true,
    grpcApp =>
    {
        grpcApp.UseRouting();
        grpcApp.MapGrpcService<GreeterService>();
    });

// 3. Map — admin sub-app on /internal (path stripped; no rejoin)
app.Map("/internal", internalApp =>
{
    internalApp.Use(async (ctx, next) =>
    {
        if (!ctx.Connection.LocalIpAddress?.IsLoopback() ?? true)
        {
            ctx.Response.StatusCode = 403;
            return;
        }
        await next(ctx);
    });
    internalApp.MapGet("/status", () => Results.Ok("internal ok"));
});

// Main pipeline continues for all non-Map/non-MapWhen-matched requests
app.UseHttpsRedirection();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

### `UseWhen` vs per-route middleware (minimal API approach)

In .NET 7+ minimal APIs you can apply middleware-like behavior using endpoint filters, which is often cleaner than `UseWhen` for route-specific logic:

```csharp
app.MapGet("/api/data", () => Results.Ok())
   .AddEndpointFilter<ApiKeyFilter>();  // only this route
```

See [endpoint-filters.md](endpoint-filters.md) for details.

## Common Follow-up Questions

- What happens if the branch created by `UseWhen` short-circuits — does the main pipeline still execute?
- How does `Map` affect `HttpContext.Request.Path` and `PathBase`?
- Can you call `app.MapControllers()` inside a `Map` branch and also in the main pipeline?
- Why would you choose `UseWhen` over applying a middleware conditionally inside the middleware itself?
- How do `MapWhen`/`UseWhen` perform — is the predicate evaluated per request?

## Common Mistakes / Pitfalls

- **Expecting `Map`-branched requests to reach main-pipeline middleware** — they don't. If you want common middleware (logging, auth) to apply everywhere, register it before the `Map` call.
- **Putting `app.Run()` in a `UseWhen` branch** — this terminates the request; it never rejoins the main pipeline, defeating the purpose of `UseWhen`.
- **Calling `app.UseRouting()` only in the main pipeline but needing routing in a branch** — sub-apps created by `Map` are isolated; they need their own `UseRouting()` if they serve endpoints.
- **Using `Map` when you only want to conditionally add a middleware** — `UseWhen` is the right tool for conditional middleware that should still allow the request to continue.
- **Relying on path-stripping behavior without updating `PathBase`** — `Map("/admin", ...)` strips `/admin` from `Path` but moves it to `PathBase`. Link generation (URL helper, `LinkGenerator`) must account for `PathBase`.

## References

- [Microsoft Learn — ASP.NET Core middleware — Branch the pipeline](https://learn.microsoft.com/aspnet/core/fundamentals/middleware/?view=aspnetcore-8.0#branch-the-middleware-pipeline)
- [Microsoft — Map/MapWhen/UseWhen source (ApplicationBuilderExtensions)](https://github.com/dotnet/aspnetcore/blob/main/src/Http/Http/src/Builder/ApplicationBuilderExtensions.cs)
- [Andrew Lock — Exploring UseWhen in ASP.NET Core](https://andrewlock.net/tag/middleware/) (verify URL)
- [Microsoft Learn — Endpoint filters (.NET 7+)](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/min-api-filters?view=aspnetcore-8.0)
