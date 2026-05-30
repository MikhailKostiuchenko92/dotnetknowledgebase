# Pagination Strategies

**Category:** System Design / APIs
**Difficulty:** 🟡 Middle
**Tags:** `pagination`, `cursor-based`, `offset-pagination`, `keyset-pagination`, `large-datasets`, `API-design`

## Question

> Compare offset-based and cursor-based (keyset) pagination. What are the trade-offs with large datasets? How does cursor-based pagination work in practice?

## Short Answer

Offset pagination (`SKIP N TAKE M`) is simple to implement and allows jumping to any page, but is O(N) in the database — scanning all preceding rows — and produces inconsistent results when rows are inserted or deleted mid-navigation. Cursor-based (keyset) pagination uses the last-seen value as a bookmark and adds a `WHERE id > :last_id` clause, giving O(log N) performance via index and stable results even as data changes. It cannot jump to arbitrary pages but is the correct choice for large datasets and infinite scroll.

## Detailed Explanation

### Offset Pagination

```sql
SELECT * FROM Orders ORDER BY created_at DESC
OFFSET 500 ROWS FETCH NEXT 20 ROWS ONLY;
-- or: LIMIT 20 OFFSET 500
```

**How it works**: the database scans and discards the first 500 rows, then returns 20.

| Pros | Cons |
|------|------|
| Simple API: `?page=26&size=20` | O(N) scan — page 10,000 scans 200,000 rows |
| Can jump to any page number | Inconsistent on concurrent writes (rows shift) |
| Easy to implement with EF Core `.Skip().Take()` | Count query required for "total pages" (expensive on large tables) |

**Inconsistency problem**: if row is inserted on page 1 while user is on page 2, all subsequent rows shift — page 3 now shows a row that appeared to be on page 2, and the previous page 2's last row is duplicated.

**When acceptable**: small datasets (< 100K rows), admin tools where jumping to page N makes sense, and eventual consistency on pagination is acceptable.

### Cursor-Based (Keyset) Pagination

```sql
-- Page 1 (no cursor)
SELECT * FROM Orders ORDER BY created_at DESC, id DESC LIMIT 20;

-- Subsequent pages (cursor = last row's values)
SELECT * FROM Orders
WHERE (created_at, id) < (:last_created_at, :last_id)   -- keyset comparison
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

**How it works**: the cursor encodes the values of the last row seen. The next query uses those values as a `WHERE` filter. This is a direct index seek — O(log N) with an index on `(created_at, id)`.

| Pros | Cons |
|------|------|
| O(log N) — scales to billions of rows | Cannot jump to arbitrary page numbers |
| Stable — inserts/deletes don't cause skips or duplicates | Cursor must include all ORDER BY columns |
| No separate count query needed | Cursor is opaque to the client |
| Natural for infinite scroll / "load more" | Sorting changes require new cursor strategy |

**Cursor encoding**: encode the cursor as a base64 JSON string so the client can't parse or manipulate it:
```
cursor = base64({"created_at": "2025-01-15T12:00:00Z", "id": 42})
```

Include in response: `"next_cursor": "eyJjcmVhdGVkX2..."` and `"has_next_page": true`.

### Tie-Breaking and Stable Sorting

Cursor-based pagination requires a **unique, stable sort key**. Sorting by `created_at` alone is insufficient if two rows have the same timestamp — they'll be skipped or duplicated. Always include the primary key as a tiebreaker:

```sql
ORDER BY created_at DESC, id DESC   -- id ensures uniqueness
WHERE (created_at, id) < (:last_ts, :last_id)
```

The composite tuple comparison `(created_at, id) < (:last_ts, :last_id)` correctly implements "earlier timestamp, or same timestamp but smaller id."

### Relay Cursor Specification (GraphQL)

GraphQL commonly uses the Relay Cursor Connection Specification:

```graphql
type OrderConnection {
  edges: [OrderEdge!]!
  pageInfo: PageInfo!
}
type OrderEdge    { node: Order!, cursor: String! }
type PageInfo     { hasNextPage: Boolean!, endCursor: String }
```

This standard is supported by HotChocolate and Apollo via `UseOffsetPaging` / `UsePaging` built-in directives.

### Total Count Problem

Offset pagination often shows "Page 1 of 47 (934 items)". The `COUNT(*)` query is expensive on large tables.

Options:
1. **Skip total count**: show "Load more" instead of page numbers (works well with cursor pagination).
2. **Approximate count**: `SELECT reltuples FROM pg_class WHERE relname = 'orders'` (PostgreSQL stats, fast but stale).
3. **Separate counter table**: maintain a counter updated on insert/delete.
4. **Cache the count**: recalculate every few minutes; show "~1,000 results".

### EF Core Implementation

EF Core `.Skip().Take()` generates OFFSET/FETCH. Keyset pagination requires a raw query or a `Where` clause with composite key comparison.

## Code Example

```csharp
// ASP.NET Core 8 — offset vs cursor pagination side by side
// Using EF Core with SQL Server

using Microsoft.EntityFrameworkCore;

// ── Offset pagination (simple, limited) ──────────────────────────────
app.MapGet("/orders/offset", async (
    int page,
    int pageSize = 20,
    OrderDbContext db = default!,
    CancellationToken ct = default) =>
{
    pageSize = Math.Clamp(pageSize, 1, 100);

    var total = await db.Orders.CountAsync(ct);      // expensive on large tables!
    var items = await db.Orders
        .OrderByDescending(o => o.CreatedAt)
        .ThenByDescending(o => o.Id)
        .Skip((page - 1) * pageSize)                 // O(N) scan
        .Take(pageSize)
        .ToListAsync(ct);

    return Results.Ok(new
    {
        Items     = items,
        Page      = page,
        PageSize  = pageSize,
        Total     = total,
        TotalPages = (int)Math.Ceiling(total / (double)pageSize)
    });
});

// ── Cursor-based pagination (scalable) ────────────────────────────────
app.MapGet("/orders/cursor", async (
    string? cursor,    // base64-encoded cursor from previous response
    int pageSize = 20,
    OrderDbContext db = default!,
    CancellationToken ct = default) =>
{
    pageSize = Math.Clamp(pageSize, 1, 100);

    // Decode cursor → last seen (createdAt, id)
    OrderCursor? decoded = cursor is null ? null : DecodeCursor(cursor);

    var query = db.Orders.AsQueryable();

    if (decoded is not null)
    {
        // Keyset: WHERE (created_at, id) < (:last_ts, :last_id)
        query = query.Where(o =>
            o.CreatedAt < decoded.CreatedAt ||
            (o.CreatedAt == decoded.CreatedAt && o.Id < decoded.Id));
    }

    // Fetch pageSize + 1 to determine if there's a next page
    var items = await query
        .OrderByDescending(o => o.CreatedAt)
        .ThenByDescending(o => o.Id)
        .Take(pageSize + 1)               // O(log N) index seek
        .ToListAsync(ct);

    var hasNext = items.Count > pageSize;
    if (hasNext) items.RemoveAt(items.Count - 1);

    var nextCursor = hasNext ? EncodeCursor(items[^1]) : null;

    return Results.Ok(new
    {
        Items      = items,
        NextCursor = nextCursor,
        HasNext    = hasNext
        // No "total" — don't need it for infinite scroll
    });
});

static string EncodeCursor(Order last) =>
    Convert.ToBase64String(
        System.Text.Json.JsonSerializer.SerializeToUtf8Bytes(
            new OrderCursor(last.CreatedAt, last.Id)));

static OrderCursor DecodeCursor(string cursor)
{
    var bytes = Convert.FromBase64String(cursor);
    return System.Text.Json.JsonSerializer.Deserialize<OrderCursor>(bytes)!;
}

record OrderCursor(DateTime CreatedAt, int Id);
```

## Common Follow-up Questions

- How do you implement bidirectional cursor pagination (previous page)?
- How does cursor pagination work in GraphQL using the Relay Connection Specification?
- How do you handle a cursor that becomes invalid because the row it pointed to was deleted?
- What index is needed on the database to make keyset pagination efficient?
- How do you sort by a non-unique column (like `price`) with cursor pagination?
- How do you implement seek-based pagination in EF Core without raw SQL?

## Common Mistakes / Pitfalls

- **Sorting by a non-unique column without tiebreaker**: `ORDER BY price DESC` with cursor `WHERE price < :last_price` skips rows when multiple rows have the same price. Always append the primary key as tiebreaker.
- **Large `OFFSET` in production**: `OFFSET 10000` on a 10-million-row table requires the DB to scan 10,000 rows just to discard them — latency spikes as the user pages deeper. Switch to cursor pagination before this becomes a problem.
- **Exposing raw database IDs as cursors**: integer IDs as cursors let clients infer row counts or enumerate IDs. Always encode/obfuscate cursors (base64 JSON or encrypted).
- **Count query on every page request**: `SELECT COUNT(*) FROM large_table` is a sequential scan. Avoid it on the hot path; use approximate counts or remove total-page numbers from the UI.
- **EF Core `.Skip().Take()` on a large table without warning**: EF Core generates OFFSET/FETCH cleanly, but there's no built-in warning when the offset grows large. Monitor slow queries.
- **Not indexing the ORDER BY columns**: cursor pagination is fast only if there's a composite index matching the ORDER BY columns. Without it, the `WHERE (col1, col2) < (:v1, :v2)` clause causes a table scan.

## References

- [EF Core — Pagination](https://learn.microsoft.com/ef/core/querying/pagination)
- [Relay Cursor Connection Specification](https://relay.dev/graphql/connections.htm)
- [Use the index, Luke — Paging](https://use-the-index-luke.com/sql/partial-results/top-n-queries)
- [HotChocolate cursor paging](https://chillicream.com/docs/hotchocolate/v14/fetching-data/pagination)
- [See: database-indexing-strategies.md](./database-indexing-strategies.md) — indexing for keyset pagination
