# Resilience in .NET and ASP.NET Core

**Category:** Architecture / Resilience
**Difficulty:** 🔴 Senior
**Tags:** `Microsoft.Extensions.Resilience`, `IHttpClientFactory`, `ResiliencePipeline`, `Polly-v8`, `standard-resilience-handler`, `.NET-8`

## Question

> How does `Microsoft.Extensions.Resilience` integrate with `IHttpClientFactory` in .NET 8? Walk through the built-in standard resilience handler, named pipelines, and how to wire up custom strategies.

## Short Answer

`Microsoft.Extensions.Resilience` is the official .NET 8 wrapper around Polly v8, integrating with `IHttpClientFactory`. Call `.AddStandardResilienceHandler()` on an `HttpClient` registration to get a sensible defaults pipeline: per-attempt timeout, total timeout, retry (exponential backoff + jitter), circuit breaker, and rate limiter. For custom strategies, use `.AddResilienceHandler("name", pipeline => { ... })`. Named pipelines without HttpClient use `services.AddResiliencePipeline("name", ...)` and are resolved via `ResiliencePipelineProvider<string>`.

## Detailed Explanation

### Standard Resilience Handler (Built-In Defaults)

```csharp
// NuGet: Microsoft.Extensions.Http.Resilience
builder.Services.AddHttpClient<IInventoryClient, InventoryClient>()
    .AddStandardResilienceHandler(); // ← sensible defaults for outbound HTTP calls
```

The standard handler includes (innermost to outermost):
```
1. AttemptTimeout:  10s per single attempt
2. TotalTimeout:    30s across all retries
3. Retry:           3 retries, exponential backoff, jitter, handles 408/429/5xx
4. CircuitBreaker:  50% failure rate, 30s sampling, 30s break duration
5. (Optionally) RateLimiter: disabled by default
```

```csharp
// Tuning standard handler defaults
builder.Services.AddHttpClient<IPaymentClient, PaymentClient>()
    .AddStandardResilienceHandler(options =>
    {
        options.Retry.MaxRetryAttempts = 2;
        options.Retry.Delay = TimeSpan.FromMilliseconds(200);
        options.Retry.UseJitter = true;
        options.AttemptTimeout.Timeout = TimeSpan.FromSeconds(5);
        options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(20);
        options.CircuitBreaker.FailureRatio = 0.6;
        options.CircuitBreaker.BreakDuration = TimeSpan.FromSeconds(60);
    });
```

### Custom Resilience Handler

```csharp
builder.Services.AddHttpClient<IOrderClient, OrderClient>()
    .AddResilienceHandler("order-resilience", (pipeline, context) =>
    {
        var logger = context.ServiceProvider.GetRequiredService<ILogger<IOrderClient>>();

        pipeline
            .AddRetry(new HttpRetryStrategyOptions
            {
                MaxRetryAttempts = 3,
                BackoffType = DelayBackoffType.Exponential,
                UseJitter = true,
                OnRetry = args =>
                {
                    logger.LogWarning("Retry {Attempt} for {Op} — {Reason}",
                        args.AttemptNumber, args.Context.OperationKey,
                        args.Outcome.Exception?.Message ?? args.Outcome.Result?.StatusCode.ToString());
                    return ValueTask.CompletedTask;
                }
            })
            .AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
            {
                FailureRatio = 0.5,
                MinimumThroughput = 10,
                BreakDuration = TimeSpan.FromSeconds(30),
                OnOpened = args =>
                {
                    logger.LogError("Circuit opened — OrderService unavailable");
                    return ValueTask.CompletedTask;
                }
            })
            .AddTimeout(TimeSpan.FromSeconds(5));
    });
```

### Named Pipeline for Non-HTTP Operations

```csharp
// For DB calls, message bus, any non-HTTP resilience
builder.Services.AddResiliencePipeline("db-resilience", (pipeline, ctx) =>
{
    pipeline
        .AddRetry(new RetryStrategyOptions
        {
            MaxRetryAttempts = 3,
            Delay = TimeSpan.FromMilliseconds(100),
            BackoffType = DelayBackoffType.Exponential,
            UseJitter = true,
            ShouldHandle = new PredicateBuilder()
                .Handle<SqlException>(ex => IsTransient(ex))
                .Handle<TimeoutException>()
        })
        .AddCircuitBreaker(new CircuitBreakerStrategyOptions
        {
            FailureRatio = 0.5,
            SamplingDuration = TimeSpan.FromSeconds(30),
            MinimumThroughput = 5,
            BreakDuration = TimeSpan.FromSeconds(30)
        });
});

// Usage in repository
public class OrderRepository(
    AppDbContext db,
    ResiliencePipelineProvider<string> pipelineProvider) : IOrderRepository
{
    private readonly ResiliencePipeline _pipeline = pipelineProvider.GetPipeline("db-resilience");

    public Task<Order?> GetByIdAsync(int id, CancellationToken ct)
        => _pipeline.ExecuteAsync(async token => await db.Orders.FindAsync([id], token), ct);
}
```

### Resilience Metrics and Observability

```csharp
// Microsoft.Extensions.Resilience automatically emits metrics to:
// - System.Diagnostics.Metrics (compatible with OpenTelemetry, Prometheus)
// - ILogger for state changes

// To add OpenTelemetry tracing of resilience events:
builder.Services.AddOpenTelemetry()
    .WithMetrics(m => m.AddHttpClientInstrumentation())
    .WithTracing(t => t.AddHttpClientInstrumentation());

// Default metric names:
// resilience.http.request.duration (histogram)
// resilience.http.request.attempts (counter)
// resilience.http.circuit_breaker.state (gauge: 0=closed, 1=open, 2=half-open)
```

### Health Checks Integration

```csharp
// Surface circuit breaker state as a health check
builder.Services.AddHealthChecks()
    .AddCheck<CircuitBreakerHealthCheck>("payment-circuit-breaker");

public class CircuitBreakerHealthCheck(ResiliencePipelineProvider<string> pipelineProvider)
    : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext ctx, CancellationToken ct = default)
    {
        var pipeline = pipelineProvider.GetPipeline("payment-resilience");
        // Note: Polly v8 doesn't expose circuit state directly on pipeline
        // Use a registry or a custom ICircuitBreakerStateProvider
        return Task.FromResult(HealthCheckResult.Healthy("Circuit breaker operational"));
    }
}
```

## Code Example

```csharp
// Program.cs: production-ready resilience setup
var builder = WebApplication.CreateBuilder(args);

// Payment service: custom strict policy (max 1 retry, short timeout)
builder.Services.AddHttpClient<IPaymentClient, PaymentHttpClient>()
    .AddResilienceHandler("payment", pipeline =>
        pipeline
            .AddRetry(new HttpRetryStrategyOptions { MaxRetryAttempts = 1, UseJitter = true })
            .AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions { MinimumThroughput = 5 })
            .AddTimeout(TimeSpan.FromSeconds(3)));

// Catalog service: standard handler with custom timeout
builder.Services.AddHttpClient<ICatalogClient, CatalogHttpClient>()
    .AddStandardResilienceHandler(o => o.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(15));

// DB: named non-HTTP pipeline
builder.Services.AddResiliencePipeline("db", pipeline =>
    pipeline.AddRetry(new RetryStrategyOptions
    {
        MaxRetryAttempts = 2, UseJitter = true,
        ShouldHandle = new PredicateBuilder().Handle<TimeoutException>()
    }));
```

## Common Follow-up Questions

- What is the `AddStandardHedgingHandler()` — how does request hedging differ from retry?
- How do you configure resilience strategies from `appsettings.json` instead of code?
- How do you test resilience pipelines — how do you inject faults in unit/integration tests?
- What is `ResilienceContextPool` and why should you use it for high-throughput scenarios?
- How does `AddResilienceHandler` differ from `AddPolicyHandler` in Polly v7?

## Common Mistakes / Pitfalls

- **Using AddPolicyHandler (Polly v7 API) in .NET 8**: `Polly.Extensions.Http` and `AddPolicyHandler` is the Polly v7 API. .NET 8 uses `Microsoft.Extensions.Http.Resilience` with `AddResilienceHandler`. Don't mix v7 and v8 APIs.
- **Standard handler retry on POST**: the standard handler retries on 5xx for all HTTP methods including POST. POST is not idempotent — configure `ShouldRetryOnPost = false` or exclude POST from retry via `ShouldHandle` predicate.
- **Forgetting to call `AddHttpClient` before `AddResilienceHandler`**: `AddResilienceHandler` is an extension on `IHttpClientBuilder` — it requires an existing `AddHttpClient` registration.
- **Per-call timeouts longer than total timeout**: setting `AttemptTimeout = 15s` and `TotalTimeout = 10s` is contradictory — per-call timeout should always be shorter than total timeout.

## References

- [Microsoft.Extensions.Http.Resilience — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/core/resilience/http-resilience)
- [Polly v8 migration guide](https://www.thepollyproject.org/2023/03/13/polly-v8-is-here/) (verify URL)
- [See: resilience-patterns-overview.md](./resilience-patterns-overview.md)
- [See: retry-pattern-design.md](./retry-pattern-design.md)
- [See: circuit-breaker-design.md](./circuit-breaker-design.md)
