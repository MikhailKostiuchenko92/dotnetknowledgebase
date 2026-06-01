# Minimal API Performance Patterns in ASP.NET Core

**Category:** ASP.NET Core / Performance & Diagnostics
**Difficulty:** 🔴 Senior
**Tags:** `TypedResults`, `IResult`, `allocation`, `endpoint-filter`, `AOT`, `benchmarks`, `minimal-api`

## Question

> What are the key performance optimizations available in ASP.NET Core minimal APIs? How do `TypedResults` vs `IResult`, endpoint filter cost, and AOT-safe patterns affect throughput and allocations?

## Short Answer

Key minimal API performance wins: (1) **`TypedResults` over `Results`** — avoids boxing the result in `object?`, and enables OpenAPI schema inference without reflection at startup; (2) **avoiding `async`/`await` on synchronous paths** — eliminates state machine allocation when the result is already available; (3) **`[LoggerMessage]` source gen** over string interpolation; (4) **`RequestDelegateGenerator` (RDG)** eliminates runtime reflection for parameter binding; (5) **`WebApplication.CreateSlimBuilder`** reduces startup service registration overhead.

## Detailed Explanation

### `TypedResults` vs `Results` — allocation difference

```csharp
// Results.Ok() returns IResult (object?, boxing potential)
app.MapGet("/v1/{id}", (int id) => Results.Ok(id));

// TypedResults.Ok<T>() returns Ok<T> (strongly typed, no boxing for structs)
app.MapGet("/v2/{id}", (int id) => TypedResults.Ok(id));
```

The practical allocation difference is small for most scenarios, but `TypedResults` is important for:
- **OpenAPI schema inference** — `TypedResults` carries `T` at compile time; Swashbuckle/OTEL can infer the response type automatically
- **`Results<T1, T2>` union return types** — enables accurate OpenAPI spec for multiple response types

### Avoid unnecessary `async` on sync paths

```csharp
// ❌ Allocates a state machine even though no I/O happens
app.MapGet("/health", async () => TypedResults.Ok("healthy"));

// ✅ No state machine — synchronous, no heap allocation
app.MapGet("/health", () => TypedResults.Ok("healthy"));

// ✅ For async: use ConfigureAwait(false) to avoid context capture overhead
app.MapGet("/products/{id}", async (int id, IProductService svc, CancellationToken ct) =>
    await svc.GetByIdAsync(id, ct).ConfigureAwait(false) is { } p
        ? TypedResults.Ok(p)
        : TypedResults.NotFound());
```

### Endpoint filter overhead

Each `IEndpointFilter` adds a delegate call overhead. For hot paths:

```csharp
// Use factory filters to skip when not applicable
app.MapGet("/read-only-endpoint", GetData)
   .AddEndpointFilterFactory((ctx, next) =>
   {
       // Return no-op delegate for GET requests (zero cost)
       if (ctx.MethodInfo.GetCustomAttribute<HttpGetAttribute>() is not null)
           return invCtx => next(invCtx); // direct passthrough

       return async invCtx =>
       {
           await ValidatePermissionsAsync(invCtx);
           return await next(invCtx);
       };
   });
```

### Reduce allocations with `ValueTask<IResult>`

```csharp
// ValueTask avoids Task allocation for synchronous fast paths
app.MapGet("/status", () => ValueTask.FromResult<IResult>(TypedResults.Ok("ok")));
```

### `WebApplication.CreateSlimBuilder` — reduced overhead

`.CreateSlimBuilder` omits services not needed for API-only apps:
- No MVC/Razor services
- No HttpLogging by default
- Smaller `IConfiguration` setup
- ~30% fewer default services registered

```csharp
// Best for minimal API AOT targets
var builder = WebApplication.CreateSlimBuilder(args);
```

### Response body pooling with `IBufferWriter<byte>`

```csharp
// For JSON heavy endpoints, pre-serialize using pooled arrays
app.MapGet("/large-dataset", async (IProductService svc, HttpResponse response) =>
{
    response.ContentType = "application/json";
    var products = await svc.GetAllAsync();
    await JsonSerializer.SerializeAsync(response.Body, products,
        AppJsonContext.Default.IEnumerableProduct); // source-gen context
});
```

### Benchmark comparison (illustrative)

| Pattern | Relative allocations | Notes |
|---|---|---|
| `Results.Ok(obj)` | Baseline | Standard path |
| `TypedResults.Ok(obj)` | ~Same | Better for OpenAPI |
| `async () => TypedResults.Ok(val)` (no await) | +1 state machine alloc | Use sync lambda |
| With 3 `IEndpointFilter`s | +3 delegate invocations | Filter cost is small |
| AOT + RDG | Lowest | No startup reflection |
| `CreateSlimBuilder` | -30% startup allocations | For AOT targets |

## Code Example

```csharp
// Performance-optimized endpoint group
var api = app.MapGroup("/api/products");

// Sync — no async state machine
api.MapGet("/count", (IProductRepository repo) =>
    TypedResults.Ok(repo.Count()));

// Factory filter — zero cost for GET endpoints
api.AddEndpointFilterFactory((ctx, next) =>
{
    var isReadOnly = ctx.MethodInfo.GetCustomAttribute<HttpGetAttribute>() is not null
                     || ctx.MethodInfo.GetCustomAttribute<HttpHeadAttribute>() is not null;

    if (isReadOnly) return invCtx => next(invCtx); // no-op

    return async invCtx =>
    {
        if (!await ValidateIdempotencyAsync(invCtx))
            return TypedResults.Conflict();
        return await next(invCtx);
    };
});

// Pre-serialized response for read-heavy endpoints
api.MapGet("/", async (IProductService svc, CancellationToken ct) =>
{
    var products = await svc.GetAllAsync(ct);
    return TypedResults.Ok(products); // TypedResults carries T for OpenAPI
});
```

## Common Follow-up Questions

- How do you benchmark minimal API endpoints with `BenchmarkDotNet`?
- What is the `Results<T1, T2>` union type and how does it affect OpenAPI schema generation?
- How does `ConfigureAwait(false)` affect performance in ASP.NET Core (already no SynchronizationContext)?
- What is the throughput difference between controller-based MVC and minimal APIs in a microbenchmark?
- How does `WebApplication.CreateSlimBuilder` interact with third-party packages that register services via `IHostBuilder`?

## Common Mistakes / Pitfalls

- **Adding `async` to every handler** — unnecessary `async` on non-I/O handlers allocates a state machine. Use synchronous lambdas where the result is immediately available.
- **Using `Results.Ok()` when `TypedResults.Ok()` provides identical runtime behavior plus better OpenAPI inference** — `TypedResults` is strictly better for code that uses Swagger/OTEL; there's no reason to use `Results` for simple scalar returns.
- **Adding many endpoint filters to hot endpoints** — each filter adds a delegate invocation; for sub-millisecond endpoints, 5+ filters can double the overhead. Use factory filters with no-op passthrough.
- **Not using `JsonSerializerContext` for AOT** — source-generated JSON is significantly faster and required for AOT; runtime reflection-based serialization is both slower and incompatible with AOT.
- **Benchmarking with development configuration** — always benchmark in `Release` mode with `ASPNETCORE_ENVIRONMENT=Production` to get production-representative numbers.

## References

- [Microsoft Learn — Minimal API best practices](https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis/best-practices?view=aspnetcore-8.0) (verify URL)
- [Microsoft Learn — CreateSlimBuilder](https://learn.microsoft.com/aspnet/core/fundamentals/native-aot?view=aspnetcore-8.0#createslimbuilder)
- [David Fowler — Minimal API performance tips](https://github.com/davidfowl/AspNetCoreDiagnosticScenarios/blob/master/AspNetCoreGuidance.md) (verify URL)
- [BenchmarkDotNet documentation](https://benchmarkdotnet.org/articles/guides/getting-started.html)
