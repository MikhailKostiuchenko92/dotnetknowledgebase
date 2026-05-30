# Dapper vs EF Core — Choosing the Right Tool

**Category:** Data Access / Dapper
**Difficulty:** 🟡 Middle
**Tags:** `dapper`, `ef-core`, `ORM`, `micro-ORM`, `CQRS`, `decision-framework`, `performance`

## Question

> When should you choose Dapper over EF Core, and vice versa? What are the specific technical reasons to prefer each tool, and is it reasonable to use both in the same project?

## Short Answer

EF Core excels at write operations with business logic: it provides entity tracking, migrations, relationships, concurrency tokens, and domain-model mapping. Dapper excels at read operations: it gives you full SQL control, has minimal overhead, handles complex queries EF Core LINQ can't easily express, and works natively with stored procedures and multiple result sets. Using both in the same project (CQRS-style: EF Core for commands, Dapper for queries) is a well-established pattern and is not over-engineering — they complement each other cleanly.

## Detailed Explanation

### Feature Comparison

| Feature | EF Core | Dapper |
|---------|---------|--------|
| Object-relational mapping | ✅ Full model | ✅ Result-to-POCO |
| LINQ queries | ✅ Full LINQ-to-SQL | ❌ Raw SQL only |
| Change tracking | ✅ Automatic | ❌ No |
| Migrations | ✅ Code-first migrations | ❌ No |
| Relationships / navigations | ✅ Full support | ❌ Manual JOIN + mapping |
| Concurrency tokens | ✅ rowversion / ConcurrencyCheck | ❌ Manual |
| Stored procedures | ⚠️ Limited | ✅ Native, with output params |
| Multiple result sets | ❌ No | ✅ QueryMultiple |
| Complex SQL (CTE, window fn) | ❌ LINQ limits | ✅ Any SQL |
| Read performance | ~~2–5× slower~~ tracked; near Dapper with AsNoTracking | Fast |
| Maintainability | ✅ Compile-time LINQ | ⚠️ String SQL, runtime errors |
| Learning curve | Higher | Low |
| Schema changes cascade | ✅ Migration recompile errors | ❌ Runtime failures |

### Decision Framework

**Choose EF Core when:**
- Performing CRUD operations where entities have business logic in setters/methods.
- You need migrations and model-driven schema management.
- Relationships, cascade deletes, and navigation properties are needed.
- Domain-Driven Design with aggregate roots and owned entities.
- Concurrency control is required (rowversion).
- Codebase mostly junior-to-mid: LINQ compile-time safety reduces bugs.

**Choose Dapper when:**
- Read-heavy queries with JOINs, aggregations, window functions.
- Stored procedure integration with output/return parameters.
- Multiple result sets from a single database round-trip.
- Maximum read throughput is needed (report generation, API endpoints).
- Working with an existing database schema you can't change (no migrations needed).
- Complex dynamic SQL (conditional WHERE clauses, sorting by user input).

**Use Both (CQRS Pattern):**

```
Command side → EF Core
  PlaceOrderCommand, UpdateCustomerCommand, DeleteProductCommand
  → Tracked entities, business rules, migrations, concurrency

Query side → Dapper
  GetOrderDetailQuery, GetDashboardQuery, GetProductListQuery
  → Raw SQL, JOINs, DTOs, no tracking overhead
```

### Team and Project Norms

| Context | Recommendation |
|---------|---------------|
| Small CRUD app | EF Core only — migrations alone justify it |
| High-traffic read-heavy API | EF Core + Dapper reads |
| Legacy stored procedure–heavy DB | Dapper only or Dapper primary |
| DDD aggregate model | EF Core for writes + Dapper for reads |
| Polyglot persistence (SQL + Redis) | EF Core for SQL writes; direct client for others |

### Code Organization with Both

```csharp
// Command handler — EF Core
public class PlaceOrderHandler(AppDb db) : ICommandHandler<PlaceOrderCommand>
{
    public async Task<OrderId> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var customer = await db.Customers.FindAsync([cmd.CustomerId], ct);
        var order = customer!.PlaceOrder(cmd.Items);  // domain logic
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);
        return new OrderId(order.Id);
    }
}

// Query handler — Dapper
public class GetOrderDetailHandler(IDbConnectionFactory factory)
    : IQueryHandler<GetOrderDetailQuery, OrderDetailDto?>
{
    public async Task<OrderDetailDto?> Handle(GetOrderDetailQuery query, CancellationToken ct)
    {
        using var conn = factory.CreateConnection();
        using var multi = await conn.QueryMultipleAsync(
            """
            SELECT o.Id, o.Reference, o.Total, c.Name AS CustomerName
            FROM Orders o JOIN Customers c ON c.Id = o.CustomerId
            WHERE o.Id = @Id;

            SELECT l.ProductId, p.Name AS ProductName, l.Quantity, l.UnitPrice
            FROM OrderLines l JOIN Products p ON p.Id = l.ProductId
            WHERE l.OrderId = @Id;
            """,
            new { query.Id });

        var header = await multi.ReadFirstOrDefaultAsync<OrderHeaderDto>();
        if (header is null) return null;

        var lines = (await multi.ReadAsync<OrderLineDto>()).ToList();
        return new OrderDetailDto(header, lines);
    }
}
```

## Code Example

```csharp
// DI registration — both in the same project
services.AddDbContext<AppDb>(opt => opt.UseSqlServer(connStr));
services.AddSingleton<IDbConnectionFactory>(
    _ => new SqlConnectionFactory(connStr));

public interface IDbConnectionFactory
{
    IDbConnection CreateConnection();
}

public sealed class SqlConnectionFactory(string connectionString) : IDbConnectionFactory
{
    public IDbConnection CreateConnection() => new SqlConnection(connectionString);
}
```

## Common Follow-up Questions

- When both EF Core and Dapper are used in the same request, how do you share a transaction?
- Should Dapper queries go through a repository, or is it acceptable to use it directly in query handlers?
- How do you handle schema changes that affect both Dapper string SQL and EF Core models?
- Is there a third option — using neither and going raw ADO.NET — and when would that apply?
- How do compile-time query validation tools (e.g., Costura or SQL analyzers) help with Dapper's string SQL fragility?

## Common Mistakes / Pitfalls

- **Using Dapper for all writes**: Dapper has no change tracking, no cascade logic, no concurrency protection. Write operations via Dapper bypass all domain rules written in entity methods. Reserve Dapper for reads.
- **Using EF Core for all reads**: EF Core with full tracking, materialization of entire entities, and navigation loading is unnecessary overhead for read-only API endpoints. Use projections or Dapper.
- **Duplicating connection string management**: Both tools need a connection string. Centralize in a single `IDbConnectionFactory` / `IConfiguration` — don't hardcode in two places.
- **Over-abstracting with IDbConnection in EF Core paths**: Injecting `IDbConnection` where you have a `DbContext` and mixing their use in the same method without transaction coordination leads to partial commits.
- **"Choosing EF Core because it's newer"**: Neither tool is objectively better — they solve different problems. The choice should be based on the use case, not recency.

## References

- [EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/)
- [Dapper — GitHub](https://github.com/DapperLib/Dapper)
- [See: ef-core-vs-dapper-performance.md](./ef-core-vs-dapper-performance.md)
- [See: dapper-ef-core-hybrid.md](./dapper-ef-core-hybrid.md)
