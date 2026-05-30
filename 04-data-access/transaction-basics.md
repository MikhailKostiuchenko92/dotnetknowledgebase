# Transaction Basics in EF Core and ADO.NET

**Category:** Data Access / Transactions
**Difficulty:** 🟢 Junior
**Tags:** `transactions`, `ACID`, `SaveChanges`, `BeginTransactionAsync`, `rollback`, `EF Core`

## Question

> What is a database transaction? What ACID properties does it guarantee? How does EF Core handle transactions automatically, and how do you create a manual transaction when you need to wrap multiple operations?

## Short Answer

A transaction is a unit of work that is either committed entirely or rolled back entirely. The ACID properties — Atomicity, Consistency, Isolation, Durability — define what a transaction guarantees. In EF Core, every call to `SaveChanges` is automatically wrapped in an implicit transaction: all inserts, updates, and deletes in that call succeed or fail together. For operations that span multiple `SaveChanges` calls or mix EF Core and raw SQL, you open an explicit transaction with `db.Database.BeginTransactionAsync()`, wrap your work, and call `CommitAsync` on success or `RollbackAsync` (or let the `IDbContextTransaction` dispose) on failure.

## Detailed Explanation

### ACID Properties

| Property | Meaning | How DB enforces it |
|----------|---------|-------------------|
| **Atomicity** | All operations in the transaction succeed or none do | Transaction log + rollback |
| **Consistency** | DB moves from one valid state to another | Constraints, triggers, FK checks |
| **Isolation** | Concurrent transactions don't interfere | Locks, MVCC, isolation levels |
| **Durability** | Committed data survives crashes | Write-ahead log (WAL), fsync |

### Implicit Transaction — EF Core SaveChanges

Every `SaveChanges` call automatically wraps all its SQL in a transaction:

```csharp
// This is safe — both INSERT and UPDATE happen atomically
db.Orders.Add(new Order { CustomerId = 1, Total = 100m });
existingOrder.Status = "Processing";
await db.SaveChangesAsync(ct);
// If the UPDATE fails, the INSERT is also rolled back
```

This is an **implicit transaction** — you don't see it in code, but EF Core manages `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK` around its batched SQL.

### Explicit Transaction — Multiple SaveChanges or Mixed Operations

Use explicit transactions when:
- You call `SaveChanges` more than once and need all calls to succeed atomically.
- You mix EF Core calls with raw SQL (`ExecuteSqlRaw`) in the same logical unit.
- You need a specific isolation level (e.g., `Serializable`).

```csharp
await using IDbContextTransaction tx =
    await db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, ct);
try
{
    // First SaveChanges
    db.Invoices.Add(invoice);
    await db.SaveChangesAsync(ct);                // within the explicit transaction

    // Second SaveChanges
    db.AuditLogs.Add(new AuditLog { Action = "InvoiceCreated", EntityId = invoice.Id });
    await db.SaveChangesAsync(ct);                // same transaction

    // Raw SQL also participates
    await db.Database.ExecuteSqlRawAsync(
        "UPDATE CustomerBalance SET Balance = Balance - @amount WHERE Id = @id",
        new SqlParameter("@amount", invoice.Total),
        new SqlParameter("@id", invoice.CustomerId));

    await tx.CommitAsync(ct);                     // ← everything committed here
}
catch
{
    await tx.RollbackAsync(ct);                   // or just let Dispose() roll back
    throw;
}
```

### Transaction with `using` Rollback on Dispose

`IDbContextTransaction` rolls back automatically on `Dispose()` if not committed:

```csharp
await using var tx = await db.Database.BeginTransactionAsync(ct);

db.Orders.Add(order);
await db.SaveChangesAsync(ct);

if (!validationPasses)
    return;  // tx disposed here → automatic rollback, no explicit RollbackAsync needed

await tx.CommitAsync(ct);
```

### Savepoints (EF Core 5+)

SQL Server, PostgreSQL, and SQLite support savepoints — partial rollback within a transaction:

```csharp
await using var tx = await db.Database.BeginTransactionAsync(ct);

db.Orders.Add(order);
await db.SaveChangesAsync(ct);
await tx.CreateSavepointAsync("OrderCreated", ct);  // checkpoint

try
{
    db.Payments.Add(payment);
    await db.SaveChangesAsync(ct);
}
catch (PaymentException)
{
    await tx.RollbackToSavepointAsync("OrderCreated", ct);  // partial rollback
    // order is still in the transaction; payment is rolled back
}

await tx.CommitAsync(ct);
```

### Connection Resilience + Transactions

`EnableRetryOnFailure` cannot automatically retry user-initiated transactions. Wrap in `CreateExecutionStrategy`:

```csharp
var strategy = db.Database.CreateExecutionStrategy();
await strategy.ExecuteAsync(async () =>
{
    await using var tx = await db.Database.BeginTransactionAsync(ct);
    // ... all operations ...
    await tx.CommitAsync(ct);
});
```

[See: connection-resilience.md](./connection-resilience.md)

## Code Example

```csharp
// Transfer funds between accounts — must be atomic
public async Task TransferAsync(
    int fromAccountId, int toAccountId, decimal amount, CancellationToken ct)
{
    await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);

    var from = await db.Accounts.FindAsync([fromAccountId], ct)
        ?? throw new NotFoundException(fromAccountId);
    var to = await db.Accounts.FindAsync([toAccountId], ct)
        ?? throw new NotFoundException(toAccountId);

    if (from.Balance < amount)
        throw new InsufficientFundsException();

    from.Balance -= amount;
    to.Balance += amount;

    db.Transactions.Add(new Transaction
    {
        FromAccountId = fromAccountId,
        ToAccountId = toAccountId,
        Amount = amount,
        Timestamp = DateTimeOffset.UtcNow
    });

    await db.SaveChangesAsync(ct);   // INSERT + 2 UPDATEs in one batch

    await tx.CommitAsync(ct);
    // If any exception was thrown above: tx disposes → automatic ROLLBACK
}
```

## Common Follow-up Questions

- What is the difference between implicit and explicit transactions in EF Core?
- How does EF Core transaction interact with `TransactionScope`?
- What isolation level does EF Core use by default for implicit transactions?
- How do savepoints differ from nested transactions?
- When should you use `Serializable` isolation and what are the performance implications?

## Common Mistakes / Pitfalls

- **Calling `SaveChanges` multiple times without an explicit transaction**: Each `SaveChanges` has its own implicit transaction. If the second call fails, the first is already committed — no rollback possible. Use an explicit transaction.
- **Not handling `CommitAsync` failure**: `CommitAsync` can fail (e.g., network drop). If it throws, the transaction was rolled back by the DB. Don't assume it committed if no exception means success after a timeout.
- **Using `TransactionScope` with async code without `TransactionScopeAsyncFlowOption.Enabled`**: Standard `TransactionScope` doesn't flow through async continuations. You must pass `TransactionScopeAsyncFlowOption.Enabled` or use `db.Database.BeginTransactionAsync` instead.
- **Opening a transaction on one DbContext and calling `SaveChanges` on another**: Two separate `DbContext` instances use separate connections and transactions. Sharing a transaction requires explicitly sharing the `DbConnection` and using `db.Database.UseTransaction`.
- **Forgetting to `CommitAsync` before the `await using` scope ends**: If you don't call `CommitAsync`, the transaction rolls back on dispose — silently discarding all changes. Always call `CommitAsync` explicitly.

## References

- [Transactions — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/transactions)
- [IDbContextTransaction — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.entityframeworkcore.storage.idbcontexttransaction)
- [Savepoints — EF Core 5 — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/transactions#savepoints)
- [See: isolation-levels.md](./isolation-levels.md)
- [See: manual-transactions-ef-core.md](./manual-transactions-ef-core.md)
