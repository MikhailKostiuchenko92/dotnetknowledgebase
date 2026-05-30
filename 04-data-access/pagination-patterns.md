# Pagination Patterns in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `pagination`, `keyset-pagination`, `cursor-pagination`, `offset-pagination`, `OFFSET-FETCH`, `performance`

## Question

> What pagination strategies are available in EF Core? What is the difference between offset-based pagination and keyset (cursor) pagination, and why does keyset pagination perform better at scale?

## Short Answer

EF Core supports two pagination strategies. **Offset pagination** uses `Skip(n).Take(pageSize)` which translates to `OFFSET … FETCH NEXT`. It's simple and supports random page access but degrades badly at high page numbers because the database must scan and discard all rows up to the offset. **Keyset (cursor) pagination** uses a `WHERE id > @lastSeenId` clause instead of skipping rows — it's consistently O(index lookup) regardless of how deep into the dataset you are, but it only supports sequential navigation (next/previous, no jumping to page 50). For user-facing paginated lists beyond a few hundred pages, keyset pagination is strongly preferred.

## Detailed Explanation

### Offset Pagination: `Skip` + `Take`

```csharp
// Page 1: skip 0, take 20
// Page N: skip (N-1) * 20, take 20
var page = await db.Orders
    .Where(o => o.Status == "Pending")
    .OrderByDescending(o => o.CreatedAt)
    .Skip((pageNumber - 1) * pageSize)
    .Take(pageSize)
    .ToListAsync(ct);
```

Generated SQL (SQL Server):

```sql
SELECT * FROM Orders
WHERE  Status = 'Pending'
ORDER  BY CreatedAt DESC
OFFSET 980 ROWS FETCH NEXT 20 ROWS ONLY
```

**The problem at scale:**

To deliver page 50 (offset 980), the database engine must:
1. Sort all matching rows (full or partial index scan).
2. Skip 980 rows.
3. Return rows 981–1000.

The skipped rows are counted but their data is discarded — wasted work. At page 1000 (offset 19980), this is extremely slow even with indexes, because the index must be scanned sequentially up to that position.

**When offset is fine:**

- Datasets < 10,000 rows.
- Users rarely go beyond page 10–20.
- Admin panels, reports, internal tools where "jump to page N" is needed.

### Keyset Pagination (Cursor-Based)

Instead of skipping rows, filter `WHERE id > @lastSeenId` (or `WHERE (CreatedAt, Id) < (@lastCreatedAt, @lastId)` for stable ordering):

```csharp
// First page: no cursor
var page1 = await db.Orders
    .Where(o => o.Status == "Pending")
    .OrderByDescending(o => o.CreatedAt)
    .ThenByDescending(o => o.Id)  // tiebreaker: ID is unique
    .Take(pageSize)
    .ToListAsync(ct);

// Subsequent pages: use last row of previous page as cursor
var lastCreatedAt = page1.Last().CreatedAt;
var lastId        = page1.Last().Id;

var page2 = await db.Orders
    .Where(o => o.Status == "Pending")
    .Where(o => o.CreatedAt < lastCreatedAt ||
               (o.CreatedAt == lastCreatedAt && o.Id < lastId))  // composite cursor
    .OrderByDescending(o => o.CreatedAt)
    .ThenByDescending(o => o.Id)
    .Take(pageSize)
    .ToListAsync(ct);
```

Generated SQL:

```sql
SELECT * FROM Orders
WHERE  Status = 'Pending'
  AND  (CreatedAt < @lastCreatedAt
        OR (CreatedAt = @lastCreatedAt AND Id < @lastId))
ORDER  BY CreatedAt DESC, Id DESC
FETCH  FIRST 20 ROWS ONLY
```

This query **always hits the index directly** — no offset scan — so it's O(log n) regardless of position in the dataset.

### Passing the Cursor to the Client

The cursor is typically encoded and returned with the page:

```csharp
public record PagedResult<T>(
    List<T> Items,
    string? NextCursor,  // null = no more pages
    bool HasMore);

// Encode cursor as base64 JSON
var cursor = new { LastCreatedAt = lastItem.CreatedAt, LastId = lastItem.Id };
var nextCursor = Convert.ToBase64String(
    JsonSerializer.SerializeToUtf8Bytes(cursor));
```

### Total Count with Pagination

**Offset:** You can run a separate `CountAsync()` to show "Page 3 of 47":

```csharp
var total = await query.CountAsync(ct);  // SELECT COUNT(*) ...
var items = await query.Skip(offset).Take(pageSize).ToListAsync(ct);
```

**Keyset:** Total count is expensive (full scan) and cursor-based UIs typically don't show "page N of M" — they show "Load more" / infinite scroll. Avoid `CountAsync` with keyset pagination unless your use case requires it.

### Comparison Table

| | Offset | Keyset |
|--|--------|--------|
| Performance at page 1 | Fast | Fast |
| Performance at page 100+ | Degrades (scan + skip) | Consistent (index seek) |
| Random access ("jump to page N") | ✅ | ❌ |
| Total count | Easy | Expensive |
| Sort stability | Needs deterministic ORDER BY | Needs deterministic ORDER BY + tiebreaker |
| Cursor complexity | None | Must pass cursor between pages |
| Use case | Admin grids, small datasets | Infinite scroll, large feeds, high-traffic APIs |

> **Warning:** Offset pagination on sorted data can produce **duplicate or skipped rows** when new records are inserted between page requests. Keyset pagination is immune to this because it's anchored to a specific value, not a row count.

## Code Example

```csharp
// Generic keyset pagination helper
public sealed class KeysetPage<T>
{
    public required List<T> Items    { get; init; }
    public required bool    HasMore  { get; init; }
    public required string? Cursor   { get; init; }  // pass to next request
}

// Orders paged feed with keyset
public async Task<KeysetPage<OrderDto>> GetOrdersAsync(
    string? encodedCursor, int pageSize, CancellationToken ct)
{
    IQueryable<Order> query = db.Orders
        .Where(o => o.Status == "Pending")
        .OrderByDescending(o => o.CreatedAt)
        .ThenByDescending(o => o.Id);

    if (encodedCursor is not null)
    {
        var cursor = JsonSerializer.Deserialize<OrderCursor>(
            Convert.FromBase64String(encodedCursor))!;

        query = query.Where(o =>
            o.CreatedAt < cursor.LastCreatedAt ||
            (o.CreatedAt == cursor.LastCreatedAt && o.Id < cursor.LastId));
    }

    // Fetch pageSize + 1 to know if there are more pages without a COUNT query
    var items = await query
        .Take(pageSize + 1)
        .Select(o => new OrderDto(o.Id, o.Reference, o.Total, o.CreatedAt))
        .ToListAsync(ct);

    var hasMore = items.Count > pageSize;
    if (hasMore) items.RemoveAt(items.Count - 1);  // remove the extra item

    string? nextCursor = null;
    if (hasMore)
    {
        var last = items.Last();
        var c    = new OrderCursor(last.CreatedAt, last.Id);
        nextCursor = Convert.ToBase64String(JsonSerializer.SerializeToUtf8Bytes(c));
    }

    return new KeysetPage<OrderDto> { Items = items, HasMore = hasMore, Cursor = nextCursor };
}

private record OrderCursor(DateTimeOffset LastCreatedAt, int LastId);
```

## Common Follow-up Questions

- How do you implement stable keyset pagination when the sort column has duplicate values?
- How does the `EFCore.BulkExtensions` or `MR.EntityFrameworkCore.KeysetPagination` library simplify cursor pagination?
- What are the implications of running `CountAsync` on every paginated request for large tables?
- How do you support both forward and backward navigation with cursor pagination?
- How does cursor pagination interact with EF Core's global query filters (e.g., soft delete)?

## Common Mistakes / Pitfalls

- **Non-deterministic `ORDER BY` with offset pagination**: Paginating by a non-unique column without a tiebreaker (e.g., `ORDER BY CreatedAt`) means rows with identical `CreatedAt` values may appear on multiple pages or be skipped as records shift. Always add a unique column as a secondary sort (`ThenBy(o => o.Id)`).
- **Offset pagination on very large tables**: Even with an index, `OFFSET 100000 ROWS FETCH NEXT 20 ROWS ONLY` performs a full index scan up to row 100,000. Many APIs that show "pages" beyond 100 should switch to keyset.
- **Keyset cursor without index**: The `WHERE CreatedAt < @cursor AND Id < @cursor` filter performs poorly without a composite index on `(CreatedAt DESC, Id DESC)`. Always index the sort columns.
- **Exposing raw DB IDs as cursors**: Opaque base64-encoded cursors are preferable to raw IDs — they hide implementation details and are harder to tamper with.
- **Missing `HasMore` detection**: Returning an empty page to indicate "no more data" requires an extra round-trip. Use the `Take(pageSize + 1)` trick to detect more items without an extra count query.

## References

- [Pagination — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/pagination)
- [Use keyset pagination for SQL queries — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/pagination#keyset-pagination)
- [MR.EntityFrameworkCore.KeysetPagination library (GitHub)](https://github.com/mrahhal/MR.EntityFrameworkCore.KeysetPagination)
