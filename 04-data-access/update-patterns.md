# Update Patterns in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `update`, `disconnected-entities`, `patch`, `SetValues`, `PUT`, `PATCH`

## Question

> What are the main patterns for updating entities in EF Core? How do you handle a full update (PUT) vs a partial update (PATCH) from a web API, and what are the trade-offs between re-querying vs attaching a disconnected entity?

## Short Answer

EF Core offers three update patterns: (1) **tracked update** — query the entity, modify properties, call `SaveChanges` — safest but requires a SELECT; (2) **disconnected update via `db.Update`** — attach and mark all properties modified — no SELECT but overwrites every column; (3) **selective attach** — attach in `Unchanged` state, mark only specific properties modified — no SELECT, precise columns. For PUT endpoints (full replace), `db.Update` works but risks overwriting columns not in the DTO. For PATCH (partial update), either re-query or use `SetValues`/property-level `IsModified` to update only provided fields.

## Detailed Explanation

### Pattern 1: Tracked Update (Re-query)

```csharp
// SELECT then UPDATE — safest, respects concurrency tokens, runs business logic
var order = await db.Orders.FindAsync([id], ct)
    ?? throw new NotFoundException(id);

order.Status = newStatus;
order.UpdatedAt = DateTimeOffset.UtcNow;
// EF Core detects only changed columns → UPDATE Orders SET Status=@s, UpdatedAt=@u WHERE Id=@id

await db.SaveChangesAsync(ct);
```

**Pros:** Only changed columns in UPDATE; concurrency token checked; business logic in setters runs.
**Cons:** Extra SELECT round-trip.

**When to use:** Default choice for most web API endpoints where the extra SELECT is acceptable.

### Pattern 2: `db.Update` — All Columns

```csharp
// No SELECT — maps DTO → entity → marks all properties Modified
var order = mapper.Map<Order>(dto);  // { Id=42, Status="Shipped", Note="..." }
order.Id = id;
db.Orders.Update(order);
await db.SaveChangesAsync(ct);
// SQL: UPDATE Orders SET Status='Shipped', Note='...', CreatedAt='0001-01-01', CustomerId=0 ...
```

**Danger:** Every column is updated. Properties not in the DTO default to their C# defaults (0, null, DateTime.MinValue) — **this corrupts data**.

**When to use:** Only when the DTO maps 1:1 to the entity (all columns represented) AND you don't have audit columns managed by interceptors.

### Pattern 3: Selective Attach — Specific Columns Only

```csharp
// Attach as Unchanged → mark only target properties Modified
var order = new Order { Id = id };
db.Orders.Attach(order);                                             // state: Unchanged

db.Entry(order).Property(o => o.Status).CurrentValue = newStatus;
db.Entry(order).Property(o => o.Status).IsModified = true;

db.Entry(order).Property(o => o.UpdatedAt).CurrentValue = DateTimeOffset.UtcNow;
db.Entry(order).Property(o => o.UpdatedAt).IsModified = true;

await db.SaveChangesAsync(ct);
// SQL: UPDATE Orders SET Status=@s, UpdatedAt=@u WHERE Id=@id  ← exact columns only
```

No SELECT. Precise columns. No data corruption risk. Verbose.

### Pattern 4: `SetValues` — Copy from DTO

```csharp
// Use Entry().CurrentValues.SetValues to copy matching properties from DTO
var order = new Order { Id = id };
db.Orders.Attach(order);  // Unchanged

db.Entry(order).CurrentValues.SetValues(dto);
// Sets all properties present in dto that match Order properties by name/type
// Properties in dto but not in Order → ignored
// Properties in Order but not in dto → remain at default (0/null)

await db.SaveChangesAsync(ct);
```

> **Warning:** Properties in `Order` not present in `dto` keep their default values (same issue as `db.Update`). Use the re-query pattern if you need to preserve existing values for unset columns.

### Pattern 5: PATCH — Truly Partial Update

HTTP PATCH sends only the fields that changed (RFC 7396 JSON Merge Patch, or JSON Patch RFC 6902):

```csharp
// JsonMergePatch: only fields present in the request body should be updated
[HttpPatch("{id}")]
public async Task<IActionResult> PatchAsync(
    int id, [FromBody] JsonElement patch, CancellationToken ct)
{
    var order = await db.Orders.FindAsync([id], ct)
        ?? throw new NotFoundException(id);

    // Apply only the fields present in the patch document
    if (patch.TryGetProperty("status", out var statusEl))
        order.Status = statusEl.GetString()!;

    if (patch.TryGetProperty("note", out var noteEl))
        order.Note = noteEl.GetString();

    // EF Core tracks only what changed → minimal UPDATE
    await db.SaveChangesAsync(ct);
    return NoContent();
}
```

For structured PATCH, use the `Microsoft.AspNetCore.JsonPatch` package (Newtonsoft-based) or a custom merge-patch library.

### Comparison

| Pattern | SELECT? | Columns updated | Risk | Best for |
|---------|---------|-----------------|------|----------|
| Tracked (re-query) | ✅ Yes | Only modified | Low | Most APIs |
| `db.Update` | ❌ No | All columns | High (data loss) | Full DTO → entity |
| Selective attach | ❌ No | Explicit only | Low | Known-column updates |
| `SetValues` | ❌ No | DTO properties | Medium | Full-DTO PUT |
| PATCH re-query | ✅ Yes | Patch-provided | Low | PATCH endpoints |

## Code Example

```csharp
// PUT endpoint — recommended: re-query + map
[HttpPut("{id}")]
public async Task<IActionResult> PutAsync(
    int id, UpdateOrderRequest req, CancellationToken ct)
{
    var order = await db.Orders.FindAsync([id], ct)
        ?? throw new NotFoundException(id);

    order.Status = req.Status;
    order.Note = req.Note;
    // CreatedAt, CustomerId, etc. are NOT touched — safe

    await db.SaveChangesAsync(ct);
    return NoContent();
}

// Selective attach — skip SELECT for a known status transition
public async Task MarkShippedAsync(int id, CancellationToken ct)
{
    var order = new Order { Id = id };
    db.Orders.Attach(order);

    var entry = db.Entry(order);
    entry.Property(o => o.Status).CurrentValue = "Shipped";
    entry.Property(o => o.Status).IsModified = true;
    entry.Property(o => o.ShippedAt).CurrentValue = DateTimeOffset.UtcNow;
    entry.Property(o => o.ShippedAt).IsModified = true;

    await db.SaveChangesAsync(ct);
}
```

## Common Follow-up Questions

- How do you handle concurrency tokens (`[Timestamp]`) with the selective attach pattern?
- What happens if you call `db.Attach` on an entity that is already tracked with the same PK?
- How does `mapper.Map<Order>(dto)` interact with EF Core tracking — does AutoMapper preserve navigation properties?
- When should you use `ExecuteUpdateAsync` instead of the patterns above?
- How do you implement JSON Patch (`[PATCH]`) correctly in ASP.NET Core?

## Common Mistakes / Pitfalls

- **Using `db.Update` with a partial DTO**: If your request DTO has 5 of 20 columns and you map to an entity and call `db.Update`, the other 15 columns are overwritten with defaults. Always use the re-query pattern or selective attach for partial updates.
- **Attaching when the entity is already tracked**: If the context already has an `Order` with Id=42 in its identity map (loaded earlier in the same request), calling `db.Orders.Attach(new Order { Id = 42 })` throws `InvalidOperationException`. Always check `db.ChangeTracker.Find<Order>(id)` first.
- **Forgetting audit columns in the selective attach pattern**: If `UpdatedAt` is managed by an interceptor or `SaveChanges` override, the selective attach pattern may bypass it — the interceptor only sees tracked entities with `IsModified = true` on the expected property.
- **Not marking `IsModified` after setting `CurrentValue`**: Setting `CurrentValue` alone does not mark the property as modified. You must also set `IsModified = true` (when `AutoDetectChangesEnabled = false`) or let `DetectChanges` run.
- **Ignoring navigation property state in `db.Update` graphs**: `db.Update(order)` recursively visits navigation properties. If `order.Lines` contains new child objects, they get marked `Modified` — EF Core tries to UPDATE them even though they don't exist yet (causing a `DbUpdateConcurrencyException`).

## References

- [Disconnected entities — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/disconnected-entities)
- [Basic save — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/basic)
- [Tracking vs no-tracking — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/tracking)
- [See: entity-states.md](./entity-states.md)
- [See: concurrency-tokens.md](./concurrency-tokens.md)
