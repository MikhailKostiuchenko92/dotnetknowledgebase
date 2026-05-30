# Detecting Changes in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `DetectChanges`, `AutoDetectChanges`, `change-tracking`, `snapshots`, `performance`

## Question

> How does EF Core detect property changes before `SaveChanges`? What is `DetectChanges`, when is it called automatically, and how does disabling `AutoDetectChangesEnabled` affect behavior and performance?

## Short Answer

EF Core detects changes by comparing each tracked entity's current property values against a **snapshot** taken at load time. `DetectChanges` performs this comparison and transitions `Unchanged` entities to `Modified` when differences are found. By default, EF Core calls `DetectChanges` automatically before `SaveChanges`, `Add`, `Update`, `Remove`, `Find`, and other operations — this is `AutoDetectChangesEnabled = true`. Disabling it (`AutoDetectChangesEnabled = false`) removes these automatic calls, requiring you to call `DetectChanges` manually. This is a significant performance optimization for bulk operations but risks missing modifications if you forget the manual call.

## Detailed Explanation

### How Snapshot-Based Detection Works

1. When an entity is loaded (or attached with state `Unchanged`), EF Core serializes all scalar property values into an internal snapshot (a `object[]` array stored in the `EntityEntry`).
2. `DetectChanges` walks every `Unchanged` entry in the identity map.
3. For each entry, it compares the current property values to the snapshot using `ValueComparer` (or `Equals` by default).
4. Any entry with at least one differing property is transitioned to state `Modified`, and individual properties are marked `IsModified = true`.
5. Navigation fixup also runs (reconnecting navigation properties to changed FK values).

### When AutoDetectChanges Fires

EF Core triggers automatic `DetectChanges` before:

| Operation | Why |
|-----------|-----|
| `SaveChanges` / `SaveChangesAsync` | Must know what to persist |
| `Add` / `AddAsync` | Navigation fixup across the graph |
| `Attach` | Correctly registers state |
| `Remove` | Cascade delete evaluation |
| `Update` | Full graph state assignment |
| `ChangeTracker.Entries()` | Returns up-to-date state |
| `Find` / `FindAsync` | Checks identity map first |

Each of these calls `DetectChanges` on **all tracked entities** — not just the entity being operated on.

### The O(n) Cost

`DetectChanges` is O(n) where n = number of tracked entities × properties per entity. For typical CRUD (10–100 entities) it's imperceptibly fast. For bulk operations (10 000+ entities), it becomes a bottleneck:

```
10 properties × 10 000 entities = 100 000 comparisons per DetectChanges call
If triggered 10 000 times (once per Add) = 1 000 000 000 comparisons
```

[See: change-tracker-performance.md](./change-tracker-performance.md)

### Disabling AutoDetectChanges

```csharp
db.ChangeTracker.AutoDetectChangesEnabled = false;

// Now you must call DetectChanges manually before SaveChanges
db.Products.AddRange(products);    // AddRange: no per-entity DetectChanges
db.ChangeTracker.DetectChanges();  // manual call once
await db.SaveChangesAsync(ct);     // DetectChanges NOT called automatically
```

**What breaks if you forget `DetectChanges`:**

```csharp
db.ChangeTracker.AutoDetectChangesEnabled = false;

var order = await db.Orders.FindAsync(1, ct);  // state: Unchanged
order.Status = "Shipped";                       // state still: Unchanged
// DetectChanges never runs!
await db.SaveChangesAsync(ct);                  // ← generates NO SQL — status is NOT saved!
```

> **Critical:** With `AutoDetectChangesEnabled = false`, setting a property does NOT automatically mark the entity as `Modified`. You must either call `DetectChanges()` or manually set `db.Entry(entity).State = EntityState.Modified` (which marks ALL properties modified) or `db.Entry(entity).Property(x => x.Status).IsModified = true` (specific property).

### Forcing Specific Property as Modified

```csharp
// Without DetectChanges — explicit property marking
db.ChangeTracker.AutoDetectChangesEnabled = false;

var order = new Order { Id = 42 };
db.Orders.Attach(order);  // Unchanged

// Force only Status to be updated
db.Entry(order).Property(o => o.Status).CurrentValue = "Shipped";
db.Entry(order).Property(o => o.Status).IsModified = true;

await db.SaveChangesAsync(ct);
// SQL: UPDATE Orders SET Status = 'Shipped' WHERE Id = 42
```

### ChangeTracker.HasChanges()

Quick check without full DetectChanges overhead:

```csharp
// Efficient: returns true/false without full snapshot comparison
if (db.ChangeTracker.HasChanges())
    await db.SaveChangesAsync(ct);
```

> Note: `HasChanges()` calls `DetectChanges` internally if `AutoDetectChangesEnabled = true`. With auto-detection disabled, it only checks the current state flags without doing snapshot comparison.

## Code Example

```csharp
// Safe pattern: disable auto-detection for bulk, restore after
public async Task BulkUpdateStatusAsync(
    IEnumerable<int> orderIds, string newStatus, CancellationToken ct)
{
    db.ChangeTracker.AutoDetectChangesEnabled = false;
    try
    {
        var orders = await db.Orders
            .Where(o => orderIds.Contains(o.Id))
            .ToListAsync(ct);

        foreach (var order in orders)
            order.Status = newStatus;   // no auto-DetectChanges → fast loop

        db.ChangeTracker.DetectChanges();  // ← manual, once for all entities
        await db.SaveChangesAsync(ct);
        db.ChangeTracker.Clear();
    }
    finally
    {
        db.ChangeTracker.AutoDetectChangesEnabled = true;  // restore
    }
}

// Alternative: use ExecuteUpdateAsync for this exact pattern (better for large N)
await db.Orders
    .Where(o => orderIds.Contains(o.Id))
    .ExecuteUpdateAsync(s => s.SetProperty(o => o.Status, newStatus), ct);
```

## Common Follow-up Questions

- What is the difference between `DetectChanges` and `ChangeTracker.HasChanges()`?
- Does calling `db.Entry(entity).State = EntityState.Modified` bypass `DetectChanges`?
- How does EF Core handle custom value comparers (`ValueComparer<T>`) in change detection?
- What is `ChangeTracker.TrackGraph` and when would you use it?
- Is change detection re-entrant — can it be triggered recursively?

## Common Mistakes / Pitfalls

- **Forgetting to call `DetectChanges` after disabling auto-detection**: The most common mistake. `SaveChanges` without `DetectChanges` when `AutoDetectChangesEnabled = false` silently skips `Modified` entities — your changes are lost with no error.
- **Not restoring `AutoDetectChangesEnabled` in error paths**: If an exception occurs mid-batch and you catch it without the `finally` block, subsequent code on the same context has auto-detection disabled.
- **Using `db.ChangeTracker.Entries()` to check state before DetectChanges**: `Entries()` triggers `DetectChanges` if auto-detection is enabled. In a loop, this negates your performance optimization.
- **Assuming `AddRange` calls `DetectChanges`**: `AddRange` internally sets `AutoDetectChangesEnabled = false` temporarily, adds all items, then calls `DetectChanges` once. This is correct and efficient — don't add an extra `DetectChanges` call after `AddRange`.
- **Mixing manual state setting with auto-detection**: Setting `entry.State = EntityState.Modified` while auto-detection is enabled is safe, but the next auto-detection call may re-evaluate and potentially reset unmodified properties. Be consistent: either use auto-detection or manual state management, not both.

## References

- [Change detection — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/change-tracking/change-detection)
- [ChangeTracker.AutoDetectChangesEnabled — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.entityframeworkcore.changetracking.changetracker.autodetectchangesenabled)
- [EF Core performance — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/efficient-updating)
- [See: change-tracking-overview.md](./change-tracking-overview.md)
- [See: change-tracker-performance.md](./change-tracker-performance.md)
