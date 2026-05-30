# Shadow Properties in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `shadow-properties`, `audit`, `multi-tenancy`, `EF.Property`, `model-configuration`

## Question

> What are shadow properties in EF Core? How are they created, accessed, and used — and what practical scenarios make them worth the complexity over adding properties to the entity class?

## Short Answer

Shadow properties are EF Core model properties that exist in the database schema but have no corresponding property in the .NET entity class. They live solely in EF Core's model and change tracker. They're useful for adding audit fields (`CreatedAt`, `UpdatedAt`), soft-delete flags, or tenant IDs to entities without polluting the domain model with persistence concerns. You access them at runtime via `EF.Property<T>(entity, "PropertyName")` in LINQ or via `context.Entry(entity).Property("PropertyName")` in code.

## Detailed Explanation

### Defining Shadow Properties

In `IEntityTypeConfiguration<T>` or `OnModelCreating`:

```csharp
public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        // Shadow property — present in DB but not in Order class
        builder.Property<DateTimeOffset>("CreatedAt")
               .HasDefaultValueSql("SYSDATETIMEOFFSET()")
               .ValueGeneratedOnAdd();

        builder.Property<DateTimeOffset>("UpdatedAt")
               .HasDefaultValueSql("SYSDATETIMEOFFSET()")
               .ValueGeneratedOnAddOrUpdate();
    }
}
```

EF Core adds the `CreatedAt` and `UpdatedAt` columns to the `Orders` table in the migration, but the `Order` class has no such properties.

### EF Core Creates Shadow Properties Automatically

EF Core also creates shadow properties implicitly in several scenarios:

1. **FK without scalar property**: If you have a navigation property `public Customer Customer` but no `CustomerId` scalar, EF Core creates a shadow FK property `CustomerId`.
2. **`OwnsOne` default keys**: Owned entities often use shadow PKs.
3. **`HasMany`/`WithOne` with no FK in the dependent entity**.

### Accessing Shadow Properties

**In LINQ queries:**

```csharp
// Sort by shadow property
var orders = await db.Orders
    .OrderByDescending(o => EF.Property<DateTimeOffset>(o, "CreatedAt"))
    .ToListAsync(ct);

// Filter by shadow property
var recent = await db.Orders
    .Where(o => EF.Property<DateTimeOffset>(o, "CreatedAt") > DateTimeOffset.UtcNow.AddDays(-7))
    .ToListAsync(ct);
```

**In application code (after materialization):**

```csharp
var order = await db.Orders.FindAsync(orderId);
var createdAt = db.Entry(order!).Property<DateTimeOffset>("CreatedAt").CurrentValue;
```

**Setting a shadow property before save:**

```csharp
db.Entry(order).Property("UpdatedAt").CurrentValue = DateTimeOffset.UtcNow;
await db.SaveChangesAsync(ct);
```

### Practical Use Case: Audit Trail via `ISaveChangesInterceptor`

Shadow properties shine when combined with an interceptor that sets them automatically on every save — keeping the domain model unaware of auditing:

```csharp
public sealed class AuditInterceptor : SaveChangesInterceptor
{
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken ct = default)
    {
        var db = eventData.Context!;
        var now = DateTimeOffset.UtcNow;

        foreach (var entry in db.ChangeTracker.Entries())
        {
            if (entry.State == EntityState.Added)
            {
                if (entry.Metadata.FindProperty("CreatedAt") is not null)
                    entry.Property("CreatedAt").CurrentValue = now;
            }

            if (entry.State is EntityState.Added or EntityState.Modified)
            {
                if (entry.Metadata.FindProperty("UpdatedAt") is not null)
                    entry.Property("UpdatedAt").CurrentValue = now;
            }
        }

        return base.SavingChangesAsync(eventData, result, ct);
    }
}
```

Register the interceptor:

```csharp
builder.Services.AddDbContext<AppDbContext>((sp, opt) =>
    opt.UseSqlServer(connString)
       .AddInterceptors(sp.GetRequiredService<AuditInterceptor>()));

builder.Services.AddSingleton<AuditInterceptor>();
```

### Multi-Tenancy with Shadow Properties

A shadow `TenantId` on every entity — combined with a global query filter — isolates tenant data without any domain model changes:

```csharp
// Configuration base class applied to all tenant-isolated entities
protected override void OnModelCreating(ModelBuilder builder)
{
    foreach (var entityType in builder.Model.GetEntityTypes())
    {
        if (entityType.ClrType.IsAssignableTo(typeof(ITenantEntity)))
        {
            builder.Entity(entityType.ClrType)
                   .Property<string>("TenantId")
                   .HasMaxLength(50)
                   .IsRequired();

            // Global query filter using shadow property
            builder.Entity(entityType.ClrType)
                   .HasQueryFilter(e =>
                       EF.Property<string>(e, "TenantId") == _tenantProvider.Current);
        }
    }
}
```

### Shadow vs Explicit Property

| Criteria | Shadow property | Explicit property on entity |
|----------|-----------------|-----------------------------|
| Domain model purity | ✅ No pollution | ❌ Adds persistence concern |
| Discoverability | ❌ Hidden — requires knowing the name | ✅ Obvious from class definition |
| Compile-time safety | ❌ String-based name | ✅ Strongly typed |
| LINQ support | ✅ Via `EF.Property<T>()` | ✅ Direct |
| Change tracker access | Via entry API | Direct property access |

> **Rule of thumb:** Use shadow properties for infrastructure concerns (audit, tenancy, soft-delete) that are irrelevant to domain behaviour. Use explicit properties for anything the domain logic needs to reason about.

## Code Example

```csharp
// Clean entity — no audit fields
public class Order
{
    public int    Id        { get; private set; }
    public string Reference { get; private set; } = string.Empty;

    private Order() { }
    public static Order Create(string reference) => new() { Reference = reference };
}

// All audit concerns in infrastructure
public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.HasKey(o => o.Id);
        builder.Property(o => o.Reference).HasMaxLength(50).IsRequired();

        // Shadow audit columns — not visible in the Order class
        builder.Property<DateTimeOffset>("CreatedAt").IsRequired();
        builder.Property<DateTimeOffset>("UpdatedAt").IsRequired();
        builder.Property<string?>("CreatedBy").HasMaxLength(100);
        builder.Property<string?>("UpdatedBy").HasMaxLength(100);

        // Index on shadow property (useful for filtering by CreatedAt)
        builder.HasIndex("CreatedAt");
    }
}

// Querying using shadow property
var recentOrders = await db.Orders
    .Where(o => EF.Property<DateTimeOffset>(o, "CreatedAt") >= cutoff)
    .Select(o => new { o.Id, o.Reference,
        CreatedAt = EF.Property<DateTimeOffset>(o, "CreatedAt") })
    .ToListAsync(ct);
```

## Common Follow-up Questions

- How do you write a query that sorts or filters by a shadow property in a type-safe way?
- Can you add a shadow property to an owned entity type?
- What happens to shadow FK properties when you delete a navigation property from an entity class?
- How do shadow properties appear in migrations — can you rename them without data loss?
- What is the difference between a shadow property and a backing field in EF Core?

## Common Mistakes / Pitfalls

- **Typo in property name at runtime**: Shadow property names are strings — `EF.Property<T>(e, "CreatedAt")` vs `"CreatdAt"` won't be caught at compile time. Define names as constants.
- **Missing `FindProperty` null check in interceptors**: Not all entities have the shadow property. Always check `entry.Metadata.FindProperty("CreatedAt") is not null` before setting.
- **Setting `ValueGeneratedOnAdd` AND setting in interceptor**: If the DB has a default value SQL AND you're setting the value in an interceptor, only one should win — be deliberate about which layer owns the value.
- **Shadow FK orphans**: If you remove a navigation property but forget to remove the shadow FK property in the configuration, EF Core may generate an unexpected column or constraint in the migration.
- **Exposing shadow property names as magic strings in queries**: Scattered `EF.Property<DateTimeOffset>(e, "CreatedAt")` across the codebase creates hidden coupling. Encapsulate in a query extension method.

## References

- [Shadow and indexer properties — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/shadow-properties)
- [SaveChanges interceptors — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/logging-events-diagnostics/interceptors#savechanges-interception)
- [Global query filters — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/filters)
- [See: global-query-filters.md](./global-query-filters.md)
- [See: savechanges-interceptors.md](./savechanges-interceptors.md)
