# Data Annotations vs Fluent API

**Category:** Data Access / EF Core
**Difficulty:** 🟢 Junior
**Tags:** `ef-core`, `data-annotations`, `fluent-api`, `model-configuration`, `IEntityTypeConfiguration`

## Question

> What is the difference between data annotations and the Fluent API in EF Core? When would you choose one over the other, and what can only be done with the Fluent API?

## Short Answer

Data annotations are attributes placed directly on entity classes and properties (e.g., `[Required]`, `[MaxLength]`, `[Key]`); they are quick and co-located with the model, but they couple your domain entities to EF Core (or at least to `System.ComponentModel.DataAnnotations`). The Fluent API configures the model in `OnModelCreating` or `IEntityTypeConfiguration<T>` classes, keeping entities free of persistence concerns and enabling configurations that annotations cannot express — like composite keys, table splitting, owned entities, and query filters.

## Detailed Explanation

### Data Annotations

Annotations come from two namespaces:

- `System.ComponentModel.DataAnnotations` — `[Required]`, `[MaxLength]`, `[StringLength]`, `[Range]`, `[RegularExpression]`
- `System.ComponentModel.DataAnnotations.Schema` — `[Table]`, `[Column]`, `[ForeignKey]`, `[NotMapped]`, `[Index]`
- `Microsoft.EntityFrameworkCore` — `[Precision]`, `[Unicode]`, `[BackingField]`, `[EntityTypeConfiguration]`

**Pros:**
- Co-located with the model — easy to read at a glance.
- Works with both EF Core and ASP.NET Core model validation (e.g., `[Required]` is validated before the controller action runs).

**Cons:**
- Pollutes domain entities with persistence / UI concerns.
- Limited expressiveness — composite keys, owned types, many-to-many configuration require Fluent API.
- Cannot express filters, table splitting, or column ordering.

### Fluent API

Configured in `OnModelCreating` or via `IEntityTypeConfiguration<T>`:

```csharp
// Preferred: separate configuration class per entity
public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.ToTable("orders");
        builder.HasKey(o => o.Id);
        builder.Property(o => o.Reference).IsRequired().HasMaxLength(50);
        builder.Property(o => o.Total).HasPrecision(19, 4);
        builder.HasOne(o => o.Customer)
               .WithMany(c => c.Orders)
               .HasForeignKey(o => o.CustomerId)
               .OnDelete(DeleteBehavior.Restrict);
    }
}
```

**Pros:**
- Keeps domain entities clean (no persistence attributes).
- More expressive — can configure anything EF Core supports.
- Easier to test domain model independently.

**Cons:**
- Configuration is separated from the entity — you must jump to a different file to see column constraints.
- Slightly more verbose.

### What Only the Fluent API Can Do

| Configuration | Annotation | Fluent API |
|---------------|------------|------------|
| Composite primary key | ❌ | ✅ `.HasKey(e => new { e.A, e.B })` |
| Global query filter | ❌ | ✅ `.HasQueryFilter(e => !e.IsDeleted)` |
| Owned entity types | ❌ | ✅ `.OwnsOne()` / `.OwnsMany()` |
| Table splitting | ❌ | ✅ `.ToTable()` shared across entities |
| Alternate keys | ❌ | ✅ `.HasAlternateKey()` |
| Column ordering | ❌ | ✅ `.HasColumnOrder()` |
| Sequence generation | ❌ | ✅ `.HasDefaultValueSql("NEXT VALUE FOR ...")` |
| Shadow properties | ❌ | ✅ `.Property<DateTime>("CreatedAt")` |

### Recommended Approach for Clean Architecture

In a layered / Clean Architecture project, domain entities should live in the **Domain** layer, which must not depend on EF Core. Use `IEntityTypeConfiguration<T>` classes in the **Infrastructure** layer:

```
Domain/         ← no EF Core reference
  Order.cs      ← plain C# class

Infrastructure/ ← references EF Core
  Persistence/
    AppDbContext.cs
    Configurations/
      OrderConfiguration.cs   ← IEntityTypeConfiguration<Order>
```

The `Order` class stays a pure domain object; all persistence details live in `OrderConfiguration`.

### Mixing Both

You can mix annotations and Fluent API. Fluent API always wins if there is a conflict — it overrides any annotation. A practical middle ground: use annotations for validation (shared with ASP.NET Core model binding) and Fluent API for EF Core–specific configuration.

## Code Example

```csharp
// ❌ Annotation-heavy entity — domain polluted with persistence concerns
[Table("orders")]
public class Order
{
    [Key]
    public int Id { get; set; }

    [Required]
    [MaxLength(50)]
    public string Reference { get; set; } = string.Empty;

    [Precision(19, 4)]
    public decimal Total { get; set; }
}

// ✅ Clean entity — no EF Core dependencies
namespace MyApp.Domain.Orders;

public class Order
{
    public int Id { get; private set; }
    public string Reference { get; private set; } = string.Empty;
    public decimal Total { get; private set; }

    private Order() { }   // EF Core needs a parameterless ctor (can be private)

    public static Order Create(string reference, decimal total) =>
        new() { Reference = reference, Total = total };
}

// ✅ All persistence config in Infrastructure layer
namespace MyApp.Infrastructure.Persistence.Configurations;

public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.ToTable("orders");

        builder.HasKey(o => o.Id);

        builder.Property(o => o.Reference)
               .IsRequired()
               .HasMaxLength(50);

        builder.Property(o => o.Total)
               .HasPrecision(19, 4);
    }
}

// AppDbContext — auto-discovers all IEntityTypeConfiguration<T> in assembly
protected override void OnModelCreating(ModelBuilder builder) =>
    builder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
```

## Common Follow-up Questions

- Can data annotations be used for both EF Core validation and ASP.NET Core model validation simultaneously?
- How does `ApplyConfigurationsFromAssembly` discover configuration classes — what types does it scan for?
- If both an annotation and a Fluent API call configure the same property (e.g., both set max length), which wins?
- What is `[EntityTypeConfiguration]` attribute introduced in EF Core 7 and how does it differ?
- In Clean Architecture, should the Domain layer have any reference to EF Core at all?

## Common Mistakes / Pitfalls

- **Using `[Required]` on value types**: `int`, `bool`, `DateTime` are already non-nullable in the database — adding `[Required]` is redundant but harmless. On `string`, it adds `NOT NULL` constraint.
- **Forgetting to call `ApplyConfigurationsFromAssembly`**: Configuration classes are silently ignored if not registered, leading to EF Core falling back to conventions.
- **Putting `[Key]` on non-PK property**: If you also have `Id`, EF Core will use `[Key]` and ignore `Id`, causing subtle mapping bugs.
- **Conflating validation with mapping**: `[MaxLength]` affects the database column size; `[StringLength]` affects model validation (and optionally the column); they overlap but are not identical.
- **Domain entities depending on `Microsoft.EntityFrameworkCore`**: Even `[Precision]` and `[Unicode]` require an EF Core NuGet reference in your Domain project, which violates Clean Architecture boundaries — use Fluent API instead.

## References

- [Fluent API configuration — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/)
- [Data Annotations — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/entity-properties#data-annotations)
- [IEntityTypeConfiguration<T> — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.entityframeworkcore.ientitytypeconfiguration-1)
- [EF Core model bulk configuration — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/bulk-configuration)
