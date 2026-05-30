# Designing for Partial Failure

**Category:** Architecture / Resilience
**Difficulty:** 🔴 Senior
**Tags:** `partial-failure`, `idempotency`, `compensating-transactions`, `resilience`, `distributed-systems`, `failure-modes`

## Question

> What does "designing for partial failure" mean in distributed systems? Explain idempotent retries, compensating actions, and how to design APIs that handle partial success gracefully.

## Short Answer

In distributed systems, **partial failure is the norm** — any component can fail independently. Designing for partial failure means: assuming failure at every integration boundary, making operations **idempotent** (safe to retry), using **compensating transactions** for rollback instead of 2PC, designing APIs to distinguish "definitely failed" from "unknown outcome" (network error), and returning partial-success responses when some sub-operations succeed. The goal: a system that remains consistent and recoverable even when 20% of its components are failing.

## Detailed Explanation

### Failure Modes in Distributed Systems

```
Failure types:
  1. Clear failure:  dependent service returns 400/500 → safe to retry or compensate
  2. Timeout:        request sent, no response → DID IT EXECUTE? (unknown state)
  3. Network split:  request may or may not have been received
  4. Partial success: 3 of 5 downstream calls succeeded before failure

The hardest case: timeout + non-idempotent operation
  POST /payments → network times out → charge may or may not have been applied
  Without idempotency key: retry = potential double charge
```

### Idempotent Operations

```
Idempotent: executing N times has same effect as executing once

Naturally idempotent:
  GET  /orders/42          → always returns same state, no side effects
  PUT  /orders/42/status   → setting status to "Shipped" twice = still "Shipped"
  DELETE /orders/42        → 1st call: 204 No Content; 2nd call: 404 (acceptable)

Making POST idempotent via idempotency keys:
  1. Client generates UUID before first attempt
  2. Client sends: POST /payments with Idempotency-Key: <uuid>
  3. Server: check idempotency store for this key
     → Not found: execute, store (key → result), return result
     → Found: return stored result without re-executing
  4. Client retries with SAME key → server returns stored result
```

```csharp
// Idempotency key infrastructure
public class IdempotencyMiddleware(RequestDelegate next, IIdempotencyStore store) : IMiddleware
{
    public async Task InvokeAsync(HttpContext ctx, RequestDelegate _)
    {
        var key = ctx.Request.Headers["Idempotency-Key"].FirstOrDefault();
        if (key is null) { await next(ctx); return; }

        // Check cache
        var stored = await store.GetAsync(key, ctx.RequestAborted);
        if (stored is not null)
        {
            // Replay stored response
            ctx.Response.StatusCode = stored.StatusCode;
            ctx.Response.ContentType = "application/json";
            await ctx.Response.WriteAsync(stored.Body, ctx.RequestAborted);
            return;
        }

        // Execute request, capture response
        await next(ctx);

        await store.StoreAsync(key,
            new StoredResponse(ctx.Response.StatusCode, /* captured body */),
            ttl: TimeSpan.FromHours(24),
            ctx.RequestAborted);
    }
}
```

### Compensating Transactions

```
Traditional rollback (2PC): locks resources across services until all confirm
  → Requires coordinator, all services must be available for rollback
  → Doesn't work in distributed systems (CAP theorem)

Compensating transaction: an inverse action that reverses a completed operation
  Order placement:
    Step 1: Reserve inventory       → Compensation: Release inventory
    Step 2: Charge payment          → Compensation: Issue refund
    Step 3: Create order record     → Compensation: Cancel order

  If Step 3 fails: run compensations for Steps 1 and 2 (in reverse order)
  → Eventually consistent, no distributed lock required
```

```csharp
// Saga with compensations (simplified)
public class PlaceOrderSaga
{
    public async Task<Result> ExecuteAsync(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var compensations = new Stack<Func<CancellationToken, Task>>();

        try
        {
            // Step 1: Reserve inventory
            var reservation = await _inventory.ReserveAsync(cmd.Items, ct);
            compensations.Push(c => _inventory.ReleaseAsync(reservation.Id, c));

            // Step 2: Charge payment
            var charge = await _payment.ChargeAsync(cmd.Amount, cmd.IdempotencyKey, ct);
            compensations.Push(c => _payment.RefundAsync(charge.Id, c));

            // Step 3: Create order (if this fails, compensate above steps)
            var orderId = await _orders.CreateAsync(cmd, reservation, charge, ct);

            return Result.Success(orderId);
        }
        catch (Exception)
        {
            // Run compensations in reverse order
            while (compensations.TryPop(out var compensate))
                await compensate(CancellationToken.None); // ← use NoCancel for compensation
            throw;
        }
    }
}
```

### Partial Success API Design

```
Problem: PlaceOrder involves 3 operations; 2 succeed and 1 fails
  Bad API: return 500 (total failure) → client doesn't know which parts succeeded
  Good API: return partial success response with status per operation

HTTP 207 Multi-Status (WebDAV, used for batch operations):
```

```csharp
// Partial success response for batch operations
[HttpPost("orders/batch")]
public async Task<IActionResult> PlaceBatch([FromBody] List<PlaceOrderCommand> cmds, CancellationToken ct)
{
    var results = await Task.WhenAll(cmds.Select(cmd => ProcessSafe(cmd, ct)));

    if (results.All(r => r.IsSuccess)) return Ok(results);
    if (results.All(r => !r.IsSuccess)) return StatusCode(500, results);

    // Some succeeded, some failed → 207 Multi-Status
    return StatusCode(207, results.Select(r => new
    {
        r.CommandId,
        Status = r.IsSuccess ? 200 : 500,
        r.Error,
        r.OrderId
    }));
}

private async Task<OperationResult> ProcessSafe(PlaceOrderCommand cmd, CancellationToken ct)
{
    try { return OperationResult.Success(cmd.ClientId, await _handler.Handle(cmd, ct)); }
    catch (Exception ex) { return OperationResult.Failure(cmd.ClientId, ex.Message); }
}
```

## Code Example

```csharp
// Timeout handling: distinguish "definitely failed" from "unknown outcome"
public async Task<PlaceOrderResult> PlaceOrderWithRetryAsync(
    PlaceOrderCommand cmd, CancellationToken ct)
{
    var idempotencyKey = Guid.NewGuid().ToString("N"); // ← generate once before loop
    cmd = cmd with { IdempotencyKey = idempotencyKey };

    for (int attempt = 0; attempt <= MaxRetries; attempt++)
    {
        try
        {
            return await _client.PlaceOrderAsync(cmd, ct);
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            // Timeout — UNKNOWN whether operation executed
            // Safe to retry because idempotency key prevents double processing
            if (attempt == MaxRetries) throw new OrderSubmissionTimeoutException(idempotencyKey);
            await Task.Delay(ExponentialBackoff(attempt), ct);
        }
        catch (HttpRequestException)
        {
            // Network error — likely did NOT execute (safe to retry)
            if (attempt == MaxRetries) throw;
            await Task.Delay(ExponentialBackoff(attempt), ct);
        }
    }
    throw new InvalidOperationException("Unreachable");
}
```

## Common Follow-up Questions

- How do you implement an idempotency store with Redis for high-throughput systems?
- What is the difference between a saga and a process manager?
- How do you handle compensating transactions that also fail?
- How does the Outbox pattern help with at-least-once delivery guarantees?
- What is the "Two Generals Problem" and why does it prove perfect reliability is impossible?

## Common Mistakes / Pitfalls

- **Assuming compensation always succeeds**: compensation (refund, release) can also fail. Use the Outbox pattern with retries to ensure compensating messages are eventually delivered.
- **Re-generating idempotency key on retry**: generating a new UUID for each retry attempt defeats idempotency — the server sees each retry as a new unique request and processes it again.
- **Using `CancellationToken` for compensation calls**: compensation runs during cleanup, often after the original `CancellationToken` is already cancelled. Always pass `CancellationToken.None` to compensation operations.
- **Not distinguishing timeout from definite failure**: treating `TaskCanceledException` (timeout/unknown state) the same as `HttpRequestException` (likely network failure) can lead to incorrect retry decisions or missed idempotency.

## References

- [Distributed Systems — Designing Data-Intensive Applications (Martin Kleppmann)](https://dataintensive.net/)
- [Saga pattern — Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga)
- [Idempotency keys — Stripe Engineering Blog](https://stripe.com/blog/idempotency) (verify URL)
- [See: resilience-patterns-overview.md](./resilience-patterns-overview.md)
- [See: distributed-transaction-patterns.md](./distributed-transaction-patterns.md)
