# Database Partitioning

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🔴 Senior
**Tags:** `SQL`, `partitioning`, `table-partitioning`, `partition-pruning`, `horizontal-partitioning`, `sharding`, `vertical-partitioning`

## Question

> What is SQL Server table partitioning? How does range partitioning work, and what is partition elimination (pruning)? How is it different from application-level horizontal partitioning (sharding) and vertical partitioning?

## Short Answer

**SQL Server table partitioning** divides a large table's rows into multiple physical filegroups based on a partition key (usually a date or integer range) while appearing as a single logical table. This enables **partition elimination** (pruning) — queries that filter on the partition key skip entire partitions rather than scanning the whole table, dramatically improving query speed and maintenance operations (e.g., archiving an old month by switching out a partition instead of deleting millions of rows). **Horizontal partitioning (sharding)** splits data across separate databases or servers — a .NET application routes queries to the correct shard. **Vertical partitioning** splits columns into separate tables, reducing row size and improving query efficiency for narrow projections.

## Detailed Explanation

### SQL Server Table Partitioning

SQL Server Enterprise (and Standard since 2016 SP1 for limited partitions) supports up to 15 000 partitions per table.

**Implementation steps:**

```sql
-- Step 1: Create a partition function (defines ranges)
CREATE PARTITION FUNCTION pf_OrdersByMonth (datetime2)
AS RANGE RIGHT FOR VALUES (
    '2023-01-01', '2023-02-01', '2023-03-01', 
    -- ... one boundary per month
    '2025-01-01'
);
-- RANGE RIGHT: boundary value belongs to the RIGHT partition
-- Partition 1: everything < 2023-01-01
-- Partition 2: 2023-01-01 to < 2023-02-01
-- ...

-- Step 2: Create a partition scheme (maps partitions to filegroups)
CREATE PARTITION SCHEME ps_OrdersByMonth
AS PARTITION pf_OrdersByMonth
ALL TO ([PRIMARY]);  -- all partitions to PRIMARY; in production, separate filegroups per month

-- Step 3: Create the partitioned table
CREATE TABLE Orders (
    Id          bigint        NOT NULL,
    CustomerId  int           NOT NULL,
    CreatedAt   datetime2     NOT NULL,
    Total       decimal(18,2) NOT NULL,
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (Id, CreatedAt)
    -- CreatedAt must be part of the PK to support the partition function
)
ON ps_OrdersByMonth(CreatedAt);  -- partitioned by CreatedAt
```

### Partition Elimination (Pruning)

When a query filters on the partition key, SQL Server excludes non-relevant partitions from the execution plan:

```sql
-- Query for March 2024 only
SELECT * FROM Orders
WHERE CreatedAt >= '2024-03-01' AND CreatedAt < '2024-04-01';

-- Execution plan: "Partition 15" (March 2024 partition) only
-- 11 other monthly partitions are completely skipped
```

**Without partitioning**: SQL Server scans the entire table (or clustered index).
**With partitioning**: only 1 of 12 partitions is read — ~8x less I/O for this query.

> **Partition elimination only works when the filter predicate directly maps to the partition column.** Filtering on a derived expression (e.g., `YEAR(CreatedAt) = 2024`) may prevent elimination — use range predicates on the raw column.

### Partition Switching — Fast Archive / Load Operations

The most powerful benefit of partitioning: atomically "switch in" or "switch out" a partition to another table — O(1) metadata operation regardless of row count:

```sql
-- Archive all orders from 2023 Q1 (partition 1–3) — no row-by-row DELETE needed
-- Create a staging table with the same schema (on the same filegroup)
CREATE TABLE OrdersArchive_2023Q1 (/* same columns */) ON [PRIMARY];

-- Switch the partition: zero-downtime, instant
ALTER TABLE Orders SWITCH PARTITION 1 TO OrdersArchive_2023Q1;
-- The 10 million rows in partition 1 are "moved" to OrdersArchive instantly
-- (only metadata changes — the data pages physically stay put)
```

For **incremental data loads** (e.g., ETL), load data into a staging table, then switch it into the target table — much faster than row-by-row insert.

### Horizontal Partitioning / Sharding

Application-level sharding distributes data across separate databases or schemas. SQL Server does not manage routing — the .NET application does:

```csharp
// Shard routing by customer ID
public AppDbContext GetShardContext(int customerId)
{
    // Consistent hash → shard index
    int shard = customerId % _shardCount;
    string connStr = _shardConnectionStrings[shard];
    return new AppDbContext(connStr);
}
```

**Trade-offs vs SQL Server partitioning**:

| Feature | SQL Server Partitioning | Sharding |
|---------|------------------------|---------|
| Cross-partition queries | ✅ Single SQL query | ❌ Application must fan out + merge |
| Transactions across partitions | ✅ | ❌ Distributed transactions needed |
| Scale-out (more capacity) | ❌ Limited by one server | ✅ Add servers horizontally |
| Complexity | Medium | High |
| Tooling | SQL Server built-in | Application code + routing logic |

### Vertical Partitioning

Split a wide table into a core table + extension table(s), joined on PK:

```sql
-- Original: 40-column Orders table
-- After vertical partitioning:
Orders (Id, CustomerId, Total, Status, CreatedAt)          -- hot columns, queried frequently
OrdersExtended (OrderId, Notes, Tags, InternalMetadata)    -- cold columns, queried rarely

-- Queries that only need hot columns don't load cold column pages
```

In EF Core, vertical partitioning is modeled as **table splitting**:

```csharp
entity.ToTable("Orders");
entity.OwnsOne(e => e.Extended, b => b.ToTable("OrdersExtended"));
```

## Code Example

```csharp
// EF Core — check current partition number for a row (SQL Server specific)
var partitionInfo = await db.Database
    .SqlQuery<PartitionInfo>($"""
        SELECT 
            $partition.pf_OrdersByMonth(CreatedAt) AS PartitionNumber,
            COUNT(*) AS RowCount,
            MIN(CreatedAt) AS MinDate,
            MAX(CreatedAt) AS MaxDate
        FROM Orders
        GROUP BY $partition.pf_OrdersByMonth(CreatedAt)
        ORDER BY PartitionNumber
        """)
    .ToListAsync(ct);

// Query exploiting partition elimination — always filter on partition key
var marchOrders = await db.Orders
    .Where(o => o.CreatedAt >= new DateTime(2024, 3, 1)
             && o.CreatedAt < new DateTime(2024, 4, 1))
    .AsNoTracking()
    .ToListAsync(ct);
// EF Core generates: WHERE CreatedAt >= '2024-03-01' AND CreatedAt < '2024-04-01'
// SQL Server performs partition elimination automatically
```

## Common Follow-up Questions

- When should you use a computed column as a partition key vs a direct column?
- How do you handle foreign key constraints with partitioned tables?
- What is the difference between `RANGE LEFT` and `RANGE RIGHT` in a partition function?
- How do partitioned tables affect index design — must every index include the partition key?
- How does EF Core Migrations interact with pre-created partitioned tables?

## Common Mistakes / Pitfalls

- **Partitioning a table that doesn't need it**: table partitioning adds complexity. It benefits tables with hundreds of millions of rows and clear range-based access patterns. For a 10M-row table, proper indexes are usually sufficient.
- **Filtering on derived partition expressions**: `WHERE YEAR(CreatedAt) = 2024` prevents partition elimination. Use explicit ranges: `WHERE CreatedAt >= '2024-01-01' AND CreatedAt < '2025-01-01'`.
- **Using a non-selective partition key**: partitioning by a low-cardinality column (e.g., `Status` with 3 values) creates few large partitions that provide minimal query benefit.
- **Neglecting the partition key in indexes**: on a partitioned table, non-aligned indexes (without the partition key) cannot participate in partition elimination for queries that filter on both the partition key and the indexed column.

## References

- [Partitioned tables and indexes — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)
- [Create partitioned tables and indexes — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/create-partitioned-tables-and-indexes)
- [Table and index organization — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide#table-and-index-architecture)
- [See: index-design-patterns.md](./index-design-patterns.md)
- [See: bulk-operations.md](./bulk-operations.md)
