# Denormalization for Performance

**Category:** System Design / Performance
**Difficulty:** Middle
**Tags:** `denormalization`, `database`, `read-model`, `caching`, `performance`, `trade-offs`

## Question

> What is denormalization and when should you use it? What are the trade-offs vs a normalised schema? How do you keep denormalised data consistent?

- How is database denormalization different from building a separate read model in CQRS?
- What are common denormalization patterns in practice?

## Short Answer

Denormalization deliberately introduces redundancy into a database schema — duplicating data or pre-computing derived values — to reduce JOIN complexity and improve read performance. It is the right choice when read latency is the bottleneck and reads vastly outnumber writes. The trade-off is write complexity: every update must synchronize all copies of the duplicated data, creating a consistency burden. In practice, denormalization should follow profiling evidence; premature denormalization increases maintenance cost without measurable benefit.

## Detailed Explanation

### Normalisation Recap

A normalised schema (3NF) stores each fact exactly once:

```sql
orders(id, customer_id, status)
customers(id, name, email)
order_lines(id, order_id, product_id, qty, unit_price_cents)
products(id, name, sku, category)
```

Reading an "order summary" requires multiple JOINs. On a 100M row `orders` table, that can be slow even with indexes.

### What Denormalization Does

Denormalization trades storage and write complexity for read speed:

```sql
-- Denormalised order_summaries table: pre-joins several tables
CREATE TABLE order_summaries (
    order_id        UUID PRIMARY KEY,
    customer_name   TEXT NOT NULL,     -- copied from customers
    customer_email  TEXT NOT NULL,     -- copied from customers
    status          TEXT NOT NULL,
    line_count      INT NOT NULL,      -- computed
    total_cents     BIGINT NOT NULL,   -- computed
    created_at      TIMESTAMPTZ NOT NULL
);
-- SELECT for order list: no JOINs, single index scan
```

### Common Denormalization Patterns

| Pattern | Description | Example |
|---------|------------|---------|
| **Inline scalar** | Copy a column from a related table | Storing `customer_name` in `orders` |
| **Pre-aggregated column** | Materialised aggregate | `order_count INT` on `customers` |
| **Computed column** | DB-maintained derived value | `total_cents AS GENERATED ALWAYS AS (qty * unit_price_cents) STORED` |
| **Materialised view** | DB-managed pre-computed query | Postgres `MATERIALIZED VIEW` |
| **Separate read table** | Application-maintained projection | CQRS read model |
| **Array/JSON column** | Embed related rows as JSON | `tags TEXT[]`, `line_items JSONB` |

### Materialised Views (Database-Managed Denormalization)

Postgres `MATERIALIZED VIEW` is the simplest form: the database maintains the redundant data automatically:

```sql
CREATE MATERIALIZED VIEW order_list_mv AS
SELECT
    o.id            AS order_id,
    c.name          AS customer_name,
    o.status,
    COUNT(l.id)     AS line_count,
    SUM(l.qty * l.unit_price_cents) AS total_cents,
    o.created_at
FROM orders o
JOIN customers c ON c.id = o.customer_id
JOIN order_lines l ON l.order_id = o.id
GROUP BY o.id, c.name, o.status, o.created_at;

-- Refresh (concurrently = no read lock, but slower)
REFRESH MATERIALIZED VIEW CONCURRENTLY order_list_mv;
CREATE UNIQUE INDEX ON order_list_mv (order_id);  -- required for CONCURRENTLY
```

**Consistency model**: materialised view is stale until refreshed. Schedule refreshes via pg_cron or trigger refresh from application after significant writes.

### Inline Denormalization (Application-Managed)

For frequently read, rarely changed reference data, copying into the main table avoids JOINs:

```sql
-- Example: denormalise product name and category into order_lines
-- (product name changes are rare; we can accept that historical orders show the name at order time)
ALTER TABLE order_lines ADD COLUMN product_name TEXT NOT NULL;
ALTER TABLE order_lines ADD COLUMN category TEXT NOT NULL;

-- Populate on insert:
INSERT INTO order_lines (order_id, product_id, product_name, category, qty, unit_price_cents)
SELECT @OrderId, p.id, p.name, p.category, @Qty, p.current_price_cents
FROM products p WHERE p.id = @ProductId;
```

This also preserves historical accuracy: the order shows the product name at the time of purchase, even if the product is renamed later.

### Keeping Denormalised Data Consistent

**Strategy 1: Trigger-based sync** (database enforces consistency)

```sql
CREATE OR REPLACE FUNCTION sync_customer_name_to_orders()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE order_summaries
    SET customer_name = NEW.name
    WHERE customer_id = NEW.id; -- WARNING: table scan if no index on customer_id
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_customer_name_sync
AFTER UPDATE OF name ON customers
FOR EACH ROW EXECUTE FUNCTION sync_customer_name_to_orders();
```

**Pros**: consistent at database level. **Cons**: triggers are hidden logic, hard to test, can cause write slowdowns.

**Strategy 2: Application-level dual-write** (explicit in code)

```csharp
public async Task UpdateCustomerNameAsync(Guid customerId, string newName, CancellationToken ct)
{
    await using var tx = await _db.Database.BeginTransactionAsync(ct);
    try
    {
        await _db.Customers
            .Where(c => c.Id == customerId)
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.Name, newName), ct);

        // Keep denormalised copy in sync within same transaction
        await _db.OrderSummaries
            .Where(s => s.CustomerId == customerId)
            .ExecuteUpdateAsync(s => s.SetProperty(o => o.CustomerName, newName), ct);

        await tx.CommitAsync(ct);
    }
    catch
    {
        await tx.RollbackAsync(ct);
        throw;
    }
}
```

**Strategy 3: Event-driven rebuild** (eventual consistency, CQRS pattern)

See [cqrs-and-read-models.md](./cqrs-and-read-models.md) — the projection pattern.

### When to Denormalize

✅ **Good candidates**:
- Reference data that rarely changes (product names, category labels, user display names).
- Aggregates queried far more often than they change (total orders, follower count).
- Historical snapshots where "point-in-time" accuracy is desired (order items at checkout).
- Reporting tables queried by BI tools (analytics databases are almost entirely denormalised).

❌ **Poor candidates**:
- Frequently updated columns (stock price, real-time inventory level) — synchronisation cost too high.
- Data that is correct only if always up-to-date (current account balance in a payment system).
- Small tables where a JOIN is trivially fast — premature optimisation.

> **Warning:** Profile before denormalizing. On modern hardware, a well-indexed JOIN on millions of rows is fast. Adding denormalization without evidence it's the bottleneck creates write complexity and the risk of stale reads with no measurable read improvement.

## Code Example

```csharp
// EF Core computed column — database maintains total_cents automatically
public class OrderLine
{
    public Guid Id { get; set; }
    public Guid OrderId { get; set; }
    public string ProductName { get; set; } = default!;   // denormalised at order time
    public int Quantity { get; set; }
    public long UnitPriceCents { get; set; }

    // Generated column — always consistent, zero application effort
    public long TotalCents { get; private set; }
}

// In DbContext
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.Entity<OrderLine>()
        .Property(l => l.TotalCents)
        .HasComputedColumnSql("quantity * unit_price_cents", stored: true);
        // stored: true → persisted to disk, can be indexed
        // stored: false → recomputed on every read (virtual)
}

// Query using the computed column directly — no need to compute in C#
var expensiveLines = await _db.OrderLines
    .Where(l => l.TotalCents > 100_00)   // index on total_cents is useful here
    .OrderByDescending(l => l.TotalCents)
    .Take(10)
    .ToListAsync(ct);
```

## Common Follow-up Questions

- What is the difference between a materialised view and a database index?
- How do you handle a customer name change that should propagate to 10 million order rows?
- What is the N+1 problem and how does denormalization help or hurt it?
- How do you decide between a read model (application layer) vs materialised view (database layer) for denormalization?
- How does denormalization in OLTP differ from a data warehouse or OLAP schema?

## Common Mistakes / Pitfalls

- **Denormalizing before measuring**: adds write complexity and stale-data risk for potentially no observable speedup.
- **No index on the sync trigger's join column**: a `BEFORE UPDATE` trigger that runs `UPDATE orders WHERE customer_id = X` is a full table scan if `customer_id` is not indexed.
- **Forgetting historical accuracy**: copying a customer email into orders means updating customer email silently changes what historical order confirmation records show — sometimes correct, sometimes wrong.
- **Using materialised view without `CONCURRENTLY`**: `REFRESH MATERIALIZED VIEW` without `CONCURRENTLY` acquires an exclusive lock, blocking all reads during the refresh.
- **Dual-write without a transaction**: if the second `UPDATE` fails after the first commits, you have inconsistent data. Always wrap both updates in a transaction.

## References

- [Database normalisation — Martin Fowler](https://martinfowler.com/articles/evodb.html) (verify URL)
- [Materialised views — PostgreSQL Docs](https://www.postgresql.org/docs/current/rules-materializedviews.html)
- [EF Core generated columns](https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-7.0/whatsnew#database-generated-columns)
- [See: cqrs-and-read-models.md](./cqrs-and-read-models.md)
- [See: database-indexing-strategies.md](./database-indexing-strategies.md)
