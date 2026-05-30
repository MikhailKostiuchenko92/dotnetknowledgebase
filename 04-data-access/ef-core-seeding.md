# EF Core Data Seeding

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `seeding`, `HasData`, `migrations`, `test-data`

## Question

> What are the different ways to seed data in EF Core? When should you use `HasData`, a custom migration, or an application-level seeder — and what are the limitations of each approach?

## Short Answer

EF Core offers three seeding mechanisms: `HasData` bakes seed data directly into migrations and is best for static reference data; custom SQL in migrations handles complex backfills or environment-agnostic one-off changes; and application-level seeders (code that runs at startup) work best for dev/test environment data or data that depends on runtime state. `HasData` has strict limitations — it cannot reference navigations, requires hard-coded PKs, and every change regenerates a migration — so it's unsuitable for large or frequently evolving datasets.

## Detailed Explanation

### `HasData` — Model Seed Data

Configured in `IEntityTypeConfiguration<T>` or `OnModelCreating`:

```csharp
public sealed class RoleConfiguration : IEntityTypeConfiguration<Role>
{
    public void Configure(EntityTypeBuilder<Role> builder)
    {
        builder.HasData(
            new Role { Id = 1, Name = "Admin" },
            new Role { Id = 2, Name = "User" },
            new Role { Id = 3, Name = "ReadOnly" });
    }
}
```

EF Core tracks this data in the model snapshot. When you run `Add-Migration`, it generates `InsertData` / `UpdateData` / `DeleteData` calls for any changes.

**When to use:** Static, rarely-changing reference data — status codes, roles, countries, currencies. The PKs must be hard-coded (no auto-generated values) so EF Core can diff them.

**Limitations:**

| Limitation | Detail |
|-----------|--------|
| Hard-coded PKs required | Cannot use `IDENTITY`/auto-increment — you must supply values manually |
| No navigation properties | Cannot seed via navigation; must set FK values directly |
| No environment-specific data | Same seed data goes to dev, staging, and production |
| Every change = new migration | Modifying seed data forces a migration, cluttering history |
| No complex logic | Cannot call services, generate hashes, or use runtime state |

### Migration SQL Seeding

For one-off data backfills or initial population during a schema change, add raw SQL inside a migration:

```csharp
public partial class SeedCountries : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("""
            INSERT INTO Countries (Code, Name) VALUES
              ('US', 'United States'),
              ('GB', 'United Kingdom'),
              ('DE', 'Germany')
            ON CONFLICT (Code) DO NOTHING;   -- idempotent for re-runs
            """);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql("DELETE FROM Countries WHERE Code IN ('US','GB','DE');");
    }
}
```

**When to use:** Large static datasets, data that needs to be idempotent, or backfilling data alongside a schema change.

### Application-Level Seeder

An interface + implementation that runs at startup (or on a specific condition):

```csharp
public interface IDbSeeder
{
    Task SeedAsync(CancellationToken ct = default);
}

public sealed class DevelopmentSeeder(AppDbContext db) : IDbSeeder
{
    public async Task SeedAsync(CancellationToken ct = default)
    {
        // Idempotent: only seed if no customers exist
        if (await db.Customers.AnyAsync(ct))
            return;

        db.Customers.AddRange(
            new Customer { Name = "ACME Corp", Email = "acme@example.com" },
            new Customer { Name = "Globex Inc", Email = "globex@example.com" });

        await db.SaveChangesAsync(ct);
    }
}
```

Register and invoke at startup:

```csharp
// Program.cs
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var seeder = scope.ServiceProvider.GetRequiredService<IDbSeeder>();
    await seeder.SeedAsync();
}
```

**When to use:** Dev/test data, data that depends on other seeded data, data requiring password hashing or ID generation, environment-specific datasets.

### Comparison

| Approach | Static reference data | Dev/test data | Complex logic | Change tracking | New migration per change |
|----------|-----------------------|---------------|---------------|-----------------|--------------------------|
| `HasData` | ✅ | ❌ | ❌ | ✅ (EF diffs it) | ✅ (yes, every change) |
| Migration SQL | ✅ | ❌ | Limited | ❌ (raw SQL) | One migration per batch |
| App-level seeder | ✅ | ✅ | ✅ | ✅ | ❌ (no migration needed) |

### Seeding with Identity (Password Hashing)

`HasData` cannot call services, so you cannot hash passwords at model build time. Use an application-level seeder:

```csharp
public sealed class AdminUserSeeder(AppDbContext db, IPasswordHasher<AppUser> hasher) : IDbSeeder
{
    public async Task SeedAsync(CancellationToken ct = default)
    {
        if (await db.Users.AnyAsync(u => u.Email == "admin@example.com", ct))
            return;

        var admin = new AppUser { Email = "admin@example.com" };
        admin.PasswordHash = hasher.HashPassword(admin, "ChangeMe123!");
        db.Users.Add(admin);
        await db.SaveChangesAsync(ct);
    }
}
```

## Code Example

```csharp
// Static reference data — use HasData
public sealed class OrderStatusConfiguration : IEntityTypeConfiguration<OrderStatus>
{
    // EF Core requires hard-coded PKs for HasData
    private static readonly OrderStatus[] Statuses =
    [
        new() { Id = 1, Code = "Pending",    Label = "Pending" },
        new() { Id = 2, Code = "Processing", Label = "Processing" },
        new() { Id = 3, Code = "Shipped",    Label = "Shipped" },
        new() { Id = 4, Code = "Delivered",  Label = "Delivered" },
        new() { Id = 5, Code = "Cancelled",  Label = "Cancelled" },
    ];

    public void Configure(EntityTypeBuilder<OrderStatus> builder)
    {
        builder.HasKey(s => s.Id);
        builder.Property(s => s.Code).HasMaxLength(20).IsRequired();
        builder.Property(s => s.Label).HasMaxLength(50).IsRequired();
        builder.HasData(Statuses);
    }
}

// Dev environment sample data — use application-level seeder
public sealed class SampleOrderSeeder(AppDbContext db) : IDbSeeder
{
    public async Task SeedAsync(CancellationToken ct = default)
    {
        if (await db.Orders.AnyAsync(ct)) return;  // idempotent guard

        var customer = new Customer { Name = "Test Customer" };
        db.Customers.Add(customer);

        db.Orders.Add(new Order
        {
            Customer  = customer,          // navigation → EF Core sets FK automatically
            Reference = "TEST-001",
            Total     = 99.99m,
        });

        await db.SaveChangesAsync(ct);
    }
}
```

## Common Follow-up Questions

- How do you seed data in integration tests without polluting the production migration history?
- If you change a `HasData` entry, what does the generated migration look like — is it an UPDATE or DELETE + INSERT?
- How do you implement idempotent application-level seeders that are safe to re-run on every deployment?
- What is the Bogus library and how does it help generate realistic test seed data?
- How do you seed owned entity types with `HasData`?

## Common Mistakes / Pitfalls

- **Auto-generated PKs with `HasData`**: Using `HasData` for an entity where the PK is auto-generated by the database — EF Core will complain that the value is not provided. Supply explicit PK values.
- **Seeding via navigation properties in `HasData`**: Setting `order.Customer = new Customer()` inside `HasData` throws; you must set the FK directly: `order.CustomerId = 1`.
- **Non-idempotent app seeders**: An application seeder that doesn't check whether data already exists will duplicate rows on every restart.
- **`HasData` for frequently-changing reference data**: Adds a new migration every time an item is added/changed/removed — clutters migration history. Use a seeder or a separate admin screen instead.
- **Running seeders in production unconditionally**: Dev/test data seeders triggered in production populate the live database with fake data. Gate seeders behind `IHostEnvironment.IsDevelopment()` checks.

## References

- [Data seeding — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/modeling/data-seeding)
- [Migrations with data — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/managing#adding-raw-sql-in-a-migration)
- [See: ef-core-migrations.md](./ef-core-migrations.md)
- [See: testcontainers-for-data-access.md](./testcontainers-for-data-access.md)
