# Connection Resilience in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `resilience`, `retry`, `transient-faults`, `IExecutionStrategy`, `Azure-SQL`, `Polly`

## Question

> How do you handle transient database connection failures in EF Core? What does `EnableRetryOnFailure` do, what are its limitations, and when should you use a custom `IExecutionStrategy`?

## Short Answer

EF Core provides `EnableRetryOnFailure()` on SQL Server (and equivalents for PostgreSQL/MySQL) which wraps every database operation in a retry loop for known transient errors (connection timeouts, throttling, deadlocks). It implements exponential back-off with jitter. The key limitation is that it cannot automatically retry operations that contain **user-initiated transactions** — you must wrap the entire logical operation in an `IExecutionStrategy.ExecuteAsync` callback. For more complex retry policies (circuit breaker, fallback) you compose EF Core's strategy with `Polly`.

## Detailed Explanation

### What Are Transient Faults?

Transient faults are temporary failures that resolve on retry:
- TCP connection resets during Azure SQL failover
- SQL Server error 40613 ("Database is not currently available")
- Deadlock victim (error 1205)
- Timeout expired (error -2)
- Connection pool exhaustion (transient burst)

Permanent errors (constraint violations, syntax errors) should **not** be retried.

### Enabling Built-in Retry

```csharp
services.AddDbContext<AppDb>(opt =>
    opt.UseSqlServer(connStr, sql =>
        sql.EnableRetryOnFailure(
            maxRetryCount: 5,
            maxRetryDelay: TimeSpan.FromSeconds(30),
            errorNumbersToAdd: null)));  // null = use EF Core's default transient error list
```

EF Core SQL Server provider's default transient error list covers ~40 known error codes including throttling (40501), connection (40613), and deadlocks (1205).

**What it retries automatically:**
- Single `SaveChangesAsync()` calls
- Single query materializations (`ToListAsync`, `FirstAsync`, etc.)
- Implicit transactions

### The User-Transaction Problem

`EnableRetryOnFailure` **cannot** automatically retry when you open a user-controlled transaction:

```csharp
// ❌ This throws: InvalidOperationException if a retry is triggered
await using var tx = await db.Database.BeginTransactionAsync(ct);
db.Orders.Add(order);
await db.SaveChangesAsync(ct);
await tx.CommitAsync(ct);
```

If a transient failure happens after `BeginTransactionAsync`, EF Core cannot silently retry from before the `BEGIN TRANSACTION` — you might have already done partial work (published events, written to memory, etc.).

**Fix: wrap in `IExecutionStrategy.ExecuteAsync`:**

```csharp
var strategy = db.Database.CreateExecutionStrategy();

await strategy.ExecuteAsync(async () =>
{
    // Everything inside this lambda is retried atomically
    await using var tx = await db.Database.BeginTransactionAsync(ct);
    try
    {
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
    }
    catch
    {
        await tx.RollbackAsync(ct);
        throw;
    }
});
```

The strategy retries the **entire lambda** from the beginning on transient failure. Your lambda must be **idempotent** — avoid side effects (e.g., publishing events, sending emails) inside the retry block.

### Idempotency Inside the Retry Block

```csharp
// ❌ Publishes event on every retry attempt — duplicates on transient failure
await strategy.ExecuteAsync(async () =>
{
    db.Orders.Add(order);
    await db.SaveChangesAsync(ct);
    await eventBus.PublishAsync(new OrderPlaced(order.Id));  // runs N times
});

// ✅ Publish outside the retry block — only when fully committed
await strategy.ExecuteAsync(async () =>
{
    db.Orders.Add(order);
    await db.SaveChangesAsync(ct);
});
await eventBus.PublishAsync(new OrderPlaced(order.Id));  // once, after success
```

### Custom Execution Strategy

Implement `IDbExecutionStrategy` for fine-grained control:

```csharp
public sealed class CustomRetryStrategy(
    ExecutionStrategyDependencies deps,
    int maxRetryCount = 5)
    : SqlServerRetryingExecutionStrategy(deps, maxRetryCount)
{
    protected override bool ShouldRetryOn(Exception exception)
    {
        // Retry on all base SQL Server transients + our custom codes
        if (base.ShouldRetryOn(exception)) return true;

        if (exception is SqlException sqlEx)
            return sqlEx.Number == 49918;  // custom: Cannot process request — too many operations

        return false;
    }
}

// Registration
services.AddDbContext<AppDb>(opt =>
    opt.UseSqlServer(connStr)
       .UseExecutionStrategy(deps => new CustomRetryStrategy(deps)));
```

### Composing with Polly (Advanced)

For circuit-breaker, bulkhead, or fallback patterns, wrap EF Core operations with Polly:

```csharp
// Polly pipeline: retry 3x, then circuit-break on 5 consecutive failures
var pipeline = new ResiliencePipelineBuilder()
    .AddRetry(new RetryStrategyOptions
    {
        MaxRetryAttempts = 3,
        BackoffType = DelayBackoffType.Exponential,
        Delay = TimeSpan.FromMilliseconds(200)
    })
    .AddCircuitBreaker(new CircuitBreakerStrategyOptions
    {
        FailureRatio = 0.5,
        MinimumThroughput = 10,
        BreakDuration = TimeSpan.FromSeconds(30)
    })
    .Build();

await pipeline.ExecuteAsync(async ct =>
{
    var strategy = db.Database.CreateExecutionStrategy();
    await strategy.ExecuteAsync(async () =>
    {
        // DB operation
        await db.SaveChangesAsync(ct);
    });
}, ct);
```

### Azure SQL Recommendations

| Setting | Value | Reason |
|---------|-------|--------|
| `MaxRetryCount` | 5–6 | Azure SQL failovers typically resolve in 10–40s |
| `MaxRetryDelay` | 30s | Allows time for failover to complete |
| `ConnectTimeout` | 30s | Default; increase to 60s for geo-redundant setups |
| `ConnectRetryCount` | 3 (in connection string) | SqlClient-level reconnect before EF Core sees the error |

## Code Example

```csharp
// Full resilient write operation
public async Task<Order> PlaceOrderAsync(PlaceOrderRequest req, CancellationToken ct)
{
    var strategy = db.Database.CreateExecutionStrategy();

    Order? order = null;

    await strategy.ExecuteAsync(async () =>
    {
        await using var tx = await db.Database.BeginTransactionAsync(
            IsolationLevel.ReadCommitted, ct);

        var customer = await db.Customers
            .FirstAsync(c => c.Id == req.CustomerId, ct);

        order = new Order(customer, req.Items);
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);

        await tx.CommitAsync(ct);
    });

    // ✅ Outside the retry block — published once after commit
    await outbox.EnqueueAsync(new OrderPlacedEvent(order!.Id), ct);

    return order!;
}
```

## Common Follow-up Questions

- What is the difference between `EnableRetryOnFailure` and `ConnectRetryCount` in the connection string — which layer handles which?
- How do you test retry logic in integration tests without a real transient failure?
- Can you use `IExecutionStrategy` with distributed transactions (`TransactionScope`)?
- What happens if the retry count is exhausted — what exception is thrown?
- How does EF Core resilience interact with saga/outbox patterns?

## Common Mistakes / Pitfalls

- **Not using `CreateExecutionStrategy` for user transactions**: Opening a `BeginTransactionAsync` inside a retry-enabled context without wrapping in `ExecuteAsync` causes a runtime exception on the first retry attempt.
- **Publishing events inside the retry lambda**: Any side effect inside the retry block (emails, message bus publish, external API calls) runs on every retry attempt, causing duplicates.
- **Setting `maxRetryCount` too high**: Retrying 10+ times with exponential backoff during a sustained outage adds significant latency before the caller gets an error response. 5–6 is typically sufficient.
- **Assuming deadlocks are always retried**: By default, deadlock error 1205 is in EF Core's retryable list for SQL Server. But if you've suppressed this with `errorNumbersToAdd: null` and a custom list, deadlocks won't retry. Verify your error list.
- **Testing resilience with `EnableRetryOnFailure` disabled**: Many teams disable retry in development and test environments. This masks retry-related bugs (non-idempotent lambdas) that only surface in production.

## References

- [Connection resiliency — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/miscellaneous/connection-resiliency)
- [SQL Server retry execution strategy — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/providers/sql-server/misc#execution-strategies)
- [Polly — resilience library for .NET — GitHub](https://github.com/App-vNext/Polly)
- [Azure SQL transient errors — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-sql/database/troubleshoot-common-errors-issues)
- [See: transaction-basics.md](./transaction-basics.md)
