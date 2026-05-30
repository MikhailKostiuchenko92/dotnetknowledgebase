# Dapper Performance Tips

**Category:** Data Access / Dapper
**Difficulty:** 🔴 Senior
**Tags:** `dapper`, `performance`, `buffered`, `QueryUnbuffered`, `streaming`, `caching`, `CommandDefinition`

## Question

> What are the main performance optimization techniques in Dapper? What is the difference between buffered and unbuffered queries, how does query caching work, and how do you profile Dapper's overhead?

## Short Answer

Dapper's primary performance advantage is its IL-emitted object mapper, which caches compiled row-to-object converters per result shape. Key optimizations: (1) buffered queries (default) load the entire result set into a `List<T>` before returning — for large data sets, use `buffered: false` or `QueryUnbuffered<T>` (.NET 7+) to stream rows; (2) reuse `CommandDefinition` or parameterized SQL to leverage query plan caching in the database; (3) use `DynamicParameters` with explicit `DbType` and `size` to prevent plan cache pollution from differently-sized string parameters; (4) open the connection yourself and reuse it across multiple queries to avoid connection open/close overhead in tight loops.

## Detailed Explanation

### Dapper's Query Caching

Dapper caches its IL-emitted mapping delegate per `(ResultType, ColumnSet)` pair. The first time you execute `Query<Order>` with columns `{Id, Reference, Total}`, Dapper emits IL code that reads those specific columns and sets the matching properties. On subsequent calls with the same result shape, the cached delegate is reused — zero reflection overhead.

**Implication:** Column set changes (e.g., SELECT * from a table that gains a column) invalidate the cache automatically because the column fingerprint differs.

### Buffered vs Unbuffered

**Buffered (default):** Reads all rows into a `List<T>`, closes the reader, then returns. Safe to use after the connection closes.

```csharp
// Buffered — entire result set loaded into memory
IEnumerable<Order> orders = await conn.QueryAsync<Order>(sql, params);
// Reader is closed; all rows in memory
```

**Unbuffered:** Streams rows as you iterate. The connection and reader stay open until you've consumed all rows (or disposed the enumerator).

```csharp
// Dapper ≤ 2.0 buffered: false
IEnumerable<Order> orders = conn.Query<Order>(sql, params, buffered: false);
foreach (var order in orders)
    await ProcessAsync(order);  // ← processes one row at a time
// Connection held open during entire iteration

// Dapper 2.1+ (QueryUnbuffered — async streaming)
await foreach (var order in conn.QueryUnbufferedAsync<Order>(sql, params))
    await ProcessAsync(order, ct);
```

**When to use unbuffered:**
- Exporting millions of rows to a file/stream where you can't hold everything in memory.
- Streaming results to an HTTP response via `IAsyncEnumerable<T>`.
- Processing large audit batches where per-row processing is slow.

> **Warning:** Don't hold unbuffered queries open while performing other database operations on the same connection — the reader locks the connection. Use a dedicated connection for large streaming reads.

### CommandDefinition — Fine-Grained Control

`CommandDefinition` lets you specify command timeout, transaction, cancellation token, and flags per query:

```csharp
var cmd = new CommandDefinition(
    commandText: "SELECT * FROM Products WHERE CategoryId = @CategoryId",
    parameters: new { CategoryId = 5 },
    transaction: tx,
    commandTimeout: 30,
    commandType: CommandType.Text,
    flags: CommandFlags.Buffered,
    cancellationToken: ct);

var products = await conn.QueryAsync<Product>(cmd);
```

### Parameterized SQL and Plan Cache

SQL Server caches execution plans per unique query text + parameter types. Sending different string lengths produces different plan cache entries:

```csharp
// ❌ Plan cache pollution: each different @Name length gets a separate plan
await conn.QueryAsync("SELECT * FROM Products WHERE Name = @Name", new { Name = "Bolt" });
await conn.QueryAsync("SELECT * FROM Products WHERE Name = @Name", new { Name = "Bolt and Nut" });
// SQL Server sees NVARCHAR(4) and NVARCHAR(12) — two different plans

// ✅ Fix: specify explicit size
var p = new DynamicParameters();
p.Add("@Name", name, DbType.String, size: 200);  // always NVARCHAR(200) → one plan
```

### Connection Reuse in Loops

```csharp
// ❌ Opens/closes connection for every query — high overhead in tight loops
foreach (var id in ids)
{
    using var conn = new SqlConnection(connStr);
    await conn.QuerySingleAsync<Order>("...", new { Id = id });
}

// ✅ Open once, reuse
using var conn = new SqlConnection(connStr);
await conn.OpenAsync(ct);
foreach (var id in ids)
{
    var order = await conn.QuerySingleAsync<Order>("...", new { Id = id });
}
// Consider batching with WHERE Id IN (@Ids) instead of looping
```

### Batch Query (IN clause)

```csharp
// Fetch multiple rows in one round-trip instead of N queries
var ids = new[] { 1, 2, 3, 4, 5 };
var orders = await conn.QueryAsync<Order>(
    "SELECT * FROM Orders WHERE Id IN @Ids",
    new { Ids = ids });  // ← Dapper expands to IN (1,2,3,4,5) automatically
```

Dapper automatically expands `IEnumerable<T>` parameters to SQL `IN` lists.

## Code Example

```csharp
// Streaming large export to CSV
public async IAsyncEnumerable<OrderExportRow> StreamOrderExportAsync(
    DateOnly from, DateOnly to,
    [EnumeratorCancellation] CancellationToken ct = default)
{
    // Dedicated connection for streaming — don't share with other ops
    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);

    var cmd = new CommandDefinition(
        """
        SELECT o.Id, o.Reference, c.Name AS CustomerName, o.Total, o.CreatedAt
        FROM Orders o
        JOIN Customers c ON c.Id = o.CustomerId
        WHERE o.CreatedAt >= @From AND o.CreatedAt < @To
        ORDER BY o.CreatedAt
        """,
        new { From = from.ToDateTime(TimeOnly.MinValue), To = to.AddDays(1).ToDateTime(TimeOnly.MinValue) },
        commandTimeout: 300,
        cancellationToken: ct);

    // QueryUnbufferedAsync streams rows — no full result set in memory
    await foreach (var row in conn.QueryUnbufferedAsync<OrderExportRow>(cmd))
        yield return row;
}
```

## Common Follow-up Questions

- Does Dapper's query caching work across multiple `SqlConnection` instances, or is it per-connection?
- How do you measure Dapper's query overhead in isolation vs EF Core?
- Can Dapper's `IN` list expansion cause issues with SQL Server's maximum parameter count (2100)?
- What is the overhead of `DynamicParameters` vs an anonymous object?
- How does `CommandFlags.NoCache` work and when would you use it?

## Common Mistakes / Pitfalls

- **Holding an unbuffered query open while performing other DB operations**: The `IDataReader` locks the connection. Calling another Dapper method on the same open connection while an unbuffered reader is active throws or blocks.
- **Using anonymous objects with strings that vary in length**: Dapper infers `DbType.String` and sets the size to the actual string length. This pollutes SQL Server's plan cache with thousands of plans for the same query. Use `DynamicParameters` with explicit `size`.
- **Not cancelling long-running streaming queries**: `QueryUnbufferedAsync` respects `CancellationToken` only if you pass it via `CommandDefinition`. Passing the token to `await foreach` alone cancels the C# iteration but not the DB command.
- **`IN` list explosion**: `WHERE Id IN @Ids` with a list of 2,100+ items exceeds SQL Server's parameter limit and throws. Use a TVP, temp table, or `STRING_SPLIT` for large ID lists.
- **Assuming Dapper is always faster than EF Core without measuring**: EF Core with `AsNoTracking` + `Select` projection is within 20–30% of Dapper for most queries. Profile before switching to raw Dapper for "performance."

## References

- [Dapper buffered parameter — GitHub](https://github.com/DapperLib/Dapper#buffered-vs-unbuffered-readers)
- [CommandDefinition — Dapper GitHub](https://github.com/DapperLib/Dapper/blob/main/Dapper/CommandDefinition.cs)
- [See: ef-core-vs-dapper-performance.md](./ef-core-vs-dapper-performance.md)
- [See: dapper-overview.md](./dapper-overview.md)
