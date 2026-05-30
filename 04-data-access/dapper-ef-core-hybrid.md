# Dapper + EF Core Hybrid Pattern

**Category:** Data Access / Dapper
**Difficulty:** 🔴 Senior
**Tags:** `dapper`, `ef-core`, `hybrid`, `CQRS`, `shared-connection`, `shared-transaction`, `IDbConnectionFactory`

## Question

> How do you implement a hybrid data access layer that uses EF Core for writes and Dapper for reads? How do you share a connection and transaction between the two, and what patterns avoid DI or configuration duplication?

## Short Answer

The hybrid pattern uses EF Core for command-side operations (tracked entities, business logic, migrations) and Dapper for query-side operations (raw SQL, DTOs, complex JOINs). Each side uses its own connection from the pool — no sharing required for independent operations. When a single operation must span both (e.g., write with EF Core and update a read-model with Dapper in the same transaction), obtain the `DbConnection` and `DbTransaction` from EF Core and pass them to Dapper. Centralize connection string management with a shared `IDbConnectionFactory` that Dapper repositories resolve independently of the `DbContext`.

## Detailed Explanation

### Architecture Overview

```
┌─────────────────────────────┐
│         Application         │
├───────────────┬─────────────┤
│  Commands     │  Queries    │
│  (writes)     │  (reads)    │
├───────────────┼─────────────┤
│  EF Core      │  Dapper     │
│  DbContext    │  + Conn     │
└───────────────┴─────────────┘
          ↓           ↓
    SQL Server  (same DB, different connections from pool)
```

For most operations, EF Core and Dapper use separate connections from the ADO.NET connection pool — no sharing needed. Each connection is returned to the pool after use.

### Sharing a Connection Factory

```csharp
// Single source of truth for the connection string
public interface IDbConnectionFactory
{
    IDbConnection CreateConnection();
    Task<IDbConnection> CreateOpenConnectionAsync(CancellationToken ct = default);
}

public sealed class SqlConnectionFactory(IConfiguration config) : IDbConnectionFactory
{
    private readonly string _connStr =
        config.GetConnectionString("Default")
        ?? throw new InvalidOperationException("Missing 'Default' connection string");

    public IDbConnection CreateConnection() => new SqlConnection(_connStr);

    public async Task<IDbConnection> CreateOpenConnectionAsync(CancellationToken ct = default)
    {
        var conn = new SqlConnection(_connStr);
        await conn.OpenAsync(ct);
        return conn;
    }
}

// Registration
services.AddSingleton<IDbConnectionFactory, SqlConnectionFactory>();
services.AddDbContext<AppDb>(opt => opt.UseSqlServer(
    builder.Configuration.GetConnectionString("Default")));
```

Both use the same connection string from configuration — single point of change.

### Independent Usage (Typical CQRS)

```csharp
// Command handler — EF Core
public class CreateProductHandler(AppDb db)
{
    public async Task<int> Handle(CreateProductCommand cmd, CancellationToken ct)
    {
        var product = new Product { Name = cmd.Name, Price = cmd.Price };
        db.Products.Add(product);
        await db.SaveChangesAsync(ct);
        return product.Id;
    }
}

// Query handler — Dapper
public class GetProductListHandler(IDbConnectionFactory factory)
{
    public async Task<IReadOnlyList<ProductDto>> Handle(
        GetProductListQuery query, CancellationToken ct)
    {
        using var conn = factory.CreateConnection();
        var results = await conn.QueryAsync<ProductDto>(
            "SELECT Id, Name, Price, CategoryName FROM ProductView WHERE IsActive = 1",
            param: null);
        return results.ToList();
    }
}
```

### Shared Connection When Transactional

When a single use case requires both in the same transaction:

```csharp
// Place an order AND update a denormalized read-model atomically
public async Task PlaceOrderAsync(PlaceOrderCommand cmd, CancellationToken ct)
{
    var strategy = db.Database.CreateExecutionStrategy();

    await strategy.ExecuteAsync(async () =>
    {
        var conn = db.Database.GetDbConnection();
        if (conn.State == ConnectionState.Closed)
            await conn.OpenAsync(ct);

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        // EF Core write
        var order = new Order { CustomerId = cmd.CustomerId };
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);

        // Dapper update (same connection + transaction)
        await conn.ExecuteAsync(
            "UPDATE CustomerOrderStats SET TotalOrders = TotalOrders + 1 WHERE CustomerId = @Id",
            new { Id = cmd.CustomerId },
            transaction: tx.GetDbTransaction());

        await tx.CommitAsync(ct);
    });
}
```

### Read-Model Projection via Dapper

EF Core handles the write model; Dapper handles a dedicated read-model (could be a view or a denormalized table):

```csharp
// EF Core: write to normalized tables
// Dapper: read from denormalized view (or table)

public class OrderReadRepository(IDbConnectionFactory factory)
{
    public async Task<IReadOnlyList<OrderListItemDto>> GetByStatusAsync(
        string status, CancellationToken ct = default)
    {
        using var conn = factory.CreateConnection();
        return (await conn.QueryAsync<OrderListItemDto>(
            """
            SELECT o.Id, o.Reference, c.Name AS CustomerName,
                   o.Total, o.Status, o.CreatedAt,
                   COUNT(l.Id) AS LineCount
            FROM Orders o
            JOIN Customers c ON c.Id = o.CustomerId
            LEFT JOIN OrderLines l ON l.OrderId = o.Id
            WHERE o.Status = @Status
            GROUP BY o.Id, o.Reference, c.Name, o.Total, o.Status, o.CreatedAt
            ORDER BY o.CreatedAt DESC
            """,
            new { Status = status })).ToList();
    }
}
```

## Code Example

```csharp
// Full project layout
// /Commands → ICommandHandler<TCmd> → AppDb (EF Core)
// /Queries  → IQueryHandler<TQuery, TResult> → IDbConnectionFactory (Dapper)
// /Shared   → IDbConnectionFactory

// Program.cs registrations
builder.Services.AddSingleton<IDbConnectionFactory, SqlConnectionFactory>();
builder.Services.AddDbContext<AppDb>(opt =>
    opt.UseSqlServer(builder.Configuration.GetConnectionString("Default")));

// Mediatr / manual registration of handlers
builder.Services.AddScoped<CreateProductHandler>();
builder.Services.AddScoped<GetProductListHandler>();
builder.Services.AddScoped<PlaceOrderHandler>();

// Query handler with Dapper
public class GetDashboardHandler(IDbConnectionFactory factory)
    : IQueryHandler<GetDashboardQuery, DashboardDto>
{
    public async Task<DashboardDto> Handle(GetDashboardQuery q, CancellationToken ct)
    {
        using var conn = await factory.CreateOpenConnectionAsync(ct);
        using var multi = await conn.QueryMultipleAsync(
            """
            SELECT COUNT(*) AS Total, SUM(Total) AS Revenue FROM Orders WHERE CreatedAt >= @From;
            SELECT TOP 5 c.Name, SUM(o.Total) AS Revenue FROM Orders o
            JOIN Customers c ON c.Id = o.CustomerId
            WHERE o.CreatedAt >= @From GROUP BY c.Name ORDER BY Revenue DESC;
            """,
            new { From = q.From });

        var summary = await multi.ReadFirstAsync<SummaryDto>();
        var topCustomers = (await multi.ReadAsync<TopCustomerDto>()).ToList();

        return new DashboardDto(summary, topCustomers);
    }
}
```

## Common Follow-up Questions

- How do you prevent the connection string from being duplicated in EF Core options and the connection factory?
- How does this pattern interact with EF Core's `AddDbContextPool` — can the connection factory reuse pooled connections?
- Should Dapper read repositories live in the same assembly as EF Core write repositories, or be separated?
- How do you run integration tests for a hybrid Dapper + EF Core system — do you need two separate test fixtures?
- Can Dapper and EF Core use different databases within the same command handler?

## Common Mistakes / Pitfalls

- **Duplicating connection strings**: Having `"Default"` connection string used in two different places with different config keys means a DBA change only fixes one half. Centralize in `IDbConnectionFactory`.
- **Using Dapper for writes in a bounded context that has domain rules**: Once you start writing to `Orders` table directly via Dapper SQL in a handler, you bypass all domain logic encoded in `Order` entity methods. Keep writes in EF Core.
- **Opening connections inside `foreach` for N items**: Creating a new connection per item in a loop causes N connection pool checkouts. Open once, execute all queries, close.
- **Transaction scope mismatch**: When you need EF Core + Dapper in the same transaction, you must use EF Core's connection (`GetDbConnection()`) not a new connection from the factory. A new connection creates a new transaction.
- **Forgetting to `Dispose` Dapper connections in error paths**: In a hybrid handler where EF Core throws after Dapper already ran (outside a shared transaction), the Dapper side may have committed partial data. Ensure the shared transaction pattern is used for cross-tool atomicity.

## References

- [Dapper — GitHub](https://github.com/DapperLib/Dapper)
- [EF Core shared transactions — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/saving/transactions#using-external-dbtransactions-relational-databases-only)
- [See: dapper-vs-ef-core.md](./dapper-vs-ef-core.md)
- [See: manual-transactions-ef-core.md](./manual-transactions-ef-core.md)
