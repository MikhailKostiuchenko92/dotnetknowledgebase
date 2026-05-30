# Bulk Operations in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `bulk-insert`, `bulk-update`, `SqlBulkCopy`, `ExecuteUpdate`, `ExecuteDelete`, `Z.EntityFramework`, `performance`

## Question

> What options exist for bulk data operations in EF Core? When should you use `ExecuteUpdate`/`ExecuteDelete` vs `SqlBulkCopy` vs third-party extensions like EF Core Extensions? What are the trade-offs of each approach?

## Short Answer

EF Core 7+ provides `ExecuteUpdateAsync`/`ExecuteDeleteAsync` for set-based SQL UPDATE/DELETE without loading entities — ideal for conditional bulk updates. `SqlBulkCopy` uses the bcp protocol to stream rows directly to SQL Server at maximum throughput, with no ORM overhead. Third-party libraries like `EFCore.BulkExtensions` (free) and `Z.EntityFramework.Extensions.EFCore` (commercial) add `BulkInsert`, `BulkUpdate`, `BulkMerge` methods that map entity properties to SQL using EF Core's model metadata, bridging the gap between ORM convenience and raw SQL performance. Choose based on volume: tracked `SaveChanges` for <1k rows, `ExecuteUpdate` for set-based operations, `BulkInsert`/`SqlBulkCopy` for tens of thousands of rows.

## Detailed Explanation

### The Performance Spectrum

| Rows | Recommended approach | Throughput (approx.) |
|------|---------------------|---------------------|
| < 500 | `SaveChanges` (batched) | OK |
| 500 – 5 000 | `AddRange` + `SaveChanges`, or `ExecuteUpdate` | Good |
| 5 000 – 100 000 | `EFCore.BulkExtensions.BulkInsert` | Very good |
| > 100 000 | `SqlBulkCopy` or TVP + stored procedure | Best |

### Option 1: `ExecuteUpdateAsync` / `ExecuteDeleteAsync` (EF Core 7+)

Best for: set-based conditional updates or deletes where you know the criteria.

```csharp
// Update all active products in a category — single SQL UPDATE
int rows = await db.Products
    .Where(p => p.CategoryId == catId && p.IsActive)
    .ExecuteUpdateAsync(s => s
        .SetProperty(p => p.Price, p => p.Price * 1.05m)
        .SetProperty(p => p.UpdatedAt, DateTimeOffset.UtcNow),
        ct);

// Delete expired sessions — single SQL DELETE
await db.Sessions
    .Where(s => s.ExpiresAt < DateTimeOffset.UtcNow)
    .ExecuteDeleteAsync(ct);
```

**Pros:** Native EF Core, no third-party dependency, single SQL statement, no entity loading.
**Cons:** Can only set property values that are computable from the current row; can't call external services or trigger domain events. Does not update the change tracker.

[See: batching-in-ef-core.md](./batching-in-ef-core.md)

### Option 2: `SqlBulkCopy` (ADO.NET — SQL Server Only)

Best for: inserting large volumes (100k+) as fast as possible. Uses the TDS bulk load protocol.

```csharp
public async Task BulkInsertProductsAsync(
    IEnumerable<Product> products, string connStr, CancellationToken ct)
{
    var table = new DataTable();
    table.Columns.Add("Name", typeof(string));
    table.Columns.Add("Price", typeof(decimal));
    table.Columns.Add("Sku", typeof(string));
    table.Columns.Add("CategoryId", typeof(int));

    foreach (var p in products)
        table.Rows.Add(p.Name, p.Price, p.Sku, p.CategoryId);

    using var conn = new SqlConnection(connStr);
    await conn.OpenAsync(ct);

    using var copy = new SqlBulkCopy(conn)
    {
        DestinationTableName = "Products",
        BatchSize = 5_000,
        BulkCopyTimeout = 60
    };
    copy.ColumnMappings.Add("Name", "Name");
    copy.ColumnMappings.Add("Price", "Price");
    copy.ColumnMappings.Add("Sku", "Sku");
    copy.ColumnMappings.Add("CategoryId", "CategoryId");

    await copy.WriteToServerAsync(table, ct);
}
```

**Pros:** Fastest possible for SQL Server — easily 100k–1M rows/second.
**Cons:** SQL Server only, requires `DataTable` or `IDataReader`, no EF Core model awareness, column mapping is manual and brittle if schema changes.

### Option 3: `EFCore.BulkExtensions` (Free, Open Source)

```xml
<PackageReference Include="EFCore.BulkExtensions" Version="8.*" />
```

```csharp
// BulkInsert — uses SQL Server TVP or bcp under the hood
await db.BulkInsertAsync(products, ct);

// BulkUpdate — matches by PK, updates all other columns
await db.BulkUpdateAsync(products, ct);

// BulkInsertOrUpdate (MERGE / UPSERT)
await db.BulkInsertOrUpdateAsync(products, ct);

// Configure which columns to include/exclude
await db.BulkInsertAsync(products, opt =>
{
    opt.PropertiesToInclude = [nameof(Product.Name), nameof(Product.Price)];
    opt.SetOutputIdentity = true;  // populate Id after insert
}, ct);
```

**Pros:** EF Core model-aware (column names, table name, keys come from model), supports SQL Server, PostgreSQL, SQLite. Free, actively maintained.
**Cons:** Third-party dependency, some advanced features (e.g., shadow property mapping) occasionally lag EF Core releases.

### Option 4: `Z.EntityFramework.Extensions.EFCore` (Commercial)

```csharp
await db.BulkInsertAsync(products);
await db.BulkMergeAsync(products);  // UPSERT with concurrency control
await db.BulkSaveChangesAsync();    // batch all SaveChanges operations
```

**Pros:** Most feature-complete; supports complex merge strategies, output values, audit fields. Used in enterprise solutions.
**Cons:** Commercial license required (per-developer or per-server). Expensive for small teams.

### Table-Valued Parameters (TVP) — Stored Procedure Approach

For complex upsert logic that can't be expressed in EF Core LINQ:

```sql
-- Database side
CREATE TYPE dbo.ProductImportType AS TABLE (
    Name NVARCHAR(200), Price DECIMAL(18,2), Sku NVARCHAR(50)
);

CREATE PROCEDURE dbo.BulkUpsertProducts @Products dbo.ProductImportType READONLY
AS MERGE Products AS target
   USING @Products AS source ON target.Sku = source.Sku
   WHEN MATCHED THEN UPDATE SET target.Price = source.Price
   WHEN NOT MATCHED THEN INSERT (Name, Price, Sku) VALUES (source.Name, source.Price, source.Sku);
```

```csharp
// C# side
var tvp = new DataTable();
tvp.Columns.Add("Name", typeof(string));
tvp.Columns.Add("Price", typeof(decimal));
tvp.Columns.Add("Sku", typeof(string));

foreach (var p in products)
    tvp.Rows.Add(p.Name, p.Price, p.Sku);

var param = new SqlParameter("@Products", SqlDbType.Structured)
{
    TypeName = "dbo.ProductImportType",
    Value = tvp
};

await db.Database.ExecuteSqlRawAsync("EXEC dbo.BulkUpsertProducts @Products", param, ct);
```

## Code Example

```csharp
// Decision tree in code
public async Task ImportAsync(
    List<ProductImport> rows, BulkStrategy strategy, CancellationToken ct)
{
    switch (strategy)
    {
        case BulkStrategy.SmallBatch:
            // < 500 rows: use tracked SaveChanges
            db.Products.AddRange(rows.Select(r => new Product { Name = r.Name, Price = r.Price }));
            await db.SaveChangesAsync(ct);
            break;

        case BulkStrategy.SetBased:
            // Update existing prices without loading entities
            await db.Products
                .Where(p => rows.Select(r => r.Sku).Contains(p.Sku))
                .ExecuteUpdateAsync(
                    s => s.SetProperty(p => p.UpdatedAt, DateTimeOffset.UtcNow), ct);
            break;

        case BulkStrategy.BulkInsert:
            // 5k–100k: EFCore.BulkExtensions
            var entities = rows.Select(r => new Product { Name = r.Name, Price = r.Price, Sku = r.Sku }).ToList();
            await db.BulkInsertAsync(entities, ct);
            break;

        case BulkStrategy.MaxThroughput:
            // 100k+: SqlBulkCopy
            await BulkCopyAsync(rows, ct);
            break;
    }
}
```

## Common Follow-up Questions

- How does `EFCore.BulkExtensions.BulkInsert` handle EF Core's concurrency tokens (`[Timestamp]`)?
- Can `SqlBulkCopy` participate in an existing `SqlTransaction`?
- What is the performance difference between `BulkInsert` and `SaveChanges` with `AutoDetectChangesEnabled = false`?
- How do you populate database-generated IDs (identity columns) back into your entities after a bulk insert?
- When should you use a TVP + stored procedure over `SqlBulkCopy`?

## Common Mistakes / Pitfalls

- **Using `SaveChanges` inside a loop for large imports**: Even with `AutoDetectChangesEnabled = false`, 100k `SaveChanges` calls = 100k round-trips. Use `AddRange` + one `SaveChanges` per batch, or switch to a bulk API.
- **`SqlBulkCopy` without column mappings**: If the column order in the `DataTable` doesn't match the table's column order, SQL Server maps positionally — silently inserting wrong values into wrong columns. Always use explicit `ColumnMappings`.
- **Not wrapping bulk operations in a transaction**: A partial failure mid-import leaves the table in an inconsistent state. Wrap the entire import in `BeginTransactionAsync` and roll back on failure.
- **Assuming `ExecuteUpdate` is the right tool for row-by-row logic**: `ExecuteUpdate` uses SQL `SET col = expression` — it can reference existing column values but cannot call external services, compute complex logic, or trigger domain events. For row-specific business logic, load entities and use tracked `SaveChanges`.
- **Ignoring the stale change tracker after `ExecuteUpdate`/`ExecuteDelete`**: Any entities already tracked from the affected rows retain their pre-update values. Call `db.ChangeTracker.Clear()` after bulk operations if you'll continue to use the context.

## References

- [ExecuteUpdate / ExecuteDelete — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/execute-insert-update-delete)
- [SqlBulkCopy — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlbulkcopy)
- [EFCore.BulkExtensions — GitHub](https://github.com/borisdj/EFCore.BulkExtensions)
- [EF Core performance: efficient updating — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/performance/efficient-updating)
- [See: change-tracker-performance.md](./change-tracker-performance.md)
