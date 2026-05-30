# Circuit Breaker Design

**Category:** Architecture / Resilience
**Difficulty:** 🟡 Middle
**Tags:** `circuit-breaker`, `Polly`, `ResiliencePipeline`, `Closed-Open-HalfOpen`, `failure-rate`, `fast-fail`

## Question

> Explain the circuit breaker pattern and its three states. How do you configure a circuit breaker in Polly v8 / `Microsoft.Extensions.Resilience` — what thresholds should you tune and why?

## Short Answer

A circuit breaker wraps calls to an external dependency, tracking failure rate. In **Closed** state (normal), calls pass through. When failures exceed a threshold, it transitions to **Open** — fast-failing all calls without attempting them, giving the failing service time to recover. After a recovery window, it enters **Half-Open** — allowing one probe call. Success closes the circuit; failure re-opens it. Key tuning: failure ratio threshold (0.5 = 50%), sampling window (30s), minimum call volume before evaluating (10), and break duration (30–60s). Use `HttpCircuitBreakerStrategyOptions` in `Microsoft.Extensions.Resilience`.

## Detailed Explanation

### State Machine

```
Circuit States:
  ┌───────────┐    Failure rate exceeds threshold    ┌──────────┐
  │  CLOSED   │ ─────────────────────────────────── ▶│  OPEN    │
  │(normal)   │                                       │(fast-fail│
  └───────────┘                                       └──────────┘
       ▲                                                     │
       │ Probe succeeds                    Break duration    │
       │                    ┌──────────┐    elapsed         │
       └────────────────────│ HALF-OPEN│ ◀─────────────────┘
                            │(one probe│
                            └──────────┘
                                  │
                                  │ Probe fails
                                  ▼
                              Back to OPEN

Key actions per state:
  CLOSED:    Record success/failure; evaluate threshold periodically
  OPEN:      Immediately throw BrokenCircuitException (no HTTP call made)
  HALF-OPEN: Allow one request through; monitor result
```

### Why Circuit Breakers Matter

```
Without circuit breaker:
  Payment service goes down at 14:00
  OrderService retries (3x) every failing request → 4x load amplification
  OrderService threads queue up waiting for timeouts (e.g., 30s per request)
  At 100 req/s: 100 × 30s = 3,000 thread-seconds of waste per second
  → OrderService exhausts thread pool, goes down too → cascading failure

With circuit breaker:
  Payment service fails → CB opens after 10 failures in 30s
  All subsequent calls fast-fail (<1ms) → OrderService threads freed immediately
  After 30s: CB half-opens → probes payment service
  Payment recovered → CB closes → normal operation resumes
  → Cascading failure prevented
```

### Polly v8 Circuit Breaker Configuration

```csharp
// Microsoft.Extensions.Http.Resilience — HTTP circuit breaker
builder.Services.AddHttpClient<IPaymentClient, PaymentHttpClient>()
    .AddResilienceHandler("payment", pipeline =>
    {
        pipeline.AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
        {
            // How many failures cause the circuit to open
            FailureRatio = 0.5,                    // ← 50% of calls must fail
            SamplingDuration = TimeSpan.FromSeconds(30), // ← within this window
            MinimumThroughput = 10,                // ← only evaluate if ≥10 calls in window
            //  ^ prevents circuit opening on 1 failure out of 1 call (100% but not meaningful)

            // How long to keep circuit open before trying again
            BreakDuration = TimeSpan.FromSeconds(30),

            // What counts as a failure
            ShouldHandle = new PredicateBuilder<HttpResponseMessage>()
                .Handle<HttpRequestException>()
                .HandleResult(r => r.StatusCode >= HttpStatusCode.InternalServerError),

            // Callbacks for monitoring
            OnOpened = args =>
            {
                var logger = args.Context.ServiceProvider.GetService<ILogger<IPaymentClient>>();
                logger?.LogError("Circuit opened for {Service}. Break for {Duration}s",
                    "PaymentService", args.BreakDuration.TotalSeconds);
                return ValueTask.CompletedTask;
            },
            OnClosed = args =>
            {
                args.Context.ServiceProvider.GetService<ILogger<IPaymentClient>>()
                    ?.LogInformation("Circuit closed for PaymentService — service recovered");
                return ValueTask.CompletedTask;
            }
        });
    });
```

### Handling Open Circuit in Application Code

```csharp
// Polly v8 throws IrrecoverableException wrapper; check for CircuitBrokenException
public async Task<PaymentResult> ProcessPaymentAsync(PaymentRequest request, CancellationToken ct)
{
    try
    {
        return await _paymentClient.ProcessAsync(request, ct);
    }
    catch (BrokenCircuitException)
    {
        // Circuit is open — payment service known to be down
        // Options: fail fast, queue for retry later, or degrade gracefully
        _metrics.IncrementCounter("payment.circuit_open");
        throw new ServiceUnavailableException(
            "Payment service is temporarily unavailable. Please retry in a moment.");
    }
}
```

### Tuning Guidelines

```
FailureRatio:
  0.5 (50%) is a sensible starting point
  Lower (0.3) = more sensitive, opens sooner (good for critical dependencies)
  Higher (0.7) = less sensitive, tolerates more failures (good for non-critical)

SamplingDuration:
  30s is typical for HTTP services
  Shorter (10s) = responds faster to bursts of failures
  Longer (60s) = smooths out spike failures, less false positives

MinimumThroughput:
  10–20 is typical; prevents false opens during low-traffic periods
  (If only 2 calls happen in 30s and both fail: 100% failure rate → circuit opens incorrectly)

BreakDuration:
  30–60s typical; should be long enough for service to recover
  Too short: oscillates between Open/Half-Open under sustained failure
  Too long: slow to recover when service comes back
  Adaptive: some implementations use exponential break duration
```

### Combined Retry + Circuit Breaker

```csharp
// Correct order: retry wraps circuit breaker
// Retry applies INSIDE circuit breaker check — if circuit is open, no retry occurs
pipeline
    .AddRetry(new HttpRetryStrategyOptions
    {
        MaxRetryAttempts = 3,
        Delay = TimeSpan.FromMilliseconds(500),
        BackoffType = DelayBackoffType.Exponential,
        UseJitter = true
    })
    .AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
    {
        FailureRatio = 0.5,
        MinimumThroughput = 10,
        BreakDuration = TimeSpan.FromSeconds(30)
    })
    .AddTimeout(TimeSpan.FromSeconds(5));
```

## Code Example

```csharp
// Full example: named resilience pipeline with CB for external payment service
builder.Services.AddResiliencePipeline("payment-resilience", (pipeline, ctx) =>
{
    var logger = ctx.ServiceProvider.GetRequiredService<ILogger<Program>>();

    pipeline
        .AddRetry(new RetryStrategyOptions
        {
            MaxRetryAttempts = 2,
            Delay = TimeSpan.FromMilliseconds(300),
            BackoffType = DelayBackoffType.Exponential,
            UseJitter = true,
            ShouldHandle = new PredicateBuilder().Handle<HttpRequestException>()
        })
        .AddCircuitBreaker(new CircuitBreakerStrategyOptions
        {
            FailureRatio = 0.5,
            SamplingDuration = TimeSpan.FromSeconds(30),
            MinimumThroughput = 5,
            BreakDuration = TimeSpan.FromSeconds(30),
            OnOpened = args => { logger.LogWarning("CB opened"); return ValueTask.CompletedTask; }
        });
});

// Usage in service:
public class PaymentService(ResiliencePipelineProvider<string> pipelineProvider)
{
    private readonly ResiliencePipeline _pipeline =
        pipelineProvider.GetPipeline("payment-resilience");

    public Task<PaymentResult> ProcessAsync(PaymentRequest req, CancellationToken ct)
        => _pipeline.ExecuteAsync(async t => await _httpClient.PostAsync<PaymentResult>("/pay", req, t), ct);
}
```

## Common Follow-up Questions

- How do you monitor circuit breaker state changes in production (metrics, alerting)?
- What is the difference between `BrokenCircuitException` and `IsolatedCircuitException` in Polly?
- How do you manually open or reset a circuit breaker for maintenance (forced circuit isolation)?
- How does a circuit breaker interact with Kubernetes health checks and readiness probes?
- When should you use a circuit breaker per-instance vs a shared circuit breaker across replicas?

## Common Mistakes / Pitfalls

- **No `MinimumThroughput`**: a circuit with `FailureRatio = 0.5` and no minimum will open after 1 failure out of 2 calls (50%) during startup or low traffic — false positive that disrupts normal operation.
- **Circuit breaker with very short `BreakDuration`**: a 1-second break duration causes rapid oscillation between Open and Half-Open when a service is under sustained failure, adding instability.
- **Sharing a circuit breaker across all endpoints of a service**: one slow endpoint (`/reports`) should not open the circuit for fast endpoints (`/orders`). Use per-endpoint or per-operation circuit breakers.
- **Not logging `OnOpened`/`OnClosed` events**: circuit breaker state changes are operational signals. Without logging, on-call engineers have no visibility into which circuit is open during an incident.

## References

- [Circuit Breaker pattern — Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker)
- [Polly v8 circuit breaker](https://www.thepollyproject.org/)
- [Microsoft.Extensions.Resilience](https://learn.microsoft.com/en-us/dotnet/core/resilience/)
- [See: resilience-patterns-overview.md](./resilience-patterns-overview.md)
- [See: retry-pattern-design.md](./retry-pattern-design.md)
