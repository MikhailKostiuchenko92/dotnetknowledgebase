# Pessimistic Concurrency in EF Core

**Category:** Data Access / Transactions
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `pessimistic-concurrency`, `SELECT FOR UPDATE`, `UPDLOCK`, `ROWLOCK`, `locking-hints`, `raw-sql`

## Question

> What is pessimistic concurrency, and when should you use it over optimistic concurrency? How do you implement row-level locking in EF Core and SQL Server?

## Short Answer

Pessimistic concurrency prevents concurrent modifications by acquiring a lock at read time — the row is locked until the transaction commits or rolls back. It eliminates `DbUpdateConcurrencyException` retry loops at the cost of reduced throughput and potential deadlocks. EF Core doesn't have native pessimistic lock support — you use raw SQL with hints like `WITH (UPDLOCK, ROWLOCK)` on SQL Server, or `FOR UPDATE` on PostgreSQL/MySQL. Use pessimistic locking when: the conflict rate is high, the cost of retrying is prohibitive (long transactions), or you need to guarantee sequential processing of a shared resource (e.g., seat reservations, fund transfers).

## Detailed Explanation

### Optimistic vs Pessimistic — When to Choose

| | Optimistic | Pessimistic |
|--|-----------|------------|
| Conflict rate | Low | High |
| Transaction length | Short (web requests) | Medium (business workflows) |
| Retry cost | Acceptable | Prohibitive |
| Throughput | High | Lower (lock contention) |
| Deadlock risk | None | Present |
| EF Core native | ✅ rowversion | ❌ raw SQL required |
| Best for | CMS, profiles, articles | Seat booking, inventory, payment |

### SQL Server Locking Hints

SQL Server uses hints to control lock acquisition:

| Hint | Effect |
|------|--------|
| `UPDLOCK` | Acquires Update lock (compatible with reads, blocks other UPDLOCK) |
| `ROWLOCK` | Escalates from page/table lock to row-level lock |
| `HOLDLOCK` | Holds the lock until transaction ends (equivalent to Serializable) |
| `NOLOCK` | No lock — dirty reads (avoid: returns uncommitted data) |

### Pattern 1: SELECT with UPDLOCK + ROWLOCK

```csharp
// Pessimistic lock: read the seat and hold until transaction commits
public async Task<bool> ReserveSeatAsync(int seatId, string userId, CancellationToken ct)
{
    var strategy = db.Database.CreateExecutionStrategy();

    return await strategy.ExecuteAsync(async () =>
    {
        await using var tx = await db.Database.BeginTransactionAsync(
            IsolationLevel.ReadCommitted, ct);

        // Lock the row at read time — no other session can acquire UPDLOCK on this row
        var seat = await db.Seats
            .FromSqlInterpolated(
                $"SELECT * FROM Seats WITH (UPDLOCK, ROWLOCK) WHERE Id = {seatId}")
            .FirstOrDefaultAsync(ct);

        if (seat is null || seat.IsReserved)
        {
            await tx.RollbackAsync(ct);
            return false;
        }

        seat.IsReserved = true;
        seat.ReservedBy = userId;
        seat.ReservedAt = DateTimeOffset.UtcNow;

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return true;
    });
}
```

Between `SELECT … WITH (UPDLOCK)` and `COMMIT`, any other session trying to acquire an `UPDLOCK` on the same row will **block** (not fail) until this transaction completes.

### Pattern 2: EF Core Tag + Interceptor for Locking Hints

For a more EF Core-idiomatic approach, use an interceptor to append locking hints based on a query tag:

```csharp
public sealed class RowLockInterceptor : DbCommandInterceptor
{
    public override InterceptionResult<DbDataReader> ReaderExecuting(
        DbCommand command,
        CommandEventData eventData,
        InterceptionResult<DbDataReader> result)
    {
        // Rewrite queries tagged with "PESSIMISTIC_LOCK"
        if (command.CommandText.Contains("-- PESSIMISTIC_LOCK"))
        {
            command.CommandText = command.CommandText
                .Replace("FROM [Seats]", "FROM [Seats] WITH (UPDLOCK, ROWLOCK)");
        }
        return result;
    }
}

// Usage
var seat = await db.Seats
    .TagWith("PESSIMISTIC_LOCK")
    .FirstOrDefaultAsync(s => s.Id == seatId, ct);
```

> This approach is fragile (depends on generated SQL shape). Prefer `FromSqlInterpolated` for production locking scenarios.

### PostgreSQL: SELECT … FOR UPDATE

```csharp
var seat = await db.Seats
    .FromSqlInterpolated($"SELECT * FROM \"Seats\" WHERE \"Id\" = {seatId} FOR UPDATE")
    .FirstOrDefaultAsync(ct);
```

### Deadlock Risk

Pessimistic locking introduces deadlock risk when:
- Two sessions each hold a lock on different rows and each tries to acquire the other's lock.
- Solution: acquire locks in a consistent order (always lock lower ID first).

```csharp
// Safe: always acquire locks in ascending ID order
var orderedIds = new[] { id1, id2 }.OrderBy(x => x).ToArray();
foreach (var id in orderedIds)
{
    await db.Accounts
        .FromSqlInterpolated($"SELECT * FROM Accounts WITH (UPDLOCK, ROWLOCK) WHERE Id = {id}")
        .FirstAsync(ct);
}
```

## Code Example

```csharp
// Inventory reservation with pessimistic lock
public async Task<ReservationResult> ReserveStockAsync(
    int productId, int quantity, CancellationToken ct)
{
    var strategy = db.Database.CreateExecutionStrategy();

    return await strategy.ExecuteAsync(async () =>
    {
        await using var tx = await db.Database.BeginTransactionAsync(
            IsolationLevel.ReadCommitted, ct);

        // Acquire exclusive update lock at read time
        var stock = await db.ProductStock
            .FromSqlInterpolated(
                $"SELECT * FROM ProductStock WITH (UPDLOCK, ROWLOCK) WHERE ProductId = {productId}")
            .FirstOrDefaultAsync(ct);

        if (stock is null)
            return ReservationResult.ProductNotFound;

        if (stock.Available < quantity)
            return ReservationResult.InsufficientStock;

        stock.Available -= quantity;
        stock.Reserved += quantity;

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return ReservationResult.Success;
    });
}
```

## Common Follow-up Questions

- How does pessimistic locking interact with EF Core's connection resiliency (`EnableRetryOnFailure`)?
- What is the difference between `UPDLOCK` and `XLOCK` in SQL Server?
- How do you detect and handle deadlocks in .NET code?
- Can `TransactionScope` with `Serializable` isolation replace explicit `UPDLOCK` hints?
- What is the read-skew anomaly and which isolation level prevents it?

## Common Mistakes / Pitfalls

- **Using `NOLOCK` as a "performance optimization"**: `WITH (NOLOCK)` returns uncommitted (dirty) data and can return the same row twice or skip rows during a page split. Never use it for correctness-sensitive reads.
- **Not using `WITH (ROWLOCK)` alongside `UPDLOCK`**: Without `ROWLOCK`, SQL Server may escalate to a page or table lock — locking far more rows than intended and killing throughput.
- **Holding pessimistic locks across awaited I/O**: If you acquire an `UPDLOCK` and then `await httpClient.GetAsync(...)` before committing, you hold the DB lock during the HTTP call duration. Keep lock-holding transactions as short as possible.
- **Circular lock acquisition without consistent ordering**: Acquiring locks on rows in inconsistent order (session 1: row A then B; session 2: row B then A) is the classic deadlock recipe. Always sort by PK before locking.
- **Mixing pessimistic and optimistic on the same table**: If some code paths use `rowversion` and others use `UPDLOCK`, you have inconsistent concurrency semantics. Decide on one strategy per resource type.

## References

- [SQL Server table hints — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)
- [Transaction isolation levels — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)
- [EF Core raw SQL — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/sql-queries)
- [See: optimistic-concurrency.md](./optimistic-concurrency.md)
- [See: deadlock-analysis.md](./deadlock-analysis.md)
