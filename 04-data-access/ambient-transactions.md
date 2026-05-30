# Ambient Transactions with TransactionScope

**Category:** Data Access / Transactions
**Difficulty:** 🔴 Senior
**Tags:** `TransactionScope`, `System.Transactions`, `MSDTC`, `async`, `ambient-transaction`, `DTC-escalation`

## Question

> What is `TransactionScope` and how does it work? What are the pitfalls of using it with `async`/`await`, when does it escalate to MSDTC, and when should you prefer `db.Database.BeginTransactionAsync` instead?

## Short Answer

`TransactionScope` creates an **ambient transaction** that any code in the call stack can enlist in automatically — no explicit transaction passing required. Multiple `DbConnection` instances created within the scope enlist transparently. The critical pitfall: the default `TransactionScope` constructor doesn't flow through async continuations. You must use `TransactionScopeAsyncFlowOption.Enabled` or the transaction context is lost after the first `await`. MSDTC escalation occurs when a second distinct connection (or a non-SQL Server resource) enlists — this fails on Azure SQL and many cloud databases. Prefer `db.Database.BeginTransactionAsync()` for EF Core scenarios; use `TransactionScope` only when you must coordinate multiple independent connections or legacy ADO.NET code.

## Detailed Explanation

### How TransactionScope Works

```csharp
// Ambient transaction: both db calls enlist automatically without explicit transaction passing
using (var scope = new TransactionScope(
    TransactionScopeOption.Required,
    TransactionScopeAsyncFlowOption.Enabled))  // ← CRITICAL for async
{
    // Any SqlConnection opened here enlists in the ambient transaction
    await DoSomethingWithDb1Async(ct);
    await DoSomethingWithDb2Async(ct);  // same DB → reuses connection, no MSDTC
    scope.Complete();  // → COMMIT
}
// If Complete() not called → ROLLBACK on dispose
```

The ambient transaction is stored in `Transaction.Current`. Code doesn't need to know about it:

```csharp
// No transaction parameter needed — enlists in ambient scope automatically
async Task DoSomethingWithDb1Async(CancellationToken ct)
{
    using var conn = new SqlConnection(connStr);
    await conn.OpenAsync(ct);  // ← enlists in Transaction.Current automatically
    await conn.ExecuteAsync("INSERT INTO Logs ...", ct);
}
```

### The Async Pitfall

`TransactionScope` stores the ambient transaction in a `[ThreadStatic]` field. Before .NET 4.5.1, `await` continuations ran on thread pool threads that don't inherit `[ThreadStatic]` state:

```csharp
// ❌ BROKEN: Transaction.Current is null after the first await
using var scope = new TransactionScope();  // no AsyncFlowOption
await SomeDbCallAsync();  // ← async continuation runs on different thread
// Transaction.Current is now null — subsequent code runs without transaction!
scope.Complete();
```

**Fix: Always use `TransactionScopeAsyncFlowOption.Enabled`:**

```csharp
// ✅ Transaction context flows through async continuations
using var scope = new TransactionScope(
    TransactionScopeOption.Required,
    new TransactionOptions { IsolationLevel = IsolationLevel.ReadCommitted },
    TransactionScopeAsyncFlowOption.Enabled);

await SomeDbCallAsync();  // ← Transaction.Current still set correctly
scope.Complete();
```

### MSDTC Escalation

The transaction escalates to MSDTC (Distributed Transaction Coordinator) when:
1. A second **distinct** `SqlConnection` enlists in the same `TransactionScope`.
2. A non-SQL Server resource manager (MSMQ, Oracle, etc.) enlists.

```csharp
// ❌ Two distinct connections → MSDTC escalation
using var scope = new TransactionScope(TransactionScopeAsyncFlowOption.Enabled);

using var conn1 = new SqlConnection(connStr1);
await conn1.OpenAsync(ct);  // enlists

using var conn2 = new SqlConnection(connStr2);  // different server!
await conn2.OpenAsync(ct);  // ← MSDTC escalation → fails on Azure SQL
```

SQL Server 2005+ avoids escalation for two **promotable** connections to the **same server/database** — only one physical connection is used (SPMT — Single Phase Manage Transaction). But two different connection strings always escalate.

**Consequences:**
- Azure SQL: throws `NotSupportedException` — DTC not supported.
- Docker containers: MSDTC service not available.
- .NET Core/.NET 5+: MSDTC support exists only on Windows, and is unreliable.

### When to Use TransactionScope

| Scenario | Recommendation |
|----------|---------------|
| Single EF Core context | ❌ Use `db.Database.BeginTransactionAsync` — simpler, no MSDTC risk |
| Two EF Core contexts, same DB server | ✅ TransactionScope can work (SPMT, no escalation) |
| EF Core + legacy ADO.NET, same DB | ✅ TransactionScope — ambient enlistment convenience |
| Two different DB servers | ❌ Don't use transactions — use Saga/Outbox instead |
| Azure SQL | ⚠️ Only single-connection scenarios |

### Nested TransactionScope

```csharp
// TransactionScopeOption.Required: uses existing ambient scope (or creates one)
using var outer = new TransactionScope(
    TransactionScopeOption.Required, TransactionScopeAsyncFlowOption.Enabled);

// Inner with Suppress: inner operation runs OUTSIDE the outer transaction
using (var inner = new TransactionScope(
    TransactionScopeOption.Suppress, TransactionScopeAsyncFlowOption.Enabled))
{
    await LogAuditAsync(ct);  // commits regardless of outer transaction outcome
    inner.Complete();
}

await DoMainWorkAsync(ct);  // part of outer transaction
outer.Complete();
```

## Code Example

```csharp
// Cross-service call that must be atomic: EF Core + Dapper on SAME database
public async Task TransferBetweenAccountsAsync(
    int fromId, int toId, decimal amount, CancellationToken ct)
{
    // Use TransactionScope only because we have two independent data access layers
    using var scope = new TransactionScope(
        TransactionScopeOption.Required,
        new TransactionOptions { IsolationLevel = IsolationLevel.Serializable },
        TransactionScopeAsyncFlowOption.Enabled);

    // EF Core operation — enlists in ambient scope
    var fromAccount = await db.Accounts.FindAsync([fromId], ct)
        ?? throw new NotFoundException(fromId);
    fromAccount.Balance -= amount;
    await db.SaveChangesAsync(ct);

    // Dapper operation on same DB — enlists in the SAME ambient scope (SPMT, no MSDTC)
    using var conn = new SqlConnection(dbConnStr);
    await conn.ExecuteAsync(
        "UPDATE Accounts SET Balance = Balance + @amount WHERE Id = @id",
        new { amount, id = toId });

    scope.Complete();  // ← both operations committed atomically
}
```

## Common Follow-up Questions

- What is SPMT (Single Phase Managed Transaction) and when does SQL Server use it?
- Can you use `TransactionScope` with `IsolationLevel.Snapshot`?
- What happens if `scope.Complete()` is called but the database connection drops before the commit completes?
- How do you test code that uses `TransactionScope` — can you roll back integration tests using a non-completed scope?
- Is `TransactionScope` supported in .NET on Linux?

## Common Mistakes / Pitfalls

- **Forgetting `TransactionScopeAsyncFlowOption.Enabled`**: The default constructor does not flow ambient transactions across `await` points. This is the #1 `TransactionScope` bug in modern .NET code — the transaction silently disappears after the first await.
- **Calling `scope.Complete()` inside a try-catch that swallows exceptions**: If an inner operation throws and you catch it without re-throwing, then call `scope.Complete()`, the transaction commits despite the inner failure. Always re-throw or don't complete.
- **Using `TransactionScope` for operations across different databases**: Two different connection strings → MSDTC escalation → fails on Azure SQL, Docker, Linux. Use the Saga pattern for cross-database atomicity.
- **Nesting `TransactionScope` without understanding `Required` vs `RequiresNew`**: `Required` joins the outer scope — if outer rolls back, inner also rolls back. `RequiresNew` starts an independent transaction — inner commits/rolls back independently. Mixing these unexpectedly is a common correctness bug.
- **Using `TransactionScope` in ASP.NET Core with DI-scoped DbContext**: If the `DbContext` is scoped and `TransactionScope` is opened in a middleware, the connection enrolled in the scope may be different from the one used by the DbContext (pool checkout may return a different connection). Prefer explicit EF Core transactions.

## References

- [TransactionScope — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.transactions.transactionscope)
- [TransactionScopeAsyncFlowOption — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.transactions.transactionscopeasyncflowoption)
- [Distributed transactions — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/distributed-transactions)
- [See: transaction-basics.md](./transaction-basics.md)
- [See: distributed-transactions.md](./distributed-transactions.md)
