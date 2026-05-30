# Database Indexing Strategies

**Category:** System Design / Data Storage
**Difficulty:** 🟡 Middle
**Tags:** `indexing`, `B-tree`, `hash-index`, `composite-index`, `covering-index`, `selectivity`, `EF-Core`, `SQL-Server`

## Question

> Explain the main database index types (B-tree, hash). What are composite indexes, covering indexes, and index selectivity? How do you choose which columns to index?

## Short Answer

A B-tree index organises data in a balanced tree allowing O(log N) range lookups and equality checks — it's the default index type in SQL Server and PostgreSQL. Hash indexes support O(1) equality lookups only, not ranges. Composite indexes cover multiple columns and are most effective when the leftmost prefix matches the query's WHERE clause. A covering index includes all columns a query needs, eliminating the table lookup entirely. Index selectivity (distinct values / total rows) determines how useful an index is — low-selectivity columns (booleans, status enums) are rarely worth indexing.

## Detailed Explanation

### B-Tree Index

The standard index type. A balanced tree where:
- Each leaf node points to a row (clustered index) or to the row's physical address (non-clustered).
- Supports: equality (`=`), range (`<`, `>`, `BETWEEN`), `ORDER BY`, `LIKE 'prefix%'`.
- Does NOT support: `LIKE '%suffix'`, functions on indexed columns (`YEAR(created_at) = 2025`).
- Maintenance cost: inserts/updates/deletes must update the tree — O(log N) per write.

**Clustered vs Non-Clustered:**
- **Clustered**: rows are physically sorted by the index key. Only one per table (SQL Server: defaults to primary key). Sequential reads along the index are fast.
- **Non-clustered**: a separate structure pointing to the heap. Multiple allowed; lookup requires a "bookmark lookup" to get non-indexed columns.

### Hash Index

Stores a hash map of key → row pointer. O(1) exact equality lookup. Does NOT support ranges, ordering, or prefix matching. Rarely used in relational databases (PostgreSQL supports them; SQL Server does not for user-defined indexes). Very common in in-memory databases and key-value stores.

### Composite Indexes

An index on multiple columns: `CREATE INDEX idx ON orders (customer_id, created_at)`.

**Leftmost prefix rule**: the index is useful for queries that filter on the leftmost column(s) of the index.

| Query | Uses idx? |
|-------|----------|
| `WHERE customer_id = 1` | ✅ (leftmost prefix) |
| `WHERE customer_id = 1 AND created_at > '2025-01-01'` | ✅ (full prefix) |
| `WHERE created_at > '2025-01-01'` | ❌ (skips leftmost column) |
| `ORDER BY customer_id, created_at` | ✅ (covers the ORDER BY) |

**Column order matters**: put the equality-filtered column first, range-filtered column last. Columns after a range filter in the key are not used for filtering (only for sorting).

### Covering Indexes

A covering index includes all columns referenced in the query:

```sql
-- Query: SELECT order_id, total FROM orders WHERE customer_id = 1
-- Covering index: (customer_id, order_id, total)  ← includes SELECT columns
CREATE INDEX idx_covering ON orders (customer_id) INCLUDE (order_id, total);
```

With a covering index, the engine never touches the table rows — it gets everything from the index pages. This is called an **index-only scan** and is dramatically faster for high-read, low-write scenarios.

In SQL Server and PostgreSQL, use the `INCLUDE` clause to add non-key columns to the index leaf pages without affecting the sort order.

### Index Selectivity

```
Selectivity = DISTINCT(column_values) / total_rows
```

| Selectivity | Example | Index useful? |
|------------|---------|--------------|
| ~1.0 (high) | UUID, email address | ✅ Highly useful |
| Medium | Country code (200 values) | ⚠️ Depends on query |
| ~0 (low) | Boolean, status (3 values) | ❌ Rarely useful |

A low-selectivity index (e.g., `is_active = true` when 90% of rows are active) is ignored by the query planner because scanning the index + fetching rows is slower than a full table scan.

**Exception**: low-selectivity columns can still be indexed in composite indexes: `(status, created_at)` where `status = 'pending'` is selective enough in combination with a date range.

### When Not to Index

- Tables with very high write:read ratios (index maintenance overhead dominates).
- Small tables (< 10K rows) where full scans are faster than index lookups.
- Columns only ever used in non-SARGable predicates (`LOWER(email) = :v` — function on column bypasses index).
- Duplicate indexes (already covered by another composite index's prefix).

### Monitoring Index Usage

```sql
-- SQL Server: find unused indexes
SELECT i.name, s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE s.database_id = DB_ID()
ORDER BY s.user_seeks DESC;

-- Find missing index recommendations
SELECT * FROM sys.dm_db_missing_index_details;
```

## Code Example

```csharp
// EF Core 8 — configuring indexes in Fluent API
// Matching SQL strategies: composite, covering, unique, filtered

using Microsoft.EntityFrameworkCore;

public class OrderDbContext(DbContextOptions<OrderDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<Customer> Customers => Set<Customer>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<Order>(e =>
        {
            // Composite index: equality on customer_id first (leftmost prefix), then range on created_at
            e.HasIndex(o => new { o.CustomerId, o.CreatedAt })
             .HasDatabaseName("ix_orders_customer_created");

            // Covering index: include total so query-only scans don't need heap lookup
            // EF Core 9+ supports .IncludeProperties(); earlier versions use raw SQL migration
            e.HasIndex(o => new { o.CustomerId, o.Status })
             .IncludeProperties(o => new { o.Total, o.CreatedAt })  // EF Core 9
             .HasDatabaseName("ix_orders_customer_status_covering");

            // Filtered index: only pending orders — high selectivity when most orders are completed
            e.HasIndex(o => o.CreatedAt)
             .HasFilter("[Status] = 'Pending'")      // SQL Server syntax
             .HasDatabaseName("ix_orders_pending_created");

            // Unique constraint (creates unique index automatically)
            e.HasIndex(o => o.OrderNumber)
             .IsUnique()
             .HasDatabaseName("ux_orders_number");
        });

        mb.Entity<Customer>(e =>
        {
            // Single-column unique index on email
            e.HasIndex(c => c.Email)
             .IsUnique()
             .HasDatabaseName("ux_customers_email");
        });
    }
}

// Demonstrate SARGable vs non-SARGable queries
app.MapGet("/orders/demo", async (OrderDbContext db, string email) =>
{
    // ✅ SARGable: index on Email is used
    var customerSargable = await db.Customers
        .Where(c => c.Email == email)          // equality on indexed column
        .FirstOrDefaultAsync();

    // ❌ NOT SARGable: function on column bypasses index
    var customerNotSargable = await db.Customers
        .Where(c => c.Email.ToLower() == email.ToLower())  // LOWER() prevents index seek
        .FirstOrDefaultAsync();

    // ✅ Use EF Core collation instead:
    var customerCollation = await db.Customers
        .Where(c => EF.Functions.Like(c.Email, email))     // case-insensitive via collation
        .FirstOrDefaultAsync();

    return Results.Ok(customerSargable);
});

public record Order(int Id, int CustomerId, string OrderNumber, string Status, decimal Total, DateTime CreatedAt);
public record Customer(int Id, string Email, string Name);
```

## Common Follow-up Questions

- When does the query planner choose a full table scan over an available index?
- What is an index seek vs index scan, and which is preferred?
- How do you identify and remove duplicate or redundant indexes?
- How does index fragmentation affect performance, and how do you rebuild/reorganise it?
- What is a partial (filtered) index and when is it better than a full index?
- How does EF Core's `HasIndex().IncludeProperties()` map to SQL Server's `INCLUDE` clause?

## Common Mistakes / Pitfalls

- **Indexing every foreign key column by default**: foreign keys should usually be indexed, but blindly adding an index to every FK without considering selectivity and query patterns wastes write overhead.
- **Non-SARGable predicates on indexed columns**: `WHERE YEAR(created_at) = 2025`, `WHERE email COLLATE SQL_Latin1 = :v`, `WHERE total * 1.2 > 100` — functions or arithmetic on indexed columns prevent index seeks. Rewrite as `WHERE created_at >= '2025-01-01' AND created_at < '2026-01-01'`.
- **Composite index column order wrong**: `(created_at, customer_id)` is useless for `WHERE customer_id = 1` (doesn't use leftmost prefix). The equality filter column must come first.
- **Too many indexes on a write-heavy table**: every `INSERT`/`UPDATE`/`DELETE` must update all indexes. A table with 15 indexes can be significantly slower to write to than one with 3.
- **Ignoring the `INCLUDE` clause for covering indexes**: including columns as key columns (affecting sort order) rather than INCLUDE columns wastes space and can hurt performance.
- **Not testing index effectiveness with EXPLAIN/execution plans**: adding an index without verifying the query planner actually uses it is common. Always check the execution plan after index creation.

## References

- [SQL Server index architecture — Microsoft Learn](https://learn.microsoft.com/sql/relational-databases/indexes/clustered-and-nonclustered-indexes-described)
- [EF Core — Indexes](https://learn.microsoft.com/ef/core/modeling/indexes)
- [Use the Index, Luke — free online book on SQL indexing](https://use-the-index-luke.com/)
- [SQL Server Missing Index DMVs](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-db-missing-index-details-transact-sql)
- [See: database-sharding.md](./database-sharding.md) — how indexes interact with sharding strategy
