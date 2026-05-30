# Resilience Patterns Overview

**Category:** Architecture / Resilience
**Difficulty:** 🟢 Junior
**Tags:** `resilience`, `retry`, `circuit-breaker`, `timeout`, `bulkhead`, `fallback`, `Polly`, `failure-modes`

## Question

> What are the core resilience patterns for distributed systems? Give a brief description of retry, circuit breaker, timeout, bulkhead, and fallback — when each applies and how they relate to each other.

## Short Answer

Resilience patterns prevent transient failures from cascading into system-wide outages. **Retry**: automatically re-attempt a failed operation (for transient failures). **Circuit breaker**: stop attempting calls to a failing service until it recovers (prevents overloading a failing dependency). **Timeout**: limit how long you'll wait for a response (prevents resource exhaustion from hung calls). **Bulkhead**: isolate resources so failure in one area doesn't starve others. **Fallback**: return a degraded response when the primary path fails (graceful degradation). In .NET 8, all these are implemented via `Microsoft.Extensions.Resilience` (Polly v8 under the hood).

## Detailed Explanation

### Retry Pattern

```
Problem: Dependency temporarily unavailable (transient network glitch, 503 under load)
Solution: Re-attempt the operation with a delay
Use for: Idempotent operations (GET, read-only, or business-idempotent writes)
Don't use: Non-idempotent operations without idempotency keys (POST creating a new order)

Classic mistake: Linear retry (1s, 1s, 1s) → thundering herd when service recovers
Best practice: Exponential backoff + jitter:
  Retry 1: wait ~1s ± random jitter
  Retry 2: wait ~2s ± random jitter
  Retry 3: wait ~4s ± random jitter
```

### Circuit Breaker Pattern

```
Problem: Service is down; every call fails immediately, wasting resources and adding latency
Solution: Track failure rate; after threshold exceeded, "open" the circuit
  → Fast-fail calls without attempting them (no latency, no resource waste)
  → After a recovery window, "half-open" → probe with one call
  → If probe succeeds: close circuit (back to normal)
  → If probe fails: re-open circuit

States:
  Closed  → normal operation, requests pass through
  Open    → fast-fail all requests (no attempt to call service)
  Half-Open → allow one probe request to test service health
```

### Timeout Pattern

```
Problem: Dependency is slow but not failing; threads/connections pile up waiting
Solution: Limit wait time per call to avoid exhausting upstream resources

Critical rule: Set timeout shorter than upstream timeouts
  Your API: 10 second timeout
  → calls DB (5s timeout) → calls payment service (3s timeout)
  Cascading: if payment service is slow, it consumes your thread for up to 10s per request
  → Under load: thread pool exhaustion → your service goes down
```

### Bulkhead Pattern

```
Problem: One slow dependency (e.g., email service) exhausts all threads, affecting
         all other operations (e.g., order lookups via fast DB queries)
Solution: Isolate resources (semaphores, thread pools) per dependency type
  Email service: max 10 concurrent calls
  Order DB: max 50 concurrent calls
  → Email service failure can't steal all threads from Order DB
```

### Fallback Pattern

```
Problem: Primary service unavailable — return an error to the user
Solution: Return a degraded response from a secondary source or return a cached value

Examples:
  - Product service unavailable → return cached product catalog
  - Recommendation service down → return "popular items" default list
  - Fraud check service down → allow transaction below threshold, flag for review

Principle: Every fallback is a business decision — discuss with stakeholders
  "What should the system do when X is unavailable?"
```

### Pattern Composition

```
Typical Polly v8 resilience pipeline:
  [Request] → Timeout → Retry (with CB check) → Circuit Breaker → [Dependency]

Execution order (innermost = last applied):
  1. Timeout wraps everything      (outermost, sets max total time)
  2. Circuit breaker checks state  (fast-fails if open)
  3. Retry applies on failure      (re-attempts with backoff)
  4. Actual HTTP call

Not in this pipeline:
  Bulkhead: separate SemaphoreSlim per dependency (orthogonal to the above)
  Fallback: applied as catch handler after pipeline exhausted retries
```

## Code Example

```csharp
// .NET 8: Microsoft.Extensions.Resilience (wraps Polly v8)
// NuGet: Microsoft.Extensions.Resilience

builder.Services.AddHttpClient<IInventoryClient, InventoryHttpClient>()
    .AddResilienceHandler("inventory", pipeline =>
    {
        // Applied innermost-to-outermost: retry → circuit breaker → timeout
        pipeline
            .AddRetry(new HttpRetryStrategyOptions
            {
                MaxRetryAttempts = 3,
                Delay = TimeSpan.FromMilliseconds(500),
                BackoffType = DelayBackoffType.Exponential,
                UseJitter = true,
                ShouldHandle = args => ValueTask.FromResult(
                    args.Outcome.Exception is HttpRequestException ||
                    args.Outcome.Result?.StatusCode == HttpStatusCode.ServiceUnavailable)
            })
            .AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
            {
                FailureRatio = 0.5,          // ← open when 50% of calls fail
                SamplingDuration = TimeSpan.FromSeconds(30),
                MinimumThroughput = 10,      // ← need ≥10 calls before evaluating
                BreakDuration = TimeSpan.FromSeconds(30)
            })
            .AddTimeout(TimeSpan.FromSeconds(5));
    });
```

## Common Follow-up Questions

- What is the difference between Polly v7 and Polly v8 / `Microsoft.Extensions.Resilience`?
- When should you put resilience policies on the client vs in the service mesh vs both?
- How do you test resilience policies to verify they fire correctly?
- What is the relationship between resilience patterns and health checks?
- How do idempotency keys allow retry of otherwise non-idempotent operations?

## Common Mistakes / Pitfalls

- **Retrying non-idempotent operations**: retrying `POST /orders` without an idempotency key can create duplicate orders. Only retry operations that are idempotent or protected by idempotency keys.
- **Retry without circuit breaker**: unlimited retries against a failing service can amplify load by 3x (original + 3 retries), making recovery harder. Always pair retry with a circuit breaker.
- **Bulkhead + service mesh double retry**: if Polly retries 3x and the service mesh also retries 3x, a single request becomes 9 attempts. Coordinate retry policies across layers.
- **Fallback that hides failures**: a fallback that silently returns empty data prevents users from knowing the system is degraded, making debugging impossible. Log, alert, and surface degradation clearly.

## References

- [Microsoft.Extensions.Resilience — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/core/resilience/)
- [Polly v8 documentation](https://www.thepollyproject.org/)
- [Cloud Design Patterns — resilience — Azure Docs](https://learn.microsoft.com/en-us/azure/architecture/patterns/category/resiliency)
- [See: retry-pattern-design.md](./retry-pattern-design.md)
- [See: circuit-breaker-design.md](./circuit-breaker-design.md)
