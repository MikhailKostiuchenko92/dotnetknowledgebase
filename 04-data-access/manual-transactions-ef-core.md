# Manual Transactions in EF Core

**Category:** Data Access / Transactions
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `IDbContextTransaction`, `BeginTransactionAsync`, `UseTransaction`, `shared-connection`, `Dapper`, `savepoints`

## Question

> How do you manage explicit transactions in EF Core? How do you share a transaction between two DbContext instances, between EF Core and Dapper, and when would you use `db.Database.UseTransaction` vs `BeginTransactionAsync`?

## Short Answer

EF Core's `db.Database.BeginTransactionAsync()` creates and owns a new transaction on the current connection. For cross-context or EF Core + Dapper scenarios, you obtain the underlying `DbConnection` and `DbTransaction` from one participant and pass them to the other via `UseConnection` and `UseTransaction`. This is required when you need multiple EF Core contexts or an EF Core context alongside raw ADO.NET/Dapper to share the same atomic unit of work. Savepoints allow partial rollbacks within a transaction for scenarios where inner failures should not abort the entire outer operation.

## Detailed Explanation

### Basic Transaction Recap

[See: transaction-basics.md](./transaction-basics.md) for ACID, implicit transactions, and `BeginTransactionAsync`.

### Sharing a Transaction Between Two DbContext Instances

By default, two `DbContext` instances use separate connections and transactions. To share:

```csharp
// Open the connection and transaction on context 1
var conn = db1.Database.GetDbConnection();
await conn.OpenAsync(ct);
await using var tx = await conn.BeginTransactionAsync(ct);

// Tell db1 to use this transaction (not start its own)
await db1.Database.UseTransactionAsync(tx, ct);

// Tell db2 to use the same connection AND transaction
await db2.Database.SetDbConnectionAsync(conn, ct);  // EF Core 9+
await db2.Database.UseTransactionAsync(tx, ct);

// Now both operate within the same transaction
db1.Orders.Add(order);
await db1.SaveChangesAsync(ct);

db2.AuditLogs.Add(auditLog);
await db2.SaveChangesAsync(ct);

await tx.CommitAsync(ct);  // commits both contexts' changes
```

> **Note:** EF Core's `SetDbConnectionAsync` was added in EF Core 9. In earlier versions, configure the same `DbConnection` instance via `DbContextOptions` (`UseConnection` pattern or passing the connection to `UseSqlServer`).

### Sharing a Transaction Between EF Core and Dapper

Dapper extends `IDbConnection` — so you can pass EF Core's underlying connection and transaction to Dapper:

```csharp
// Get EF Core's connection
var conn = db.Database.GetDbConnection();
if (conn.State == ConnectionState.Closed)
    await conn.OpenAsync(ct);

// Start a transaction through EF Core
await using var tx = await db.Database.BeginTransactionAsync(ct);

// EF Core operations
db.Invoices.Add(invoice);
await db.SaveChangesAsync(ct);

// Dapper operations — same connection and transaction
await conn.ExecuteAsync(
    "UPDATE CustomerStats SET InvoiceCount = InvoiceCount + 1 WHERE Id = @Id",
    new { invoice.CustomerId },
    transaction: tx.GetDbTransaction());  // ← pass EF Core's transaction to Dapper

await tx.CommitAsync(ct);  // both EF Core and Dapper changes committed atomically
```

`tx.GetDbTransaction()` returns the underlying `DbTransaction` that Dapper accepts.

### `UseTransaction` — Enlist in an Externally Managed Transaction

Use this when the transaction was created outside EF Core (e.g., by Dapper or raw ADO.NET):

```csharp
// Transaction created externally
var conn = new SqlConnection(connStr);
await conn.OpenAsync(ct);
await using var externalTx = await conn.BeginTransactionAsync(ct);

// Enlist EF Core into the external transaction
db.Database.SetDbConnection(conn);
await db.Database.UseTransactionAsync(externalTx, ct);

// Now EF Core participates in the external transaction
db.Orders.Add(order);
await db.SaveChangesAsync(ct);

// Commit from the external transaction owner
await externalTx.CommitAsync(ct);
```

### Savepoints for Partial Rollback

```csharp
await using var tx = await db.Database.BeginTransactionAsync(ct);

// Phase 1: core operation
db.Orders.Add(mainOrder);
await db.SaveChangesAsync(ct);
await tx.CreateSavepointAsync("MainOrderSaved", ct);

// Phase 2: optional enrichment — not critical
try
{
    await enrichmentService.EnrichAsync(mainOrder.Id, ct);
    db.OrderEnrichments.Add(enrichment);
    await db.SaveChangesAsync(ct);
}
catch (EnrichmentException ex)
{
    logger.LogWarning(ex, "Enrichment failed — rolling back to savepoint");
    await tx.RollbackToSavepointAsync("MainOrderSaved", ct);
    // Main order still in transaction; enrichment rolled back
}

await tx.CommitAsync(ct);  // commits the main order (enrichment discarded on failure)
```

Savepoints are supported on SQL Server, PostgreSQL, MySQL, and SQLite.

### When NOT to Use Manual Transactions

- **Wrapping every SaveChanges in a transaction**: Implicit transactions are sufficient and cleaner. Only use explicit transactions when multiple logical operations must be atomic.
- **Long-running transactions**: Holding a transaction open while waiting for user input, external HTTP calls, or other I/O blocks database locks and can cause deadlocks. Keep transactions short.
- **Distributed operations**: A single SQL transaction cannot span two databases. Use the Saga pattern or outbox instead.

## Code Example

```csharp
// Cross-context + Dapper in one transaction
public async Task ProcessPaymentAsync(
    PaymentRequest req, CancellationToken ct)
{
    // Get shared connection from the primary context
    var conn = writeDb.Database.GetDbConnection();
    if (conn.State != ConnectionState.Open)
        await conn.OpenAsync(ct);

    await using var tx = await writeDb.Database.BeginTransactionAsync(
        IsolationLevel.ReadCommitted, ct);

    // EF Core context 1: write the payment
    writeDb.Payments.Add(new Payment
    {
        OrderId = req.OrderId,
        Amount = req.Amount,
        Method = req.Method
    });
    await writeDb.SaveChangesAsync(ct);

    // Dapper: update a denormalized read-model in the same transaction
    await conn.ExecuteAsync(
        "UPDATE OrderReadModel SET PaymentStatus = 'Paid', PaidAt = GETUTCDATE() WHERE Id = @Id",
        new { req.OrderId },
        transaction: tx.GetDbTransaction());

    // EF Core context 2 (audit): share the same transaction
    await auditDb.Database.UseTransactionAsync(tx.GetDbTransaction(), ct);
    auditDb.AuditEntries.Add(new AuditEntry { Action = "PaymentProcessed", EntityId = req.OrderId });
    await auditDb.SaveChangesAsync(ct);

    await tx.CommitAsync(ct);
}
```

## Common Follow-up Questions

- How does `UseTransaction` interact with EF Core's `EnableRetryOnFailure`?
- Can you use `TransactionScope` to coordinate EF Core and Dapper without manual connection sharing?
- What happens if one context in a shared transaction calls `SaveChanges` and fails — does it affect the other context's changes?
- How do you share a transaction across async operations where the connection might be returned to the pool?
- Is there a performance cost to using savepoints vs a full transaction rollback?

## Common Mistakes / Pitfalls

- **Passing `tx.GetDbTransaction()` to Dapper without checking if the connection matches**: Dapper verifies that the `IDbTransaction.Connection` matches the `IDbConnection` you're using. If they differ, it throws. Always share the same `DbConnection` instance.
- **Calling `CommitAsync` on a `UseTransaction` context**: EF Core's `tx.CommitAsync()` only commits if EF Core owns the transaction. If you enlisted via `UseTransaction`, the original owner must commit. Calling commit from the enslave context is a no-op or throws.
- **Opening the connection multiple times**: `GetDbConnection` returns the existing connection object. Calling `OpenAsync` when it's already open throws. Always check `conn.State` first.
- **Holding transactions across HTTP round-trips**: Passing a transaction across two HTTP requests (e.g., begin in one, commit in another) is a design anti-pattern. Transactions must be resolved within a single request or unit of work.
- **Using `SetDbConnection` on a pooled DbContext**: DbContext pooling resets the connection on return. Using `SetDbConnection` with a pooled context may cause the shared connection to be returned to the wrong pool.

## References

- [Transactions — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/transactions)
- [External transactions — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/transactions#using-external-dbtransactions-relational-databases-only)
- [GetDbTransaction — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.entityframeworkcore.storage.idbcontexttransaction.getdbtransaction)
- [See: transaction-basics.md](./transaction-basics.md)
- [See: dapper-ef-core-hybrid.md](./dapper-ef-core-hybrid.md)
