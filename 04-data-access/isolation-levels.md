# SQL Transaction Isolation Levels

**Category:** Data Access / Transactions
**Difficulty:** 🟡 Middle
**Tags:** `transactions`, `isolation-levels`, `dirty-read`, `phantom-read`, `non-repeatable-read`, `SNAPSHOT`, `SQL-Server`

## Question

> What are the SQL transaction isolation levels? What concurrency anomalies does each level prevent, and which level does SQL Server / EF Core use by default? When would you choose `Snapshot` isolation?

## Short Answer

SQL defines four ANSI isolation levels (from weakest to strongest): `Read Uncommitted`, `Read Committed`, `Repeatable Read`, `Serializable`. SQL Server also adds `Snapshot` and `Read Committed Snapshot Isolation` (RCSI). Each level trades safety for throughput by allowing or preventing three anomalies: dirty reads, non-repeatable reads, and phantom reads. SQL Server defaults to `Read Committed`; EF Core uses whatever the provider's default is (also `Read Committed` for SQL Server). `Snapshot` isolation eliminates read-write lock contention using row versioning — the best choice for high-concurrency OLTP systems where readers should never block writers.

## Detailed Explanation

### The Three Concurrency Anomalies

| Anomaly | Description | Example |
|---------|------------|---------|
| **Dirty read** | Read uncommitted data that is later rolled back | T1 reads balance changed by T2 before T2 commits |
| **Non-repeatable read** | Same row read twice gives different values | T1 reads price; T2 updates price; T1 reads again → different value |
| **Phantom read** | New rows appear in a repeated query | T1 counts orders WHERE status='Pending'; T2 inserts one; T1 counts again → different count |

### Isolation Levels and What They Prevent

| Level | Dirty Read | Non-Repeatable | Phantom | Mechanism |
|-------|-----------|----------------|---------|-----------|
| `Read Uncommitted` | ✅ allowed | ✅ allowed | ✅ allowed | No read locks |
| `Read Committed` | ❌ prevented | ✅ allowed | ✅ allowed | Shared lock released after read |
| `Repeatable Read` | ❌ | ❌ prevented | ✅ allowed | Shared lock held until end of tx |
| `Serializable` | ❌ | ❌ | ❌ prevented | Range locks prevent phantom inserts |
| `Snapshot` | ❌ | ❌ | ❌ | Row versioning in `tempdb` — no read locks |

### SQL Server Extensions: RCSI and Snapshot

SQL Server adds two row-versioning–based levels:

**Read Committed Snapshot Isolation (RCSI):** Replaces lock-based `Read Committed` with row versioning. Readers see the last committed version (no shared locks). Enabled database-wide:

```sql
ALTER DATABASE MyDb SET READ_COMMITTED_SNAPSHOT ON;
```

**Snapshot Isolation:** Readers see a consistent snapshot from the transaction start. Detects write conflicts like optimistic concurrency:

```sql
ALTER DATABASE MyDb SET ALLOW_SNAPSHOT_ISOLATION ON;
```

```csharp
// Use Snapshot isolation in EF Core
await db.Database.BeginTransactionAsync(IsolationLevel.Snapshot, ct);
```

### Default Isolation Levels

| Platform | Default |
|----------|---------|
| SQL Server | Read Committed (lock-based, or RCSI if enabled) |
| EF Core | Uses provider default (Read Committed for SQL Server) |
| PostgreSQL | Read Committed |
| MySQL/MariaDB | Repeatable Read |
| SQLite | Serializable |

### Setting Isolation Level in EF Core

```csharp
// Explicit transaction with specific isolation level
await using var tx = await db.Database.BeginTransactionAsync(
    IsolationLevel.Serializable, ct);

// Or via TransactionScope
using var scope = new TransactionScope(
    TransactionScopeOption.Required,
    new TransactionOptions { IsolationLevel = System.Transactions.IsolationLevel.RepeatableRead },
    TransactionScopeAsyncFlowOption.Enabled);
```

### When to Use Each Level

| Level | Use when |
|-------|----------|
| `Read Uncommitted` | Approximate reporting where accuracy isn't critical (avoid in general) |
| `Read Committed` | Default for OLTP — balanced safety and performance |
| `Repeatable Read` | Read-then-write operations where consistent re-reads are needed |
| `Serializable` | Critical financial operations, seat/inventory reservation (high deadlock risk) |
| `Snapshot` | High-concurrency OLTP where readers blocking writers is a problem |
| `RCSI` (database-level) | Best default for Azure SQL / high-concurrency apps — no code change needed |

> **Azure SQL Tip:** Azure SQL Database has RCSI enabled by default. This means `Read Committed` behaves like `Snapshot` for reads — no shared locks, no reader/writer blocking. This is why Azure SQL is usually very responsive under concurrent load.

## Code Example

```csharp
// Serializable: ensure no phantom inserts between two reads in the same transaction
public async Task<bool> IsUsernameAvailableAsync(string username, CancellationToken ct)
{
    // Serializable ensures: if we read "not exists", no one can INSERT the same username
    // until our transaction completes (range lock on the username index)
    await using var tx = await db.Database.BeginTransactionAsync(
        IsolationLevel.Serializable, ct);

    bool exists = await db.Users.AnyAsync(u => u.Username == username, ct);
    if (exists)
    {
        await tx.RollbackAsync(ct);
        return false;
    }

    // No other transaction can insert this username until we commit
    db.Users.Add(new User { Username = username });
    await db.SaveChangesAsync(ct);
    await tx.CommitAsync(ct);
    return true;
}

// Snapshot: long-running report that needs a consistent view without blocking writers
public async Task<SalesReport> GenerateReportAsync(DateOnly date, CancellationToken ct)
{
    await using var tx = await db.Database.BeginTransactionAsync(
        IsolationLevel.Snapshot, ct);  // reads from a point-in-time snapshot

    var orders = await db.Orders
        .AsNoTracking()
        .Where(o => o.OrderDate == date)
        .ToListAsync(ct);

    // Even if writers insert orders for today during this query, we see a consistent snapshot
    var products = await db.Products.AsNoTracking().ToListAsync(ct);

    await tx.CommitAsync(ct);
    return BuildReport(orders, products);
}
```

## Common Follow-up Questions

- Why does `Serializable` isolation cause more deadlocks than `Read Committed`?
- What is the performance cost of Snapshot isolation — where is the row version data stored?
- How does `RCSI` differ from `Snapshot` isolation for multi-statement transactions?
- Can you mix isolation levels within the same session (e.g., one query at Snapshot, another at Read Committed)?
- What is a `READ_COMMITTED_SNAPSHOT` database option and should you enable it in production?

## Common Mistakes / Pitfalls

- **Using `Read Uncommitted` (or `NOLOCK`) for "faster" queries**: This returns dirty data — uncommitted rows, skipped rows during page splits, phantom data. Not acceptable for any business logic.
- **Assuming `Serializable` prevents deadlocks**: `Serializable` requires range locks which *increase* deadlock probability because more resources are locked for longer. It prevents phantom reads but at a significant locking cost.
- **Not enabling RCSI on Azure SQL databases**: On-premises SQL Server defaults to lock-based `Read Committed`. Azure SQL uses RCSI by default, but if you restore an on-premises backup to Azure SQL, RCSI may not be enabled. This causes reader/writer blocking that Azure SQL wouldn't normally have.
- **Using `Snapshot` isolation without understanding write conflict detection**: `Snapshot` detects write conflicts (two sessions write the same row) and throws `SqlException` (error 3960: "Snapshot isolation transaction aborted due to update conflict"). You must handle this exception.
- **Setting `Serializable` as the application-level default**: Unless your application truly requires it, `Serializable` decimates throughput under concurrent load. Use it for specific critical operations only.

## References

- [SET TRANSACTION ISOLATION LEVEL — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)
- [Snapshot isolation — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/sql/snapshot-isolation-in-sql-server)
- [IsolationLevel enum — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.data.isolationlevel)
- [See: transaction-basics.md](./transaction-basics.md)
- [See: pessimistic-concurrency.md](./pessimistic-concurrency.md)
