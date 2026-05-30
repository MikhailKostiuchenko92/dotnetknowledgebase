# Dapper Stored Procedures

**Category:** Data Access / Dapper
**Difficulty:** 🟡 Middle
**Tags:** `dapper`, `stored-procedures`, `CommandType`, `DynamicParameters`, `output-params`, `RETURN-value`

## Question

> How do you call stored procedures with Dapper? How do you pass input parameters, retrieve output parameters and RETURN values, and handle stored procedures that return multiple result sets?

## Short Answer

Call a stored procedure with Dapper by passing `CommandType.StoredProcedure` to any `Query`, `Execute`, or `QueryMultiple` method. Input parameters are passed via anonymous objects or `DynamicParameters`. For output parameters and RETURN values, use `DynamicParameters` with `ParameterDirection.Output` or `ParameterDirection.ReturnValue`. For stored procedures that return multiple result sets, use `QueryMultiple` — the `GridReader` reads each result set in order.

## Detailed Explanation

### Basic Stored Procedure Call

```sql
-- Stored procedure
CREATE PROCEDURE dbo.GetOrdersByCustomer
    @CustomerId INT,
    @Status     NVARCHAR(50) = NULL
AS
SELECT * FROM Orders
WHERE CustomerId = @CustomerId
  AND (@Status IS NULL OR Status = @Status)
ORDER BY CreatedAt DESC;
```

```csharp
// Dapper call with anonymous object
var orders = await conn.QueryAsync<Order>(
    "dbo.GetOrdersByCustomer",
    new { CustomerId = customerId, Status = (string?)null },
    commandType: CommandType.StoredProcedure);
```

Anonymous objects work for pure input parameters. Property names must match SQL parameter names (without the `@`).

### Output Parameters with DynamicParameters

```sql
CREATE PROCEDURE dbo.CreateOrder
    @CustomerId INT,
    @Total      DECIMAL(18,2),
    @NewOrderId INT OUTPUT
AS
INSERT INTO Orders (CustomerId, Total, CreatedAt)
VALUES (@CustomerId, @Total, GETUTCDATE());

SET @NewOrderId = SCOPE_IDENTITY();
```

```csharp
var p = new DynamicParameters();
p.Add("@CustomerId", customerId);
p.Add("@Total", total);
p.Add("@NewOrderId",
    dbType: DbType.Int32,
    direction: ParameterDirection.Output);  // ← output parameter

await conn.ExecuteAsync(
    "dbo.CreateOrder", p,
    commandType: CommandType.StoredProcedure);

int newId = p.Get<int>("@NewOrderId");  // read after execution
Console.WriteLine($"Created order {newId}");
```

### RETURN Value

SQL `RETURN @value` returns an integer code. Read it with `ParameterDirection.ReturnValue`:

```sql
CREATE PROCEDURE dbo.ValidateOrder @OrderId INT
AS
IF NOT EXISTS (SELECT 1 FROM Orders WHERE Id = @OrderId)
    RETURN -1;  -- not found

IF EXISTS (SELECT 1 FROM Orders WHERE Id = @OrderId AND Status = 'Cancelled')
    RETURN -2;  -- already cancelled

RETURN 0;  -- success
```

```csharp
var p = new DynamicParameters();
p.Add("@OrderId", orderId);
p.Add("@Return",
    dbType: DbType.Int32,
    direction: ParameterDirection.ReturnValue);  // ← captures RETURN value

await conn.ExecuteAsync(
    "dbo.ValidateOrder", p,
    commandType: CommandType.StoredProcedure);

int returnCode = p.Get<int>("@Return");
switch (returnCode)
{
    case -1: throw new NotFoundException($"Order {orderId} not found");
    case -2: throw new InvalidOperationException("Order already cancelled");
    case 0: break;  // success
    default: throw new InvalidOperationException($"Unexpected return code {returnCode}");
}
```

### Stored Procedure Returning Multiple Result Sets

```sql
CREATE PROCEDURE dbo.GetOrderDetail @OrderId INT
AS
-- Result set 1: order header
SELECT o.Id, o.Reference, o.Total, c.Name AS CustomerName
FROM Orders o JOIN Customers c ON c.Id = o.CustomerId
WHERE o.Id = @OrderId;

-- Result set 2: order lines
SELECT l.Id, l.ProductId, p.Name AS ProductName, l.Quantity, l.UnitPrice
FROM OrderLines l JOIN Products p ON p.Id = l.ProductId
WHERE l.OrderId = @OrderId;
```

```csharp
using var multi = await conn.QueryMultipleAsync(
    "dbo.GetOrderDetail",
    new { OrderId = orderId },
    commandType: CommandType.StoredProcedure);

var header = await multi.ReadFirstOrDefaultAsync<OrderHeaderDto>();
var lines = (await multi.ReadAsync<OrderLineDto>()).ToList();
```

### Mixed Input + Output + Return

```csharp
public async Task<UpsertResult> UpsertProductAsync(
    string sku, string name, decimal price, CancellationToken ct = default)
{
    var p = new DynamicParameters();
    p.Add("@Sku", sku, DbType.String, size: 50);
    p.Add("@Name", name, DbType.String, size: 200);
    p.Add("@Price", price, DbType.Decimal);
    p.Add("@ProductId", dbType: DbType.Int32, direction: ParameterDirection.Output);
    p.Add("@WasInserted", dbType: DbType.Boolean, direction: ParameterDirection.Output);
    p.Add("@Return", dbType: DbType.Int32, direction: ParameterDirection.ReturnValue);

    using var conn = new SqlConnection(_connStr);
    await conn.ExecuteAsync("dbo.UpsertProduct", p,
        commandType: CommandType.StoredProcedure);

    if (p.Get<int>("@Return") != 0)
        throw new DataException("UpsertProduct returned a non-zero code");

    return new UpsertResult(
        ProductId: p.Get<int>("@ProductId"),
        WasInserted: p.Get<bool>("@WasInserted"));
}
```

## Code Example

```csharp
// Generic helper for stored procedures returning a result set
public async Task<IReadOnlyList<T>> ExecSpListAsync<T>(
    string procedure,
    object? parameters = null,
    CancellationToken ct = default)
{
    using var conn = new SqlConnection(_connStr);
    var results = await conn.QueryAsync<T>(
        procedure,
        parameters,
        commandType: CommandType.StoredProcedure);
    return results.ToList();
}

// Generic helper for exec-only stored procedures
public async Task<int> ExecSpAsync(
    string procedure,
    DynamicParameters parameters,
    CancellationToken ct = default)
{
    using var conn = new SqlConnection(_connStr);
    return await conn.ExecuteAsync(procedure, parameters,
        commandType: CommandType.StoredProcedure);
}

// Usage
var orders = await ExecSpListAsync<Order>("dbo.GetOrdersByStatus", new { Status = "Pending" });
```

## Common Follow-up Questions

- How do you call a stored procedure that uses a table-valued parameter (TVP) from Dapper?
- Does Dapper support stored procedures that raise `RAISERROR`? How are exceptions surfaced in .NET?
- How do you call a stored procedure within a Dapper + EF Core shared transaction?
- Can you use `Query<T>` (not `Execute`) to call a procedure that also does DML?
- How do you handle stored procedures with optional parameters that have defaults in SQL?

## Common Mistakes / Pitfalls

- **Forgetting `CommandType.StoredProcedure`**: Without it, Dapper treats the string as a plain SQL statement and sends `EXEC dbo.MyProc` as raw SQL instead of using the efficient stored procedure path. Worse, if the SP name contains special characters, it fails with a parse error.
- **Using anonymous objects for output parameters**: Anonymous objects can only hold input values. For output/ReturnValue parameters you **must** use `DynamicParameters`.
- **Reading output parameters before execution completes**: You cannot read `p.Get<int>("@NewId")` before `await conn.ExecuteAsync(...)` returns. Output values are populated by ADO.NET after the command finishes.
- **Not specifying `size` for string parameters**: `p.Add("@Name", name)` infers the size from the value's length. If SQL Server's parameter is `NVARCHAR(MAX)` but Dapper sends `NVARCHAR(5)`, SQL Server may use a different execution plan (plan cache pollution). Specify `size: -1` for `MAX` or the exact column size.
- **Ignoring RETURN value and trusting only exceptions**: Stored procedures often use RETURN codes for business logic (not database errors). If you don't capture the RETURN value, you miss silent business failures that don't throw `SqlException`.

## References

- [DynamicParameters — Dapper GitHub](https://github.com/DapperLib/Dapper#stored-procedures)
- [Table-valued parameters with Dapper — Stack Overflow](https://stackoverflow.com/questions/6232978/does-dapper-support-sql-2008-table-valued-parameters)
- [See: dapper-overview.md](./dapper-overview.md)
- [See: dapper-multi-mapping.md](./dapper-multi-mapping.md)
