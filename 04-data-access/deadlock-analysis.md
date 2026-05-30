# Deadlock Analysis in SQL Server and .NET

**Category:** Data Access / Transactions
**Difficulty:** 🔴 Senior
**Tags:** `deadlock`, `SQL-Server`, `deadlock-graph`, `lock-ordering`, `retry`, `System.Data.SqlClient`, `1205`

## Question

> What causes SQL Server deadlocks? How do you read a deadlock graph, what are the common patterns, and how do you handle and prevent deadlocks in .NET code?

## Short Answer

A deadlock occurs when two or more sessions each hold a lock on a resource the other needs, creating a circular dependency. SQL Server's deadlock monitor detects this every 5 seconds, chooses a victim (typically the transaction with the least rollback cost), and kills it with error 1205. The deadlock graph (XML or SSMS visual format) shows the two sessions, the resources they hold, and the resources they're waiting for. Prevention: acquire locks in a consistent order, keep transactions short, use `READ_COMMITTED_SNAPSHOT`, minimize lock escalation. In .NET: catch `SqlException` where `Number == 1205` and retry with exponential backoff.

## Detailed Explanation

### How Deadlocks Form — The Classic Pattern

```
Session 1:                    Session 2:
BEGIN TRANSACTION             BEGIN TRANSACTION
UPDATE Orders WHERE Id = 1    UPDATE Orders WHERE Id = 2
  → acquires X lock on row 1     → acquires X lock on row 2

UPDATE Orders WHERE Id = 2    UPDATE Orders WHERE Id = 1
  → waits for row 2 (held by 2)  → waits for row 1 (held by 1)
```

Session 1 waits for session 2; session 2 waits for session 1 → deadlock.

### Deadlock Graph

Enable deadlock tracing (SQL Server 2012+):

```sql
-- Capture deadlock XML in SQL Server error log
DBCC TRACEON(1222, -1);  -- verbose deadlock info
-- Or use Extended Events (preferred in production)
```

The deadlock graph XML contains:
- `<process>` nodes: each session involved, its current SQL, wait resource, locks held
- `<resource>` nodes: the specific database objects locked
- `victim` attribute: which session was killed

SSMS displays this as a visual graph showing arrows between processes and resources.

### Common Deadlock Patterns

**1. Different row order updates (most common)**

```sql
-- Session 1: UPDATE Orders (Id=1), then UPDATE Customers (Id=5)
-- Session 2: UPDATE Customers (Id=5), then UPDATE Orders (Id=1)
-- → deadlock
```

**Fix:** Always acquire locks in the same order (by table name, then by primary key).

**2. Index escalation**

```sql
-- Session 1: holds intent lock on Customers table, tries to escalate to table lock
-- Session 2: holds row lock on different row in Customers
-- → deadlock
```

**Fix:** Use `WITH (ROWLOCK)` to prevent lock escalation, or ensure indexes allow row-level locking.

**3. Missing index → table scan holds too many locks**

```sql
-- Session 1: SELECT with table scan → holds shared locks on all scanned rows
-- Session 2: UPDATE same table → waits for Session 1's shared locks
-- Session 1: tries to escalate → deadlock
```

**Fix:** Add the missing index to reduce scan range.

**4. Cascade delete + concurrent insert**

```sql
-- Session 1: DELETE parent row → cascade deletes child rows (holds X lock on parent)
-- Session 2: INSERT child row → waits for parent FK lock
-- Session 1: re-reads parent to verify cascade → waits for Session 2's lock
```

### Detecting Deadlocks in Production

**Extended Events (recommended):**

```sql
CREATE EVENT SESSION [DeadlockCapture] ON SERVER
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.event_file(SET filename = N'C:\Logs\Deadlocks.xel')
WITH (MAX_DISPATCH_LATENCY = 5 SECONDS);

ALTER EVENT SESSION [DeadlockCapture] ON SERVER STATE = START;
```

**System Health session (built-in — always active):**

```sql
SELECT
    xdr.value('@timestamp', 'datetime2') AS [Date],
    xdr.query('.') AS [DeadlockGraph]
FROM (
    SELECT CAST(target_data AS XML) AS TargetData
    FROM sys.dm_xe_session_targets t
    JOIN sys.dm_xe_sessions s ON s.address = t.event_session_address
    WHERE s.name = 'system_health'
      AND t.target_name = 'ring_buffer'
) AS Data
CROSS APPLY TargetData.nodes('//RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData(xdr);
```

### Handling Deadlocks in .NET

```csharp
// Error 1205 = deadlock victim
public static bool IsDeadlock(this SqlException ex) =>
    ex.Number == 1205;

public async Task<T> ExecuteWithDeadlockRetryAsync<T>(
    Func<CancellationToken, Task<T>> operation,
    CancellationToken ct,
    int maxRetries = 3)
{
    for (int attempt = 0; attempt < maxRetries; attempt++)
    {
        try
        {
            return await operation(ct);
        }
        catch (SqlException ex) when (ex.IsDeadlock() && attempt < maxRetries - 1)
        {
            var delay = TimeSpan.FromMilliseconds(100 * Math.Pow(2, attempt));
            logger.LogWarning("Deadlock on attempt {Attempt}, retrying in {Delay}ms", attempt + 1, delay.TotalMilliseconds);
            await Task.Delay(delay, ct);
        }
    }
    throw new InvalidOperationException("Max deadlock retries exceeded.");
}
```

EF Core's `EnableRetryOnFailure` includes deadlock (1205) in its default transient error list — so basic deadlock retry is automatic if you've configured resilience.

## Code Example

```csharp
// Prevention: consistent lock ordering
public async Task TransferAsync(int fromId, int toId, decimal amount, CancellationToken ct)
{
    // Always lock lower ID first to prevent deadlocks
    var (firstId, secondId) = fromId < toId
        ? (fromId, toId)
        : (toId, fromId);

    var strategy = db.Database.CreateExecutionStrategy();
    await strategy.ExecuteAsync(async () =>
    {
        await using var tx = await db.Database.BeginTransactionAsync(
            IsolationLevel.ReadCommitted, ct);

        // Lock in consistent order using UPDLOCK
        await db.Accounts
            .FromSqlInterpolated(
                $"SELECT * FROM Accounts WITH (UPDLOCK, ROWLOCK) WHERE Id = {firstId}")
            .FirstAsync(ct);
        await db.Accounts
            .FromSqlInterpolated(
                $"SELECT * FROM Accounts WITH (UPDLOCK, ROWLOCK) WHERE Id = {secondId}")
            .FirstAsync(ct);

        // Now safe to update
        var from = await db.Accounts.FindAsync([fromId], ct);
        var to = await db.Accounts.FindAsync([toId], ct);
        from!.Balance -= amount;
        to!.Balance += amount;
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
    });
}
```

## Common Follow-up Questions

- How does `READ_COMMITTED_SNAPSHOT` isolation reduce deadlock frequency?
- What is the difference between a deadlock and a lock timeout (error 1222)?
- How do you identify the most frequent deadlock pattern in a production system?
- Can index fragmentation contribute to deadlocks?
- How does EF Core's `EnableRetryOnFailure` handle deadlock retries?

## Common Mistakes / Pitfalls

- **Not retrying on deadlock**: Application throws a 500 error to the user on every deadlock. Deadlocks are transient — add retry logic with backoff.
- **Using `NOLOCK` (Read Uncommitted) to avoid deadlocks**: `NOLOCK` prevents read-write deadlocks but introduces dirty reads, non-repeatable reads, and phantom rows. It's not an acceptable solution for correctness-sensitive data.
- **Long transactions holding many locks**: SELECT-heavy queries inside transactions hold shared locks for the entire transaction duration. Use `READ_COMMITTED_SNAPSHOT` or move reads outside the transaction.
- **Retrying without resetting the DbContext**: After a deadlock, any partially-executed changes remain in the change tracker. Retrying `SaveChanges` on the same context may try to INSERT already-inserted rows. Detach modified entities or use a fresh context for the retry.
- **Ignoring the deadlock victim selection**: SQL Server picks the "cheapest" victim to roll back. Frequent victimization of the same query indicates it's time to redesign the lock acquisition order or reduce lock scope.

## References

- [Deadlock guide — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-deadlocks-guide)
- [Detect and end deadlocks — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/use-extended-events-to-capture-deadlocks)
- [SqlException.Number 1205 — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/errors-events/mssqlserver-1205-database-engine-error)
- [See: pessimistic-concurrency.md](./pessimistic-concurrency.md)
- [See: connection-resilience.md](./connection-resilience.md)
