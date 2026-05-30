# Dapper Multi-Mapping

**Category:** Data Access / Dapper
**Difficulty:** 🟡 Middle
**Tags:** `dapper`, `multi-mapping`, `splitOn`, `QueryMultiple`, `JOIN`, `object-graph`, `one-to-many`

## Question

> How does Dapper handle queries that JOIN multiple tables and need to populate object graphs? What is `splitOn`, how do you map one-to-many relationships, and when should you use `QueryMultiple` vs a single JOIN query?

## Short Answer

Dapper's multi-mapping (`Query<T1, T2, TReturn>`) splits a single `IDataReader` row into multiple objects using a `splitOn` column name that marks where the second (and subsequent) object begins. This works well for one-to-one and one-to-a-few relationships. For one-to-many, multi-mapping produces duplicate parent rows (one per child) which you must deduplicate in C# with a `Dictionary`. `QueryMultiple` executes a batch of SQL statements and returns a `GridReader` from which you read each result set separately — better for one-to-many and dashboard-style queries where N result sets are needed.

## Detailed Explanation

### Multi-Mapping — One-to-One Join

```csharp
// Order joined with Customer — one Customer per Order
var orders = await conn.QueryAsync<Order, Customer, Order>(
    sql: """
        SELECT o.Id, o.Reference, o.Total, o.CustomerId,
               c.Id, c.Name, c.Email
        FROM Orders o
        JOIN Customers c ON c.Id = o.CustomerId
        WHERE o.Status = @Status
        """,
    map: (order, customer) =>
    {
        order.Customer = customer;  // wire navigation property
        return order;
    },
    param: new { Status = "Pending" },
    splitOn: "Id");  // ← second "Id" column in the result marks where Customer begins
// splitOn: "Id" splits on the SECOND occurrence of "Id" in the column list
```

**How `splitOn` works:**
- Dapper scans column names left to right.
- When it encounters the `splitOn` column for the second time, it starts mapping to the next type.
- Column names must be unambiguous — if both `Orders.Id` and `Customers.Id` are named `Id`, Dapper splits at the second `Id`.
- You can alias columns to avoid ambiguity: `c.Id AS CustomerId` and then `splitOn: "CustomerId"`.

### Multi-Mapping with Aliases (Safer)

```csharp
var orders = await conn.QueryAsync<Order, Customer, Order>(
    sql: """
        SELECT o.Id, o.Reference, o.Total,
               c.Id AS CustId, c.Name AS CustName, c.Email AS CustEmail
        FROM Orders o
        JOIN Customers c ON c.Id = o.CustomerId
        """,
    map: (order, customer) => { order.Customer = customer; return order; },
    splitOn: "CustId");  // unambiguous split point
```

Map `CustId`, `CustName`, `CustEmail` to `Customer.Id`, `Customer.Name`, `Customer.Email` — works if Dapper matches by name after stripping the prefix, but you may need a custom `TypeHandler` or matching property names.

### One-to-Many — Deduplicate with Dictionary

A JOIN for one-to-many produces duplicate parent rows:

```csharp
var orderDict = new Dictionary<int, Order>();

await conn.QueryAsync<Order, OrderLine, Order>(
    sql: """
        SELECT o.Id, o.Reference, o.Total,
               l.Id AS LineId, l.ProductId, l.Quantity, l.Price
        FROM Orders o
        LEFT JOIN OrderLines l ON l.OrderId = o.Id
        WHERE o.CustomerId = @CustomerId
        """,
    map: (order, line) =>
    {
        // Deduplicate: get or create the parent order
        if (!orderDict.TryGetValue(order.Id, out var existing))
        {
            existing = order;
            existing.Lines = [];
            orderDict[order.Id] = existing;
        }

        if (line is not null)
            existing.Lines.Add(line);

        return existing;
    },
    param: new { CustomerId = customerId },
    splitOn: "LineId");

var orders = orderDict.Values.ToList();
```

> **Caution:** For large data sets this produces N parent rows × M child rows in the result set (cartesian product). Use `QueryMultiple` or two separate queries for performance.

### QueryMultiple — Multiple Result Sets

```csharp
using var multi = await conn.QueryMultipleAsync(
    """
    SELECT * FROM Orders WHERE Id = @Id;
    SELECT * FROM OrderLines WHERE OrderId = @Id;
    SELECT * FROM OrderNotes WHERE OrderId = @Id;
    """,
    new { Id = orderId });

var order = await multi.ReadFirstOrDefaultAsync<Order>();
var lines = (await multi.ReadAsync<OrderLine>()).ToList();
var notes = (await multi.ReadAsync<OrderNote>()).ToList();

if (order is not null)
{
    order.Lines = lines;
    order.Notes = notes;
}
```

Advantages:
- 1 round-trip for 3 result sets.
- No cartesian product — each set has only its own rows.
- Clean separation of parent and children.

### When to Use Each

| Scenario | Recommendation |
|----------|---------------|
| Simple parent + single child (1:1) | Multi-mapping with `splitOn` |
| Parent + multiple children (1:N) | `QueryMultiple` or two separate queries |
| Dashboard: 3+ unrelated result sets | `QueryMultiple` |
| Deep nested graph (3 levels) | 3+ separate `Query<T>` calls, join in C# |

## Code Example

```csharp
// Order with lines — QueryMultiple (clean, performant)
public async Task<OrderDetailDto?> GetOrderDetailAsync(int orderId, CancellationToken ct = default)
{
    using var conn = new SqlConnection(_connStr);

    using var multi = await conn.QueryMultipleAsync(
        """
        SELECT o.Id, o.Reference, o.Total, o.Status, o.CreatedAt,
               c.Name AS CustomerName, c.Email AS CustomerEmail
        FROM Orders o
        JOIN Customers c ON c.Id = o.CustomerId
        WHERE o.Id = @Id;

        SELECT l.Id, l.ProductId, p.Name AS ProductName, l.Quantity, l.UnitPrice
        FROM OrderLines l
        JOIN Products p ON p.Id = l.ProductId
        WHERE l.OrderId = @Id
        ORDER BY l.Id;
        """,
        new { Id = orderId });

    var order = await multi.ReadFirstOrDefaultAsync<OrderHeaderDto>();
    if (order is null) return null;

    var lines = (await multi.ReadAsync<OrderLineDto>()).ToList();

    return new OrderDetailDto(order, lines);
}
```

## Common Follow-up Questions

- How does `splitOn` handle three or more joined tables?
- What happens if `splitOn` column contains `null` — does Dapper map a null object or skip?
- Can you use multi-mapping with `DynamicParameters`?
- How do you map a query with a column that doesn't match any property name?
- What is the performance difference between `QueryMultiple` and two separate `QueryAsync` calls?

## Common Mistakes / Pitfalls

- **Incorrect `splitOn` column name**: If the split column doesn't exist in the result set, Dapper throws `ArgumentException`. If it's the wrong column, mapping is offset — all properties shift incorrectly with no useful error message.
- **Not deduplicating for one-to-many**: Using `Query<Order, OrderLine, Order>` for a one-to-many JOIN without a `Dictionary` deduplication returns duplicate `Order` objects — one per `OrderLine` row.
- **Using multi-mapping for deeply nested graphs**: Three JOINs with collections produce a multiplicative cartesian product (O × L₁ × L₂ × L₃ rows). Switch to `QueryMultiple` or multiple queries for anything beyond one level of children.
- **Not disposing `GridReader` from `QueryMultiple`**: `GridReader` holds an open `DbDataReader`. Forgetting `using var multi = ...` leaks the reader and keeps the connection busy.
- **Reading `QueryMultiple` result sets out of order**: `GridReader.ReadAsync<T>` reads result sets sequentially — the order you call `.ReadAsync` must match the order of SELECT statements. Swapping calls returns data mapped to the wrong type.

## References

- [Dapper multi-mapping — GitHub wiki](https://github.com/DapperLib/Dapper#multi-mapping)
- [QueryMultiple — Dapper GitHub](https://github.com/DapperLib/Dapper#multi-results)
- [See: dapper-overview.md](./dapper-overview.md)
- [See: dapper-stored-procedures.md](./dapper-stored-procedures.md)
