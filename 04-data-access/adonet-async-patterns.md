# Async Patterns in ADO.NET

**Category:** Data Access / ADO.NET
**Difficulty:** 🔴 Senior
**Tags:** `ADO.NET`, `async`, `OpenAsync`, `ExecuteReaderAsync`, `ReadAsync`, `CancellationToken`, `sync-over-async`

## Question

> What is the correct async pattern for ADO.NET operations? What are the async counterparts of the main ADO.NET methods, and what are the sync-over-async anti-patterns that cause thread pool starvation in ASP.NET Core?

## Short Answer

Every blocking ADO.NET operation has an async equivalent: `OpenAsync`, `ExecuteReaderAsync`, `ExecuteNonQueryAsync`, `ExecuteScalarAsync`, `ReadAsync`, `NextResultAsync`, and `GetFieldValueAsync<T>`. Use these exclusively in `async` code — calling the sync versions blocks a thread pool thread for the duration of the I/O wait, causing thread pool starvation under load. Pass `CancellationToken` to every async call to allow request cancellation to abort long-running queries. The most common mistake is calling `conn.Open()` or `reader.Read()` synchronously from an `async` method — visually simple but catastrophic under load.

## Detailed Explanation

### Full Async Method Map

| Sync (❌ in async code) | Async (✅) |
|------------------------|------------|
| `conn.Open()` | `await conn.OpenAsync(ct)` |
| `conn.Close()` | `await conn.CloseAsync()` |
| `conn.ChangeDatabase()` | `await conn.ChangeDatabaseAsync(ct)` |
| `cmd.ExecuteReader()` | `await cmd.ExecuteReaderAsync(ct)` |
| `cmd.ExecuteNonQuery()` | `await cmd.ExecuteNonQueryAsync(ct)` |
| `cmd.ExecuteScalar()` | `await cmd.ExecuteScalarAsync(ct)` |
| `reader.Read()` | `await reader.ReadAsync(ct)` |
| `reader.NextResult()` | `await reader.NextResultAsync(ct)` |
| `reader.GetValue(i)` | `await reader.GetFieldValueAsync<T>(i, ct)` |
| `tx.Commit()` | `await tx.CommitAsync(ct)` |
| `tx.Rollback()` | `await tx.RollbackAsync(ct)` |
| `SqlBulkCopy.WriteToServer()` | `await copy.WriteToServerAsync(ct)` |

### The Sync-Over-Async Anti-Pattern

```csharp
// ❌ Blocks a thread pool thread while waiting for SQL Server I/O
public async Task<Product?> GetProductAsync(int id, CancellationToken ct)
{
    await using var conn = new SqlConnection(_connStr);
    conn.Open();  // ← SYNC! Blocks thread for TCP handshake (~1–50ms)

    await using var cmd = conn.CreateCommand();
    cmd.CommandText = "SELECT * FROM Products WHERE Id = @Id";
    cmd.Parameters.AddWithValue("@Id", id);

    var reader = cmd.ExecuteReader();  // ← SYNC! Blocks thread while SQL Server executes
    if (reader.Read())                  // ← SYNC! Blocks thread reading next row
        return MapProduct(reader);

    return null;
}
```

In ASP.NET Core, every blocked thread pool thread reduces capacity to handle other requests. With 100 concurrent requests to this endpoint, 100 threads are blocked — leading to thread pool starvation, request queuing, and degraded latency across the entire application.

### The Correct Async Pattern

```csharp
// ✅ Fully async — no threads blocked during I/O
public async Task<Product?> GetProductAsync(int id, CancellationToken ct)
{
    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);  // ← async: releases thread during TCP handshake

    await using var cmd = conn.CreateCommand();
    cmd.CommandText = "SELECT * FROM Products WHERE Id = @Id";
    cmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = id });

    await using var reader = await cmd.ExecuteReaderAsync(ct);  // ← async query execution
    if (await reader.ReadAsync(ct))                               // ← async row fetch
        return MapProduct(reader);

    return null;
}
```

### CancellationToken — Stop Long Queries

When a client disconnects (e.g., user navigates away), ASP.NET Core cancels `HttpContext.RequestAborted`. Passing this token to ADO.NET methods cancels the SQL Server command:

```csharp
// HttpContext.RequestAborted propagates through the service layer
[HttpGet("{id}")]
public async Task<Product?> GetAsync(int id, CancellationToken ct)
//                                              ↑ injected by ASP.NET Core
    => await _service.GetProductAsync(id, ct);

// Service passes ct to ADO.NET
public async Task<Product?> GetProductAsync(int id, CancellationToken ct)
{
    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);  // ← cancels if request is cancelled before connection opens
    // ...
    await using var reader = await cmd.ExecuteReaderAsync(ct);  // ← cancels in-flight query
```

When `ct` is cancelled, ADO.NET sends `ATTENTION` to SQL Server to abort the running query, then throws `OperationCanceledException`.

### Async with Multiple Result Sets

```csharp
// Multiple result sets — all async
await using var reader = await cmd.ExecuteReaderAsync(ct);

// First result set
while (await reader.ReadAsync(ct))
    orders.Add(MapOrder(reader));

// Advance to second result set
await reader.NextResultAsync(ct);

while (await reader.ReadAsync(ct))
    lines.Add(MapOrderLine(reader));
```

### Async Column Reading — GetFieldValueAsync

For BLOB columns (`VARBINARY(MAX)`, `NVARCHAR(MAX)`) with `CommandBehavior.SequentialAccess`:

```csharp
await using var reader = await cmd.ExecuteReaderAsync(
    CommandBehavior.SequentialAccess, ct);

while (await reader.ReadAsync(ct))
{
    int id = await reader.GetFieldValueAsync<int>(0, ct);
    // Stream large binary column without loading it all into memory
    var stream = reader.GetStream(1);  // returns a Stream backed by the DB
    await ProcessBlobAsync(stream, ct);
}
```

## Code Example

```csharp
// Complete async ADO.NET repository method
public async Task<OrderDetailResult?> GetOrderDetailAsync(int id, CancellationToken ct)
{
    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);

    await using var cmd = conn.CreateCommand();
    cmd.CommandText = """
        SELECT o.Id, o.Reference, o.Total, o.Status,
               c.Name AS CustomerName, c.Email AS CustomerEmail
        FROM Orders o
        JOIN Customers c ON c.Id = o.CustomerId
        WHERE o.Id = @Id;

        SELECT l.Id, l.ProductId, l.Quantity, l.UnitPrice
        FROM OrderLines l
        WHERE l.OrderId = @Id
        ORDER BY l.Id;
        """;
    cmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = id });

    await using var reader = await cmd.ExecuteReaderAsync(ct);

    if (!await reader.ReadAsync(ct))
        return null;

    var order = new OrderDetailResult
    {
        Id = reader.GetInt32(0),
        Reference = reader.GetString(1),
        Total = reader.GetDecimal(2),
        Status = reader.GetString(3),
        CustomerName = reader.GetString(4),
        CustomerEmail = reader.GetString(5),
        Lines = []
    };

    await reader.NextResultAsync(ct);

    while (await reader.ReadAsync(ct))
    {
        order.Lines.Add(new OrderLineResult(
            reader.GetInt32(0),
            reader.GetInt32(1),
            reader.GetInt32(2),
            reader.GetDecimal(3)));
    }

    return order;
}
```

## Common Follow-up Questions

- What happens if you call `conn.Open()` on a connection that's already in an async state?
- How does `CancellationToken` cancellation interact with an in-progress `ExecuteReaderAsync` — is the running query on the server actually aborted?
- Why does `Task.Run(() => conn.Open())` NOT fix the sync-over-async problem?
- What is the difference between `reader.GetValue(i)` and `reader.GetFieldValueAsync<T>(i, ct)` for non-BLOB columns?
- How do you handle `OperationCanceledException` in ADO.NET to distinguish cancelled vs timeout?

## Common Mistakes / Pitfalls

- **Calling sync ADO.NET methods in `async` methods**: `conn.Open()` and `reader.Read()` in an `async` method looks correct (no compiler error) but blocks a thread pool thread. Under load, this causes ASP.NET Core thread pool starvation.
- **`Task.Run(() => conn.Open())`**: Offloading sync ADO.NET calls to `Task.Run` wastes a thread pool thread — it doesn't do async I/O, it blocks a different thread. Use `OpenAsync`.
- **Not passing `CancellationToken`**: Without passing `ct`, a cancelled request continues executing the SQL query on the server, wasting database resources and preventing connection pool reuse until the query completes.
- **Using `CommandBehavior.CloseConnection` without async disposal**: `CloseConnection` closes the connection when the reader is disposed. With `await using var reader`, disposal is async — don't mix sync `using` with async disposal here.
- **Assuming `ReadAsync` is always faster than `Read` for OLTP**: For small result sets (< 10 rows), the overhead of async state machines can be marginally slower. The benefit is scalability under concurrent load, not raw throughput for single queries.

## References

- [DbConnection.OpenAsync — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.data.common.dbconnection.openasync)
- [DbCommand.ExecuteReaderAsync — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.data.common.dbcommand.executereaderasync)
- [Asynchronous programming — ADO.NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/asynchronous-programming)
- [See: adonet-overview.md](./adonet-overview.md)
- [See: connection-pooling.md](./connection-pooling.md)
