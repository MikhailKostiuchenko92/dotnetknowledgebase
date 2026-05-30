# Stored Procedures vs ORM

**Category:** Data Access / SQL & Query Optimization
**Difficulty:** 🟡 Middle
**Tags:** `SQL`, `stored-procedures`, `ORM`, `EF Core`, `Dapper`, `plan-cache`, `security`, `portability`

## Question

> What are the trade-offs between using stored procedures and an ORM like EF Core or Dapper? When would you choose stored procedures over LINQ or raw SQL in application code?

## Short Answer

Stored procedures compile once, cache their execution plan, run in the database engine (reducing network round-trips), and enable fine-grained SQL Server permission grants (EXECUTE only, no direct table access). The trade-offs: they split business logic between app code and the database, make version control and CI/CD harder, and reduce portability. ORMs like EF Core keep all logic in C# — easier to test, refactor, and maintain — but send queries as strings over the wire, parameterize on every call, and can generate suboptimal SQL for complex scenarios. The right answer for most teams: ORM for CRUD and standard queries, stored procedures for complex reporting, batch operations, or where database-level security isolation is required.

## Detailed Explanation

### How Plan Caching Works

When SQL Server executes an ad-hoc query or a stored procedure for the first time:
1. Parse the SQL
2. Generate a query plan (expensive — CPU + memory)
3. Cache the plan keyed by the statement hash

**Stored procedures**: the plan is compiled once per parameter data-type signature and reused. The procedure name is the cache key.

**Ad-hoc parameterized queries** (EF Core, Dapper with `@param`): SQL Server also caches these — as long as the query text is identical between calls, the plan is reused. *Parameterization is the key* — string interpolation or concatenation produces a unique SQL string per call, defeating plan caching.

```sql
-- ❌ Unparameterized — unique SQL string per CustomerId → no plan reuse
SELECT * FROM Orders WHERE CustomerId = 42
SELECT * FROM Orders WHERE CustomerId = 99

-- ✅ Parameterized — same SQL text → plan cached and reused
SELECT * FROM Orders WHERE CustomerId = @CustomerId
```

EF Core always generates parameterized SQL, so plan caching is not a significant advantage of stored procedures over EF Core in modern .NET.

### Security Model

With stored procedures, you can grant users/roles `EXECUTE` permission on the procedure without granting `SELECT`/`INSERT`/`UPDATE`/`DELETE` on the underlying tables. This implements *least-privilege* data access:

```sql
-- Service account only gets EXECUTE, not direct table access
GRANT EXECUTE ON dbo.usp_GetCustomerOrders TO AppServiceAccount;
REVOKE SELECT ON Orders FROM AppServiceAccount;
```

This is meaningful in environments with strict database security compliance requirements. With ORM approaches, the database user needs direct table permissions.

### Comparison Table

| Feature | Stored Procedures | EF Core / Dapper |
|---------|------------------|-----------------|
| Plan caching | Always (first-class) | Yes, if parameterized |
| Syntax validation | At compile time in DB | At runtime (string queries) |
| Business logic location | Database + application | Application only |
| Testability | Integration tests only (DB required) | Unit + integration |
| Version control | DDL scripts (harder to diff) | C# code (first-class VCS) |
| Database portability | Low (T-SQL specific) | High (EF Core supports multiple DBs) |
| Fine-grained security | ✅ EXECUTE permission isolation | ❌ Requires table permissions |
| Complex operations (temp tables, cursors) | ✅ Native | ❌ Awkward to express |
| Debugging | SQL Server Profiler / SSMS | Application logging |
| CI/CD integration | Requires DB migration scripts | EF Core migrations |

### Calling Stored Procedures from .NET

**EF Core:**
```csharp
// Simple SP returning entities
var orders = await db.Orders
    .FromSqlRaw("EXEC dbo.usp_GetCustomerOrders @CustomerId", 
                new SqlParameter("@CustomerId", customerId))
    .ToListAsync(ct);

// SP with output parameter — must use raw ADO.NET or Dapper for output params
```

**Dapper (preferred for SP with output params):**
```csharp
var parameters = new DynamicParameters();
parameters.Add("@CustomerId", customerId);
parameters.Add("@TotalOrders", dbType: DbType.Int32, direction: ParameterDirection.Output);

await conn.ExecuteAsync("dbo.usp_GetCustomerOrders", parameters,
    commandType: CommandType.StoredProcedure);

int totalOrders = parameters.Get<int>("@TotalOrders");
```

### When to Choose Stored Procedures

- **Complex T-SQL operations** that are hard to express in LINQ: multi-step batch logic with temp tables, cursors, recursive CTEs, dynamic SQL
- **Security isolation**: app runs with EXECUTE-only permissions, no direct table access
- **Database-owned logic**: logic that must be consistent across multiple calling applications (e.g., a legacy .NET Framework app + a new .NET 8 app + SSRS reports all calling the same SP)
- **DBA-managed optimizations**: DBAs want to tune the execution plan without redeploying the application

### When to Choose ORM

- Standard CRUD operations
- Teams want all logic in one language (C#) and one VCS history
- Application needs to support multiple databases
- TDD / unit testing of data access logic
- Schema change frequency requires easy refactoring

## Code Example

```csharp
// Hybrid pattern: EF Core for writes, Dapper for complex read SP
public class OrderRepository(AppDbContext db, IDbConnectionFactory connFactory)
{
    // Write: EF Core with full change tracking
    public async Task CreateOrderAsync(Order order, CancellationToken ct)
    {
        db.Orders.Add(order);
        await db.SaveChangesAsync(ct);
    }

    // Complex read report: Dapper calling a stored procedure
    public async Task<SalesReport> GetSalesReportAsync(
        int year, int month, CancellationToken ct)
    {
        await using var conn = await connFactory.OpenAsync(ct);
        
        var parameters = new DynamicParameters();
        parameters.Add("@Year", year);
        parameters.Add("@Month", month);

        using var multi = await conn.QueryMultipleAsync(
            "dbo.usp_GetSalesReport",
            parameters,
            commandType: CommandType.StoredProcedure);

        var summary = await multi.ReadSingleAsync<SalesSummary>();
        var lineItems = (await multi.ReadAsync<SalesLineItem>()).ToList();
        
        return new SalesReport(summary, lineItems);
    }
}
```

## Common Follow-up Questions

- How do you manage stored procedure versioning alongside application deployments?
- What is parameter sniffing, and how does it cause stored procedure performance issues?
- How do table-valued parameters (TVPs) allow passing collections to stored procedures?
- Can EF Core call stored procedures that return multiple result sets?
- How do you unit test business logic that currently lives in a stored procedure?

## Common Mistakes / Pitfalls

- **Business logic drift into stored procedures**: complex if/else logic in T-SQL is harder to test, debug, and version than C#. Keep SP logic to data operations, not business rules.
- **Assuming SPs are always faster than ORM**: modern EF Core with parameterized queries uses the plan cache as effectively as stored procedures. The gap is small for standard queries.
- **Not handling output parameters in EF Core**: `FromSqlRaw` can return entity rows but cannot capture `OUTPUT` parameters. Use Dapper or raw ADO.NET for SPs that use `OUTPUT` params.
- **One SP per query "just to be safe"**: creating SPs for every SELECT adds maintenance overhead. Reserve SPs for logic where they provide clear advantages (security, complex T-SQL, batch operations).

## References

- [Stored procedures — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/stored-procedures/stored-procedures-database-engine)
- [FromSqlRaw — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/raw-sql)
- [Dapper stored procedure usage — GitHub](https://github.com/DapperLib/Dapper#stored-procedures)
- [See: dapper-stored-procedures.md](./dapper-stored-procedures.md)
- [See: raw-sql-in-ef-core.md](./raw-sql-in-ef-core.md)
