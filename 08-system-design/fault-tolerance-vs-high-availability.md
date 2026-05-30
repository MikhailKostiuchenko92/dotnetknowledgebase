# Fault Tolerance vs High Availability

**Category:** System Design / Fundamentals
**Difficulty:** 🟡 Middle
**Tags:** `fault-tolerance`, `high-availability`, `graceful-degradation`, `bulkhead`, `circuit-breaker`, `resilience`

## Question

> What is the difference between fault tolerance and high availability? How do patterns like graceful degradation and the bulkhead pattern contribute to each? How do you implement these in an ASP.NET Core system?

## Short Answer

High availability (HA) means the system is up and responsive as close to 100% of the time as possible, typically through redundancy and fast failover. Fault tolerance means the system continues to function correctly even when components fail — it goes further than HA by defining *how* the system behaves under failure, not just whether it stays up. Graceful degradation lets a system return reduced-quality responses rather than complete failure; the bulkhead pattern isolates failures so one subsystem can't take down others.

## Detailed Explanation

### High Availability (HA)

HA focuses on **uptime**: minimising the time the system is unavailable.

- Achieved through: redundancy, failover, health checks, rolling deployments.
- Measured by: availability percentage (uptime / total time).
- Metric: MTBF (Mean Time Between Failures) and MTTR (Mean Time To Recover).

**Formula**: `Availability = MTBF / (MTBF + MTTR)`

To improve availability, you either make failures rarer (improve reliability) or recover faster (reduce MTTR).

### Fault Tolerance

Fault tolerance focuses on **correctness during failure**: the system continues serving correct (or gracefully degraded) responses even when components fail, without necessarily having zero downtime.

| | High Availability | Fault Tolerance |
|--|---|---|
| **Goal** | Minimise downtime | Continue operation during failure |
| **Approach** | Redundancy + fast failover | Redundancy + degraded-mode operation |
| **Failure response** | Switch to healthy replica | Return degraded response |
| **Example** | Active-passive DB failover | Serve cached data when DB is down |

A system can be highly available but not fault tolerant: it fails over in 30 seconds (HA), but during those 30 seconds it returns 500 errors (not fault tolerant). True fault tolerance means requests succeed even as failover happens.

### Graceful Degradation

Instead of failing completely, the system returns a **degraded but useful response**:

- Search results without personalisation if the recommendation engine is down.
- Checkout with stock check skipped (using last-known value) if inventory service is slow.
- Serve cached/stale data when the database is temporarily unreachable.
- Disable non-essential features via **feature flags** when under load.

Graceful degradation requires defining, for each dependency: "what is the acceptable fallback?"

### Bulkhead Pattern

Named after the watertight compartments on a ship — if one compartment floods, others don't. In software:

- Partition thread pools / connection pools / semaphores per dependency.
- If Service B's thread pool is exhausted (Service B is slow), requests to Service A still succeed because they use a separate pool.
- Without bulkheads, a single slow dependency consumes all shared threads → entire application degrades.

**In .NET with Polly:**
- `AddConcurrencyLimiter` (Polly v8) — limits concurrent calls to one dependency.
- Separate `HttpClient` instances per upstream service (separate connection pools).
- `SemaphoreSlim` for fine-grained resource limiting in application code.

### Circuit Breaker Pattern

Complements the bulkhead by **failing fast** when a dependency is clearly unhealthy:

1. **Closed**: normal operation; failures counted.
2. **Open**: failure threshold crossed; all requests fail immediately (no waiting for timeout). This prevents thread-pool exhaustion.
3. **Half-Open**: after `BreakDuration`, allows a probe request through. If it succeeds, closes the circuit; if it fails, re-opens.

[See: circuit-breaker-pattern.md](./circuit-breaker-pattern.md)

### Combining Patterns for Resilience

```
Request → Circuit Breaker → Bulkhead (concurrency limit) → Retry → Dependency
                ↓ (circuit open)
           Fallback (cached/degraded response)
```

This pipeline ensures:
1. If the dependency is healthy: retries handle transient errors.
2. If the dependency is slow: bulkhead caps thread consumption.
3. If the dependency is down: circuit opens, fallback activates immediately.

### Health Checks and Kubernetes Probes

Kubernetes uses three probe types that map to HA/fault-tolerance concerns:

| Probe | Purpose | Response on fail |
|-------|---------|-----------------|
| **Liveness** | Is the process alive? | Container restarted |
| **Readiness** | Is the pod ready to receive traffic? | Pod removed from Service endpoints |
| **Startup** | Has the app finished initialising? | Liveness/readiness probes deferred |

ASP.NET Core supports all three via `IHealthCheck` and `MapHealthChecks`. [See: health-checks-in-aspnet-core.md](./health-checks-in-aspnet-core.md)

## Code Example

```csharp
// Bulkhead + graceful degradation in ASP.NET Core
// .NET 8 — Microsoft.Extensions.Http.Resilience (Polly v8)

using Microsoft.Extensions.Http.Resilience;
using Microsoft.Extensions.Caching.Memory;
using Polly;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddMemoryCache();

// Separate HttpClient per dependency = separate connection pool (bulkhead at transport layer)
builder.Services.AddHttpClient("RecommendationService", c =>
    c.BaseAddress = new Uri("https://recommendations.internal/"))
.AddResilienceHandler("rec-pipeline", pipeline =>
{
    // Bulkhead: max 20 concurrent calls; excess queue depth 10, then reject immediately
    pipeline.AddConcurrencyLimiter(new ConcurrencyLimiterStrategyOptions
    {
        PermitLimit = 20,
        QueueLimit = 10
    });

    // Circuit breaker: open after 50% failure rate; stay open 15s
    pipeline.AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
    {
        FailureRatio = 0.5,
        SamplingDuration = TimeSpan.FromSeconds(20),
        MinimumThroughput = 5,
        BreakDuration = TimeSpan.FromSeconds(15)
    });

    // Timeout: don't let slow dependencies hold threads indefinitely
    pipeline.AddTimeout(TimeSpan.FromSeconds(2));
});

var app = builder.Build();

app.MapGet("/home", async (IHttpClientFactory factory, IMemoryCache cache) =>
{
    var products = await GetProductsFromDbAsync();   // assumed fast, no resilience needed here

    // Recommendations: non-essential — degrade gracefully if unavailable
    IEnumerable<string> recommendations;
    try
    {
        var client = factory.CreateClient("RecommendationService");
        var response = await client.GetFromJsonAsync<string[]>("/user/42/recommendations");
        recommendations = response ?? [];

        // Cache successful response for fallback
        cache.Set("rec:42", recommendations, TimeSpan.FromMinutes(5));
    }
    catch (Exception ex) when (ex is BrokenCircuitException or TaskCanceledException or HttpRequestException)
    {
        // Graceful degradation: serve stale cached recommendations or empty list
        recommendations = cache.TryGetValue("rec:42", out IEnumerable<string>? cached)
            ? cached!
            : ["Popular Product A", "Popular Product B"];   // generic fallback

        Console.WriteLine($"Recommendation service degraded: {ex.GetType().Name}");
    }

    return Results.Ok(new { Products = products, Recommendations = recommendations });
});

static Task<string[]> GetProductsFromDbAsync() =>
    Task.FromResult(new[] { "Product 1", "Product 2", "Product 3" });

app.Run();
```

## Common Follow-up Questions

- How does the bulkhead pattern interact with the ASP.NET Core thread pool and `async`/`await`?
- What is the difference between retry-with-backoff and a circuit breaker — when do you use each?
- How do you implement graceful degradation when the fallback itself might fail?
- What is a "thundering herd" problem, and how do circuit breakers and bulkheads mitigate it?
- How do Kubernetes liveness and readiness probes work together with circuit breakers?
- What does "cascading failure" mean, and which patterns prevent it?

## Common Mistakes / Pitfalls

- **Retrying without circuit breaker**: aggressive retries against a failing dependency amplify load, triggering cascading failure. Circuit breakers break the feedback loop.
- **Shared thread pool for all HTTP clients**: using a single `HttpClient` for all upstream services means one slow service exhausts threads for all. Use separate named `HttpClient` registrations.
- **Fallback that calls another failing service**: a fallback that depends on the same infrastructure as the primary doesn't help. Fallbacks should use cached data, defaults, or a different data path.
- **Setting retry count too high**: 3 retries with exponential backoff is usually correct. 10 retries on a 2-second timeout = 20 seconds blocked thread per request.
- **Not setting timeouts**: without explicit timeouts, a slow dependency can hold a thread indefinitely. Always set `HttpClient.Timeout` and pipeline-level timeout.
- **Confusing readiness and liveness probes**: liveness failure triggers a pod restart (disruptive); readiness failure only removes the pod from the load-balancer endpoint (graceful). Using the DB health check as liveness means a DB outage restarts every pod — exactly the wrong response.

## References

- [Microsoft.Extensions.Http.Resilience — .NET docs](https://learn.microsoft.com/dotnet/core/resilience/)
- [Polly — .NET resilience library](https://github.com/App-vNext/Polly)
- [Azure Architecture Center — Bulkhead pattern](https://learn.microsoft.com/azure/architecture/patterns/bulkhead)
- [Azure Architecture Center — Circuit Breaker pattern](https://learn.microsoft.com/azure/architecture/patterns/circuit-breaker)
- [Michael T. Nygard — Release It! (2nd ed.) — Chapter 4: Stability Patterns](https://pragprog.com/titles/mnee2/release-it-second-edition/)
