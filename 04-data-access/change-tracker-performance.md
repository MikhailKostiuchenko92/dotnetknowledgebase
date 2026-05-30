# Change Tracker Performance in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `change-tracker`, `performance`, `DetectChanges`, `AutoDetectChanges`, `bulk-import`, `high-throughput`

## Question

> What is the performance cost of EF Core's change tracker and `DetectChanges`? How does `AutoDetectChangesEnabled` work, and what patterns do you use to maximize throughput in high-volume import or batch processing scenarios?

## Short Answer

EF Core's change tracker maintains a snapshot of every tracked entity's property values so it can detect modifications before `SaveChanges`. `DetectChanges` is O(n) in the number of tracked entities — it walks every tracked entity, compares every property against the snapshot, and marks modified ones. By default, EF Core calls `DetectChanges` automatically before `SaveChanges`, `Add`, `Update`, `Find`, and several other operations. In high-throughput scenarios (bulk imports, data migrations) this O(n) cost compounds to O(n²) overall. The key mitigations are: call `db.ChangeTracker.Clear()` periodically, set `AutoDetectChangesEnabled = false` during batch loads, use `AddRange` + single `SaveChanges` over loops, or switch to `ExecuteUpdate`/`ExecuteDelete` and `SqlBulkCopy` to bypass the change tracker entirely.

## Detailed Explanation

### What DetectChanges Does

When you call `db.SaveChangesAsync()`, EF Core calls `ChangeTracker.DetectChanges()` internally. This method:

1. Iterates all entries in the identity map (`_stateManager`).
2. For each entry in state `Unchanged`, compares every scalar property to its snapshot value.
3. Marks entries as `Modified` if any property differs.
4. Fixes up navigation properties (adds/removes from collections).

The cost is proportional to **number of tracked entities × number of properties per entity**. With 10 properties and N entities, DetectChanges is ~10N operations.

### The O(n²) Problem in Loops

```csharp
// ❌ Catastrophically slow for large N
foreach (var row in csvRows)  // 100,000 rows
{
    db.Products.Add(new Product { /* ... */ });  // Add() calls DetectChanges
    await db.SaveChangesAsync(ct);               // SaveChanges calls DetectChanges
}
// Total DetectChanges calls: 100,000 + 100,000 = 200,000
// Each call iterates all accumulated tracked entities → O(n²) total
```

Each `Add()` triggers DetectChanges on all previously added entities. After 50,000 adds, each `Add()` walks all 50,000 entries. The 100,000th add walks all 99,999 — catastrophic.

### Fix 1: Disable AutoDetectChanges + Batch SaveChanges

```csharp
db.ChangeTracker.AutoDetectChangesEnabled = false;

try
{
    const int batchSize = 500;
    int count = 0;

    foreach (var row in csvRows)
    {
        db.Products.Add(new Product { Name = row.Name, Price = row.Price });
        count++;

        if (count % batchSize == 0)
        {
            db.ChangeTracker.DetectChanges();  // manual, once per batch
            await db.SaveChangesAsync(ct);
            db.ChangeTracker.Clear();          // release tracked entities → constant memory
        }
    }

    db.ChangeTracker.DetectChanges();
    await db.SaveChangesAsync(ct);
}
finally
{
    db.ChangeTracker.AutoDetectChangesEnabled = true;  // restore for safety
}
```

This reduces DetectChanges calls from O(n) to O(n/batchSize), and each call only walks `batchSize` entities.

### Fix 2: `ChangeTracker.Clear()` Between Batches

```csharp
// Without Clear(): entities accumulate → each batch's DetectChanges is slower
// With Clear(): each batch resets to ~0 tracked entities → O(1) constant cost per batch
await db.SaveChangesAsync(ct);
db.ChangeTracker.Clear();  // detach all entities; GC can reclaim them
```

> **Warning:** After `Clear()`, any reference you hold to a previously tracked entity is in the `Detached` state. Do not call `SaveChanges` expecting those to persist.

### Fix 3: `AddRange` Instead of Repeated `Add`

```csharp
// ❌ Each Add() triggers AutoDetectChanges
foreach (var p in products) db.Products.Add(p);

// ✅ AddRange suspends AutoDetectChanges for the duration, calls it once at the end
db.Products.AddRange(products);
```

`AddRange`, `UpdateRange`, `RemoveRange`, and `AttachRange` all temporarily disable `AutoDetectChangesEnabled` internally for the duration of the call.

### Fix 4: Bypass the Change Tracker Entirely

For the fastest possible bulk inserts, skip EF Core's tracked path:

| Method | Entities in memory | Change tracker | Performance |
|--------|--------------------|----------------|-------------|
| `AddRange` + `SaveChanges` | Yes | Yes | Moderate |
| `ExecuteUpdate`/`ExecuteDelete` | No | No | Fast (set-based) |
| `SqlBulkCopy` | No | No | Fastest (bcp protocol) |
| EF Core Extensions (`BulkInsert`) | Configurable | No | Very fast |

```csharp
// SqlBulkCopy — 100k rows in under a second
using var copy = new SqlBulkCopy(connectionString);
copy.DestinationTableName = "Products";
copy.BatchSize = 1000;
await copy.WriteToServerAsync(dataTable, ct);
```

[See: bulk-operations.md](./bulk-operations.md)

### Measuring Change Tracker Cost

Instrument with `Stopwatch` or BenchmarkDotNet. Typical numbers on a modern machine with SQL Server:

| N tracked entities | DetectChanges (ms) |
|-------------------|-------------------|
| 1 000 | < 1 ms |
| 10 000 | ~5–10 ms |
| 100 000 | ~100–300 ms |
| 1 000 000 | ~1 000–3 000 ms |

The cost becomes noticeable above ~10k–20k tracked entities.

### AutoDetectChangesEnabled vs QueryTrackingBehavior

These are different settings:

| Setting | Scope | Effect |
|---------|-------|--------|
| `AutoDetectChangesEnabled = false` | Per-context instance | Disables automatic DetectChanges calls inside Add/Update/SaveChanges |
| `QueryTrackingBehavior.NoTracking` | Per-context or per-query | Queries don't register entities in the change tracker at all |

For read-only queries, `AsNoTracking` / `NoTracking` is better than disabling `AutoDetectChanges` (which still tracks, just doesn't auto-detect).

## Code Example

```csharp
// High-throughput import — 500k product rows
public async Task ImportProductsAsync(
    IAsyncEnumerable<ProductCsvRow> rows, CancellationToken ct)
{
    const int BatchSize = 1_000;
    var batch = new List<Product>(BatchSize);

    // Use a fresh DbContext per import — don't share with request-scoped context
    await using var db = await dbFactory.CreateDbContextAsync(ct);
    db.ChangeTracker.AutoDetectChangesEnabled = false;

    await foreach (var row in rows.WithCancellation(ct))
    {
        batch.Add(new Product { Name = row.Name, Price = row.Price, Sku = row.Sku });

        if (batch.Count >= BatchSize)
        {
            await FlushBatchAsync(db, batch, ct);
        }
    }

    if (batch.Count > 0)
        await FlushBatchAsync(db, batch, ct);
}

private static async Task FlushBatchAsync(
    AppDb db, List<Product> batch, CancellationToken ct)
{
    db.Products.AddRange(batch);     // AddRange: no per-entity DetectChanges
    await db.SaveChangesAsync(ct);   // one round-trip for the whole batch
    db.ChangeTracker.Clear();        // release entities → constant memory usage
    batch.Clear();
}
```

## Common Follow-up Questions

- What is the difference between `ChangeTracker.Clear()` and `ChangeTracker.DetectChanges()`?
- How does `SaveChangesAsync` interact with `AutoDetectChangesEnabled = false`? (You must call DetectChanges manually.)
- Does `AsNoTracking` also disable `AutoDetectChanges`? (No — different mechanism.)
- When is it safe to re-enable `AutoDetectChangesEnabled` after a batch operation?
- How does EF Core 8's new "typed model building" affect snapshot generation?

## Common Mistakes / Pitfalls

- **Not calling `DetectChanges` manually after disabling auto-detection**: If `AutoDetectChangesEnabled = false` and you call `SaveChanges` without calling `DetectChanges`, EF Core only persists entities in state `Added`/`Deleted` — `Modified` entities are **silently skipped** (their state was never updated from `Unchanged`).
- **Forgetting to restore `AutoDetectChangesEnabled` in error paths**: If an exception is thrown mid-batch and you catch it without restoring, subsequent operations in the same context will have auto-detection disabled.
- **Using the same DbContext for batch import and request handling**: Long-running imports keep thousands of entities in memory on the context. If the context is shared (e.g., request-scoped), other requests will be slow due to accumulated tracked entities.
- **Calling `db.Products.Add` in a tight loop with AutoDetectChanges enabled**: Each `Add` call checks and re-runs DetectChanges on all previous entries. Switch to `AddRange` or collect items and `AddRange` once per batch.
- **Not clearing after each batch**: Without `ChangeTracker.Clear()`, entities from previous batches remain tracked. Even with `AutoDetectChangesEnabled = false`, the identity map grows unboundedly, consuming memory.

## References

- [Performance: change tracking — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/efficient-updating#use-executeupdate-and-executedelete-when-relevant)
- [ChangeTracker.DetectChanges — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.entityframeworkcore.changetracking.changetracker.detectchanges)
- [EF Core performance tips — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/advanced-performance-topics)
- [See: bulk-operations.md](./bulk-operations.md)
- [See: batching-in-ef-core.md](./batching-in-ef-core.md)
