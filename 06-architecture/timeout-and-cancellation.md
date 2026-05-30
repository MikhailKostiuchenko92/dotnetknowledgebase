# Timeout and Cancellation

**Category:** Architecture / Resilience
**Difficulty:** 🟡 Middle
**Tags:** `timeout`, `CancellationToken`, `cascading-timeout`, `Polly`, `TimeoutException`, `HttpClient`, `OperationCanceledException`

## Question

> How do you implement request timeouts correctly in ASP.NET Core? Explain `CancellationToken` propagation from the HTTP request to downstream calls, cascading timeout risks, and how to configure timeout policies with Polly v8.

## Short Answer

ASP.NET Core's `CancellationToken` in action method parameters is automatically cancelled when the client disconnects or the request times out. **Propagate it to every async call**: `dbContext.FindAsync(id, ct)`, `httpClient.SendAsync(req, ct)`, etc. **Cascading timeout risk**: if your API has a 10s timeout, calling a DB (5s timeout) calling a payment service (8s timeout), the stacked timeouts can exceed the outer limit. Set timeouts tighter as you go deeper. Use Polly `AddTimeout()` to enforce per-dependency timeouts on `HttpClient` in addition to per-request timeouts.

## Detailed Explanation

### CancellationToken Propagation

```csharp
// ASP.NET Core injects request CancellationToken automatically
[HttpGet("{id:int}")]
public async Task<ActionResult<OrderDto>> Get(int id, CancellationToken ct)  // ← from HttpContext
{
    // Propagate ct to ALL awaited async calls:
    var order = await _repository.GetByIdAsync(id, ct);    // ← DB call
    var customer = await _customerClient.GetAsync(order.CustomerId, ct); // ← HTTP call
    var enriched = await _enrichmentService.EnrichAsync(order, ct);      // ← internal call

    return Ok(MapToDto(order, customer, enriched));
}

// What happens on client disconnect:
// → HttpContext.RequestAborted fires → ct.IsCancellationRequested = true
// → EF Core / HttpClient / your code observes ct and throws OperationCanceledException
// → ASP.NET Core swallows it (no 500 response needed — client already gone)
```

### Cascading Timeout Problem

```
Request pipeline with timeouts:
  API Gateway:    15s timeout (outer)
  ↓
  OrderService:   10s timeout
  ↓
  DB:             5s timeout
  ↓
  PaymentService: 8s timeout    ← PROBLEM: 5 (DB) + 8 (Payment) > 10 (OrderService)

Correct pattern: each downstream timeout < upstream timeout with headroom
  OrderService:   10s
    DB:            3s (leaves 7s remaining)
    PaymentService: 5s (leaves 2s remaining for overhead)
  API Gateway:   15s (5s beyond OrderService for routing/middleware)
```

### Polly Timeout in HttpClient Pipeline

```csharp
// Per-request timeout on HttpClient calls
builder.Services.AddHttpClient<IPaymentClient, PaymentHttpClient>()
    .AddResilienceHandler("payment", pipeline =>
    {
        // Total outer timeout for the entire retry + circuit breaker pipeline
        pipeline.AddTimeout(TimeSpan.FromSeconds(5));  // ← innermost: per-attempt timeout

        pipeline.AddRetry(new HttpRetryStrategyOptions
        {
            MaxRetryAttempts = 2,
            Delay = TimeSpan.FromMilliseconds(200),
            UseJitter = true
        });

        // Or: total timeout for all retries combined
        // (outer timeout > inner timeout is typical)
    });

// For HTTP + total timeout (wraps everything including retries):
// AddStandardResilienceHandler sets both per-attempt AND total timeouts
builder.Services.AddHttpClient<IInventoryClient, InventoryClient>()
    .AddStandardResilienceHandler(options =>
    {
        options.AttemptTimeout.Timeout = TimeSpan.FromSeconds(3);   // ← per attempt
        options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(10); // ← total (all retries)
    });
```

### Handling OperationCanceledException

```csharp
// Do NOT log OperationCanceledException as an error when client cancelled
public class OrdersController : ControllerBase
{
    [HttpGet("{id}")]
    public async Task<IActionResult> Get(int id, CancellationToken ct)
    {
        try
        {
            var order = await _service.GetOrderAsync(id, ct);
            return Ok(order);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            // Client disconnected — not an error; no response needed
            return StatusCode(499, "Client Closed Request"); // ← nginx 499 convention (optional)
        }
        catch (TimeoutException tex)
        {
            // Polly timeout exceeded (distinct from cancellation)
            _logger.LogError(tex, "Timeout fetching order {OrderId}", id);
            return StatusCode(503, "Service temporarily unavailable — request timed out");
        }
    }
}
```

### Request Timeout Middleware (.NET 8)

```csharp
// .NET 8: built-in request timeout middleware
// NuGet: none required — part of ASP.NET Core

builder.Services.AddRequestTimeouts(options =>
{
    options.DefaultPolicy = new RequestTimeoutPolicy
    {
        Timeout = TimeSpan.FromSeconds(10),
        TimeoutStatusCode = StatusCodes.Status503ServiceUnavailable
    };

    // Named policy for specific endpoints
    options.AddPolicy("FastEndpoint", TimeSpan.FromSeconds(2));
    options.AddPolicy("SlowReport", TimeSpan.FromSeconds(60));
});

app.UseRequestTimeouts();

// Apply named policy to a Minimal API endpoint:
app.MapGet("/api/orders", async (ISender sender, CancellationToken ct)
    => await sender.Send(new GetOrdersQuery(), ct))
    .WithRequestTimeout("FastEndpoint");

// Or to a controller action:
[HttpPost("reports"), RequestTimeout("SlowReport")]
public async Task<IActionResult> GenerateReport(CancellationToken ct) { ... }
```

## Code Example

```csharp
// Full cancellation-aware service: timeout policy + ct propagation
public class InventoryService(
    IHttpClientFactory httpFactory,
    ResiliencePipelineProvider<string> pipelines,
    ILogger<InventoryService> logger)
{
    private readonly ResiliencePipeline _pipeline = pipelines.GetPipeline("inventory");

    public async Task<int> GetStockLevelAsync(int productId, CancellationToken ct)
    {
        return await _pipeline.ExecuteAsync(async token =>
        {
            var http = httpFactory.CreateClient("inventory");
            var response = await http.GetAsync($"/products/{productId}/stock", token);
            response.EnsureSuccessStatusCode();
            var dto = await response.Content.ReadFromJsonAsync<StockDto>(token);
            return dto?.Level ?? 0;
        }, ct);
        // ↑ CancellationToken is linked: ct (request) + Polly timeout combined
        // → whichever fires first cancels the operation
    }
}
```

## Common Follow-up Questions

- How does Polly link its timeout `CancellationToken` with the incoming request `CancellationToken`?
- What happens if you don't propagate `CancellationToken` — does the operation keep running after client disconnect?
- How do you test that timeouts are respected in integration tests?
- What is the difference between `TaskCanceledException` and `TimeoutException` from Polly?
- How do you implement a graceful degradation when a timeout occurs (e.g., return cached data)?

## Common Mistakes / Pitfalls

- **Ignoring `CancellationToken` in method signatures**: `async Task<T> GetAsync(int id)` without `CancellationToken` means the operation runs to completion even after client disconnect — wasting CPU, DB connections, and HTTP call budget.
- **Swallowing `OperationCanceledException` silently**: catching and hiding cancellation exceptions prevents upstream callers from knowing the operation was cancelled, breaking cooperative cancellation.
- **Setting all timeouts to the same value**: `OuterTimeout == InnerTimeout` means inner operations never have time to fail cleanly before the outer timeout fires — you get a race condition on which fires first.
- **Using `Task.Wait(timeout)` instead of proper async timeout**: `task.Wait(TimeSpan.FromSeconds(5))` blocks a thread and doesn't cancel the underlying operation — it just unblocks the caller while the operation continues consuming resources.

## References

- [CancellationToken — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/standard/parallel-programming/how-to-cancel-a-task-and-its-children)
- [Request timeouts in ASP.NET Core (.NET 8)](https://learn.microsoft.com/en-us/aspnet/core/performance/timeouts)
- [Polly timeout strategy](https://www.thepollyproject.org/2023/03/13/polly-v8-is-here/) (verify URL)
- [See: resilience-patterns-overview.md](./resilience-patterns-overview.md)
- [See: retry-pattern-design.md](./retry-pattern-design.md)
