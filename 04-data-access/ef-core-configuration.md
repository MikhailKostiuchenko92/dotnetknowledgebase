# EF Core Entity Configuration

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `IEntityTypeConfiguration`, `fluent-api`, `OnModelCreating`, `assembly-scanning`

## Question

> What is `IEntityTypeConfiguration<T>` and why is it preferred over putting all configuration in `OnModelCreating`? How do you register configuration classes, and what are the benefits for large models?

## Short Answer

`IEntityTypeConfiguration<T>` is an interface that lets you move entity mapping code into a dedicated class per entity type, rather than cramming everything into a single `OnModelCreating` method. You register all implementations at once with `modelBuilder.ApplyConfigurationsFromAssembly(...)`, which discovers them by reflection. The pattern keeps `OnModelCreating` clean, makes each entity's mapping independently readable and testable, and scales well as the model grows beyond a handful of entities.

## Detailed Explanation

### The Problem with `OnModelCreating`

As a model grows, `OnModelCreating` becomes a megamethod hundreds of lines long — hard to navigate, prone to merge conflicts, and impossible to unit-test in isolation:

```csharp
// ❌ All configuration dumped into one method
protected override void OnModelCreating(ModelBuilder builder)
{
    builder.Entity<Order>(e => {
        e.ToTable("orders");
        e.HasKey(o => o.Id);
        e.Property(o => o.Reference).HasMaxLength(50);
        // ... 20 more lines
    });

    builder.Entity<Customer>(e => {
        // ... another 20 lines
    });

    // ... 10 more entities
}
```

### `IEntityTypeConfiguration<T>`

```csharp
public interface IEntityTypeConfiguration<TEntity> where TEntity : class
{
    void Configure(EntityTypeBuilder<TEntity> builder);
}
```

Each implementation focuses on one entity:

```csharp
public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.ToTable("orders");
        builder.HasKey(o => o.Id);
        builder.Property(o => o.Reference).IsRequired().HasMaxLength(50);
        builder.Property(o => o.Total).HasPrecision(19, 4);
        builder.HasMany(o => o.Lines)
               .WithOne(l => l.Order)
               .HasForeignKey(l => l.OrderId)
               .OnDelete(DeleteBehavior.Cascade);
    }
}
```

### Registering Configuration Classes

**Option 1 — Assembly scanning (recommended):**

```csharp
protected override void OnModelCreating(ModelBuilder builder) =>
    builder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
```

`ApplyConfigurationsFromAssembly` scans the assembly for all non-abstract, non-generic classes that implement `IEntityTypeConfiguration<T>` and calls their `Configure` method. Zero maintenance: new configuration classes are picked up automatically.

**Option 2 — Manual registration (explicit):**

```csharp
protected override void OnModelCreating(ModelBuilder builder)
{
    builder.ApplyConfiguration(new OrderConfiguration());
    builder.ApplyConfiguration(new CustomerConfiguration());
}
```

Verbose but avoids reflection — a minor consideration only in startup-critical code.

**Option 3 — `[EntityTypeConfiguration]` attribute (EF Core 7+):**

```csharp
[EntityTypeConfiguration(typeof(OrderConfiguration))]
public class Order { ... }
```

The configuration class is discovered when EF Core processes the entity type. Useful when you want co-location of entity and its configuration reference without full assembly scanning.

### Folder Structure

```
Infrastructure/
  Persistence/
    AppDbContext.cs
    Configurations/
      CustomerConfiguration.cs
      OrderConfiguration.cs
      OrderLineConfiguration.cs
      ProductConfiguration.cs
```

This makes the persistence layer highly navigable. Each file has a single responsibility: map one entity type.

### Scoped Configuration Logic

Sometimes configuration must be environment-specific or parameterised. Pass parameters via the configuration class constructor:

```csharp
public sealed class OrderConfiguration(string schema) : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.ToTable("orders", schema);  // e.g., "tenant_a"."orders"
    }
}

// Registration with parameters — must use manual registration:
protected override void OnModelCreating(ModelBuilder builder)
{
    builder.ApplyConfiguration(new OrderConfiguration(_tenantSchema));
}
```

### Bulk Convention Configuration (EF Core 7+)

For cross-cutting conventions (e.g., all `string` properties max 256 characters), use `ConfigureConventions`:

```csharp
protected override void ConfigureConventions(ModelConfigurationBuilder conventions)
{
    conventions.Properties<string>().HaveMaxLength(256);
    conventions.Properties<decimal>().HavePrecision(19, 4);
}
```

This runs before individual configurations and sets defaults, which `IEntityTypeConfiguration<T>` can then override per-property.

## Code Example

```csharp
// AppDbContext.cs
namespace MyApp.Infrastructure.Persistence;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Order>    Orders    => Set<Order>();
    public DbSet<Customer> Customers => Set<Customer>();
    public DbSet<Product>  Products  => Set<Product>();

    protected override void ConfigureConventions(ModelConfigurationBuilder conventions)
    {
        // Cross-cutting defaults — override per-entity when needed
        conventions.Properties<string>().HaveMaxLength(256);
        conventions.Properties<decimal>().HavePrecision(19, 4);
    }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        // One call auto-discovers all IEntityTypeConfiguration<T> in this assembly
        builder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}

// Configurations/OrderConfiguration.cs
public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.ToTable("orders");

        builder.HasKey(o => o.Id);

        builder.Property(o => o.Reference)
               .IsRequired()
               .HasMaxLength(50);       // overrides the 256 default for this property

        builder.Property(o => o.Total)
               .HasPrecision(19, 4);    // matches the convention default — explicit for clarity

        // Shadow property: created_at stored in DB, not in domain model
        builder.Property<DateTimeOffset>("CreatedAt")
               .HasDefaultValueSql("SYSDATETIMEOFFSET()");

        builder.HasMany(o => o.Lines)
               .WithOne(l => l.Order)
               .HasForeignKey(l => l.OrderId)
               .OnDelete(DeleteBehavior.Cascade);
    }
}
```

## Common Follow-up Questions

- What is the execution order when both `ConfigureConventions` and `IEntityTypeConfiguration<T>` configure the same property?
- How does `ApplyConfigurationsFromAssembly` handle generic entity configuration classes (e.g., `AuditableEntityConfiguration<T>`)? Does it pick them up?
- Can you apply the same configuration interface for entities that live in a different assembly (e.g., Domain assembly)?
- How do you test that entity configurations are correct without spinning up a real database?
- Is there a performance difference between assembly scanning and manual `ApplyConfiguration` calls?

## Common Mistakes / Pitfalls

- **Forgetting `ApplyConfigurationsFromAssembly`**: Configuration classes are silently ignored — EF Core falls back to conventions, causing subtle mapping differences discovered only at runtime.
- **Abstract or generic configuration classes are skipped**: `ApplyConfigurationsFromAssembly` only instantiates concrete, non-generic types. A base `AuditableEntityConfiguration<T>` won't be applied directly — subclass it for each entity.
- **Mixing `OnModelCreating` inline code with configuration classes**: If you call `builder.Entity<Order>(...)` inline AND have an `OrderConfiguration`, the inline code runs first and the configuration class may override it (or not, depending on order) — choose one approach and stick to it.
- **Not calling `base.OnModelCreating(builder)`**: Not needed for plain `DbContext` but required if you inherit from a library base class (e.g., `IdentityDbContext`) — failing to call it silently omits Identity's model setup.

## References

- [IEntityTypeConfiguration — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.entityframeworkcore.ientitytypeconfiguration-1)
- [Bulk configuration — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/bulk-configuration)
- [EF Core model creation — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/)
- [See: data-annotations-vs-fluent-api.md](./data-annotations-vs-fluent-api.md)
