# ADO.NET Overview

**Category:** Data Access / ADO.NET
**Difficulty:** 🟢 Junior
**Tags:** `ADO.NET`, `SqlConnection`, `SqlCommand`, `SqlDataReader`, `async`, `IDisposable`, `connection-lifecycle`

## Question

> What is ADO.NET? Describe the core objects — `SqlConnection`, `SqlCommand`, `SqlDataReader` — their lifecycle, and the correct pattern for async usage and resource disposal.

## Short Answer

ADO.NET is the foundational .NET data access layer that sits directly above database drivers. Its three core objects are: `SqlConnection` (manages the physical TCP connection to SQL Server), `SqlCommand` (represents a SQL statement or stored procedure), and `SqlDataReader` (forward-only, read-only stream of query results). Use `await using` for both `SqlConnection` and `SqlDataReader`, call `OpenAsync` before executing commands, and use `ExecuteReaderAsync`, `ReadAsync`, and `GetFieldValueAsync<T>` for fully async data access with cancellation support.

## Detailed Explanation

### The Three Core Objects

| Object | Role | Disposable |
|--------|------|-----------|
| `SqlConnection` | Opens and manages a connection to SQL Server | ✅ Yes |
| `SqlCommand` | Holds SQL text, parameters, and execution settings | ✅ Yes |
| `SqlDataReader` | Forward-only, read-only cursor over a result set | ✅ Yes |

### Connection Lifecycle

```csharp
// Connection string elements
// Server=.;Database=MyDb;Integrated Security=True;Encrypt=False — local dev
// Server=tcp:myserver.database.windows.net;Database=MyDb;Authentication=Active Directory Default — Azure

await using var conn = new SqlConnection(connectionString);
await conn.OpenAsync(ct);  // ← borrows a connection from the ADO.NET pool
// ... use connection ...
// conn.Dispose() / await conn.DisposeAsync() → returns to pool (not physically closed)
```

The connection is **not physically closed** on dispose — ADO.NET connection pooling returns it to a pool keyed by the connection string. The next caller gets the same physical TCP connection.

### SqlCommand

```csharp
await using var cmd = conn.CreateCommand();
// or: new SqlCommand("SELECT ...", conn)

cmd.CommandText = "SELECT Id, Name FROM Products WHERE CategoryId = @CategoryId";
cmd.CommandType = CommandType.Text;  // or StoredProcedure
cmd.CommandTimeout = 30;  // seconds; 0 = no timeout

// Parameters — always parameterize, never concatenate
cmd.Parameters.AddWithValue("@CategoryId", categoryId);
// Preferred: explicit type + size to avoid plan cache pollution
cmd.Parameters.Add(new SqlParameter("@CategoryId", SqlDbType.Int) { Value = categoryId });
```

### SqlDataReader

```csharp
await using var reader = await cmd.ExecuteReaderAsync(
    CommandBehavior.CloseConnection,  // closes connection when reader is disposed
    ct);

while (await reader.ReadAsync(ct))
{
    var id = reader.GetInt32(0);            // by ordinal (fastest)
    var name = reader.GetString(1);         // by ordinal
    // or:
    var id2 = reader.GetInt32(reader.GetOrdinal("Id"));  // by name
    // or:
    var id3 = await reader.GetFieldValueAsync<int>("Id", ct);  // async, non-blocking
}
```

**Null handling:**

```csharp
// Column may be NULL
string? email = reader.IsDBNull(2) ? null : reader.GetString(2);
// Or:
string? email2 = await reader.IsDBNullAsync(2, ct)
    ? null
    : reader.GetString(2);
```

### CommandBehavior Flags

| Flag | Effect |
|------|--------|
| `CloseConnection` | Closes the connection when the reader is disposed |
| `SingleRow` | Hint: optimize for single-row result |
| `SequentialAccess` | Enables column-by-column streaming (required for BLOB streaming) |
| `KeyInfo` | Includes column metadata (primary key info) |

### Full CRUD Example

```csharp
// INSERT returning the generated ID
public async Task<int> InsertProductAsync(string name, decimal price, CancellationToken ct)
{
    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);

    await using var cmd = conn.CreateCommand();
    cmd.CommandText = """
        INSERT INTO Products (Name, Price, CreatedAt)
        OUTPUT INSERTED.Id
        VALUES (@Name, @Price, GETUTCDATE())
        """;
    cmd.Parameters.Add(new SqlParameter("@Name", SqlDbType.NVarChar, 200) { Value = name });
    cmd.Parameters.Add(new SqlParameter("@Price", SqlDbType.Decimal) { Value = price, Precision = 18, Scale = 2 });

    var result = await cmd.ExecuteScalarAsync(ct);
    return Convert.ToInt32(result);
}
```

## Code Example

```csharp
// Complete async read with proper resource management
public async Task<IReadOnlyList<ProductDto>> GetActiveByCategoryAsync(
    int categoryId, CancellationToken ct = default)
{
    var results = new List<ProductDto>();

    await using var conn = new SqlConnection(_connStr);
    await conn.OpenAsync(ct);

    await using var cmd = conn.CreateCommand();
    cmd.CommandText = """
        SELECT Id, Name, Price
        FROM Products
        WHERE CategoryId = @CategoryId AND IsActive = 1
        ORDER BY Name
        """;
    cmd.Parameters.Add(new SqlParameter("@CategoryId", SqlDbType.Int) { Value = categoryId });

    await using var reader = await cmd.ExecuteReaderAsync(ct);

    // Cache ordinals before the loop for performance
    int idOrd = reader.GetOrdinal("Id");
    int nameOrd = reader.GetOrdinal("Name");
    int priceOrd = reader.GetOrdinal("Price");

    while (await reader.ReadAsync(ct))
    {
        results.Add(new ProductDto(
            Id: reader.GetInt32(idOrd),
            Name: reader.GetString(nameOrd),
            Price: reader.GetDecimal(priceOrd)));
    }

    return results;
}
```

## Common Follow-up Questions

- What is the difference between `ExecuteReaderAsync`, `ExecuteNonQueryAsync`, and `ExecuteScalarAsync`?
- How does `CommandBehavior.CloseConnection` affect resource management?
- What happens if you call `conn.Open()` synchronously inside an `async` method?
- How do connection pool settings affect `SqlConnection.OpenAsync` latency?
- How do you read a `VARBINARY(MAX)` / `NVARCHAR(MAX)` column efficiently using `SequentialAccess`?

## Common Mistakes / Pitfalls

- **Using `AddWithValue` for string parameters without size**: `cmd.Parameters.AddWithValue("@Name", "Widget")` infers `NVARCHAR(6)`. SQL Server creates a different execution plan for every unique string length — polluting the plan cache. Use `new SqlParameter("@Name", SqlDbType.NVarChar, 200)`.
- **Not disposing `SqlDataReader`**: An undisposed reader holds the connection busy (it's in an "executing" state). Other commands on the same connection will fail or block. Always `await using var reader = ...`.
- **Calling `conn.Open()` (sync) in async code**: Sync `Open()` blocks a thread pool thread for the duration of the TCP handshake. Use `await conn.OpenAsync(ct)`.
- **Reading columns out of order with `SequentialAccess`**: Sequential access mode requires reading columns strictly left to right. Attempting to read column 2 after column 3 throws `InvalidOperationException`.
- **Catching `SqlException` without checking the `Number`**: `SqlException` covers a wide range: deadlocks (1205), timeouts (-2), constraint violations (2627), etc. Log `ex.Number` and handle each class appropriately.

## References

- [SqlConnection — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlconnection)
- [SqlDataReader — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqldatareader)
- [ADO.NET overview — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/ado-net-overview)
- [See: parameterized-queries.md](./parameterized-queries.md)
- [See: connection-pooling.md](./connection-pooling.md)
