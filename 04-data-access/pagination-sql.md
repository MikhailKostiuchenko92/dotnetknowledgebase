# SQL Pagination Patterns

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🟡 Middle
**Tags:** `SQL`, `pagination`, `OFFSET-FETCH`, `keyset-pagination`, `cursor-pagination`, `ROW_NUMBER`, `performance`, `large-datasets`

## Question

> What are the different SQL pagination strategies? What is the difference between `OFFSET/FETCH` and keyset (cursor) pagination? When does offset-based pagination break down, and how does keyset pagination fix it?

## Short Answer

`OFFSET N ROWS FETCH NEXT M ROWS ONLY` (SQL:2008, supported in SQL Server 2012+) implements offset pagination — skip N rows, return M. It's simple but has two critical problems at large offsets: (1) SQL Server must scan and discard all N preceding rows, making `OFFSET 1000000 FETCH NEXT 10` extremely slow; (2) concurrent inserts/deletes cause rows to be skipped or duplicated across pages. **Keyset pagination** (cursor-based) instead uses `WHERE id > @lastSeenId ORDER BY id` — it seeks directly to the next batch position using the index. It's O(log N) at any page regardless of depth, but requires a stable sort key and does not support random page access.

## Detailed Explanation

### Offset / FETCH — Simple but Problematic at Scale

```sql
-- Page 1: OFFSET 0 (skip nothing)
SELECT Id, Name, CreatedAt FROM Products
ORDER BY CreatedAt DESC, Id DESC
OFFSET 0 ROWS FETCH NEXT 20 ROWS ONLY;

-- Page 50: OFFSET 980 (skip 980 rows)
SELECT Id, Name, CreatedAt FROM Products
ORDER BY CreatedAt DESC, Id DESC
OFFSET 980 ROWS FETCH NEXT 20 ROWS ONLY;
```

**The problem**: SQL Server must internally process all 980 rows before discarding them to get to row 981. At offset 1 000 000 the server reads and discards 1M rows even though it returns only 20. Performance degrades linearly with page depth.

**A second problem — data drift**: if a product is inserted or deleted between page requests, rows shift and a user gets a duplicate or a gap across pages.

### Keyset (Cursor) Pagination — Scalable

```sql
-- First page: no cursor needed
SELECT Id, Name, CreatedAt FROM Products
ORDER BY CreatedAt DESC, Id DESC
FETCH NEXT 20 ROWS ONLY;  -- or TOP 20

-- Next page: WHERE clause uses the last seen values as a cursor
DECLARE @lastCreatedAt datetime2 = '2024-03-15 10:22:00';
DECLARE @lastId int = 8423;

SELECT Id, Name, CreatedAt FROM Products
WHERE (CreatedAt < @lastCreatedAt)
   OR (CreatedAt = @lastCreatedAt AND Id < @lastId)
ORDER BY CreatedAt DESC, Id DESC
FETCH NEXT 20 ROWS ONLY;
```

The composite `OR` condition handles ties on `CreatedAt` by falling back to `Id` for stable ordering. With an index on `(CreatedAt DESC, Id DESC)`, this is an index seek — O(log N) regardless of how deep in the result set you are.

### Composite Cursor — Encoding and Sending to the Client

In practice, encode the cursor as an opaque token:

```csharp
// Encode the cursor (serialize to Base64 JSON)
public record PageCursor(DateTime CreatedAt, int Id);

string Encode(PageCursor cursor) =>
    Convert.ToBase64String(JsonSerializer.SerializeToUtf8Bytes(cursor));

PageCursor? Decode(string? token) =>
    token is null ? null :
    JsonSerializer.Deserialize<PageCursor>(Convert.FromBase64String(token));
```

API response:
```json
{
  "items": [...],
  "nextCursor": "eyJDcmVhdGVkQXQiOiIyMDI0LTAzLTE1VDEwOjIyOjAwWiIsIklkIjo4NDIzfQ=="
}
```

### EF Core Implementation

```csharp
// Offset pagination (LINQ)
var page = await db.Products
    .OrderByDescending(p => p.CreatedAt).ThenByDescending(p => p.Id)
    .Skip(pageNumber * pageSize)
    .Take(pageSize)
    .ToListAsync(ct);

// Keyset pagination (LINQ — EF Core 8+ has built-in keyset support)
IQueryable<Product> query = db.Products
    .OrderByDescending(p => p.CreatedAt).ThenByDescending(p => p.Id);

if (cursor is not null)
{
    query = query.Where(p =>
        p.CreatedAt < cursor.CreatedAt ||
        (p.CreatedAt == cursor.CreatedAt && p.Id < cursor.Id));
}

var items = await query.Take(pageSize).ToListAsync(ct);
```

### EF Core 8+ — Native Keyset Pagination via `Keyset` API

EF Core 8 introduced `Keyset` extension for cursor pagination:

```csharp
// NuGet: MR.EntityFrameworkCore.KeysetPagination (community library, verify URL)
var page = await db.Products
    .KeysetPaginate(b => b.Descending(p => p.CreatedAt).Descending(p => p.Id),
                    KeysetPaginationDirection.Forward,
                    reference: lastProduct)
    .Take(pageSize)
    .ToListAsync(ct);
```

### Comparison Summary

| Feature | OFFSET/FETCH | Keyset/Cursor |
|---------|-------------|--------------|
| Random page access | ✅ (page 47 directly) | ❌ (must follow cursor chain) |
| Performance at deep pages | ❌ O(N) scan to discard | ✅ O(log N) index seek |
| Data drift (insert/delete) | ❌ duplicate / skip rows | ✅ stable |
| Sort key requirement | Any | Stable, unique sort key |
| Total count query | Easy (`COUNT(*)`) | Expensive / impractical |
| UI fit | Traditional numbered pages | Infinite scroll / "Load more" |

## Code Example

```csharp
// Production keyset pagination endpoint
[HttpGet]
public async Task<PagedResult<ProductDto>> GetProductsAsync(
    [FromQuery] string? cursor,
    [FromQuery] int pageSize = 20,
    CancellationToken ct = default)
{
    pageSize = Math.Clamp(pageSize, 1, 100);

    var decoded = cursor is not null
        ? JsonSerializer.Deserialize<ProductCursor>(
            Convert.FromBase64String(cursor))
        : null;

    var query = _db.Products.AsNoTracking()
        .OrderByDescending(p => p.CreatedAt)
        .ThenByDescending(p => p.Id);

    if (decoded is not null)
    {
        query = (IOrderedQueryable<Product>)query.Where(p =>
            p.CreatedAt < decoded.CreatedAt ||
            (p.CreatedAt == decoded.CreatedAt && p.Id < decoded.Id));
    }

    var items = await query
        .Take(pageSize + 1)  // +1 to detect if there is a next page
        .Select(p => new ProductDto(p.Id, p.Name, p.Price, p.CreatedAt))
        .ToListAsync(ct);

    bool hasMore = items.Count > pageSize;
    if (hasMore) items.RemoveAt(items.Count - 1);

    var nextCursor = hasMore
        ? Convert.ToBase64String(JsonSerializer.SerializeToUtf8Bytes(
            new ProductCursor(items[^1].CreatedAt, items[^1].Id)))
        : null;

    return new PagedResult<ProductDto>(items, nextCursor);
}
```

## Common Follow-up Questions

- How would you implement bidirectional cursor pagination (previous page + next page)?
- How do you handle keyset pagination when the sort column has many ties?
- Why does a `TOTAL COUNT(*)` query become expensive at large table sizes, and how do you work around it?
- How does GraphQL Relay cursor specification relate to keyset pagination?
- How does EF Core translate `Skip().Take()` — does it always generate `OFFSET/FETCH`?

## Common Mistakes / Pitfalls

- **Not using `ORDER BY` with `OFFSET/FETCH`**: `OFFSET` without `ORDER BY` is non-deterministic in SQL Server — results vary between executions. It's also a syntax error in SQL Server (ORDER BY is required with OFFSET).
- **Using a non-unique sort key for keyset pagination**: if two rows have the same `CreatedAt`, the cursor `WHERE CreatedAt < @last` may skip one of them. Always add a unique tiebreaker (`Id`) as a secondary sort key.
- **Returning total page count with keyset pagination**: this requires `COUNT(*)` over the full filtered result set — exactly the expensive scan you're trying to avoid. For infinite scroll UIs, just return "has more" instead.
- **Using the same cursor for ascending and descending queries**: a cursor built for `ORDER BY CreatedAt DESC` is not compatible with `ORDER BY CreatedAt ASC` — the same value cuts in the opposite direction.

## References

- [Pagination with EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/pagination)
- [OFFSET FETCH — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-order-by-clause-transact-sql)
- [See: ctes-and-window-functions.md](./ctes-and-window-functions.md)
- [See: pagination-patterns.md](./pagination-patterns.md)
