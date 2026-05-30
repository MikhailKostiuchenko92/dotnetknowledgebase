# SqlDataReader vs DataSet in ADO.NET

**Category:** Data Access / ADO.NET
**Difficulty:** 🟡 Middle
**Tags:** `ADO.NET`, `SqlDataReader`, `DataSet`, `DataTable`, `forward-only`, `disconnected`, `streaming`

## Question

> What is the difference between `SqlDataReader` and `DataSet`/`DataTable` in ADO.NET? When is each appropriate, and is `DataSet` still relevant in modern .NET?

## Short Answer

`SqlDataReader` is a forward-only, read-only cursor that streams rows one at a time while the connection is open — minimal memory, maximum throughput. `DataSet`/`DataTable` loads the entire result set into memory as an in-memory relational database, disconnected from the server. `SqlDataReader` is the right default for all performance-sensitive code. `DataSet` is appropriate when: you need to pass data to legacy APIs that require `DataTable` (e.g., `SqlBulkCopy`, SSRS reports, DataGridView), or you need to navigate/update a result set multiple times in memory. In modern .NET, Dapper and EF Core have largely replaced direct `DataSet` use.

## Detailed Explanation

### SqlDataReader — Streaming, Connected

```
Open connection → Execute query → Read row 1 → Read row 2 → … → Close reader → Return connection to pool
```

- One row in memory at a time (or one page, depending on fetch size).
- Connection must stay open for the entire iteration.
- Read-only, forward-only: can't go back to row 1 after reading row 2.
- The `while (await reader.ReadAsync(ct))` pattern processes each row and can discard it.

```csharp
// Streaming 1M rows without loading them all into memory
await using var reader = await cmd.ExecuteReaderAsync(ct);
while (await reader.ReadAsync(ct))
{
    var row = MapRow(reader);  // process and discard
    await writer.WriteAsync(row, ct);
}
```

### DataSet / DataTable — In-Memory, Disconnected

`SqlDataAdapter.Fill(dataSet)` executes a query, loads **all rows** into `DataTable` objects, and closes the connection. The in-memory copy can be navigated freely:

```csharp
var adapter = new SqlDataAdapter(
    "SELECT Id, Name, Price FROM Products", conn);
var ds = new DataSet();
adapter.Fill(ds);  // all rows loaded; connection closed

// Navigate in any direction
foreach (DataRow row in ds.Tables[0].Rows)
{
    var id = (int)row["Id"];
    var name = (string)row["Name"];
}

// Modify and persist back (bi-directional with SqlCommandBuilder)
ds.Tables[0].Rows[0]["Price"] = 19.99m;
adapter.Update(ds);  // generates UPDATE statements for changed rows
```

### Comparison

| | SqlDataReader | DataSet / DataTable |
|--|--------------|---------------------|
| Memory usage | O(1) — one row at a time | O(n) — all rows loaded |
| Navigation | Forward-only | Random access, multiple passes |
| Read/write | Read-only | Read/write (with SqlDataAdapter) |
| Connection required | Yes (held open) | No (disconnected after Fill) |
| Performance (read) | Best | Slower (all rows materialized) |
| Schema introspection | Via `GetSchemaTable()` | Via `DataTable.Columns` |
| Thread safety | No | Limited (single-thread per DataTable) |
| Modern relevance | ✅ Primary API | ⚠️ Legacy, specific scenarios |

### When DataSet/DataTable is Still Used

1. **`SqlBulkCopy` source**: `SqlBulkCopy.WriteToServerAsync(DataTable)` is a common bulk insert pattern.
2. **SSRS / Crystal Reports / RDLC**: Older reporting engines still expect `DataSet` as data source.
3. **Windows Forms / WPF DataGrid binding**: `DataTable` binds directly to `DataGridView` / `DataGrid`.
4. **Existing codebase with DataSet APIs**: Migrating all at once isn't always practical.
5. **Schema-driven metadata**: `DataTable.Columns` provides column metadata without a separate schema query.

### DataTable for SqlBulkCopy

```csharp
public async Task BulkInsertAsync(IEnumerable<Product> products, CancellationToken ct)
{
    var table = new DataTable();
    table.Columns.Add("Name", typeof(string));
    table.Columns.Add("Price", typeof(decimal));
    table.Columns.Add("CategoryId", typeof(int));

    foreach (var p in products)
        table.Rows.Add(p.Name, p.Price, p.CategoryId);

    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);

    using var copy = new SqlBulkCopy(conn)
    {
        DestinationTableName = "Products",
        BatchSize = 1000
    };
    await copy.WriteToServerAsync(table, ct);
}
```

In this scenario, `DataTable` is the mechanism for bulk loading — the overhead is acceptable because the goal is maximum write throughput.

## Code Example

```csharp
// SqlDataReader — streaming large export
public async IAsyncEnumerable<string> StreamCsvAsync(
    [EnumeratorCancellation] CancellationToken ct = default)
{
    yield return "Id,Name,Price";  // header

    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);

    await using var cmd = conn.CreateCommand();
    cmd.CommandText = "SELECT Id, Name, Price FROM Products ORDER BY Id";

    await using var reader = await cmd.ExecuteReaderAsync(ct);
    while (await reader.ReadAsync(ct))
    {
        yield return $"{reader.GetInt32(0)},{reader.GetString(1)},{reader.GetDecimal(2)}";
    }
}

// DataTable — for SqlBulkCopy (acceptable DataSet usage)
public static DataTable ToDataTable(IEnumerable<ProductCsvRow> rows)
{
    var table = new DataTable("Products");
    table.Columns.Add("Name", typeof(string));
    table.Columns.Add("Price", typeof(decimal));

    foreach (var r in rows)
        table.Rows.Add(r.Name, r.Price);

    return table;
}
```

## Common Follow-up Questions

- Can `SqlDataReader` handle multiple result sets from a single query?
- What is `DataView` and how does it differ from `DataTable`?
- How do you convert a `DataTable` to `IEnumerable<T>` in modern .NET?
- Is `SqlDataAdapter.Update` ever appropriate for production write operations?
- What replaced `DataSet` for passing data between application layers in modern architecture?

## Common Mistakes / Pitfalls

- **Using `DataSet` for performance-sensitive reads**: Loading 100k rows into a `DataTable` consumes significant memory (each `DataRow` has original, current, and proposed versions). Use `SqlDataReader` or Dapper for reads.
- **Holding `SqlDataReader` open while processing slow operations**: The connection is reserved while the reader is open. Don't call external APIs, send emails, or perform other I/O between `ReadAsync` calls — do that after the reader is closed.
- **`DataSet.Tables[0]` without checking if table exists**: `Fill` may add fewer tables than expected (e.g., if the SP returns 0 result sets). Always check `ds.Tables.Count`.
- **Modifying a `DataTable` while enumerating `Rows`**: Iterating `table.Rows` and removing rows in the same loop throws. Use a reverse loop or collect rows to delete then call `row.Delete()` after iteration.
- **Using `DataTable` where Dapper or a DTO suffices**: In new code, there's almost always a cleaner alternative to `DataSet`. `DataSet` carries significant cognitive overhead (untyped rows, string-indexed columns, original/current value layers).

## References

- [SqlDataReader — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqldatareader)
- [DataSet — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/dataset-datatable-dataview/)
- [SqlDataAdapter — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqldataadapter)
- [See: adonet-overview.md](./adonet-overview.md)
- [See: sqlbulkcopy.md](./sqlbulkcopy.md)
