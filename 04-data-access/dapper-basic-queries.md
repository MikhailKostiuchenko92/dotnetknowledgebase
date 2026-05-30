# Dapper Basic Queries

**Category:** Data Access / Dapper
**Difficulty:** 🟢 Junior
**Tags:** `dapper`, `Query`, `Execute`, `DynamicParameters`, `QuerySingle`, `ExecuteScalar`

## Question

> How do you execute basic queries with Dapper? Demonstrate `Query<T>`, `Execute`, `QuerySingleOrDefault`, `ExecuteScalar`, and `DynamicParameters` with correct parameterization and async usage.

## Short Answer

Dapper extends `IDbConnection` with `Query<T>` (SELECT → list), `QuerySingleOrDefault<T>` (SELECT → one or null), `Execute` (INSERT/UPDATE/DELETE), and `ExecuteScalar<T>` (single scalar value). Parameters are passed as anonymous objects (`new { Id = 1 }`) — Dapper maps them to `@Name` placeholders in SQL and wraps them in `DbParameter` objects, preventing SQL injection. For stored procedures or mixed input/output parameters, use `DynamicParameters`. Always use the `Async` variants in `async` code; always dispose connections with `using`.

## Detailed Explanation

### Query<T> — SELECT → IEnumerable

```csharp
// Returns all matching rows as a buffered List<Product> (default: buffered)
IEnumerable<Product> products = await conn.QueryAsync<Product>(
    "SELECT Id, Name, Price, CategoryId FROM Products WHERE IsActive = @Active",
    new { Active = true });

// Mapping: column names matched to property names (case-insensitive)
public record Product(int Id, string Name, decimal Price, int CategoryId);
```

### QuerySingleOrDefault<T> — Exactly 0 or 1 Row

```csharp
// Returns null if no row found; throws InvalidOperationException if >1 row returned
var customer = await conn.QuerySingleOrDefaultAsync<Customer>(
    "SELECT Id, Name, Email FROM Customers WHERE Email = @Email",
    new { Email = email });

if (customer is null) throw new NotFoundException(email);
```

Variants:
- `QueryFirst<T>` — returns first row, throws if none
- `QueryFirstOrDefault<T>` — returns first row or null (doesn't throw on multiple rows)
- `QuerySingle<T>` — throws if zero OR more than one row

### Execute — INSERT, UPDATE, DELETE

```csharp
// Returns number of rows affected
int rowsAffected = await conn.ExecuteAsync(
    "UPDATE Products SET Price = @Price, UpdatedAt = @Now WHERE Id = @Id",
    new { Price = newPrice, Now = DateTimeOffset.UtcNow, Id = productId });

// INSERT
await conn.ExecuteAsync(
    "INSERT INTO AuditLogs (Action, EntityId, CreatedAt) VALUES (@Action, @EntityId, @Now)",
    new { Action = "Updated", EntityId = productId, Now = DateTimeOffset.UtcNow });

// INSERT multiple rows — pass an IEnumerable; Dapper executes once per item
var newProducts = new List<Product> { /* ... */ };
await conn.ExecuteAsync(
    "INSERT INTO Products (Name, Price) VALUES (@Name, @Price)",
    newProducts);  // ← Dapper loops; not a true bulk insert (use SqlBulkCopy for large volumes)
```

### ExecuteScalar<T> — Single Value

```csharp
int count = await conn.ExecuteScalarAsync<int>(
    "SELECT COUNT(*) FROM Orders WHERE Status = @Status",
    new { Status = "Pending" });

// Works for any scalar type
decimal maxPrice = await conn.ExecuteScalarAsync<decimal>(
    "SELECT MAX(Price) FROM Products WHERE CategoryId = @CategoryId",
    new { CategoryId = 3 });
```

### DynamicParameters — Output Parameters and Stored Procedures

```csharp
var parameters = new DynamicParameters();
parameters.Add("@Input", "hello");
parameters.Add("@Output", dbType: DbType.String, direction: ParameterDirection.Output, size: 100);
parameters.Add("@ReturnValue", dbType: DbType.Int32, direction: ParameterDirection.ReturnValue);

await conn.ExecuteAsync("dbo.MyStoredProcedure", parameters,
    commandType: CommandType.StoredProcedure);

string output = parameters.Get<string>("@Output");
int returnVal = parameters.Get<int>("@ReturnValue");
```

### Anonymous Objects vs DynamicParameters

```csharp
// Anonymous object — simplest, most common
await conn.QueryAsync<Order>(
    "SELECT * FROM Orders WHERE CustomerId = @CustomerId AND Status = @Status",
    new { CustomerId = 5, Status = "Pending" });

// DynamicParameters — needed when you want to add parameters conditionally
var p = new DynamicParameters();
p.Add("@CustomerId", customerId);
if (status is not null)
    p.Add("@Status", status);

string sql = status is not null
    ? "SELECT * FROM Orders WHERE CustomerId = @CustomerId AND Status = @Status"
    : "SELECT * FROM Orders WHERE CustomerId = @CustomerId";

var orders = await conn.QueryAsync<Order>(sql, p);
```

## Code Example

```csharp
public class ProductRepository(IDbConnectionFactory factory)
{
    // Query list
    public async Task<IReadOnlyList<ProductDto>> SearchAsync(
        string? nameFilter, decimal? maxPrice, CancellationToken ct = default)
    {
        var p = new DynamicParameters();
        var conditions = new List<string>();

        if (!string.IsNullOrWhiteSpace(nameFilter))
        {
            p.Add("@Name", $"%{nameFilter}%");
            conditions.Add("Name LIKE @Name");
        }
        if (maxPrice.HasValue)
        {
            p.Add("@MaxPrice", maxPrice.Value);
            conditions.Add("Price <= @MaxPrice");
        }

        var where = conditions.Count > 0 ? "WHERE " + string.Join(" AND ", conditions) : "";
        var sql = $"SELECT Id, Name, Price, CategoryId FROM Products {where} ORDER BY Name";

        using var conn = factory.CreateConnection();
        var results = await conn.QueryAsync<ProductDto>(sql, p);
        return results.ToList();
    }

    // Get one
    public async Task<ProductDto?> GetByIdAsync(int id, CancellationToken ct = default)
    {
        using var conn = factory.CreateConnection();
        return await conn.QuerySingleOrDefaultAsync<ProductDto>(
            "SELECT Id, Name, Price FROM Products WHERE Id = @Id",
            new { Id = id });
    }

    // Upsert via stored procedure with output param
    public async Task<int> UpsertAsync(UpsertProductRequest req, CancellationToken ct = default)
    {
        var p = new DynamicParameters();
        p.Add("@Name", req.Name);
        p.Add("@Price", req.Price);
        p.Add("@NewId", dbType: DbType.Int32, direction: ParameterDirection.Output);

        using var conn = factory.CreateConnection();
        await conn.ExecuteAsync("dbo.UpsertProduct", p,
            commandType: CommandType.StoredProcedure);

        return p.Get<int>("@NewId");
    }
}
```

## Common Follow-up Questions

- What happens if the SQL has a column that doesn't match any property of `T` in `Query<T>`?
- How does Dapper handle `NULL` database values — does it throw or map to the default?
- Can Dapper map query results to an `IAsyncEnumerable<T>`?
- What is the difference between `QueryAsync<T>` with `buffered: false` and `QueryUnbuffered<T>`?
- How does Dapper handle `DateTimeOffset` vs `DateTime` across different database providers?

## Common Mistakes / Pitfalls

- **SQL injection via string interpolation**: `$"WHERE Name = '{name}'"` bypasses Dapper's parameterization entirely. Always use `@ParameterName` in the SQL string and pass values via the parameter object.
- **Using `QuerySingle` when multiple rows are possible**: `QuerySingle<T>` throws `InvalidOperationException` if the query returns more than one row. Use `QueryFirst<T>` or `Query<T>` if multiple matches are expected.
- **Not disposing connections inside loops**: `using var conn = factory.CreateConnection()` inside a loop creates and disposes a connection per iteration. This is correct but expensive — pull the connection outside the loop if you're executing multiple queries.
- **Passing DateTime.UtcNow where DateTimeOffset is expected**: SQL Server's `datetimeoffset` type correctly stores `DateTimeOffset`. Using `DateTime.UtcNow` discards timezone info. Match the C# type to the SQL column type.
- **Expecting `Execute` to return data**: `Execute` returns only `int` (rows affected). To retrieve the inserted ID, use `QuerySingle<int>` with `INSERT … OUTPUT INSERTED.Id` or a stored procedure with an output parameter.

## References

- [Dapper — GitHub](https://github.com/DapperLib/Dapper)
- [DynamicParameters — Dapper GitHub](https://github.com/DapperLib/Dapper/blob/main/Dapper/DynamicParameters.cs)
- [See: dapper-overview.md](./dapper-overview.md)
- [See: dapper-multi-mapping.md](./dapper-multi-mapping.md)
