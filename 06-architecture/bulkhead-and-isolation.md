# Bulkhead and Isolation

**Category:** Architecture / Microservices
**Difficulty:** 🔴 Senior
**Tags:** `bulkhead`, `isolation`, `Polly`, `resilience`, `thread-pool`, `semaphore`, `failure-isolation`

## Question

> What is the Bulkhead pattern? How do you implement resource isolation between services in .NET using Polly, and what are the thread-pool vs semaphore-based bulkhead approaches?

## Short Answer

The **Bulkhead pattern** partitions resources (threads, connections, semaphores) so that a failure or overload in one partition doesn't exhaust resources for the rest of the system — named after ship bulkheads that contain flooding to one compartment. In .NET, Polly 8 implements bulkheads via `RateLimiter` or `Semaphore` isolation: limit concurrent calls to a downstream service so that its slowness doesn't consume all available threads in your service. Thread-pool isolation (like Hystrix) is complex in .NET; semaphore-based isolation with `ConcurrencyLimiter` is simpler and effective for I/O-bound calls.

## Detailed Explanation

### The Problem Without Bulkheads

```
Without isolation:
  OrderService calls:
    - InventoryService (usually 50ms, occasionally 10s under load)
    - PaymentService   (always 200ms)
    - NotificationService (fast, rarely used)

  Scenario: InventoryService becomes slow (10s responses)
    - All 100 ThreadPool threads are waiting for InventoryService
    - PaymentService calls start queuing — no threads available
    - OrderService appears "down" even though it's the dependency that's slow

With bulkhead:
  InventoryService gets max 10 concurrent calls (semaphore limit = 10)
  PaymentService gets max 20 concurrent calls
  Even if InventoryService is slow, only 10 threads are tied up
  PaymentService still has threads available
```

### Polly 8 Bulkhead with ConcurrencyLimiter

```csharp
// .NET 8 Polly resilience pipeline with concurrency limiter (bulkhead)
builder.Services.AddHttpClient("inventory-service")
    .AddResilienceHandler("inventory-bulkhead", builder =>
    {
        // Bulkhead: max 10 concurrent calls to inventory; queue max 20 waiting
        builder.AddConcurrencyLimiter(new ConcurrencyLimiterOptions
        {
            PermitLimit = 10,
            QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
            QueueLimit = 20
        });

        // Combine with retry and circuit breaker
        builder.AddRetry(new HttpRetryStrategyOptions
        {
            MaxRetryAttempts = 3,
            Delay = TimeSpan.FromMilliseconds(100)
        });

        builder.AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
        {
            SamplingDuration = TimeSpan.FromSeconds(30),
            FailureRatio = 0.5,
            BreakDuration = TimeSpan.FromSeconds(10)
        });

        builder.AddTimeout(TimeSpan.FromSeconds(5));
    });
```

### Semaphore-Based Isolation

For manual implementation or non-HttpClient scenarios:

```csharp
public class IsolatedInventoryClient(HttpClient http) : IInventoryClient
{
    // Separate semaphores per downstream dependency
    private static readonly SemaphoreSlim _inventorySemaphore = new(initialCount: 10, maxCount: 10);
    private static readonly SemaphoreSlim _paymentSemaphore = new(initialCount: 20, maxCount: 20);

    public async Task<StockInfo?> CheckStockAsync(int productId, CancellationToken ct)
    {
        if (!await _inventorySemaphore.WaitAsync(TimeSpan.FromSeconds(1), ct))
        {
            _metrics.IncrementCounter("inventory.bulkhead.rejected");
            throw new BulkheadRejectedException("InventoryService bulkhead full");
        }

        try
        {
            return await http.GetFromJsonAsync<StockInfo>($"/api/stock/{productId}", ct);
        }
        finally
        {
            _inventorySemaphore.Release();
        }
    }
}
```

### Thread-Pool vs Semaphore Isolation

| | Thread-Pool Isolation | Semaphore Isolation |
|--|----------------------|---------------------|
| **Mechanism** | Dedicated thread pool per dependency | Semaphore limit on shared thread pool |
| **Complexity** | High — needs separate task schedulers | Low — `SemaphoreSlim` |
| **Overhead** | Context switching, thread management | Minimal |
| **Use case** | CPU-bound work isolation | I/O-bound calls (HTTP, DB) |
| **.NET support** | Complex, not built-in | Native (`SemaphoreSlim`) |
| **Polly 8** | Not supported natively | `ConcurrencyLimiter` |

> In .NET, thread-pool isolation (Hystrix-style) is rarely needed — .NET async/await uses the thread pool efficiently, and `SemaphoreSlim` provides effective bulkhead isolation for I/O-bound operations.

### Bulkhead Metrics and Alerting

```csharp
// Track bulkhead rejections to size limits correctly
builder.Services.AddResilienceEnricher(); // ← adds OpenTelemetry metrics for Polly

// Or manually track rejections in the semaphore-based approach
public async Task<StockInfo?> CheckStockAsync(int productId, CancellationToken ct)
{
    var entered = await _semaphore.WaitAsync(0, ct); // ← 0ms timeout = immediate reject
    if (!entered)
    {
        _meter.CreateCounter<int>("inventory.bulkhead.rejected")
            .Add(1, new TagList { { "service", "inventory" } });
        throw new BulkheadRejectedException("InventoryService concurrency limit exceeded");
    }
    // ...
}
```

## Code Example

```csharp
// Complete resilience pipeline per service with named clients
// Each external dependency gets its own pipeline + bulkhead

var resiliencePipelineOptions = new HttpStandardResilienceOptions
{
    TotalRequestTimeout = { Timeout = TimeSpan.FromSeconds(10) },
    Retry = new()
    {
        MaxRetryAttempts = 3,
        UseJitter = true,
        Delay = TimeSpan.FromMilliseconds(200)
    },
    CircuitBreaker = new()
    {
        SamplingDuration = TimeSpan.FromSeconds(30),
        FailureRatio = 0.5,
        BreakDuration = TimeSpan.FromSeconds(15)
    },
    AttemptTimeout = { Timeout = TimeSpan.FromSeconds(3) }
};

// InventoryService: strict bulkhead (slow service)
builder.Services.AddHttpClient("inventory")
    .AddStandardResilienceHandler(resiliencePipelineOptions)
    .AddResilienceHandler("inventory-bulkhead", b =>
        b.AddConcurrencyLimiter(permitLimit: 5, queueLimit: 10));

// PaymentService: looser bulkhead (critical, fast service)
builder.Services.AddHttpClient("payment")
    .AddStandardResilienceHandler(resiliencePipelineOptions)
    .AddResilienceHandler("payment-bulkhead", b =>
        b.AddConcurrencyLimiter(permitLimit: 25, queueLimit: 50));
```

## Common Follow-up Questions

- How do you size bulkhead limits — what metrics should drive the limits?
- What happens to callers when the bulkhead queue is full — should they fail fast or wait?
- How do you combine bulkhead isolation with circuit breaking?
- What is the difference between rate limiting and bulkhead isolation?
- How do you test bulkhead behavior in integration tests?

## Common Mistakes / Pitfalls

- **Same thread pool for all downstream calls**: not isolating slow dependencies means one slow service can exhaust threads for the entire service. Each external dependency should have its own semaphore limit.
- **Bulkhead limits too high**: a limit of 500 for a service that can only handle 50 concurrent requests provides no real isolation. Size based on the downstream service's known capacity.
- **No metrics on bulkhead rejections**: without monitoring rejection rates, you don't know if the bulkhead is misconfigured (too tight = lots of rejections, too loose = no protection).
- **Bulkhead for internal in-process calls**: bulkheads are for external I/O calls. Adding semaphore limits to in-memory repository calls or domain operations is needless overhead.

## References

- [Bulkhead pattern — Microsoft Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/bulkhead)
- [Polly v8 resilience strategies — GitHub](https://github.com/App-vNext/Polly/wiki/Bulkhead)
- [See: choreography-vs-orchestration.md](./choreography-vs-orchestration.md)
- [See: inter-service-communication.md](./inter-service-communication.md)
