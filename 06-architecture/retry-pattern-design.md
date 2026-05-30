# Retry Pattern Design

**Category:** Architecture / Resilience
**Difficulty:** 🟢 Junior
**Tags:** `retry`, `exponential-backoff`, `jitter`, `idempotency`, `Polly`, `transient-faults`, `resilience`

## Question

> How do you design a robust retry policy? Explain exponential backoff, jitter, idempotency requirements, and how to configure retry with Polly v8 / `Microsoft.Extensions.Resilience`.

## Short Answer

A retry policy re-executes failed operations to handle transient failures. Key design decisions: **max retries** (3–5 is typical), **delay strategy** (exponential backoff doubles the wait each attempt), **jitter** (adds randomness to prevent synchronized retry storms when many clients retry at once), and **retry predicate** (only retry on specific error codes — e.g., 429, 503, 5xx; never on 400, 401, 404). **Idempotency is required**: only retry operations that are safe to execute multiple times. Use `Microsoft.Extensions.Http.Resilience` in .NET 8 for `IHttpClientFactory`-integrated retry pipelines.

## Detailed Explanation

### Why Exponential Backoff

```
Linear retry (every 1s):
  Client 1: t=0 fail, t=1 retry, t=2 retry → 3 attempts
  Client 2: t=0 fail, t=1 retry, t=2 retry → all clients retry in sync
  → Thundering herd: when service recovers, all clients hammer it simultaneously

Exponential backoff:
  Attempt 1: wait 1s
  Attempt 2: wait 2s
  Attempt 3: wait 4s
  Formula: delay = baseDelay * (2^retryAttempt)
  → Clients back off longer, giving service time to recover

Jitter (randomized delay):
  Each client adds random offset to the calculated delay
  Attempt 1: wait 1s ± 500ms random  (0.5s – 1.5s)
  Attempt 2: wait 2s ± 1s random     (1s – 3s)
  → Different clients retry at different times → no herd
```

### Idempotency Requirement

```
Safe to retry:
  ✅ GET /products/42           (read-only)
  ✅ PUT /orders/42/status      (PUT is idempotent by definition)
  ✅ POST /payments with Idempotency-Key: uuid  (key prevents duplicate processing)

Not safe to retry without protection:
  ❌ POST /orders               (creates new order on each attempt — duplicates!)
  ❌ POST /payments             (charges card twice!)
  ❌ DELETE /orders/42          (first call: 204 No Content; retry: 404 Not Found)

Idempotency key pattern:
  - Client generates a UUID before the first attempt
  - Sends: POST /orders with Idempotency-Key: f47ac10b-58cc-4372-a567-0e02b2c3d479
  - Server stores (key → result) for the request lifetime
  - Retry with same key → server returns stored result without re-executing
```

### Polly v8 Retry (via Microsoft.Extensions.Resilience)

```csharp
// NuGet: Microsoft.Extensions.Http.Resilience
builder.Services.AddHttpClient<IOrderClient, OrderHttpClient>()
    .AddStandardResilienceHandler(); // ← built-in sensible defaults: retry + CB + timeout

// Or custom retry-only pipeline:
builder.Services.AddHttpClient<IInventoryClient, InventoryClient>()
    .AddResilienceHandler("inventory-retry", pipeline =>
    {
        pipeline.AddRetry(new HttpRetryStrategyOptions
        {
            // Max 3 additional attempts (4 total including original)
            MaxRetryAttempts = 3,

            // Base delay for first retry
            Delay = TimeSpan.FromMilliseconds(500),

            // Exponential: 500ms, 1s, 2s (+ jitter)
            BackoffType = DelayBackoffType.Exponential,
            UseJitter = true,   // ← ALWAYS enable — prevents synchronized retries

            // Only retry on transient errors
            ShouldHandle = new PredicateBuilder<HttpResponseMessage>()
                .Handle<HttpRequestException>()
                .HandleResult(r => r.StatusCode is
                    HttpStatusCode.RequestTimeout or           // 408
                    HttpStatusCode.TooManyRequests or          // 429
                    HttpStatusCode.InternalServerError or      // 500
                    HttpStatusCode.BadGateway or               // 502
                    HttpStatusCode.ServiceUnavailable or       // 503
                    HttpStatusCode.GatewayTimeout),            // 504

            // Respect Retry-After header from 429 responses
            OnRetry = args =>
            {
                var logger = args.Context.ServiceProvider.GetService<ILogger<IInventoryClient>>();
                logger?.LogWarning("Retry attempt {Attempt} for {Operation} after {Delay}ms",
                    args.AttemptNumber, args.Context.OperationKey, args.RetryDelay.TotalMilliseconds);
                return ValueTask.CompletedTask;
            }
        });
    });
```

### Standalone Polly v8 (Non-HTTP)

```csharp
using Polly;
using Polly.Retry;

// Generic retry pipeline for any async operation
var retryPipeline = new ResiliencePipelineBuilder()
    .AddRetry(new RetryStrategyOptions
    {
        MaxRetryAttempts = 3,
        Delay = TimeSpan.FromMilliseconds(100),
        BackoffType = DelayBackoffType.Exponential,
        UseJitter = true,
        ShouldHandle = new PredicateBuilder()
            .Handle<SqlException>(ex => ex.IsTransient)
            .Handle<TimeoutException>()
    })
    .Build();

// Execute with retry
var result = await retryPipeline.ExecuteAsync(async ct =>
{
    return await dbRepository.GetOrderAsync(42, ct);
}, CancellationToken.None);
```

### Retry with Idempotency Key

```csharp
// Client: generate idempotency key before first attempt (persisted across retries)
public class OrderHttpClient(HttpClient http, ILogger<OrderHttpClient> log)
{
    public async Task<int> PlaceOrderAsync(PlaceOrderRequest request, CancellationToken ct)
    {
        // Generate key ONCE before the retry loop
        var idempotencyKey = Guid.NewGuid().ToString();

        return await _pipeline.ExecuteAsync(async token =>
        {
            using var req = new HttpRequestMessage(HttpMethod.Post, "/api/orders")
            {
                Content = JsonContent.Create(request),
                Headers = { { "Idempotency-Key", idempotencyKey } }
            };
            var response = await http.SendAsync(req, token);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadFromJsonAsync<int>(token) ?? 0;
        }, ct);
    }

    private readonly ResiliencePipeline _pipeline = new ResiliencePipelineBuilder()
        .AddRetry(new RetryStrategyOptions { MaxRetryAttempts = 3, UseJitter = true })
        .Build();
}
```

## Code Example

```csharp
// .NET 8 standard resilience handler (recommended default)
builder.Services.AddHttpClient<IProductCatalogClient, ProductCatalogClient>()
    .AddStandardResilienceHandler(options =>
    {
        // Tweak built-in defaults
        options.Retry.MaxRetryAttempts = 4;
        options.Retry.Delay = TimeSpan.FromMilliseconds(200);
        options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(15);
        // CircuitBreaker, Timeout, Retry are all included in standard handler
    });
```

## Common Follow-up Questions

- How do you handle `CancellationToken` cancellation vs transient failures in retry policies?
- What is `RetryAfterDelay` from Polly, and how does it respect `Retry-After` HTTP headers?
- How do you test retry policies to verify the correct number of attempts are made?
- How does the standard resilience handler (`AddStandardResilienceHandler`) configure each strategy?
- When should retries be performed on the client side vs the infrastructure layer (service mesh)?

## Common Mistakes / Pitfalls

- **Missing jitter**: a retry policy without jitter causes all instances of a service to retry at the same moment — amplifying load instead of spreading it. Always set `UseJitter = true`.
- **Retrying 400 Bad Request**: a 400 response is a client error — retrying it will always fail. Only retry server-side errors (5xx) and rate limits (429).
- **Infinite retries**: unlimited retries can exhaust caller resources and prevent recovery. Always set `MaxRetryAttempts`.
- **Sharing ResiliencePipeline across different retry budgets**: one pipeline configured for `InventoryService` (fast, max 2 retries) shouldn't be reused for `PaymentService` (slow, max 1 retry). Create separate pipelines per dependency.

## References

- [Retry pattern — Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/retry)
- [Microsoft.Extensions.Resilience — Retry](https://learn.microsoft.com/en-us/dotnet/core/resilience/http-resilience)
- [Polly v8 retry options](https://www.thepollyproject.org/2023/03/13/polly-v8-is-here/)  (verify URL)
- [See: resilience-patterns-overview.md](./resilience-patterns-overview.md)
- [See: circuit-breaker-design.md](./circuit-breaker-design.md)
