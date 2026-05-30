# Circuit Breaker Pattern

**Category:** System Design / Rate Limiting & Resilience
**Difficulty:** 🟡 Middle
**Tags:** `circuit-breaker`, `Polly`, `resilience`, `fault-tolerance`, `half-open`, `timeout`, `retry`, `Microsoft.Extensions.Resilience`

## Question

> What is the circuit breaker pattern and why is it used in distributed systems? Describe the three states (Closed, Open, Half-Open) and how to implement it in .NET with Polly or `Microsoft.Extensions.Resilience`.

## Short Answer

A circuit breaker wraps calls to an external dependency (HTTP service, DB, broker). When the dependency starts failing, the circuit "opens" and subsequent calls are rejected immediately without attempting the underlying call — preventing the caller from wasting resources waiting for a service that's clearly down. After a cooldown, the circuit moves to "half-open": it allows a limited trial request through to test recovery. If it succeeds, the circuit closes; if it fails again, it re-opens. This prevents cascading failures, reduces latency during outages, and gives failing services time to recover.

## Detailed Explanation

### The Problem Without Circuit Breaker

```
Payment Service calls Tax Service (timeout: 30s)

Tax Service is DOWN.

Without circuit breaker:
  Each request waits 30s for timeout
  Thread pool fills with waiting threads
  Payment Service OOMs / becomes unresponsive
  Order Service → Payment Service also starts timing out
  ← cascading failure up the call chain
```

A circuit breaker makes these calls **fail-fast** instead of slow — preserving threads and capacity.

### The Three States

```
          failure threshold                  trial request
CLOSED ──────────────────────► OPEN ───────────────────────► HALF-OPEN
  ▲         (normal)                       (cooldown)                │
  │                                                    success ──────┘
  └────────────────────────────────────────────────────
                      failure (re-open)
```

| State | Behaviour | Transition |
|-------|-----------|-----------|
| **Closed** | Calls pass through normally; failure count tracked | → Open when failure rate ≥ threshold |
| **Open** | All calls rejected immediately (`BrokenCircuitException`) | → Half-open after break duration |
| **Half-Open** | A limited number of trial calls allowed through | → Closed on success; → Open on failure |

**Configurable parameters**:
- `FailureThreshold`: e.g., 50% failure rate in last 10 calls.
- `MinimumThroughput`: don't open on 1 failure out of 1 call (noise). Require e.g. 10 minimum calls.
- `BreakDuration`: how long to stay Open before testing (e.g., 30 seconds).
- `HalfOpenAttempts`: how many trial calls in Half-Open state.

### Circuit Breaker vs Retry

| Pattern | Use When | Risk |
|---------|---------|------|
| **Retry** | Transient failures (network blip, transient 503) | Can amplify load if service is overloaded — retries make it worse |
| **Circuit Breaker** | Sustained failures (service down for seconds/minutes) | Fail-fast; don't retry at all while open |

**Combine them**: retry 1–2 times for transient errors; if the circuit opens, stop retrying entirely.

### Polly v8 + Microsoft.Extensions.Resilience (.NET 8)

.NET 8 introduced `Microsoft.Extensions.Resilience` (built on Polly v8), which provides a `ResiliencePipeline` combining retry, circuit breaker, timeout, and hedging in a single fluent API.

### Fallback Strategies When Circuit Is Open

When the circuit is open, instead of returning an error, you can:
- Serve a cached response (`stale-while-revalidate`).
- Return a degraded partial response.
- Queue the request for retry later.
- Return a default "service unavailable" response with `Retry-After`.

## Code Example

```csharp
// .NET 8 — Circuit breaker with Microsoft.Extensions.Resilience (Polly v8)

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Http.Resilience;
using Polly;
using Polly.CircuitBreaker;

var builder = WebApplication.CreateBuilder(args);

// ── Option A: Standard HTTP resilience (retry + circuit breaker) ──────
builder.Services.AddHttpClient("tax-service", c =>
    c.BaseAddress = new Uri("https://tax.internal"))
    .AddStandardResilienceHandler(o =>
    {
        // Retry: 3 retries with exponential back-off
        o.Retry.MaxRetryAttempts = 3;
        o.Retry.BackoffType      = DelayBackoffType.Exponential;

        // Circuit breaker: open when 50% failure rate in 30s window
        o.CircuitBreaker.FailureRatio                 = 0.5;
        o.CircuitBreaker.SamplingDuration             = TimeSpan.FromSeconds(30);
        o.CircuitBreaker.MinimumThroughput            = 10;
        o.CircuitBreaker.BreakDuration                = TimeSpan.FromSeconds(30);
    });

// ── Option B: Custom pipeline with fallback ───────────────────────────
builder.Services.AddResiliencePipeline<string, decimal>("tax-fallback", (pipeline, ctx) =>
{
    pipeline
        // 1. Fallback: serve cached value when circuit is open
        .AddFallback(new FallbackStrategyOptions<decimal>
        {
            ShouldHandle = args => args.Outcome.Exception is BrokenCircuitException
                                || args.Outcome.Exception is TimeoutRejectedException,
            FallbackAction = async args =>
            {
                var cache = ctx.ServiceProvider.GetRequiredService<IMemoryCache>();
                var cachedRate = cache.TryGetValue("tax-rate", out decimal rate) ? rate : 0.15m;
                return Outcome.FromResult(cachedRate);
            }
        })
        // 2. Timeout: don't wait more than 5s for tax service
        .AddTimeout(TimeSpan.FromSeconds(5))
        // 3. Retry: 2 retries for transient errors (not circuit open)
        .AddRetry(new RetryStrategyOptions<decimal>
        {
            ShouldHandle = args => args.Outcome.Exception is HttpRequestException,
            MaxRetryAttempts = 2,
            Delay = TimeSpan.FromMilliseconds(500)
        })
        // 4. Circuit breaker: open after 5 failures in 60s
        .AddCircuitBreaker(new CircuitBreakerStrategyOptions<decimal>
        {
            FailureRatio      = 0.6,
            SamplingDuration  = TimeSpan.FromSeconds(60),
            MinimumThroughput = 5,
            BreakDuration     = TimeSpan.FromSeconds(30),
            // Called when circuit opens — good place to log/alert
            OnOpened = args =>
            {
                Console.WriteLine($"Circuit OPEN: {args.BreakDuration.TotalSeconds}s break");
                return ValueTask.CompletedTask;
            },
            OnClosed = _ =>
            {
                Console.WriteLine("Circuit CLOSED: service recovered");
                return ValueTask.CompletedTask;
            },
            OnHalfOpened = _ =>
            {
                Console.WriteLine("Circuit HALF-OPEN: testing recovery");
                return ValueTask.CompletedTask;
            }
        });
});

var app = builder.Build();

// ── Using the HTTP client with built-in resilience ────────────────────
app.MapGet("/orders/{id}/tax", async (
    int id,
    IHttpClientFactory clientFactory,
    CancellationToken ct) =>
{
    var client = clientFactory.CreateClient("tax-service");
    try
    {
        var rate = await client.GetFromJsonAsync<decimal>($"/rates/{id}", ct);
        return Results.Ok(new { orderId = id, taxRate = rate });
    }
    catch (BrokenCircuitException)
    {
        // Circuit is open — respond with degraded info
        return Results.Ok(new { orderId = id, taxRate = 0.15m, degraded = true });
    }
});

// ── Using the custom pipeline with fallback ───────────────────────────
app.MapGet("/orders/{id}/tax/v2", async (
    int id,
    ResiliencePipelineProvider<string> pipelineProvider,
    IHttpClientFactory clientFactory,
    CancellationToken ct) =>
{
    var pipeline = pipelineProvider.GetPipeline<decimal>("tax-fallback");
    var taxRate  = await pipeline.ExecuteAsync(async token =>
    {
        var client = clientFactory.CreateClient("tax-service");
        return await client.GetFromJsonAsync<decimal>($"/rates/{id}", token);
    }, ct);

    return Results.Ok(new { orderId = id, taxRate });
});

app.Run();

// ── Missing using for IMemoryCache ────────────────────────────────────
using Microsoft.Extensions.Caching.Memory;
```

## Common Follow-up Questions

- How do you expose circuit breaker state (open/closed/half-open) as a health check endpoint?
- What is "bulkhead isolation" and how does it combine with circuit breakers to limit blast radius?
- How does Polly's `HedgingStrategy` differ from retry in terms of latency tail reduction?
- How do you test circuit breaker behaviour in integration tests without actually taking a service down?
- When should the circuit breaker be at the HTTP client level vs at a higher service layer?
- What is the difference between a circuit breaker and a timeout? Can they conflict?

## Common Mistakes / Pitfalls

- **Setting `MinimumThroughput` too low**: a circuit breaker that opens on 1 failure out of 1 attempt (100% rate) is too sensitive. Set a minimum of 5–10 calls to avoid opening on noise.
- **Not handling `BrokenCircuitException`**: when the circuit is open, Polly throws `BrokenCircuitException`. If your code doesn't catch it (or the fallback doesn't handle it), users get a generic 500 instead of a graceful degraded response.
- **Sharing one circuit breaker instance across all users**: if one user triggers the threshold, all users are blocked (circuit opens globally). Consider per-dependency or per-resource-type circuit breakers rather than one global one.
- **Circuit breaker on idempotent reads but not writes**: opening the circuit on GET failures is safe. Opening it on POST failures may mean pending writes are lost. Use separate pipelines for reads and writes.
- **`BreakDuration` shorter than service restart time**: if your downstream service takes 60s to restart but `BreakDuration` is 10s, the circuit opens, waits 10s, half-opens, immediately fails again (service still down), re-opens — tight cycling that wastes Half-Open trial requests and never gives the service enough time to recover.
- **Logging circuit state changes in hot paths**: `OnOpened`/`OnClosed` callbacks should log at WARN/ERROR level and ideally emit a metric. Don't do expensive work (DB writes, synchronous I/O) in these callbacks — they run on the hot request path.

## References

- [Microsoft.Extensions.Resilience — Microsoft Learn](https://learn.microsoft.com/dotnet/core/resilience/http-resilience)
- [Polly v8 — GitHub](https://github.com/App-vNext/Polly)
- [Polly — circuit breaker strategy](https://www.pollydocs.org/strategies/circuit-breaker)
- [Azure Architecture Center — Circuit Breaker pattern](https://learn.microsoft.com/azure/architecture/patterns/circuit-breaker)
- [See: fault-tolerance-vs-high-availability.md](./fault-tolerance-vs-high-availability.md) — resilience patterns overview
