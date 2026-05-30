# AsNoTracking in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟢 Junior
**Tags:** `ef-core`, `AsNoTracking`, `performance`, `read-only`, `change-tracker`

## Question

> What does `AsNoTracking` do in EF Core, and when should you use it? What is the difference between `AsNoTracking` and `AsNoTrackingWithIdentityResolution`?

## Short Answer

`AsNoTracking()` tells EF Core not to register the returned entities in the change tracker — the materialized objects are plain .NET instances with no tracking overhead. This typically cuts query execution time by 30–50% for read-only operations because EF Core skips snapshotting property values and registering identity entries. Use it on any query where you will not call `SaveChanges` with the results — read APIs, reports, projections, and background jobs. `AsNoTrackingWithIdentityResolution` gives you the performance benefit while still deduplicating the same entity when it appears multiple times in the result set (e.g., the same `Customer` referenced by multiple `Order` rows).

## Detailed Explanation

### What the Change Tracker Does (and Why It Costs)

When EF Core materializes a tracked entity, it:

1. Checks the **identity map** — if an entity with the same PK was already loaded, returns the cached instance.
2. Snapshots all property values (deep copy of current state).
3. Registers the entity in the change tracker with state `Unchanged`.

This overhead is worthwhile when you need `SaveChanges` to detect modifications. For read-only scenarios it's pure waste.

### `AsNoTracking()` — Maximum Performance

```csharp
// ✅ Read-only list — no tracking overhead
var orders = await db.Orders
    .AsNoTracking()
    .Where(o => o.Status == "Pending")
    .ToListAsync(ct);
```

The materialized `Order` objects have the correct property values but are not registered in the change tracker. Calling `db.SaveChangesAsync()` after this will not persist any modifications to these objects (they'd be silently ignored or throw if you call `db.Update(order)` without re-attaching).

### `AsNoTracking` + Identity Map Caveat

Without tracking, if the same `Customer` is referenced by multiple orders in the result set, EF Core creates **separate `Customer` instances** for each:

```csharp
var orders = await db.Orders
    .AsNoTracking()
    .Include(o => o.Customer)
    .ToListAsync(ct);

// Without identity resolution:
var c1 = orders[0].Customer;
var c2 = orders[1].Customer;  // same CustomerId, but different object!
bool same = ReferenceEquals(c1, c2);  // false — two separate instances
```

This is usually fine for DTOs and APIs, but can cause unexpected behaviour in object graphs.

### `AsNoTrackingWithIdentityResolution` — Best of Both Worlds

Preserves object identity (same `Customer` PK → same reference) without the full tracking overhead:

```csharp
var orders = await db.Orders
    .AsNoTrackingWithIdentityResolution()
    .Include(o => o.Customer)
    .ToListAsync(ct);

var c1 = orders[0].Customer;
var c2 = orders[1].Customer;
bool same = ReferenceEquals(c1, c2);  // true — same instance
```

Slower than `AsNoTracking` (maintains an identity map but doesn't snapshot) but faster than full tracking.

### Comparison

| | Tracked | `AsNoTracking` | `AsNoTrackingWithIdentityResolution` |
|--|---------|----------------|--------------------------------------|
| Change detection | ✅ | ❌ | ❌ |
| `SaveChanges` support | ✅ | ❌ | ❌ |
| Identity map (dedup) | ✅ | ❌ | ✅ |
| Property snapshotting | ✅ | ❌ | ❌ |
| Performance | Baseline | ~30–50% faster | ~10–20% faster |
| Use case | Write ops | Pure reads | Reads with shared nav objects |

### Where to Apply `AsNoTracking`

Apply it at the `DbContext` level for read-only contexts (e.g., a dedicated read replica context):

```csharp
public sealed class ReadDbContext(DbContextOptions<ReadDbContext> options) : DbContext(options)
{
    public ReadDbContext() : this(new DbContextOptionsBuilder<ReadDbContext>()
        .UseSqlServer(...)
        .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking)  // global no-tracking
        .Options) { }
}
```

Or globally via options:

```csharp
services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlServer(connStr)
       .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking));
// Then opt-in to tracking for write operations:
db.Orders.AsTracking().FirstAsync(o => o.Id == id, ct);
```

## Code Example

```csharp
// Controller: read-only list endpoint
[HttpGet]
public async Task<IReadOnlyList<OrderDto>> GetOrdersAsync(
    [FromQuery] string status, CancellationToken ct)
{
    return await db.Orders
        .AsNoTracking()                          // ← no tracking needed for GET
        .Where(o => o.Status == status)
        .OrderByDescending(o => o.CreatedAt)
        .Take(50)
        .Select(o => new OrderDto(o.Id, o.Reference, o.Total))
        .ToListAsync(ct);
    // Never materializes tracked entities — faster and lower memory
}

// Service: write operation — needs tracking
public async Task<Order> UpdateStatusAsync(int id, string status, CancellationToken ct)
{
    var order = await db.Orders               // ← no AsNoTracking → tracked
        .FirstAsync(o => o.Id == id, ct);

    order.Status = status;
    await db.SaveChangesAsync(ct);            // ← change tracker detects the modification
    return order;
}

// When to use AsNoTrackingWithIdentityResolution:
var invoices = await db.Invoices
    .AsNoTrackingWithIdentityResolution()
    .Include(i => i.Customer)   // same Customer may appear on multiple Invoices
    .Include(i => i.Lines)
    .ToListAsync(ct);
// All Invoice.Customer references to the same CustomerId are the same object instance
```

## Common Follow-up Questions

- Does `AsNoTracking` affect global query filters (e.g., soft delete)?
- Can you call `db.Update(entity)` on a no-tracking entity and have it persist?
- How does `AsNoTracking` interact with lazy loading proxies?
- What is the performance difference between `AsNoTracking` and projecting to a DTO (which also bypasses tracking)?
- Is `AsNoTracking` the same as setting `QueryTrackingBehavior.NoTracking` globally?

## Common Mistakes / Pitfalls

- **Modifying a no-tracked entity and expecting `SaveChanges` to persist it**: The change tracker doesn't know about no-tracked entities. `db.SaveChangesAsync()` ignores them. You must re-attach with `db.Update(entity)` or reload the entity as tracked.
- **Using `AsNoTracking` with lazy loading proxies**: Lazy loading requires EF Core to intercept property access, which requires tracked entities. `AsNoTracking` entities don't have lazy proxies — navigations return `null` if not explicitly loaded.
- **`AsNoTracking` in a long-running write scenario**: If your code reads with `AsNoTracking` and then needs to save changes, you have to re-query with tracking or manually track the entity — awkward and error-prone. Use tracking from the start if writes are expected.
- **Assuming `AsNoTracking` = `Select` projection performance**: `AsNoTracking` still materializes the full entity (all columns). A `Select` projection to a DTO fetches fewer columns AND skips tracking — projections are usually faster for narrow reads.
- **Forgetting `AsNoTracking` on background jobs**: Long-running background jobs that load thousands of entities without `AsNoTracking` accumulate all those entities in the change tracker, consuming significant memory over time.

## References

- [Tracking vs no-tracking queries — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/tracking)
- [AsNoTrackingWithIdentityResolution — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/tracking#no-tracking-with-identity-resolution)
- [EF Core performance — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/efficient-querying#no-tracking-queries)
