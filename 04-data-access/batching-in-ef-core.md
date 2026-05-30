# Batching in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `batching`, `SaveChanges`, `ExecuteUpdateAsync`, `ExecuteDeleteAsync`, `bulk-update`, `performance`

## Question

> How does EF Core batch SQL statements? What is the difference between `SaveChanges` batching and the `ExecuteUpdate`/`ExecuteDelete` APIs introduced in EF Core 7? When should you use each approach?

## Short Answer

EF Core's `SaveChanges` automatically batches all pending `INSERT`/`UPDATE`/`DELETE` statements into a single database round-trip using a multi-command packet. This eliminates per-row round-trip overhead for tracked entity changes. `ExecuteUpdateAsync` and `ExecuteDeleteAsync` (EF Core 7+) go further: they issue a single `UPDATE` or `DELETE` SQL statement that affects all matching rows without loading entities into memory or touching the change tracker. Use `SaveChanges` batching when you have tracked entities with complex business logic or relationships; use `ExecuteUpdate`/`ExecuteDelete` for bulk set-based operations where you know the criteria upfront.

## Detailed Explanation

### SaveChanges Batching

When you modify multiple tracked entities and call `SaveChanges`, EF Core does **not** issue one SQL statement per entity. Instead, it groups all pending changes into the minimum number of round-trips:

```csharp
for (int i = 0; i < 100; i++)
    db.Orders.Add(new Order { /* … */ });

await db.SaveChangesAsync(ct);
// EF Core sends one batch: INSERT INTO Orders … (row 1), … (row 100)
// Not 100 separate INSERT statements
```

**Batch size limit:** By default, EF Core uses a batch size of 42 for SQL Server (configurable). Larger batches are split automatically:

```csharp
services.AddDbContext<AppDb>(opt =>
    opt.UseSqlServer(conn, sql =>
        sql.MaxBatchSize(100)));  // adjust for your workload
```

**What's included in a batch:**
- INSERT for Added entities
- UPDATE for Modified entities
- DELETE for Deleted entities
- These can be mixed in one round-trip

**What SaveChanges still does per-entity:**
- Change detection (DetectChanges)
- Snapshot comparison for modified properties
- Navigation fixup and FK population

So `SaveChanges` batching reduces round-trips but not memory/CPU for change tracking.

### ExecuteUpdateAsync / ExecuteDeleteAsync (EF Core 7+)

These methods operate directly on the database **without loading any entities**:

```csharp
// ✅ Single UPDATE statement — no entities in memory
await db.Orders
    .Where(o => o.Status == "Pending" && o.CreatedAt < cutoff)
    .ExecuteUpdateAsync(setters => setters
        .SetProperty(o => o.Status, "Expired")
        .SetProperty(o => o.UpdatedAt, DateTimeOffset.UtcNow),
        ct);
// SQL: UPDATE Orders SET Status = 'Expired', UpdatedAt = @now
//      WHERE Status = 'Pending' AND CreatedAt < @cutoff

// ✅ Single DELETE statement
await db.AuditLogs
    .Where(l => l.CreatedAt < DateTimeOffset.UtcNow.AddYears(-2))
    .ExecuteDeleteAsync(ct);
// SQL: DELETE FROM AuditLogs WHERE CreatedAt < @cutoff
```

**Key differences vs SaveChanges:**

| | `SaveChanges` batch | `ExecuteUpdate` / `ExecuteDelete` |
|--|--------------------|------------------------------------|
| Loads entities | ✅ Yes | ❌ No |
| Change tracker affected | ✅ Yes | ❌ No (stale tracked entities!) |
| Business logic in entities | ✅ Runs | ❌ Bypassed |
| Domain events triggered | ✅ If wired to SaveChanges | ❌ No |
| SQL shape | Multi-row INSERT/UPDATE/DELETE | Single set-based UPDATE/DELETE |
| Best for | Normal CRUD + business rules | Bulk administrative updates |
| Supports `Include`/navigation | N/A | Only on filter predicate |

### Change Tracker Staleness After ExecuteUpdate

A critical gotcha: `ExecuteUpdate` does not update already-loaded tracked entities:

```csharp
var order = await db.Orders.FindAsync(1, ct);  // tracked, Status = "Pending"

await db.Orders
    .Where(o => o.Id == 1)
    .ExecuteUpdateAsync(s => s.SetProperty(o => o.Status, "Expired"), ct);

Console.WriteLine(order.Status);  // still "Pending" — tracked instance is stale!
```

Fix: call `db.ChangeTracker.Clear()` after bulk operations, or reload the entity.

### Combining Both Approaches

A common pattern: use `ExecuteUpdate` for the bulk portion, then `SaveChanges` for the entity-level changes:

```csharp
// Step 1: bulk expire old drafts (set-based, no entity loading)
await db.Orders
    .Where(o => o.Status == "Draft" && o.CreatedAt < oldCutoff)
    .ExecuteUpdateAsync(s => s.SetProperty(o => o.Status, "Expired"), ct);

// Step 2: create a new batch report entity (tracked, with business logic)
db.BatchReports.Add(new BatchReport { RunAt = DateTimeOffset.UtcNow, Action = "ExpireOldDrafts" });
await db.SaveChangesAsync(ct);
```

## Code Example

```csharp
// SaveChanges batching — 500 inserts in one round-trip
public async Task SeedProductsAsync(IEnumerable<ProductDto> dtos, CancellationToken ct)
{
    foreach (var dto in dtos)
        db.Products.Add(new Product { Name = dto.Name, Price = dto.Price });

    await db.SaveChangesAsync(ct);  // batched insert, not 500 separate queries
}

// ExecuteUpdate — bulk price increase
public async Task ApplyDiscountAsync(int categoryId, decimal factor, CancellationToken ct)
{
    int affected = await db.Products
        .Where(p => p.CategoryId == categoryId && p.IsActive)
        .ExecuteUpdateAsync(s =>
            s.SetProperty(p => p.Price, p => p.Price * factor)
             .SetProperty(p => p.UpdatedAt, DateTimeOffset.UtcNow),
            ct);

    logger.LogInformation("Updated {Count} product prices in category {Id}", affected, categoryId);
}

// ExecuteDelete — purge old logs
public async Task PurgeAuditLogsAsync(int retentionDays, CancellationToken ct)
{
    var cutoff = DateTimeOffset.UtcNow.AddDays(-retentionDays);
    int deleted = await db.AuditLogs
        .Where(l => l.CreatedAt < cutoff)
        .ExecuteDeleteAsync(ct);

    logger.LogInformation("Purged {Count} audit log entries older than {Days} days", deleted, retentionDays);
}
```

## Common Follow-up Questions

- Does `ExecuteUpdate` fire domain events or interceptors registered on `ISaveChangesInterceptor`?
- How does `SaveChanges` batching behave inside an explicit transaction?
- What is the maximum batch size for SQL Server, PostgreSQL, and SQLite?
- Can `ExecuteUpdate` use navigation properties in the `SetProperty` expression?
- How do you perform a conditional bulk update (SET … WHERE) with `ExecuteUpdate`?

## Common Mistakes / Pitfalls

- **Assuming `ExecuteUpdate` refreshes tracked entities**: After `ExecuteUpdateAsync`, any in-memory entities that match the filter still hold their old values. Stale entities can cause incorrect reads or a double-update on the next `SaveChanges`.
- **Using `SaveChanges` for millions of rows**: Loading 1 million entities into memory for change tracking, then calling `SaveChanges`, will exhaust memory and be very slow. Switch to `ExecuteUpdate`/`ExecuteDelete` or `SqlBulkCopy` for massive operations.
- **Bypassing domain logic with `ExecuteUpdate`**: If your `Order.Status` setter runs validation, raises domain events, or calls other services, `ExecuteUpdate` bypasses all of that. Reserve it for purely administrative/technical operations.
- **Not wrapping `ExecuteUpdate` + `SaveChanges` in a transaction**: If your operation requires both a bulk update and entity-tracked changes to succeed atomically, wrap them in `BeginTransactionAsync` — they don't share a transaction by default.
- **Setting batch size too large**: Very large batches can exceed the SQL Server command packet limit and cause `TDS protocol errors`. The default 42 is conservative; test before increasing significantly.

## References

- [ExecuteUpdate and ExecuteDelete — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/execute-insert-update-delete)
- [Efficient updating — EF Core performance — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/efficient-updating)
- [SaveChanges — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/basic)
- [See: bulk-operations.md](./bulk-operations.md)
- [See: change-tracker-performance.md](./change-tracker-performance.md)
