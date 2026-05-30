# Entity States and Transitions in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `EntityState`, `Attach`, `Update`, `Add`, `disconnected-entities`, `change-tracking`

## Question

> Explain the `EntityState` transitions in EF Core. What is the difference between `db.Add`, `db.Attach`, and `db.Update`? How do you handle disconnected entities (e.g., from a PUT request) correctly?

## Short Answer

EF Core entities transition through five states: `Detached → Added/Unchanged/Modified/Deleted → Unchanged` (after save). `db.Add` places entities in `Added` state (INSERT). `db.Attach` places them in `Unchanged` state (no SQL unless you modify them). `db.Update` places them in `Modified` state (UPDATE all columns). For disconnected scenarios (e.g., a PUT endpoint that receives a deserialized entity), the correct approach depends on whether you want to update all columns or only changed ones. The "stub entity" pattern and `SetValues` allow selective property updates without re-querying the database.

## Detailed Explanation

### State Transition Diagram

```
Detached
  │ db.Add()           → Added    → [SaveChanges] → Unchanged
  │ db.Attach()        → Unchanged
  │ db.Update()        → Modified → [SaveChanges] → Unchanged
  │ db.Remove()        → (must be tracked first)
  │ Query()            → Unchanged
  │
Unchanged
  │ Modify property    → Modified (after DetectChanges)
  │ db.Remove()        → Deleted  → [SaveChanges] → Detached
  │ db.ChangeTracker.Clear() → Detached
  │
Modified  → [SaveChanges] → Unchanged
Added     → [SaveChanges] → Unchanged (Id populated)
Deleted   → [SaveChanges] → Detached
```

### `db.Add` vs `db.Attach` vs `db.Update`

```csharp
// db.Add — state: Added → INSERT on SaveChanges
var newOrder = new Order { CustomerId = 1, Total = 100m };
db.Orders.Add(newOrder);
// SaveChanges generates: INSERT INTO Orders (CustomerId, Total) VALUES (1, 100)

// db.Attach — state: Unchanged → no SQL unless you modify properties
var existingOrder = new Order { Id = 42, Status = "Pending" };
db.Orders.Attach(existingOrder);
existingOrder.Status = "Shipped";
// SaveChanges generates: UPDATE Orders SET Status = 'Shipped' WHERE Id = 42
// (only modified column, not all columns)

// db.Update — state: Modified → UPDATE all columns on SaveChanges
var updatedOrder = new Order { Id = 42, CustomerId = 1, Total = 100m, Status = "Shipped" };
db.Orders.Update(updatedOrder);
// SaveChanges generates: UPDATE Orders SET CustomerId=1, Total=100, Status='Shipped' WHERE Id=42
// ALL columns updated — even those you didn't change
```

### Handling Disconnected Entities in a PUT Endpoint

Three common patterns:

**Pattern 1: Re-query + apply values (safest, recommended)**

```csharp
// Re-load from DB → apply only the incoming changes → save
[HttpPut("{id}")]
public async Task<IActionResult> UpdateAsync(int id, OrderUpdateDto dto, CancellationToken ct)
{
    var order = await db.Orders.FindAsync([id], ct) ?? throw new NotFoundException(id);
    order.Status = dto.Status;          // only set what the DTO contains
    order.Note = dto.Note;
    await db.SaveChangesAsync(ct);      // UPDATE only changed columns
    return NoContent();
}
```

**Pros:** Only updates what changed; concurrency token works correctly; business validation in the entity.
**Cons:** Extra SELECT round-trip.

**Pattern 2: `db.Update` (fast, dangerous)**

```csharp
// Map DTO → entity → attach as Modified
var order = new Order { Id = id, Status = dto.Status, Note = dto.Note };
db.Orders.Update(order);
await db.SaveChangesAsync(ct);  // UPDATE ALL columns — overwrites columns not in DTO with defaults!
```

**Danger:** Columns not included in the DTO (e.g., `CreatedAt`, `CustomerId`) are overwritten with `default` values (0, null, DateTime.MinValue).

**Pattern 3: `SetValues` (all-columns update without re-query)**

```csharp
// Use Entry().CurrentValues.SetValues to copy DTO values onto a stub entity
var order = new Order { Id = id };
db.Orders.Attach(order);                   // Unchanged
db.Entry(order).CurrentValues.SetValues(dto);  // sets only properties present in dto
await db.SaveChangesAsync(ct);             // UPDATE only matching columns
```

### The Stub Entity Trick

Avoid a SELECT when you only need to delete or update by ID:

```csharp
// Delete without loading
var stub = new Order { Id = idToDelete };
db.Orders.Remove(stub);   // no SELECT needed
await db.SaveChangesAsync(ct);  // DELETE FROM Orders WHERE Id = @id
```

> **Warning:** The stub entity trick bypasses any business logic, validation, or concurrency tokens that would be enforced if you loaded the real entity. Only use it for administrative operations.

### Graph Traversal — Adding a Full Object Graph

When you `Add` or `Update` a parent entity, EF Core traverses the navigation properties:

```csharp
var order = new Order
{
    CustomerId = 1,
    Lines = [
        new OrderLine { ProductId = 10, Quantity = 2 },
        new OrderLine { ProductId = 11, Quantity = 1 }
    ]
};

db.Orders.Add(order);  // order: Added, each Line: Added
await db.SaveChangesAsync(ct);  // INSERT INTO Orders + INSERT INTO OrderLines (2 rows)
```

## Code Example

```csharp
// Disconnected update — safest approach for web APIs
public async Task<OrderDto> UpdateStatusAsync(
    int id, UpdateStatusRequest req, CancellationToken ct)
{
    var order = await db.Orders
        .FirstOrDefaultAsync(o => o.Id == id, ct)
        ?? throw new NotFoundException($"Order {id} not found");

    // Only update the status — EF Core tracks which columns changed
    order.Status = req.Status;
    order.UpdatedAt = DateTimeOffset.UtcNow;

    // Inspect before saving:
    var entry = db.Entry(order);
    // entry.State == EntityState.Modified
    // entry.Properties.Where(p => p.IsModified) → Status, UpdatedAt only

    await db.SaveChangesAsync(ct);
    // SQL: UPDATE Orders SET Status = @s, UpdatedAt = @u WHERE Id = @id
    // CustomerId, Total, etc. are NOT included in the UPDATE

    return order.ToDto();
}
```

## Common Follow-up Questions

- What happens when you call `db.Update` on a graph that includes new child entities — do they get `Added` or `Modified`?
- How do concurrency tokens (`[Timestamp]`) interact with `db.Attach` + selective property updates?
- What is the difference between `entry.State = EntityState.Modified` and `db.Update(entity)`?
- How do you implement a PATCH endpoint (partial update) correctly in EF Core?
- Can `db.Attach` throw if an entity with the same PK is already tracked?

## Common Mistakes / Pitfalls

- **Using `db.Update` for partial updates**: `db.Update` marks ALL properties as modified. If your `Order` has 20 columns and your DTO only has 3, you'll overwrite the other 17 with their current (possibly default) values.
- **Attaching an entity when one with the same PK is already tracked**: `db.Attach` throws `InvalidOperationException` if the identity map already contains an entity with the same key. Always check if the entity is already tracked before attaching.
- **Ignoring navigation state on `db.Update`**: If the entity has navigation properties, `db.Update` recursively marks all related entities as `Modified` too — even ones that haven't changed. This causes unnecessary UPDATEs on child tables.
- **Using stub entities for concurrency-sensitive operations**: If `Order` has a `[Timestamp]` row version, the stub entity has `RowVersion = null`. EF Core's UPDATE includes `WHERE RowVersion = NULL` which matches nothing — the update silently affects 0 rows and EF Core thinks it's a concurrency conflict.
- **Calling `db.Add` on an entity that already has a non-zero PK**: EF Core will INSERT with the specified PK value. If the row already exists, you'll get a primary key violation. Use `db.Update` or the re-query pattern for upserts.

## References

- [Entity states — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/change-tracking/entity-entries)
- [Disconnected entities — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/disconnected-entities)
- [Change tracking — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/change-tracking/)
- [See: change-tracking-overview.md](./change-tracking-overview.md)
- [See: update-patterns.md](./update-patterns.md)
