# Multi-Tenant Schema Strategies

**Category:** Data Access / Migrations & Schema Management
**Difficulty:** 🔴 Senior
**Tags:** `multi-tenancy`, `schema`, `row-level-security`, `database-per-tenant`, `shared-schema`, `EF Core`, `tenant-isolation`

## Question

> What are the main database schema strategies for multi-tenant SaaS applications? What are the trade-offs between per-tenant databases, shared database with tenant_id, and per-tenant schemas? How does each affect EF Core configuration and migrations?

## Short Answer

Three strategies: (1) **Database per tenant** — maximum isolation, highest operational cost; (2) **Shared database, shared schema** — lowest cost, all tenants in one table with a `TenantId` column; (3) **Shared database, schema per tenant** — middle ground, each tenant has their own schema (`tenant1.Orders`, `tenant2.Orders`). The right choice depends on isolation requirements, scale, and compliance needs. In .NET, shared-schema is most common — implemented via EF Core global query filters (`HasQueryFilter`) and `ITenantProvider`. Schema-per-tenant requires dynamic `DbContext` configuration per request.

## Detailed Explanation

### Strategy 1: Database per Tenant

```
TenantA → ConnectionString → TenantA.mdf (dedicated database)
TenantB → ConnectionString → TenantB.mdf (dedicated database)
```

```csharp
// Resolve connection string from tenant context
public class TenantConnectionResolver(ITenantProvider tenant, IConfiguration config)
{
    public string GetConnectionString()
        => config.GetConnectionString($"Tenant_{tenant.CurrentTenantId}")
           ?? throw new InvalidOperationException(
               $"No connection string for tenant {tenant.CurrentTenantId}");
}

// Per-tenant DbContext via IDbContextFactory
builder.Services.AddDbContextFactory<AppDbContext>((sp, options) =>
{
    var resolver = sp.GetRequiredService<TenantConnectionResolver>();
    options.UseSqlServer(resolver.GetConnectionString());
});
```

**Migrations**: each tenant database needs independent migration runs:
```bash
# Deploy migrations to each tenant database individually
foreach ($tenantId in $tenants) {
    dotnet ef database update --connection "Server=...;Database=Tenant_$tenantId;"
}
```

**Pros**: complete data isolation, compliance-friendly (GDPR — delete one DB to erase all tenant data), individual backup/restore per tenant  
**Cons**: 100s of databases = high operational cost, complex migration management

### Strategy 2: Shared Database, Shared Schema (Row-Level Tenancy)

All tenants share the same tables. Every row has a `TenantId` column. EF Core global query filters enforce isolation:

```csharp
// Global query filter — automatically adds WHERE TenantId = @current to every query
protected override void OnModelCreating(ModelBuilder model)
{
    model.Entity<Order>()
        .HasQueryFilter(o => o.TenantId == _tenantProvider.CurrentTenantId);
}

// Migrations are run once for all tenants — simple
dotnet ef database update
```

**Automatic TenantId population via interceptor or SaveChanges override**:
```csharp
public override int SaveChanges()
{
    foreach (var entry in ChangeTracker.Entries()
        .Where(e => e.State == EntityState.Added))
    {
        if (entry.Entity is ITenantEntity entity)
            entity.TenantId = _tenantProvider.CurrentTenantId;
    }
    return base.SaveChanges();
}
```

**Pros**: simple schema, single migration run, cost-effective  
**Cons**: weaker isolation (a bug could expose cross-tenant data), compliance challenges, large tables (all tenants mixed), harder to offboard a single tenant

### Strategy 3: Schema per Tenant

```
Tenant1 → Orders → tenant1.Orders
Tenant2 → Orders → tenant2.Orders
```

```csharp
// Dynamic schema via DbContext option
public class AppDbContext(DbContextOptions<AppDbContext> options, ITenantProvider tenant)
    : DbContext(options)
{
    private readonly string _schema = tenant.CurrentTenantId;

    protected override void OnModelCreating(ModelBuilder m)
    {
        m.HasDefaultSchema(_schema);
        // All entities automatically use the tenant's schema
        m.Entity<Order>().ToTable("Orders");      // → tenant1.Orders
        m.Entity<Customer>().ToTable("Customers"); // → tenant1.Customers
    }
}
```

**Migrations with schema substitution**:
```csharp
// Generate migration SQL once, replace schema name per tenant
var script = db.Database.GenerateCreateScript();
foreach (var tenant in tenants)
{
    var tenantScript = script.Replace("dbo.", $"{tenant.Id}.");
    // Apply tenantScript to the shared database
}
```

**Pros**: better isolation than shared schema (separate schema namespaces), simpler than separate databases  
**Cons**: 1000 tenants = 1000 copies of every table/index in one DB, complex migrations (run per schema)

### Comparison

| | DB per tenant | Shared schema | Schema per tenant |
|-|---------------|---------------|------------------|
| Data isolation | ✅ Maximum | ❌ Lowest (TenantId filter) | 🟡 Medium |
| Compliance (delete tenant) | ✅ Drop database | ❌ DELETE WHERE TenantId | 🟡 DROP SCHEMA |
| Migration complexity | ❌ Per-tenant runs | ✅ Single run | ❌ Per-tenant runs |
| Cost (100 tenants) | ❌ High | ✅ Low | 🟡 Medium |
| Performance isolation | ✅ | ❌ Noisy neighbors | 🟡 Same DB |
| EF Core complexity | 🟡 Per-tenant factory | ✅ Global filter | ❌ Dynamic schema |

## Code Example

```csharp
// Shared schema — EF Core global filter + tenant resolution
public interface ITenantProvider { string CurrentTenantId { get; } }

public class HttpContextTenantProvider(IHttpContextAccessor http) : ITenantProvider
{
    public string CurrentTenantId =>
        http.HttpContext?.User.FindFirst("tenant_id")?.Value
        ?? throw new InvalidOperationException("No tenant context");
}

public class AppDbContext(DbContextOptions<AppDbContext> opts, ITenantProvider tenant)
    : DbContext(opts)
{
    protected override void OnModelCreating(ModelBuilder m)
    {
        m.Entity<Order>().HasQueryFilter(
            o => o.TenantId == tenant.CurrentTenantId);
        m.Entity<Customer>().HasQueryFilter(
            c => c.TenantId == tenant.CurrentTenantId);
    }

    public override int SaveChanges()
    {
        SetTenantIds();
        return base.SaveChanges();
    }

    public override Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        SetTenantIds();
        return base.SaveChangesAsync(ct);
    }

    private void SetTenantIds()
    {
        foreach (var entry in ChangeTracker.Entries<ITenantEntity>()
                     .Where(e => e.State == EntityState.Added))
            entry.Entity.TenantId = tenant.CurrentTenantId;
    }
}
```

## Common Follow-up Questions

- How do you handle background jobs that run outside a tenant context (e.g., billing jobs)?
- What are the performance implications of global query filters on large shared tables?
- How does Row-Level Security (RLS) in SQL Server complement or replace EF Core global filters?
- How do you test multi-tenant code — how do you switch tenant context in integration tests?
- When should you migrate from shared-schema to schema-per-tenant or database-per-tenant?

## Common Mistakes / Pitfalls

- **Forgetting to set `TenantId` on new entities**: without automatic population (SaveChanges override or interceptor), developers must manually set `TenantId` on every `Add` call. One oversight = data cross-contamination.
- **Using `IgnoreQueryFilters()` broadly**: `IgnoreQueryFilters()` bypasses all filters including the tenant filter. Code that calls this for unrelated reasons (e.g., soft-delete bypass) may accidentally expose cross-tenant data.
- **Cross-tenant query in background jobs**: jobs that don't have an HTTP context and need to process all tenants must explicitly query across tenants. The global filter breaks this unless the job bypasses it with a super-admin context.
- **Not testing tenant isolation at the integration test level**: unit tests with fake repositories don't catch SQL-level tenant isolation failures. Integration tests that create two tenants' data and verify the query returns only the correct tenant's rows are essential.

## References

- [Multi-tenancy — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/miscellaneous/multitenancy)
- [Global query filters — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/filters)
- [Row-Level Security — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security)
- [See: global-query-filters.md](./global-query-filters.md)
- [See: zero-downtime-migrations.md](./zero-downtime-migrations.md)
