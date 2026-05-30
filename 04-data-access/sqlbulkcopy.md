# SqlBulkCopy in ADO.NET

**Category:** Data Access / ADO.NET
**Difficulty:** 🔴 Senior
**Tags:** `ADO.NET`, `SqlBulkCopy`, `bulk-insert`, `bcp`, `DataTable`, `IDataReader`, `performance`, `batch-size`

## Question

> How does `SqlBulkCopy` work, and when should you use it over `INSERT` statements or EF Core bulk extensions? What are the key configuration options — batch size, table lock, column mappings — and what are common pitfalls?

## Short Answer

`SqlBulkCopy` uses SQL Server's TDS bulk load protocol (same as `bcp` utility) to stream rows directly into a table at maximum throughput — bypassing row-by-row INSERT parsing, logging individual row changes, and per-row network round-trips. It's the fastest option for inserting tens of thousands or millions of rows. Key configuration: `DestinationTableName`, `BatchSize` (rows per batch), `BulkCopyTimeout`, `SqlBulkCopyOptions.TableLock` (full table lock for maximum speed), and explicit `ColumnMappings` to prevent positional mapping errors. Use it when neither EF Core batching nor `ExecuteUpdate` are fast enough — typically above 10k–50k rows.

## Detailed Explanation

### How It Works

```
C# IDataReader/DataTable → SqlBulkCopy → TDS bulk load packet → SQL Server
```

SQL Server receives bulk load packets containing raw row data — no individual `INSERT` statements are parsed. The server writes rows directly to the data file with minimal transaction log activity (only extent allocations are logged with simple recovery or `BULK_LOGGED`).

### Basic Usage with DataTable

```csharp
public async Task BulkInsertProductsAsync(
    IEnumerable<ProductImport> products,
    CancellationToken ct)
{
    // Build DataTable — column names must match destination table columns
    var table = new DataTable();
    table.Columns.Add("Name", typeof(string));
    table.Columns.Add("Price", typeof(decimal));
    table.Columns.Add("Sku", typeof(string));
    table.Columns.Add("CategoryId", typeof(int));
    table.Columns.Add("CreatedAt", typeof(DateTimeOffset));

    foreach (var p in products)
        table.Rows.Add(p.Name, p.Price, p.Sku, p.CategoryId, DateTimeOffset.UtcNow);

    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);

    using var copy = new SqlBulkCopy(conn, SqlBulkCopyOptions.TableLock, null)
    {
        DestinationTableName = "dbo.Products",
        BatchSize = 5_000,
        BulkCopyTimeout = 120
    };

    // Explicit column mappings (source → destination) — prevents positional errors
    copy.ColumnMappings.Add("Name", "Name");
    copy.ColumnMappings.Add("Price", "Price");
    copy.ColumnMappings.Add("Sku", "Sku");
    copy.ColumnMappings.Add("CategoryId", "CategoryId");
    copy.ColumnMappings.Add("CreatedAt", "CreatedAt");

    await copy.WriteToServerAsync(table, ct);
}
```

### SqlBulkCopyOptions Flags

| Option | Effect |
|--------|--------|
| `Default` | Row-level locking, individual row rollback |
| `TableLock` | Exclusive table lock for the duration — maximum speed, blocks other sessions |
| `CheckConstraints` | Check FK and CHECK constraints during bulk load (default: off — constraints skipped) |
| `FireTriggers` | Fire INSERT triggers per row (disabled by default — enable if triggers are required) |
| `KeepIdentity` | Preserve source IDENTITY values (don't generate new IDs) |
| `KeepNulls` | Insert NULL for missing values instead of the column default |

```csharp
// For maximum throughput: TableLock (blocks other reads/writes during import)
var options = SqlBulkCopyOptions.TableLock | SqlBulkCopyOptions.CheckConstraints;
using var copy = new SqlBulkCopy(conn, options, externalTransaction);
```

### Using IDataReader — Memory-Efficient for Large Sources

`WriteToServerAsync` accepts `IDataReader`, which allows streaming without loading everything into a `DataTable` first:

```csharp
// Custom IDataReader that wraps IEnumerable<T> — streams without full materialization
using var reader = new EnumerableDataReader<ProductImport>(products, columnSchema);
await copy.WriteToServerAsync(reader, ct);
```

Libraries like `FastMember.ObjectReader` (NuGet) provide this adapter:

```csharp
// NuGet: FastMember
using var reader = ObjectReader.Create(products, "Name", "Price", "Sku", "CategoryId");
await copy.WriteToServerAsync(reader, ct);
```

### Wrapping in a Transaction

```csharp
await using var conn = new SqlConnection(_connStr);
await conn.OpenAsync(ct);
await using var tx = (SqlTransaction)await conn.BeginTransactionAsync(ct);

using var copy = new SqlBulkCopy(conn, SqlBulkCopyOptions.Default, tx)
{
    DestinationTableName = "Products",
    BatchSize = 5_000
};

try
{
    await copy.WriteToServerAsync(table, ct);
    await tx.CommitAsync(ct);
}
catch
{
    await tx.RollbackAsync(ct);
    throw;
}
```

### Batch Size — Trade-offs

| Batch size | Transaction log | Memory | Speed |
|-----------|----------------|--------|-------|
| 1 (default if unset) | One tx per row | Low | Slow |
| 1 000 | One tx per 1k rows | Low | Good |
| 5 000 | One tx per 5k rows | Medium | Best for most |
| Unlimited (0) | One tx for all | High | Fast but risky |

For large imports, set `BatchSize` between 1 000–10 000. Batch 0 (no batching) risks large transactions that are slow to roll back on failure.

## Code Example

```csharp
// Production-ready bulk insert with streaming, transaction, and error handling
public async Task<int> BulkImportOrdersAsync(
    IAsyncEnumerable<OrderImportRow> source, CancellationToken ct)
{
    // Materialize to List first (or use IDataReader for true streaming)
    var rows = new List<OrderImportRow>();
    await foreach (var row in source.WithCancellation(ct))
        rows.Add(row);

    var table = new DataTable();
    table.Columns.Add("CustomerId", typeof(int));
    table.Columns.Add("Reference", typeof(string));
    table.Columns.Add("Total", typeof(decimal));
    table.Columns.Add("CreatedAt", typeof(DateTimeOffset));
    table.Columns.Add("Status", typeof(string));

    foreach (var r in rows)
        table.Rows.Add(r.CustomerId, r.Reference, r.Total, r.CreatedAt, r.Status);

    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);
    await using var tx = (SqlTransaction)await conn.BeginTransactionAsync(ct);

    using var copy = new SqlBulkCopy(conn, SqlBulkCopyOptions.CheckConstraints, tx)
    {
        DestinationTableName = "dbo.Orders",
        BatchSize = 2_000,
        BulkCopyTimeout = 300
    };
    copy.ColumnMappings.Add("CustomerId", "CustomerId");
    copy.ColumnMappings.Add("Reference", "Reference");
    copy.ColumnMappings.Add("Total", "Total");
    copy.ColumnMappings.Add("CreatedAt", "CreatedAt");
    copy.ColumnMappings.Add("Status", "Status");

    await copy.WriteToServerAsync(table, ct);
    await tx.CommitAsync(ct);

    return table.Rows.Count;
}
```

## Common Follow-up Questions

- How does `SqlBulkCopy` handle identity columns — can you insert a specific ID value?
- What recovery model should the database be in for minimum log usage during bulk inserts?
- How do you bulk insert into a table with foreign key constraints — should you disable them?
- Can `SqlBulkCopy` insert into partitioned tables?
- What is the difference between `SqlBulkCopy` and `OPENROWSET(BULK ...)` in T-SQL?

## Common Mistakes / Pitfalls

- **Not specifying `ColumnMappings`**: Without explicit mappings, `SqlBulkCopy` maps `DataTable` columns to database table columns **by position**, not by name. If column order in the `DataTable` differs from the physical table column order (which changes over time as columns are added), data is silently inserted into wrong columns.
- **Using `SqlBulkCopyOptions.TableLock` in a multi-user environment**: Table lock blocks all other reads and writes during the bulk insert. For production imports during business hours, use the default row-level locking unless throughput is critical.
- **`CheckConstraints` off by default**: FK constraints are skipped during bulk load unless you set `CheckConstraints`. A bulk insert can succeed while violating referential integrity — causing foreign key errors later.
- **Not setting `BatchSize`**: Default `BatchSize = 0` means all rows in a single transaction. A 5M-row batch creates a huge transaction log entry and a very slow rollback on failure. Always set a reasonable batch size.
- **Ignoring `KeepIdentity` when source data has IDs**: If your import file has `Id` values you want to preserve (e.g., migrating to a new database), you must set `KeepIdentity` — otherwise SQL Server generates new identity values and your source IDs are lost.

## References

- [SqlBulkCopy — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlbulkcopy)
- [SqlBulkCopyOptions — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlbulkcopyoptions)
- [Bulk import and export — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/bulk-import-and-export-of-data-sql-server)
- [See: bulk-operations.md](./bulk-operations.md)
- [See: datareader-vs-dataset.md](./datareader-vs-dataset.md)
