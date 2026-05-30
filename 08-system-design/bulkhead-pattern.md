# Bulkhead Pattern

**Category:** System Design / Performance
**Difficulty:** Middle
**Tags:** `bulkhead`, `isolation`, `polly`, `thread-pool`, `resource-limits`, `resilience`

## Question

> What is the bulkhead pattern? Why is it important for resilience? How do you implement it in .NET using Polly?

- What does the "bulkhead" metaphor mean and what problem does it solve?
- How is bulkhead different from circuit breaking?

## Short Answer

The bulkhead pattern isolates parts of a system so that a failure in one part cannot exhaust resources (threads, connections, memory) needed by others — just as a ship's bulkheads prevent flooding in one compartment from sinking the entire vessel. In a web service, a slow downstream dependency can exhaust the shared thread pool if every request blocks waiting for it; a bulkhead allocates a fixed number of concurrent slots to each dependency, so other requests continue to be served when one dependency is slow. Circuit breaking stops calling a failing service; bulkheading limits how many concurrent calls can be in-flight to any one dependency.

## Detailed Explanation

### The Problem: Shared Resource Exhaustion

Imagine a service that calls two downstreams: `InventoryService` (fast, <10ms) and `ReportingService` (slow, sometimes 5s).

```
Thread pool: 100 threads

Scenario: ReportingService starts being slow (5s per call)
→ 20 req/s × 5s = 100 concurrent blocked threads
→ Thread pool exhausted
→ InventoryService calls also queued — can't be served
→ Entire service goes down, even though Inventory is fine
```

A bulkhead limits ReportingService to 10 concurrent slots. Even if all 10 are blocked:
- 90 threads remain free for InventoryService and other calls.
- ReportingService callers get fast 503s instead of waiting.
- Service stays alive.

### Bulkhead vs Circuit Breaker

| | Bulkhead | Circuit Breaker |
|--|---------|----------------|
| Triggers on | Concurrency limit exceeded | Failure rate threshold |
| Behaviour | Rejects excess concurrent calls | Stops all calls during open state |
| Goal | Isolate resource exhaustion | Give failing service recovery time |
| Complements | Circuit breaker (use both together) | Bulkhead (use both together) |

They work together: bulkhead limits concurrent exposure; circuit breaker reacts to persistent failure.

### Polly v8 Bulkhead (`ConcurrencyLimiter`)

In Polly v8 (`Microsoft.Extensions.Resilience`), bulkhead is called `ConcurrencyLimiter`:

```csharp
using Microsoft.Extensions.Http.Resilience;
using Polly;

// Per-downstream isolation via named HttpClient resilience pipelines
builder.Services.AddHttpClient("inventory-service")
    .AddResilienceHandler("inventory", pipeline =>
    {
        // Bulkhead: max 20 concurrent calls to Inventory; no queue
        pipeline.AddConcurrencyLimiter(new ConcurrencyLimiterOptions
        {
            PermitLimit = 20,
            QueueLimit  = 0,  // fail immediately when limit reached (no waiting queue)
        });
        pipeline.AddCircuitBreaker(new CircuitBreakerStrategyOptions<HttpResponseMessage>
        {
            FailureRatio      = 0.5,
            SamplingDuration  = TimeSpan.FromSeconds(20),
            MinimumThroughput = 10,
            BreakDuration     = TimeSpan.FromSeconds(15),
        });
        pipeline.AddTimeout(TimeSpan.FromSeconds(3));
    });

builder.Services.AddHttpClient("reporting-service")
    .AddResilienceHandler("reporting", pipeline =>
    {
        // Tighter bulkhead for slow reporting service — protects thread pool
        pipeline.AddConcurrencyLimiter(new ConcurrencyLimiterOptions
        {
            PermitLimit = 5,   // only 5 concurrent calls; rest get immediate 503
            QueueLimit  = 10,  // small queue before failing
        });
        pipeline.AddTimeout(TimeSpan.FromSeconds(10));
    });
```

### Thread Pool Partitioning (Heavyweight Bulkhead)

For CPU-intensive or truly isolated work, use a dedicated `SemaphoreSlim` to gate concurrency:

```csharp
public sealed class ReportingService
{
    // Hard cap on concurrent reports — won't exhaust shared thread pool
    private static readonly SemaphoreSlim _semaphore = new(5, 5);

    public async Task<Report> GenerateAsync(ReportRequest request, CancellationToken ct)
    {
        if (!await _semaphore.WaitAsync(TimeSpan.Zero, ct))
            throw new BulkheadRejectedException("Report generation capacity exceeded");

        try
        {
            return await DoGenerateAsync(request, ct);
        }
        finally
        {
            _semaphore.Release();
        }
    }
}
```

`TimeSpan.Zero` gives an immediate rejection (non-blocking) when the semaphore is full — fast failure, no thread waste.

### Bulkhead for Database Connections

The database connection pool is itself a bulkhead: `Max Pool Size` limits how many concurrent DB queries any one service can have in-flight. The bulkhead pattern applied at the application layer ensures separate logical operations don't compete for those connections:

```csharp
// Two separate semaphores for two independent DB operation groups
private static readonly SemaphoreSlim _readSemaphore  = new(30, 30); // 30 concurrent reads
private static readonly SemaphoreSlim _writeSemaphore = new(10, 10); // 10 concurrent writes

// Heavy write batches can't starve read queries
```

### Bulkhead + Fallback

A bulkhead rejection is most useful when paired with a fallback:

```csharp
pipeline.AddFallback(new FallbackStrategyOptions<Report>
{
    ShouldHandle = args => args.Outcome.Exception is BulkheadRejectedException
        ? PredicateResult.True()
        : PredicateResult.False(),
    FallbackAction = _ => ValueTask.FromResult(Report.Empty("Service busy, try later")),
});
```

> **Warning:** A bulkhead with a large queue (`QueueLimit = 1000`) is almost as bad as no bulkhead — the queue just delays the failure and increases memory pressure. Keep `QueueLimit` small or zero; rely on client retry/backoff to handle rejection gracefully.

## Code Example

```csharp
// Full isolation example: three downstream services with independent bulkheads
using Microsoft.Extensions.Http.Resilience;

namespace Orders;

public static class HttpClientRegistrations
{
    public static IServiceCollection AddIsolatedClients(this IServiceCollection services)
    {
        // Fast critical service — wide bulkhead, tight timeout
        services.AddHttpClient<IInventoryClient, InventoryHttpClient>()
            .AddResilienceHandler("inventory", p =>
            {
                p.AddConcurrencyLimiter(permitLimit: 50, queueLimit: 0);
                p.AddCircuitBreaker(new() { FailureRatio = 0.3, MinimumThroughput = 20,
                    SamplingDuration = TimeSpan.FromSeconds(10), BreakDuration = TimeSpan.FromSeconds(10) });
                p.AddTimeout(TimeSpan.FromMilliseconds(500));
            });

        // Slow non-critical service — narrow bulkhead, longer timeout, fallback
        services.AddHttpClient<IRecommendationsClient, RecommendationsHttpClient>()
            .AddResilienceHandler("recommendations", p =>
            {
                p.AddFallback(new FallbackStrategyOptions<HttpResponseMessage>
                {
                    ShouldHandle = args => ValueTask.FromResult(
                        args.Outcome.Exception is not null),
                    FallbackAction = _ => ValueTask.FromResult(
                        new HttpResponseMessage(HttpStatusCode.OK)
                        { Content = JsonContent.Create(Array.Empty<string>()) }),
                });
                p.AddConcurrencyLimiter(permitLimit: 5, queueLimit: 5);
                p.AddTimeout(TimeSpan.FromMilliseconds(150));
            });

        // Payment — critical, zero queue (fail fast rather than queue)
        services.AddHttpClient<IPaymentClient, PaymentHttpClient>()
            .AddResilienceHandler("payments", p =>
            {
                p.AddConcurrencyLimiter(permitLimit: 20, queueLimit: 0);
                p.AddTimeout(TimeSpan.FromSeconds(5));
            });

        return services;
    }
}
```

## Common Follow-up Questions

- How do you choose the right `PermitLimit` value for a bulkhead?
- What is the difference between a bulkhead at the application layer vs a connection pool at the infrastructure layer?
- How do you monitor bulkhead rejection rate in Prometheus?
- If a service is protected by both a bulkhead and a circuit breaker, in which order do they fire?
- How does Polly v8's `AddConcurrencyLimiter` differ from Polly v7's `BulkheadAsync`?

## Common Mistakes / Pitfalls

- **One shared bulkhead for all downstreams**: the point of bulkheads is isolation — if all downstreams share one semaphore, a slow service still starves fast ones.
- **Large queue limit**: `QueueLimit = 1000` lets 1000 requests wait (potentially for minutes), consuming memory and returning stale responses; keep queues tiny.
- **No metric on bulkhead rejections**: a bulkhead that silently drops 20% of requests looks like a success rate issue; count rejections and alert.
- **Applying bulkhead to CPU-bound operations without a worker thread limit**: a `SemaphoreSlim` limits concurrency but doesn't isolate CPU; use `Task.Run` with a custom scheduler for CPU work.
- **Not combining with timeout**: a bulkhead without a timeout means slots are held indefinitely by hung requests, quickly filling the small permit pool.

## References

- [Bulkhead pattern — Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/bulkhead)
- [Polly v8 Concurrency Limiter](https://www.pollydocs.org/strategies/concurrency-limiter.html)
- [Release It! — Michael Nygard (Chapter: Bulkheads)](https://pragprog.com/titles/mnee2/release-it-second-edition/)
- [See: circuit-breaker-pattern.md](./circuit-breaker-pattern.md)
- [See: graceful-degradation-patterns.md](./graceful-degradation-patterns.md)
