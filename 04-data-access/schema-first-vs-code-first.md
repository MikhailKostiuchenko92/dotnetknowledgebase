# Schema-First vs Code-First Development

**Category:** Data Access / Migrations & Schema Management
**Difficulty:** 🔴 Senior
**Tags:** `code-first`, `database-first`, `schema-first`, `EF Core scaffolding`, `migrations`, `DDD`

## Question

> What is the difference between code-first and database-first (schema-first) approaches with EF Core? What are the trade-offs of each, and when would you choose database-first over code-first in a .NET project?

## Short Answer

**Code-first**: you define C# model classes and EF Core migrations generate and evolve the database schema. The code is the source of truth. **Database-first** (schema-first): you design the schema directly in SQL or a migration tool, then reverse-engineer (scaffold) EF Core model classes from the existing database. The database is the source of truth. Code-first suits greenfield .NET applications where a developer owns both code and schema. Database-first suits legacy databases, DBA-owned schemas, or shared databases accessed by multiple applications where the schema was designed independently.

## Detailed Explanation

### Code-First Workflow

```csharp
// 1. Define model
public class Order
{
    public int Id { get; set; }
    public int CustomerId { get; set; }
    public decimal Total { get; set; }
    public string Status { get; set; } = "Pending";
}

// 2. Configure in DbContext
protected override void OnModelCreating(ModelBuilder model)
    => model.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

// 3. Generate migration
// dotnet ef migrations add InitialCreate
// → Generates Up()/Down() C# code → generates SQL schema

// 4. Apply
// dotnet ef database update
```

**Source of truth**: C# model + EF Core configuration  
**Schema evolution**: via `dotnet ef migrations add`  

### Database-First Workflow

```bash
# 1. Create schema manually in SQL Server Management Studio or via SQL scripts
# 2. Scaffold EF Core model from existing database
dotnet ef dbcontext scaffold \
    "Server=...;Database=LegacyApp;" \
    Microsoft.EntityFrameworkCore.SqlServer \
    --output-dir Models \
    --context AppDbContext \
    --use-database-names \       # preserve exact column names from DB
    --no-onconfiguring           # don't put connection string in generated context
```

Generated output:
```csharp
// Auto-generated — regenerated each time you re-scaffold
public partial class Order
{
    public int Id { get; set; }
    public int CustomerId { get; set; }
    public decimal Total { get; set; }
    public string? Status { get; set; }
    public virtual Customer Customer { get; set; } = null!;
}
```

**Source of truth**: database schema  
**Schema evolution**: SQL scripts (by DBAs or DbUp/Flyway), then re-scaffold  

### When to Choose Database-First

| Scenario | Database-First | Code-First |
|----------|---------------|-----------|
| Legacy database predates .NET app | ✅ | ❌ |
| DBA team owns and evolves the schema | ✅ | ❌ |
| Multiple apps access the same database | ✅ | ❌ (who owns migrations?) |
| Schema requires complex T-SQL (partitioning, computed columns) | ✅ | Awkward |
| Greenfield .NET app, developer owns schema | ❌ | ✅ |
| EF Core migrations for CI/CD | ❌ (re-scaffold instead) | ✅ |
| DDD aggregate design drives schema | ❌ | ✅ |

### Partial Classes — Customizing Scaffolded Models

Scaffolded models use `partial` classes, allowing customization without being overwritten on re-scaffold:

```csharp
// Auto-generated (overwritten on re-scaffold)
public partial class Order
{
    public int Id { get; set; }
    public string? Status { get; set; }
}

// Your customizations (never overwritten — separate file)
public partial class Order
{
    // Domain logic added manually
    public bool IsPending => Status == "Pending";

    public void MarkShipped()
    {
        if (Status != "Processing")
            throw new InvalidOperationException("Can only ship processing orders");
        Status = "Shipped";
    }
}
```

### Mixed Approach — Schema-First Writes, EF Core Reads

Some teams use database-first for the schema (managed by DBAs with FluentMigrator/DbUp) and code-first EF Core scaffolding for read-only query models:

```csharp
// Read-only scaffolded context — AsNoTracking on all entities
public class ReadOnlyDbContext(DbContextOptions<ReadOnlyDbContext> options)
    : DbContext(options)
{
    // All DbSets are marked AsNoTracking by convention
    protected override void OnModelCreating(ModelBuilder m)
    {
        m.HasDefaultSchema("dbo");
        base.OnModelCreating(m);
        foreach (var entity in m.Model.GetEntityTypes())
            entity.SetIsKeyless(false);  // Allow scalar projections
    }
}
```

## Code Example

```bash
# Scaffold specific tables (not the entire database)
dotnet ef dbcontext scaffold "Server=...;Database=LegacyApp;" \
    Microsoft.EntityFrameworkCore.SqlServer \
    --table Orders \
    --table Customers \
    --table OrderLines \
    --output-dir Data/Models \
    --context LegacyDbContext \
    --context-dir Data \
    --force  # overwrite existing files

# Re-scaffold after schema changes (idempotent with --force)
dotnet ef dbcontext scaffold ... --force
```

```csharp
// Preventing re-scaffold from overwriting domain logic:
// Keep all business methods in a separate partial class file
// that the scaffold command never touches.

// Orders.Generated.cs — overwritten by scaffold
public partial class Order { /* ... EF Core properties ... */ }

// Orders.cs — YOUR file, never touched by scaffold
public partial class Order
{
    public bool CanBeReturned =>
        Status == "Delivered" &&
        DateTime.UtcNow <= DeliveredAt?.AddDays(30);
}
```

## Common Follow-up Questions

- How do you keep scaffolded models synchronized with a frequently-changing legacy database?
- What happens to custom partial class methods when the scaffolded `partial class` is regenerated?
- How do you add indexes, query filters, or owned entities to a scaffolded EF Core model?
- Can you use EF Core migrations alongside database-first scaffolding?
- How does the `--use-database-names` flag affect FK navigation property naming?

## Common Mistakes / Pitfalls

- **Editing scaffolded files directly**: any changes to scaffolded files are overwritten the next time you run `dotnet ef dbcontext scaffold --force`. Use partial classes for customizations.
- **Using code-first migrations on a legacy database**: code-first migrations assume EF Core owns the entire schema. On a shared legacy database, running `dotnet ef database update` may attempt to recreate tables that already exist.
- **Not setting `--no-onconfiguring`**: by default, scaffolding writes the connection string into `OnConfiguring(...)` in the context file. This is a security risk — never commit connection strings. Use `--no-onconfiguring` and configure via DI.
- **Re-scaffolding entire database after every schema change**: for large databases, full re-scaffold is slow and generates noise. Scaffold only the changed tables with `--table` and merge changes carefully.

## References

- [Reverse engineering (database-first) — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/scaffolding/)
- [Code-first vs database-first — EF Core docs](https://learn.microsoft.com/en-us/ef/core/managing-schemas/)
- [See: ef-core-migrations-deep-dive.md](./ef-core-migrations-deep-dive.md)
- [See: dbup-and-fluentmigrator.md](./dbup-and-fluentmigrator.md)
