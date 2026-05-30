# Query Hints and the Query Optimizer

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🔴 Senior
**Tags:** `SQL`, `query-hints`, `NOLOCK`, `READPAST`, `UPDLOCK`, `FORCESEEK`, `FORCESCAN`, `optimizer`, `locking`

## Question

> What are SQL Server query hints, and when should you use them? What does `NOLOCK` actually do, and why is it dangerous? When are `UPDLOCK`, `READPAST`, `FORCESEEK`, and `FORCESCAN` appropriate?

## Short Answer

Query hints override the SQL Server query optimizer's default choices for joins, locking, or index selection. **`NOLOCK` (READ UNCOMMITTED)** reads rows without acquiring shared locks — it never blocks writers, but can return dirty reads (uncommitted data), phantom rows, or miss rows entirely due to page splits. It is dangerous and widely misused as a performance shortcut. **`UPDLOCK`** acquires an update lock during reads in a transaction, preventing deadlocks in check-then-update patterns. **`READPAST`** skips locked rows (rather than waiting) — useful for queue consumers. **`FORCESEEK`** / **`FORCESCAN`** override the optimizer's index access method choice and should be used only as a last resort after statistics updates and covering indexes have been tried.

## Detailed Explanation

### Lock Hints — What They Do

SQL Server uses a lock-based concurrency model by default (unless using RCSI):

| Hint | Isolation Level | Behavior |
|------|----------------|----------|
| `NOLOCK` | Read Uncommitted | No shared locks — reads uncommitted data |
| `READPAST` | Read Committed | Skip locked rows — never blocks |
| `READCOMMITTEDLOCK` | Read Committed | Force lock-based read committed (disable RCSI for this query) |
| `UPDLOCK` | Read Committed | Acquire U locks instead of S locks — prevents lock escalation deadlocks |
| `XLOCK` | Serializable | Exclusive lock — block all other readers and writers |
| `ROWLOCK` | — | Hint to use row-level locks instead of page/table |
| `PAGLOCK` | — | Hint to use page-level locks |
| `TABLOCK` | — | Table-level lock |
| `TABLOCKX` | — | Exclusive table lock |

### NOLOCK — What It Actually Returns

`WITH (NOLOCK)` / `SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED` does not take shared locks. Consequences:

1. **Dirty reads**: a row committed by transaction A, then modified but not yet committed by transaction B, is returned. If B rolls back, you've returned data that never existed.
2. **Non-repeatable reads**: the same row read twice in one query can return different values.
3. **Phantom rows**: rows being inserted/deleted during a B-tree page split can be read twice or skipped entirely.
4. **Out-of-order row reads**: during page splits, `NOLOCK` can read the same row on both the old and new page location, or miss a row that moved.

```sql
-- ❌ NOLOCK on financial data — returns incorrect balances during active transactions
SELECT SUM(Balance) FROM Accounts WITH (NOLOCK);

-- The sum may include partial transfers: Account A debited, Account B not yet credited
-- Result: $1,000,000 appears as $999,500 transiently
```

**Legitimate use**: reporting queries on append-only audit logs or event tables where dirty reads are acceptable, and blocking is genuinely a problem. Even then, enabling RCSI (Row-Level Versioning) on the database is a better solution.

### UPDLOCK — Preventing Deadlocks in Check-Then-Update

Classic deadlock scenario without hints:

```sql
-- Session A                      -- Session B
BEGIN TRAN;                        BEGIN TRAN;
SELECT * FROM Queue                SELECT * FROM Queue
WHERE Id = 1;  -- S lock           WHERE Id = 1;  -- S lock

-- Both have S locks → neither can escalate to X lock
UPDATE Queue SET Processed = 1     UPDATE Queue SET Processed = 1
WHERE Id = 1;  -- DEADLOCK         WHERE Id = 1;  -- DEADLOCK
```

With `UPDLOCK`:
```sql
-- Session A acquires U lock first — Session B waits
SELECT * FROM Queue WITH (UPDLOCK)
WHERE Id = 1;  -- U lock (blocks other U locks, not S locks yet)
-- U lock upgrades to X lock on UPDATE — no deadlock
```

### READPAST — Queue Consumer Pattern

`READPAST` skips rows that are locked by another transaction rather than blocking:

```sql
-- Competing queue consumers — each takes the next unlocked row
BEGIN TRAN;

SELECT TOP 1 @Id = Id
FROM JobQueue WITH (UPDLOCK, READPAST)  -- skip rows locked by other consumers
WHERE Status = 'Pending'
ORDER BY CreatedAt;

UPDATE JobQueue SET Status = 'Processing', WorkerId = @WorkerId
WHERE Id = @Id;

COMMIT;
```

This enables multiple workers to consume from the same table concurrently without blocking each other.

### FORCESEEK and FORCESCAN

`FORCESEEK` forces the optimizer to use index seeks (not scans). Use only when:
- You are certain the optimizer is incorrectly choosing a scan
- Statistics are up to date and you've confirmed it via `sys.dm_db_missing_index_details`
- You cannot create a better covering index for other reasons

```sql
-- Force seek on a specific index
SELECT * FROM Orders WITH (FORCESEEK, INDEX(IX_Orders_Status_CreatedAt))
WHERE Status = 'Pending' AND CreatedAt >= '2024-01-01';

-- FORCESCAN overrides optimizer when you know a full scan is cheaper
-- (e.g., returning > 30% of rows — optimizer mis-estimated)
SELECT * FROM Orders WITH (FORCESCAN)
WHERE CategoryId = 1;  -- if CategoryId = 1 represents 80% of the table
```

> Hints hard-code optimizer decisions at query write time. As data distribution changes, the hint may become counterproductive.

### When to Use Hints vs Not

| Hint | Use? | Better alternative |
|------|------|-------------------|
| `NOLOCK` | ❌ Almost never | Enable RCSI or SNAPSHOT isolation on the database |
| `UPDLOCK` | ✅ Queue patterns, check-then-update | — |
| `READPAST` | ✅ Competing consumers | — |
| `FORCESEEK` | ⚠️ Last resort | Update statistics, add/fix indexes |
| `FORCESCAN` | ⚠️ Last resort | Update statistics |
| `ROWLOCK` | ⚠️ Hints only, may be ignored | Correct index design |

## Code Example

```csharp
// Queue consumer with UPDLOCK + READPAST via Dapper
public async Task<QueueItem?> DequeueAsync(Guid workerId, CancellationToken ct)
{
    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);
    await using var tx = (SqlTransaction)await conn.BeginTransactionAsync(ct);

    var item = await conn.QuerySingleOrDefaultAsync<QueueItem>("""
        SELECT TOP 1 Id, Payload, CreatedAt
        FROM JobQueue WITH (UPDLOCK, READPAST)
        WHERE Status = 'Pending'
        ORDER BY CreatedAt
        """,
        transaction: tx);

    if (item is null)
    {
        await tx.RollbackAsync(ct);
        return null;
    }

    await conn.ExecuteAsync("""
        UPDATE JobQueue
        SET Status = 'Processing', WorkerId = @WorkerId, StartedAt = GETUTCDATE()
        WHERE Id = @Id
        """,
        new { item.Id, WorkerId = workerId },
        transaction: tx);

    await tx.CommitAsync(ct);
    return item;
}
```

## Common Follow-up Questions

- How does Row-Level Version-based isolation (RCSI/Snapshot) eliminate the need for `NOLOCK` in most scenarios?
- What is lock escalation, and how can `ROWLOCK` hints affect it?
- How do query hints interact with Query Store plan forcing?
- What is the `OPTION (RECOMPILE)` hint, and when does it solve parameter sniffing?
- Can hints be applied via EF Core without raw SQL?

## Common Mistakes / Pitfalls

- **Using `NOLOCK` as a general performance fix**: the correct solution for read blocking is RCSI (Row-Level Versioning), which is enabled at the database level and doesn't risk dirty reads.
- **Assuming `NOLOCK` means "read-only" transactions are safe**: `NOLOCK` does not prevent the table from being modified — it just means you read without waiting for locks, including reading incomplete writes.
- **Using `ROWLOCK` to prevent table-level locks**: `ROWLOCK` is a hint, not a guarantee. SQL Server may still escalate to a table lock if it judges that locking thousands of individual rows is more expensive than one table lock.
- **Hard-coding `FORCESEEK` in production code**: as the data distribution changes over months, the hint may force a suboptimal plan. Prefer fixing the root cause (statistics, indexes) over hard-coding hints.

## References

- [Table hints — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)
- [Query hints — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query)
- [Transaction locking and row versioning guide — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)
- [See: isolation-levels.md](./isolation-levels.md)
- [See: deadlock-analysis.md](./deadlock-analysis.md)
