# Global Query Filters in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `global-query-filters`, `soft-delete`, `multi-tenancy`, `HasQueryFilter`, `IgnoreQueryFilters`

## Question

> What are global query filters in EF Core, and what problems do they solve? How do you implement soft delete and multi-tenancy using `HasQueryFilter`, and when should you bypass them with `IgnoreQueryFilters`?

## Short Answer

Global query filters are LINQ predicates registered on an entity type that EF Core automatically appends to every query involving that type. They're primarily used for **soft delete** (automatically excluding `IsDeleted = true` rows) and **multi-tenancy** (automatically scoping queries to the current tenant's data). The filter is defined once in `HasQueryFilter` and applies invisibly to all `DbSet<T>` queries, `Include` navigations, and sub-queries — you never forget to add `WHERE IsDeleted = 0`. Use `IgnoreQueryFilters()` to opt out when you explicitly need to query all rows (e.g., restore a soft-deleted record, or an admin panel).

## Detailed Explanation

### Defining a Global Query Filter

```csharp
// In IEntityTypeConfiguration<T>:
builder.HasQueryFilter(e => !e.IsDeleted);
```

Or via `OnModelCreating` for multiple entities:

```csharp
protected override void OnModelCreating(ModelBuilder builder)
{
    builder.Entity<Order>().HasQueryFilter(o => !o.IsDeleted);
    builder.Entity<Customer>().HasQueryFilter(c => !c.IsDeleted);
}
```

Every `SELECT` against `Order` or `Customer` now includes `AND IsDeleted = 0` automatically.

### Soft Delete Pattern

Add `IsDeleted` to entities (or a base class):

```csharp
public abstract class SoftDeletableEntity
{
    public bool IsDeleted { get; private set; }
    public DateTimeOffset? DeletedAt { get; private set; }

    public void SoftDelete()
    {
        IsDeleted = true;
        DeletedAt = DateTimeOffset.UtcNow;
    }
}

public class Order : SoftDeletableEntity
{
    public int Id { get; set; }
    public string Reference { get; set; } = string.Empty;
}
```

Configure the filter using an expression on the base type, or per entity. To apply to all `SoftDeletableEntity` subtypes at once:

```csharp
protected override void OnModelCreating(ModelBuilder builder)
{
    foreach (var entityType in builder.Model.GetEntityTypes())
    {
        if (entityType.ClrType.IsAssignableTo(typeof(SoftDeletableEntity)))
        {
            var param = Expression.Parameter(entityType.ClrType, "e");
            var prop  = Expression.Property(param, nameof(SoftDeletableEntity.IsDeleted));
            var filter = Expression.Lambda(Expression.Not(prop), param);
            builder.Entity(entityType.ClrType).HasQueryFilter(filter);
        }
    }
}
```

### Multi-Tenancy with a Scoped Service

The filter lambda runs per query, so it can close over a **scoped service** injected into `DbContext`:

```csharp
public sealed class AppDbContext(
    DbContextOptions<AppDbContext> options,
    ITenantProvider tenantProvider) : DbContext(options)
{
    protected override void OnModelCreating(ModelBuilder builder)
    {
        // Closes over tenantProvider — evaluated lazily per query
        builder.Entity<Order>().HasQueryFilter(
            o => o.TenantId == tenantProvider.CurrentTenantId);

        builder.Entity<Customer>().HasQueryFilter(
            c => c.TenantId == tenantProvider.CurrentTenantId);
    }
}
```

> **Important:** The filter is an expression tree stored on the model — it's **not** evaluated at model build time. `tenantProvider.CurrentTenantId` is read at query execution time, so each request gets its own tenant value.

### Bypassing with `IgnoreQueryFilters()`

```csharp
// Restore a soft-deleted order — must see deleted rows
var deletedOrder = await db.Orders
    .IgnoreQueryFilters()
    .FirstOrDefaultAsync(o => o.Id == orderId && o.IsDeleted, ct);

// Admin: all tenants' data
var allOrders = await db.Orders
    .IgnoreQueryFilters()
    .ToListAsync(ct);
```

`IgnoreQueryFilters()` removes **all** filters on the entity for that query — you cannot selectively disable only one filter if multiple are registered. (Per-filter disabling is a frequently requested feature but was not in EF Core as of .NET 9.)

> **Warning:** `IgnoreQueryFilters()` bypasses **all** registered filters, including multi-tenancy filters. In a multi-tenant application, a misconfigured admin service that accidentally calls `IgnoreQueryFilters()` will leak cross-tenant data. Add authorization guards around any code path that uses it.

### Filters Apply to `Include` Navigations

Global filters also apply to eagerly loaded navigations:

```csharp
var customer = await db.Customers
    .Include(c => c.Orders)   // ← soft-deleted Orders are automatically excluded
    .FirstAsync(c => c.Id == customerId, ct);
```

If you want to include soft-deleted orders for this specific query:

```csharp
var customer = await db.Customers
    .IgnoreQueryFilters()
    .Include(c => c.Orders)
    .FirstAsync(c => c.Id == customerId, ct);
```

### Combining Soft Delete and Multi-Tenancy

EF Core supports only **one `HasQueryFilter` call per entity type** — a second call overwrites the first. Combine conditions in a single filter:

```csharp
builder.Entity<Order>().HasQueryFilter(o =>
    !o.IsDeleted &&
    o.TenantId == tenantProvider.CurrentTenantId);
```

## Code Example

```csharp
// Infrastructure: tenant provider (scoped)
public interface ITenantProvider
{
    string CurrentTenantId { get; }
}

public sealed class HttpContextTenantProvider(IHttpContextAccessor accessor) : ITenantProvider
{
    public string CurrentTenantId =>
        accessor.HttpContext?.User.FindFirstValue("tenant_id")
            ?? throw new InvalidOperationException("No tenant in context");
}

// DbContext with both filters combined
public sealed class AppDbContext(
    DbContextOptions<AppDbContext> options,
    ITenantProvider tenant) : DbContext(options)
{
    public DbSet<Order>    Orders    => Set<Order>();
    public DbSet<Customer> Customers => Set<Customer>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        builder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        // Apply combined filter to all ISoftDeletable + ITenantScoped entities
        foreach (var entityType in builder.Model.GetEntityTypes())
        {
            var type = entityType.ClrType;
            bool hasSoftDelete = type.IsAssignableTo(typeof(ISoftDeletable));
            bool hasTenant     = type.IsAssignableTo(typeof(ITenantScoped));

            if (!hasSoftDelete && !hasTenant) continue;

            var param = Expression.Parameter(type, "e");
            Expression? filter = null;

            if (hasSoftDelete)
            {
                var prop = Expression.Property(param, nameof(ISoftDeletable.IsDeleted));
                filter = Expression.Not(prop);
            }

            if (hasTenant)
            {
                var prop = Expression.Property(param, nameof(ITenantScoped.TenantId));
                // Capture tenant.CurrentTenantId — evaluated at query time
                Expression<Func<string>> tenantExpr = () => tenant.CurrentTenantId;
                var tenantFilter = Expression.Equal(prop, tenantExpr.Body);
                filter = filter is null ? tenantFilter : Expression.AndAlso(filter, tenantFilter);
            }

            builder.Entity(type).HasQueryFilter(Expression.Lambda(filter!, param));
        }
    }
}
```

## Common Follow-up Questions

- How do you disable a global query filter for just one of the two registered predicates (e.g., only bypass soft-delete but keep the tenant filter)?
- What happens to `Count()`, `Any()`, and aggregate queries — do global filters apply there too?
- How does EF Core handle global filters on owned entity types?
- Can global query filters reference related entities or navigation properties in the predicate?
- How do you test code that uses global query filters — does `IgnoreQueryFilters()` make tests brittle?

## Common Mistakes / Pitfalls

- **Two `HasQueryFilter` calls for the same entity**: The second call silently overwrites the first. Always merge conditions into one expression.
- **Capturing a mutable field instead of a scoped service**: `builder.Entity<Order>().HasQueryFilter(o => o.TenantId == _tenantId)` where `_tenantId` is a field set at construction time — this captures a **single value** baked into the model, not the per-request value. Always close over a scoped service property, not a value.
- **`IgnoreQueryFilters()` in shared services**: A repository or service method that calls `IgnoreQueryFilters()` unconditionally will bypass security constraints for every caller. Make this an opt-in, explicit parameter.
- **Filters not applying to raw SQL**: `FromSqlRaw` and `ExecuteSqlRaw` bypass global query filters. If you use raw SQL for performance, re-add the filter condition manually.
- **Forgetting that `Include` also applies filters**: When troubleshooting "missing" related entities, check whether a global filter is silently excluding them.

## References

- [Global query filters — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/filters)
- [Multi-tenancy with EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/miscellaneous/multitenancy)
- [See: shadow-properties.md](./shadow-properties.md)
- [See: ef-core-configuration.md](./ef-core-configuration.md)
