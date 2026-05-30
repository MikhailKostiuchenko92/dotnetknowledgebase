# Concurrency Tokens in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `concurrency`, `optimistic-concurrency`, `rowversion`, `Timestamp`, `DbUpdateConcurrencyException`, `ConcurrencyCheck`

## Question

> How does EF Core implement optimistic concurrency? What is the difference between `[ConcurrencyCheck]` and `[Timestamp]`/rowversion? How do you handle a `DbUpdateConcurrencyException` — what are the merge strategies?

## Short Answer

EF Core implements optimistic concurrency by including concurrency token values in UPDATE/DELETE `WHERE` clauses. If zero rows are affected (because another process changed the row), EF Core throws `DbUpdateConcurrencyException`. `[ConcurrencyCheck]` marks any property as a concurrency token, checking its original value in the WHERE clause. `[Timestamp]`/`rowversion` uses a database-managed binary version column that SQL Server increments on every row modification — preferred because the DB guarantees uniqueness without application-side management. On conflict, you must choose a merge strategy: database-wins (client changes lost), client-wins (overwrite database), or merge (apply only non-conflicting fields).

## Detailed Explanation

### Optimistic vs Pessimistic Concurrency

Optimistic concurrency assumes conflicts are rare — it does not lock rows. Instead, it detects conflicts at write time by verifying the row hasn't changed since it was read. Pessimistic concurrency locks rows with `SELECT … FOR UPDATE` or `UPDLOCK` to prevent concurrent writes.

Optimistic is default in EF Core and appropriate for most web scenarios (short-lived DbContext, low contention).

### `[ConcurrencyCheck]` — Application-Managed Token

```csharp
public class Product
{
    public int Id { get; set; }
    public string Name { get; set; } = "";

    [ConcurrencyCheck]
    public decimal Price { get; set; }  // protected by optimistic concurrency
}
```

When you update a product:
```sql
UPDATE Products SET Price = @newPrice, Name = @newName
WHERE Id = @id AND Price = @originalPrice  -- ← original Price added to WHERE
```

If another request changed the price between your read and write, the WHERE matches 0 rows → `DbUpdateConcurrencyException`.

**Problem:** You must manage the token value yourself. If you forget to pass the original value (e.g., in a disconnected scenario), the check fails silently.

### `[Timestamp]` / `rowversion` — Database-Managed Token (Preferred)

```csharp
public class Order
{
    public int Id { get; set; }
    public string Status { get; set; } = "";

    [Timestamp]
    public byte[] RowVersion { get; set; } = [];  // SQL Server rowversion: auto-updated on write
}
```

Or via Fluent API:
```csharp
modelBuilder.Entity<Order>()
    .Property(o => o.RowVersion)
    .IsRowVersion();
```

SQL Server automatically increments the `rowversion` column on every row modification. EF Core includes it in every UPDATE/DELETE:

```sql
UPDATE Orders SET Status = @status
WHERE Id = @id AND RowVersion = @originalRowVersion
```

**Advantages over `[ConcurrencyCheck]`:**
- DB guarantees the version is updated — no application logic needed.
- Works even if you update the row via raw SQL (DB still increments rowversion).
- `byte[]` is unambiguous; no floating-point equality issues.

### Handling `DbUpdateConcurrencyException`

```csharp
try
{
    await db.SaveChangesAsync(ct);
}
catch (DbUpdateConcurrencyException ex)
{
    foreach (var entry in ex.Entries)
    {
        var dbValues = await entry.GetDatabaseValuesAsync(ct);  // current DB values
        if (dbValues == null)
        {
            // Row was deleted by another process
            throw new ConflictException("The entity was deleted by another user.");
        }

        // Choose a merge strategy:
        // Strategy A — Database wins: discard client changes
        entry.OriginalValues.SetValues(dbValues);
        entry.CurrentValues.SetValues(dbValues);
        // entry.State is now Unchanged → client changes lost

        // Strategy B — Client wins: overwrite database with our values
        entry.OriginalValues.SetValues(dbValues);  // update rowversion to current DB value
        // entry.CurrentValues stays as-is → our changes will be applied

        // Strategy C — Merge: apply non-conflicting field changes
        var proposed = entry.CurrentValues.Clone();
        entry.OriginalValues.SetValues(dbValues);  // must update to prevent infinite loop
        entry.CurrentValues.SetValues(dbValues);   // start from DB state
        foreach (var prop in entry.Properties)
        {
            // Keep client value if DB didn't change it since our read
            if (proposed[prop.Metadata.Name] != dbValues[prop.Metadata.Name] &&
                dbValues[prop.Metadata.Name]?.Equals(entry.OriginalValues[prop.Metadata.Name]) == false)
            {
                // Both client and DB changed this property → conflict
                throw new ConflictException($"Conflict on property {prop.Metadata.Name}");
            }
            entry.CurrentValues[prop.Metadata.Name] = proposed[prop.Metadata.Name];
        }
    }

    // Retry save with updated OriginalValues
    await db.SaveChangesAsync(ct);
}
```

### Concurrency Tokens in Disconnected Scenarios

For web APIs, the client must return the `RowVersion` value so EF Core can check it:

```csharp
// Return RowVersion in DTO (as Base64 string)
public record OrderDto(int Id, string Status, string RowVersion);

// PUT handler — client sends back RowVersion
[HttpPut("{id}")]
public async Task<IActionResult> UpdateAsync(int id, UpdateOrderDto dto, CancellationToken ct)
{
    var order = await db.Orders.FindAsync([id], ct)
        ?? throw new NotFoundException(id);

    // Restore original RowVersion so EF Core includes it in WHERE
    db.Entry(order).Property(o => o.RowVersion).OriginalValue =
        Convert.FromBase64String(dto.RowVersion);

    order.Status = dto.Status;

    try
    {
        await db.SaveChangesAsync(ct);
        return NoContent();
    }
    catch (DbUpdateConcurrencyException)
    {
        return Conflict(new { error = "The record was modified by another user. Reload and retry." });
    }
}
```

## Code Example

```csharp
// Entity with rowversion
public class InventoryItem
{
    public int Id { get; set; }
    public string Sku { get; set; } = "";
    public int Quantity { get; set; }

    [Timestamp]
    public byte[] RowVersion { get; set; } = [];
}

// Service: retry on concurrency conflict (last-write-wins after re-read)
public async Task AdjustQuantityAsync(int id, int delta, CancellationToken ct)
{
    const int maxRetries = 3;

    for (int attempt = 0; attempt < maxRetries; attempt++)
    {
        var item = await db.InventoryItems.FindAsync([id], ct)
            ?? throw new NotFoundException(id);

        item.Quantity += delta;

        try
        {
            await db.SaveChangesAsync(ct);
            return;  // success
        }
        catch (DbUpdateConcurrencyException) when (attempt < maxRetries - 1)
        {
            // Reload and retry
            db.Entry(item).State = EntityState.Detached;
        }
    }

    throw new ConflictException("Failed to update inventory after multiple retries.");
}
```

## Common Follow-up Questions

- How does EF Core handle concurrency tokens when using `ExecuteUpdateAsync`?
- What is the difference between `rowversion` and `timestamp` in SQL Server — are they the same?
- How do you return the updated `RowVersion` to the client after a successful save?
- Can `[ConcurrencyCheck]` be applied to a navigation property or only scalar properties?
- How does optimistic concurrency interact with EF Core's `EnableRetryOnFailure`?

## Common Mistakes / Pitfalls

- **Forgetting to return `RowVersion` in the API response**: If clients never receive the `RowVersion`, they can't send it back in PUT requests, making the concurrency check always fail for disconnected scenarios.
- **Assuming `DbUpdateConcurrencyException` always means a conflict**: If a row is deleted between read and update, `GetDatabaseValuesAsync` returns `null`. Code that blindly retries the update will keep failing unless it handles the deletion case.
- **Using `[ConcurrencyCheck]` on a floating-point column**: Floating-point equality is unreliable. Prefer `rowversion` or an integer version column.
- **Not updating `OriginalValues` before retrying**: After catching `DbUpdateConcurrencyException` and deciding to retry (client-wins), you must call `entry.OriginalValues.SetValues(dbValues)` to update EF Core's stored original `RowVersion` — otherwise the next `SaveChanges` fails again immediately.
- **Conflating optimistic concurrency with row-level locking**: `[Timestamp]` does not lock the row. Between your read and write, any number of other processes can modify the row. The concurrency token only detects the conflict at write time — it doesn't prevent the concurrent write.

## References

- [Optimistic concurrency — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/concurrency)
- [Handling DbUpdateConcurrencyException — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/concurrency#resolving-concurrency-conflicts)
- [rowversion — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/data-types/rowversion-transact-sql)
- [See: optimistic-concurrency.md](./optimistic-concurrency.md)
- [See: update-patterns.md](./update-patterns.md)
