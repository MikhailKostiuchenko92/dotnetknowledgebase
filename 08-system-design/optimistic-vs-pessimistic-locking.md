# Optimistic vs Pessimistic Locking

**Category:** System Design / Data Storage
**Difficulty:** 🟡 Middle
**Tags:** `optimistic-locking`, `pessimistic-locking`, `concurrency`, `EF-Core`, `concurrency-token`, `deadlock`, `row-versioning`

## Question

> What is the difference between optimistic and pessimistic locking? When do you use each? How do you implement optimistic concurrency in EF Core, and how do you avoid deadlocks with pessimistic locking?

## Short Answer

Optimistic locking assumes conflicts are rare — it doesn't lock rows on read; instead, it validates at write time that the data hasn't changed since it was read, and fails if it has (a `DbUpdateConcurrencyException` in EF Core). Pessimistic locking acquires a database lock on read to prevent other writers until the transaction completes. Use optimistic locking for low-contention scenarios (read-mostly, infrequent concurrent updates); use pessimistic locking when conflicts are common or when you cannot afford retries (financial inventory, seat reservations).

## Detailed Explanation

### Optimistic Locking

**Assumption**: conflicts are rare. Don't block reads. Detect conflicts at write time.

**Mechanism**: each row has a version token (a `rowversion` / `timestamp` column in SQL Server, `xmin` in PostgreSQL, or an `int` version column). On read, the token is captured. On update, a `WHERE id = :id AND version = :original_version` clause is added. If 0 rows are affected, another writer changed the row — a conflict occurred.

**Workflow**:
1. Read row → version = 5
2. Modify in memory
3. `UPDATE ... WHERE id = X AND version = 5` → 0 rows affected → **conflict** → retry or show error
4. OR → 1 row affected → success, version incremented to 6

**Pros**: No locking overhead on reads; high concurrency for read-heavy workloads; no risk of deadlocks.
**Cons**: Requires retry logic; bad UX if conflicts are frequent (user fills form, submits, gets conflict error).

### Pessimistic Locking

**Assumption**: conflicts are likely. Lock the row on read to prevent concurrent writers.

**Mechanism**: a `SELECT ... WITH (UPDLOCK)` (SQL Server) or `SELECT ... FOR UPDATE` (PostgreSQL) acquires an update lock. Other transactions that attempt to lock the same row are blocked until the first transaction commits or rolls back.

**Workflow**:
1. `SELECT ... WITH (UPDLOCK)` → acquire lock
2. Modify row
3. `UPDATE ...` → commit → lock released
4. Concurrent transaction trying to lock the same row unblocks and proceeds

**Pros**: Guarantees exclusive access; no retries; appropriate for high-contention scenarios.
**Cons**: Reduces concurrency; risk of **deadlocks** if multiple rows are locked in different orders by concurrent transactions; connection held open during the entire operation.

### Deadlocks

A deadlock occurs when Transaction A holds a lock on row 1 and waits for row 2, while Transaction B holds a lock on row 2 and waits for row 1 — circular wait, neither can proceed.

**Prevention:**
- **Consistent lock ordering**: always lock rows in the same order (by primary key ascending).
- **Use `UPDLOCK` instead of `HOLDLOCK`**: acquires a less restrictive lock that still prevents concurrent writers.
- **Keep transactions short**: minimise the time between lock acquisition and release.
- **Use optimistic locking where possible**: no lock → no deadlock.

SQL Server detects deadlocks and kills one transaction (the deadlock victim). The application must catch `SqlException` with error 1205 and retry.

### EF Core: Optimistic Concurrency

EF Core supports optimistic concurrency via `[ConcurrencyCheck]` or `IsRowVersion()` / `IsConcurrencyToken()` in Fluent API.

SQL Server `rowversion` column is automatically incremented on every `UPDATE` by the database — perfect for optimistic locking.

When EF Core's `SaveChanges()` detects 0 rows affected (due to a version mismatch), it throws `DbUpdateConcurrencyException`.

### EF Core: Pessimistic Locking

EF Core 5+ supports pessimistic locking via `FromSqlRaw` with lock hints, or using explicit SQL within a transaction.

## Code Example

```csharp
// EF Core 8 — optimistic and pessimistic locking patterns

using Microsoft.EntityFrameworkCore;

// ── Data model with rowversion (optimistic) ───────────────────────────
public class Seat
{
    public int Id { get; set; }
    public string EventId { get; set; } = "";
    public bool IsReserved { get; set; }
    public string? ReservedBy { get; set; }

    // SQL Server rowversion: automatically updated on every write
    // EF Core uses this as a concurrency token
    [System.ComponentModel.DataAnnotations.Timestamp]
    public byte[] RowVersion { get; set; } = [];
}

public class TicketDbContext(DbContextOptions<TicketDbContext> options) : DbContext(options)
{
    public DbSet<Seat> Seats => Set<Seat>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<Seat>()
          .Property(s => s.RowVersion)
          .IsRowVersion();   // marks as concurrency token; included in UPDATE WHERE clause
    }
}

// ── Optimistic locking: reserve a seat ───────────────────────────────
app.MapPost("/seats/{id}/reserve", async (int id, string userId, TicketDbContext db) =>
{
    const int maxRetries = 3;

    for (int attempt = 0; attempt < maxRetries; attempt++)
    {
        var seat = await db.Seats.FindAsync(id);
        if (seat is null)        return Results.NotFound();
        if (seat.IsReserved)     return Results.Conflict("Seat already reserved");

        seat.IsReserved  = true;
        seat.ReservedBy  = userId;

        try
        {
            // EF Core generates:
            // UPDATE Seats SET IsReserved=1, ReservedBy=:userId
            // WHERE Id=:id AND RowVersion=:original_version
            await db.SaveChangesAsync();
            return Results.Ok($"Seat {id} reserved for {userId}");
        }
        catch (DbUpdateConcurrencyException)
        {
            // Another writer updated the row between our read and write
            // Reload from DB and retry
            db.ChangeTracker.Clear();   // discard stale tracked entities

            if (attempt == maxRetries - 1)
                return Results.Conflict("Seat was modified by another user — please try again");
        }
    }

    return Results.Conflict("Could not reserve seat after retries");
});

// ── Pessimistic locking: reserve seat with exclusive lock ─────────────
app.MapPost("/seats/{id}/reserve-pessimistic", async (int id, string userId, TicketDbContext db) =>
{
    // Use explicit transaction + UPDLOCK hint to prevent concurrent reservations
    await using var transaction = await db.Database.BeginTransactionAsync(
        System.Data.IsolationLevel.ReadCommitted);

    // UPDLOCK: blocks other UPDLOCK/exclusive lock attempts on the same row
    // Prevents the "lost update" problem without rowversion
    var seat = await db.Seats
        .FromSqlRaw("SELECT * FROM Seats WITH (UPDLOCK, ROWLOCK) WHERE Id = {0}", id)
        .FirstOrDefaultAsync();

    if (seat is null)      { await transaction.RollbackAsync(); return Results.NotFound(); }
    if (seat.IsReserved)   { await transaction.RollbackAsync(); return Results.Conflict("Already reserved"); }

    seat.IsReserved = true;
    seat.ReservedBy = userId;
    await db.SaveChangesAsync();
    await transaction.CommitAsync();

    return Results.Ok($"Seat {id} reserved (pessimistic) for {userId}");
});

// ── Deadlock retry with pessimistic locking ───────────────────────────
async Task ExecuteWithDeadlockRetryAsync(Func<Task> action, int maxRetries = 3)
{
    for (int i = 0; i < maxRetries; i++)
    {
        try   { await action(); return; }
        catch (Microsoft.Data.SqlClient.SqlException ex) when (ex.Number == 1205)
        {
            // 1205 = deadlock victim — retry after backoff
            if (i == maxRetries - 1) throw;
            await Task.Delay(TimeSpan.FromMilliseconds(50 * (i + 1)));
        }
    }
}
```

## Common Follow-up Questions

- How do you implement optimistic concurrency for a multi-step business process (not just a single row update)?
- What is the difference between `UPDLOCK` and `XLOCK` hints in SQL Server?
- How does the `IsolationLevel.Serializable` transaction isolation level compare to pessimistic row locking?
- How do you handle `DbUpdateConcurrencyException` in a command/CQRS handler?
- What is the "lost update" anomaly, and which locking strategy prevents it?
- How do you implement optimistic locking for a document database like Cosmos DB?

## Common Mistakes / Pitfalls

- **Forgetting to configure the concurrency token in EF Core**: without `[Timestamp]` / `IsRowVersion()`, EF Core does not add the version check to the `UPDATE` statement — optimistic locking silently has no effect.
- **Not handling `DbUpdateConcurrencyException`**: this exception is thrown at `SaveChanges` time and must be caught explicitly. An unhandled exception returns `500 Internal Server Error` to the user with no explanation.
- **Pessimistic lock held across network calls**: opening a transaction, acquiring a lock, calling an external HTTP API (which may be slow), then committing — holds the DB lock for the duration of the HTTP call, severely limiting concurrency.
- **Inconsistent lock order causing deadlocks**: two transactions that lock rows in different orders (A then B vs B then A) always risk deadlock. Always sort row IDs before locking in any batch operation.
- **Using optimistic locking in high-contention scenarios**: if multiple users concurrently update the same "trending" entity, most will repeatedly fail and retry — creating a thundering herd on that row. Use pessimistic locking or a queue for high-contention cases.
- **`NOLOCK` hint "to avoid locking"**: `WITH (NOLOCK)` / `READ UNCOMMITTED` reads dirty data (uncommitted changes from other transactions). It avoids lock contention but at the cost of correctness — can read phantom rows, rolled-back data, or partially-updated rows.

## References

- [EF Core — Optimistic concurrency](https://learn.microsoft.com/ef/core/saving/concurrency)
- [SQL Server — Transaction locking and row versioning guide](https://learn.microsoft.com/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)
- [EF Core pessimistic locking patterns](https://learn.microsoft.com/ef/core/querying/sql-queries) (verify URL)
- Martin Kleppmann, *Designing Data-Intensive Applications*, Chapter 7 — Transactions
- [See: distributed-transactions.md](./distributed-transactions.md) — when locking needs to span services
