# Multi-Tenancy Strategies

**Category:** System Design / Data Storage
**Difficulty:** 🔴 Senior
**Tags:** `multi-tenancy`, `SaaS`, `schema-per-tenant`, `row-level-isolation`, `EF-Core`, `tenant-isolation`, `Azure-SQL`

## Question

> What are the main multi-tenancy strategies for a SaaS application (separate databases, schema-per-tenant, shared database with row-level isolation)? What are the trade-offs, and how do you implement tenant isolation in EF Core?

## Short Answer

Multi-tenancy serves multiple customers (tenants) from shared infrastructure. The three main strategies are: **separate database per tenant** (best isolation, highest cost), **schema per tenant** (good isolation, shared server), and **shared database with row-level isolation** (lowest cost, risk of data leakage). The right choice depends on your compliance requirements, tenant count, and pricing model. EF Core supports all three via connection string switching, schema configuration, or global query filters that enforce `WHERE tenant_id = :current_tenant` on every query.

## Detailed Explanation

### Strategy 1: Separate Database per Tenant

Each tenant has their own database instance.

| Pros | Cons |
|------|------|
| Complete data isolation (compliance, GDPR) | Highest infrastructure cost |
| No risk of cross-tenant data leakage | Connection pool explosion (1000 tenants = 1000 DBs) |
| Independent backup, restore, scaling | Schema migration must run against every DB |
| Tenant data never touches other tenants' queries | Harder to query across tenants (analytics) |
| Easy to move a tenant to a dedicated server | |

**Use when**: high-value enterprise customers, compliance requirements (HIPAA, SOC 2), or tenants need isolated performance guarantees.

**In Azure**: Azure SQL Elastic Pools let you host many tenant databases on a shared compute pool with burstable DTUs, reducing cost while maintaining isolation.

### Strategy 2: Schema per Tenant

One database server, each tenant has their own schema (PostgreSQL) or set of tables with a schema prefix (SQL Server).

| Pros | Cons |
|------|------|
| Better isolation than row-level | Schema migrations must run N times |
| Fewer connections than per-DB | Still complex connection routing |
| Shared server reduces infra cost | Not available in all databases (SQL Server schemas differ from PostgreSQL) |
| Easier cross-tenant analytics (same DB) | |

**Practical note**: In SQL Server, a "schema" is a namespace (`tenant_a.Orders`, `tenant_b.Orders`), not a separate database. In PostgreSQL, schemas are isolated namespaces with their own tables, which works well for this pattern.

### Strategy 3: Shared Database, Row-Level Isolation

All tenants share tables; a `tenant_id` column on every table discriminates rows.

| Pros | Cons |
|------|------|
| Lowest infrastructure cost | **Requires discipline**: every query must filter by tenant_id |
| Simple schema migrations (once) | One SQL bug leaks all tenant data |
| Easy analytics across tenants | Less isolation for compliance |
| Scales to thousands of tenants easily | Noisy neighbour: one tenant's queries affect others |

**Risk**: a developer forgets to add `WHERE tenant_id = :current_tenant` → full data exposure across all tenants. This must be enforced automatically — never trust individual query writers.

**EF Core Global Query Filters** enforce this automatically, making it the standard approach for this strategy.

### Hybrid Approach

Many SaaS products use a tiered approach:
- **Free/Starter tier**: shared DB with row isolation.
- **Professional tier**: dedicated schema or dedicated pool on shared server.
- **Enterprise tier**: dedicated database instance.

This balances cost efficiency for small customers with isolation needs for large ones.

### EF Core Implementation

#### Row-Level Isolation (Global Query Filter)

```csharp
protected override void OnModelCreating(ModelBuilder mb)
{
    mb.Entity<Order>()
        .HasQueryFilter(o => o.TenantId == _currentTenantId);
    // EF Core appends AND tenant_id = :id to EVERY query on this entity
}
```

The `_currentTenantId` is injected from the HTTP request context at DbContext creation time.

#### Separate Database / Schema

Use a custom `IDbContextFactory<T>` or connection string resolver that maps `tenantId → connectionString`.

### Security Considerations

- Always validate the tenant context server-side — never trust the client to provide their own `tenant_id`.
- Use Row-Level Security (RLS) at the database level as a second layer of defence (SQL Server / PostgreSQL both support RLS policies that the DB engine enforces regardless of application code).
- Log cross-tenant access attempts for audit purposes.

## Code Example

```csharp
// EF Core 8 — shared database, row-level isolation via Global Query Filter
// + ITenantContext for current tenant resolution from HTTP headers/JWT

using Microsoft.EntityFrameworkCore;

// ── Tenant resolution ─────────────────────────────────────────────────
public interface ITenantContext
{
    string TenantId { get; }
}

public class HttpTenantContext(IHttpContextAccessor accessor) : ITenantContext
{
    // Resolve from JWT claim or request header
    public string TenantId =>
        accessor.HttpContext?.User.FindFirst("tenant_id")?.Value
        ?? accessor.HttpContext?.Request.Headers["X-Tenant-Id"].ToString()
        ?? throw new InvalidOperationException("No tenant context");
}

// ── DbContext with global query filter ───────────────────────────────
public class AppDbContext : DbContext
{
    private readonly string _tenantId;

    public AppDbContext(DbContextOptions<AppDbContext> options, ITenantContext tenant)
        : base(options)
    {
        _tenantId = tenant.TenantId;
    }

    public DbSet<Order> Orders => Set<Order>();
    public DbSet<Product> Products => Set<Product>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        // Global filter on ALL tenant-owned entities
        // EF Core adds AND tenant_id = :id to every generated SQL query
        mb.Entity<Order>()
          .HasQueryFilter(o => o.TenantId == _tenantId);

        mb.Entity<Product>()
          .HasQueryFilter(p => p.TenantId == _tenantId);

        // Composite indexes: tenant_id first for efficient per-tenant queries
        mb.Entity<Order>()
          .HasIndex(o => new { o.TenantId, o.CreatedAt });
    }
}

// ── Startup ───────────────────────────────────────────────────────────
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ITenantContext, HttpTenantContext>();
builder.Services.AddDbContext<AppDbContext>((sp, options) =>
    options.UseSqlServer(connectionString));

// ── Endpoints ─────────────────────────────────────────────────────────
// All queries are automatically scoped to the current tenant
app.MapGet("/orders", async (AppDbContext db) =>
{
    // Generated SQL: SELECT * FROM Orders WHERE tenant_id = 'tenant-a' AND ...
    var orders = await db.Orders.ToListAsync();
    return Results.Ok(orders);
});

app.MapPost("/orders", async (CreateOrderRequest req, AppDbContext db, ITenantContext tenant) =>
{
    var order = new Order
    {
        TenantId   = tenant.TenantId,   // always set from context — never trust client
        CustomerId = req.CustomerId,
        Total      = req.Total,
        CreatedAt  = DateTime.UtcNow
    };
    db.Orders.Add(order);
    await db.SaveChangesAsync();
    return Results.Created($"/orders/{order.Id}", order);
});

// ── Separate DB strategy (alternative): tenant-specific connection string ──
public class TenantDbContextFactory(IConfiguration config, ITenantContext tenant)
{
    public AppDbContext Create()
    {
        // Look up connection string by tenant ID from config or a tenant registry DB
        var cs = config.GetConnectionString($"Tenant_{tenant.TenantId}")
            ?? config.GetConnectionString("Shared");   // fallback to shared DB

        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(cs)
            .Options;

        return new AppDbContext(options, tenant);
    }
}

public class Order { public int Id { get; set; } public string TenantId { get; set; } = ""; public string CustomerId { get; set; } = ""; public decimal Total { get; set; } public DateTime CreatedAt { get; set; } }
public class Product { public int Id { get; set; } public string TenantId { get; set; } = ""; public string Name { get; set; } = ""; }
record CreateOrderRequest(string CustomerId, decimal Total);
```

## Common Follow-up Questions

- How do you run schema migrations safely in a per-tenant database model with 1,000 tenant databases?
- How does Row-Level Security (RLS) in SQL Server / PostgreSQL provide defence-in-depth beyond the application layer?
- How do you handle cross-tenant admin queries (e.g., "show all orders across all tenants")?
- What is an Azure SQL Elastic Pool, and how does it reduce cost for per-tenant databases?
- How do you prevent a noisy neighbour tenant from starving other tenants in a shared database model?
- How do you implement tenant onboarding / offboarding for each strategy?

## Common Mistakes / Pitfalls

- **Forgetting to set `tenant_id` on insert**: the global query filter protects reads but not writes. A `DbContext.Add()` without setting `tenant_id` inserts an orphaned row visible to no tenant (or worse, all tenants if the filter is ever bypassed).
- **Disabling the global query filter for "admin" queries that accidentally access production data**: `db.Orders.IgnoreQueryFilters().ToList()` bypasses all tenant isolation — this must be restricted to explicitly-elevated admin paths, not general code paths.
- **No database-level enforcement**: application-level filtering can be bypassed by a bug, a raw SQL query, or a direct DB connection. Add Row-Level Security at the DB level as a second defence.
- **Connection pool explosion with per-tenant databases**: 5,000 tenants × a minimum of 1 connection each = 5,000 connections. Use Azure SQL Elastic Pools, connection multiplexers, or lazy connection opening to manage pool size.
- **Treating all tenants the same in shared schema**: different tenants may need different configurations, feature flags, or soft-delete behaviour. Ensure the data model and business logic can express per-tenant variation without schema duplication.
- **Schema migration applied to all tenant DBs synchronously**: migrating 10,000 tenant databases one-by-one during deployment creates hours-long maintenance windows. Use migration tools with parallel execution (Flyway teams, custom background migration workers) and design migrations to be backward-compatible.

## References

- [Multi-tenancy in EF Core](https://learn.microsoft.com/ef/core/miscellaneous/multitenancy)
- [Azure SQL Elastic Pools for SaaS applications](https://learn.microsoft.com/azure/azure-sql/database/elastic-pool-overview)
- [Row-Level Security — SQL Server](https://learn.microsoft.com/sql/relational-databases/security/row-level-security)
- [SaaS multi-tenancy patterns — Azure Architecture Center](https://learn.microsoft.com/azure/azure-sql/database/saas-tenancy-app-design-patterns)
- [See: database-sharding.md](./database-sharding.md) — sharding as a scaling strategy for tenant databases
