# Change Tracking Overview in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟢 Junior
**Tags:** `ef-core`, `change-tracking`, `entity-states`, `SaveChanges`, `identity-map`

## Question

> How does EF Core's change tracking work? What are the entity states, and how does EF Core know what SQL to generate when you call `SaveChanges`?

## Short Answer

EF Core maintains a **change tracker** that records every entity loaded or attached to a `DbContext`. Each entity has an `EntityState`: `Added`, `Modified`, `Deleted`, `Unchanged`, or `Detached`. When you call `SaveChanges`, EF Core walks the change tracker, compares current property values against an internal snapshot taken at load time, and generates INSERT/UPDATE/DELETE statements accordingly. Entities you query are tracked as `Unchanged`; setting a property moves them to `Modified`; calling `db.Add` makes them `Added`; calling `db.Remove` marks them `Deleted`.

## Detailed Explanation

### The Five Entity States

| State | Meaning | SQL generated on SaveChanges |
|-------|---------|------------------------------|
| `Added` | New entity, not yet in DB | INSERT |
| `Modified` | Loaded entity with changed properties | UPDATE |
| `Deleted` | Marked for removal | DELETE |
| `Unchanged` | Loaded entity, no changes detected | None |
| `Detached` | Not being tracked by this context | None |

### How Tracking Works

When you load an entity (e.g., `db.Orders.FindAsync(1)`):
1. EF Core executes the SQL and materializes an `Order` object.
2. It registers the entity in the **identity map** keyed by its PK.
3. It creates a **snapshot** of all current property values.
4. The entity state is set to `Unchanged`.

When you modify a property:
```csharp
order.Status = "Shipped";
```
Nothing happens immediately. The entity is still in state `Unchanged` until `DetectChanges` runs.

When you call `SaveChangesAsync`:
1. EF Core calls `DetectChanges` — it compares every `Unchanged` entity's current values to its snapshot.
2. Any entity with differing values is moved to `Modified`.
3. EF Core generates SQL for all `Added`, `Modified`, and `Deleted` entities.
4. Executes in a transaction (implicit, unless you provide one).
5. After success, resets all entities back to `Unchanged` and updates their snapshots.

### Identity Map — Deduplication

The identity map ensures that loading the same entity twice from the same context returns the same object reference:

```csharp
var o1 = await db.Orders.FindAsync(1, ct);
var o2 = await db.Orders.FindAsync(1, ct);  // returns cached instance — no SQL
bool same = ReferenceEquals(o1, o2);        // true
```

This is important: modifications to `o1` are visible through `o2` because they are the same object.

### Inspecting the Change Tracker

```csharp
// Before SaveChanges — inspect what will happen
foreach (var entry in db.ChangeTracker.Entries())
{
    Console.WriteLine($"{entry.Metadata.Name} [{entry.State}]");
    if (entry.State == EntityState.Modified)
    {
        foreach (var prop in entry.Properties.Where(p => p.IsModified))
            Console.WriteLine($"  {prop.Metadata.Name}: {prop.OriginalValue} → {prop.CurrentValue}");
    }
}
```

### Adding, Modifying, Deleting

```csharp
// Add — creates new entity
var product = new Product { Name = "Widget", Price = 9.99m };
db.Products.Add(product);        // state: Added
await db.SaveChangesAsync(ct);   // SQL: INSERT INTO Products ...
// After SaveChanges: state = Unchanged, Id populated from DB

// Modify — change tracked entity
var order = await db.Orders.FindAsync(id, ct);  // state: Unchanged
order.Status = "Shipped";                        // state: Modified (after DetectChanges)
await db.SaveChangesAsync(ct);                   // SQL: UPDATE Orders SET Status = ...

// Delete
db.Orders.Remove(order);        // state: Deleted
await db.SaveChangesAsync(ct);  // SQL: DELETE FROM Orders WHERE Id = ...
```

## Code Example

```csharp
// Full lifecycle example
public async Task ProcessOrderAsync(int orderId, CancellationToken ct)
{
    // Load — entity is Unchanged
    var order = await db.Orders
        .Include(o => o.Lines)
        .FirstAsync(o => o.Id == orderId, ct);

    Console.WriteLine(db.Entry(order).State);  // Unchanged

    // Modify — EF Core will detect this in DetectChanges
    order.Status = "Processing";

    // Add a new related entity
    var note = new OrderNote { OrderId = orderId, Text = "Processing started" };
    db.OrderNotes.Add(note);

    Console.WriteLine(db.Entry(order).State);  // still Unchanged (pre-DetectChanges)
    Console.WriteLine(db.Entry(note).State);   // Added

    // SaveChanges: runs DetectChanges → UPDATE order + INSERT note in one batch
    await db.SaveChangesAsync(ct);

    Console.WriteLine(db.Entry(order).State);  // Unchanged (reset after save)
    Console.WriteLine(note.Id);                // populated with DB-generated Id
}
```

## Common Follow-up Questions

- What is the difference between `db.Entry(entity).State = EntityState.Modified` and simply modifying a property?
- How do you work with detached entities (e.g., entities deserialized from JSON in a PUT request)?
- Does EF Core track entities retrieved with `AsNoTracking`?
- What happens to the change tracker if `SaveChanges` throws an exception?
- How does `db.ChangeTracker.Clear()` differ from disposing and recreating the DbContext?

## Common Mistakes / Pitfalls

- **Assuming property assignment immediately changes the EntityState**: Setting a property doesn't change `EntityState` from `Unchanged` to `Modified` until `DetectChanges` runs (which happens automatically before `SaveChanges`, `Add`, `Update`, `Find`, and a few others).
- **Loading entities with `AsNoTracking` and expecting SaveChanges to persist changes**: No-tracking entities are in state `Detached` — EF Core completely ignores them in `SaveChanges`.
- **Using the same DbContext across multiple requests**: In web apps, the DbContext is scoped. Sharing it across concurrent requests corrupts the change tracker because it's not thread-safe.
- **Not checking state after a failed `SaveChanges`**: If `SaveChangesAsync` throws, entities remain in their pre-save state (e.g., `Added`, `Modified`). Retrying `SaveChanges` on the same context may produce duplicate operations. Dispose and recreate the context on failure.
- **Mixing tracked and no-tracking queries for the same entity**: If you load entity A with tracking, then load A again with `AsNoTracking`, you get two separate instances. Modifying the no-tracking copy and trying to save it requires manual re-attachment.

## References

- [Change tracking — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/change-tracking/)
- [Entity states — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/change-tracking/entity-entries)
- [Identity resolution — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/tracking#identity-resolution)
- [See: entity-states.md](./entity-states.md)
- [See: change-tracker-performance.md](./change-tracker-performance.md)
