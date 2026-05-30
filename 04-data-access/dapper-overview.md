# Dapper Overview

**Category:** Data Access / Dapper
**Difficulty:** 🟢 Junior
**Tags:** `dapper`, `micro-ORM`, `IDbConnection`, `SqlMapper`, `ADO.NET`, `mapping`

## Question

> What is Dapper? How does it extend `IDbConnection`, what are its core capabilities, and why would you choose it over EF Core for certain scenarios?

## Short Answer

Dapper is a micro-ORM NuGet package (`Dapper`) by Stack Overflow that extends `IDbConnection` with helper methods (`Query<T>`, `Execute`, `QuerySingle`, etc.) that execute raw SQL and automatically map result columns to .NET objects. It has no change tracker, no model metadata, no migration support — just SQL execution and fast object mapping. Choose Dapper when you need full SQL control, are working with complex queries that are difficult to express in LINQ, or need maximum read throughput with minimal overhead.

## Detailed Explanation

### What Dapper Provides

Dapper adds extension methods to `IDbConnection`:

| Method | Use |
|--------|-----|
| `Query<T>` | Execute SELECT, returns `IEnumerable<T>` |
| `QueryAsync<T>` | Async version |
| `QueryFirst<T>` / `QuerySingle<T>` | Return first or exactly one result |
| `QueryFirstOrDefault<T>` | Return first or null |
| `Execute` | INSERT / UPDATE / DELETE / stored proc |
| `ExecuteAsync` | Async DML |
| `QueryMultiple` | Multiple result sets from one call |
| `ExecuteScalar<T>` | Return a single scalar value |

### How Mapping Works

Dapper uses `Reflection.Emit` to generate IL code at runtime that maps `IDataReader` column values to object properties by **name matching** (case-insensitive). The generated code is cached after the first use:

```csharp
// Property "FirstName" maps to column "FirstName" (or "firstname", "FIRSTNAME")
// If names don't match, the property remains at its default value
public record Customer(int Id, string FirstName, string LastName, string Email);
```

### Dapper vs EF Core — At a Glance

| Feature | EF Core | Dapper |
|---------|---------|--------|
| Change tracking | ✅ Yes | ❌ No |
| Migrations | ✅ Yes | ❌ No |
| LINQ queries | ✅ Yes | ❌ Raw SQL only |
| Read performance | ~~2–5× slower~~ (tracked); near Dapper with AsNoTracking | Fast (no tracking overhead) |
| Complex queries | Limited (LINQ only) | Unlimited (raw SQL) |
| Multiple result sets | ❌ No | ✅ QueryMultiple |
| Stored procedures | Limited | ✅ Native support |
| Schema awareness | ✅ Full model | ❌ None |
| Learning curve | Higher | Low |

### Setup

```xml
<PackageReference Include="Dapper" Version="2.*" />
```

No `DbContext`, no `OnModelCreating`, no migration — just open a connection and go:

```csharp
// Works with SqlConnection (SQL Server), NpgsqlConnection (PostgreSQL), etc.
public class ProductRepository(IDbConnectionFactory connectionFactory)
{
    public async Task<IEnumerable<Product>> GetByCategoryAsync(int categoryId, CancellationToken ct)
    {
        using var conn = connectionFactory.CreateConnection();
        return await conn.QueryAsync<Product>(
            "SELECT Id, Name, Price FROM Products WHERE CategoryId = @CategoryId",
            new { CategoryId = categoryId });
    }
}
```

### Parameterization

Dapper parameterizes automatically via anonymous objects or `DynamicParameters`:

```csharp
// Anonymous object — each property becomes a SQL parameter
var products = await conn.QueryAsync<Product>(
    "SELECT * FROM Products WHERE Price BETWEEN @Min AND @Max AND IsActive = @Active",
    new { Min = 10m, Max = 100m, Active = true });

// The SQL sent to the database: WHERE Price BETWEEN @Min AND @Max AND IsActive = @Active
// Parameters are injected as SqlParameter objects — immune to SQL injection
```

> **Warning:** Never use string concatenation for SQL in Dapper. `$"WHERE Name = '{name}'"` is SQL injection. Always use parameters.

### Connection Management

Dapper doesn't manage connections — you must open and close them:

```csharp
// Option A: Dapper opens/closes if you pass a closed connection
using var conn = new SqlConnection(connStr);
// Do NOT call conn.Open() — Dapper opens it automatically and closes after query

// Option B: Explicitly manage open connection (e.g., to reuse across queries)
using var conn = new SqlConnection(connStr);
await conn.OpenAsync(ct);
// Multiple Dapper calls share the open connection
var count = await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM Orders");
var orders = await conn.QueryAsync<Order>("SELECT TOP 10 * FROM Orders ORDER BY CreatedAt DESC");
```

## Code Example

```csharp
// Repository using Dapper for read-heavy operations
public class OrderReadRepository(string connectionString)
{
    // Simple query
    public async Task<OrderDto?> GetByIdAsync(int id, CancellationToken ct = default)
    {
        using var conn = new SqlConnection(connectionString);
        return await conn.QuerySingleOrDefaultAsync<OrderDto>(
            "SELECT o.Id, o.Reference, c.Name AS CustomerName, o.Total, o.Status " +
            "FROM Orders o JOIN Customers c ON c.Id = o.CustomerId " +
            "WHERE o.Id = @Id",
            new { Id = id });
    }

    // Parameterized list query
    public async Task<IReadOnlyList<OrderSummary>> GetRecentAsync(
        int days, CancellationToken ct = default)
    {
        var since = DateTimeOffset.UtcNow.AddDays(-days);
        using var conn = new SqlConnection(connectionString);
        var results = await conn.QueryAsync<OrderSummary>(
            "SELECT Id, Reference, Total, CreatedAt FROM Orders WHERE CreatedAt >= @Since ORDER BY CreatedAt DESC",
            new { Since = since });
        return results.ToList();
    }

    // Scalar
    public async Task<int> CountPendingAsync(CancellationToken ct = default)
    {
        using var conn = new SqlConnection(connectionString);
        return await conn.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM Orders WHERE Status = 'Pending'");
    }
}
```

## Common Follow-up Questions

- Does Dapper support automatic camelCase to snake_case column mapping?
- How do you map a query result with multiple JOINs to a nested object graph in Dapper?
- What is `DynamicParameters` and when do you need it over an anonymous object?
- Can Dapper execute stored procedures — how do you handle output parameters?
- How does Dapper's buffered vs unbuffered mode affect memory usage?

## Common Mistakes / Pitfalls

- **Using string concatenation for SQL parameters**: `$"WHERE Name = '{name}'"` is SQL injection. Always use `@ParameterName` in SQL and pass values via anonymous objects or `DynamicParameters`.
- **Forgetting to dispose connections**: Dapper doesn't manage connection lifecycle. A missing `using` statement leaves connections open, exhausting the connection pool under load.
- **Column name mismatch silently returning defaults**: If a DTO property is named `FullName` but the column is `Name`, Dapper silently maps `null` or `0` — no exception. Always verify mapping with a small integration test.
- **Using `Query<T>` when you expect exactly one row**: `Query<T>` returns an `IEnumerable<T>` — if zero rows match, you get an empty collection (not an exception). Use `QuerySingle<T>` for required single rows or `QuerySingleOrDefault<T>` for optional ones.
- **Buffering large result sets into memory**: By default Dapper buffers the entire result set. For very large queries, use `QueryUnbuffered<T>` (.NET 7+) or `buffered: false` to stream rows.

## References

- [Dapper — GitHub](https://github.com/DapperLib/Dapper)
- [Dapper documentation — GitHub wiki](https://github.com/DapperLib/Dapper/blob/main/Readme.md)
- [See: dapper-vs-ef-core.md](./dapper-vs-ef-core.md)
- [See: dapper-basic-queries.md](./dapper-basic-queries.md)
