# EF Core Migrations Deep Dive

**Category:** Data Access / Migrations & Schema Management
**Difficulty:** 🟢 Junior
**Tags:** `EF Core`, `migrations`, `ModelSnapshot`, `migration-file`, `Up-Down`, `migration-history`, `idempotent`

## Question

> Walk me through the anatomy of an EF Core migration. What is the `ModelSnapshot`, what does the migration history table (`__EFMigrationsHistory`) track, and how do you generate an idempotent SQL migration script for a CI/CD pipeline?

## Short Answer

An EF Core migration is a pair of `Up()` / `Down()` methods that describe schema changes as C# code. When you run `Add-Migration`, EF Core compares the current model to the `ModelSnapshot` (a C# representation of the last-applied model) and generates the delta. The `__EFMigrationsHistory` table records which migration names have been applied to the database, so `Database.MigrateAsync()` only runs new migrations. Idempotent scripts (`--idempotent` flag) wrap each migration in an `IF NOT EXISTS` check, making them safe to re-run in CI/CD without failing if already applied.

## Detailed Explanation

### Migration File Anatomy

When you run `dotnet ef migrations add AddOrderStatus`, EF Core generates:

```
Migrations/
├── 20240315_AddOrderStatus.cs       ← the migration
└── AppDbContextModelSnapshot.cs     ← updated model snapshot
```

```csharp
// 20240315_AddOrderStatus.cs
public partial class AddOrderStatus : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Schema changes to apply
        migrationBuilder.AddColumn<string>(
            name: "Status",
            table: "Orders",
            type: "nvarchar(20)",
            nullable: false,
            defaultValue: "Pending");

        migrationBuilder.CreateIndex(
            name: "IX_Orders_Status",
            table: "Orders",
            column: "Status");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Reversal of Up() — used for rollback
        migrationBuilder.DropIndex(name: "IX_Orders_Status", table: "Orders");
        migrationBuilder.DropColumn(name: "Status", table: "Orders");
    }
}
```

### ModelSnapshot — The Migration Baseline

`AppDbContextModelSnapshot.cs` contains a C# representation of the **entire current model** (all tables, columns, relationships, indexes). It is regenerated every time a migration is added:

```csharp
[DbContext(typeof(AppDbContext))]
partial class AppDbContextModelSnapshot : ModelSnapshot
{
    protected override void BuildModel(ModelBuilder modelBuilder)
    {
        modelBuilder.HasAnnotation("ProductVersion", "8.0.0");

        modelBuilder.Entity("Order", b =>
        {
            b.Property<int>("Id").ValueGeneratedOnAdd();
            b.Property<string>("Status").HasMaxLength(20).IsRequired();
            // ... all current model properties
            b.HasKey("Id");
        });
        // ...
    }
}
```

`Add-Migration` compares `BuildModel(...)` output to your `DbContext.OnModelCreating(...)` and generates only the **delta** as the new migration's `Up()` / `Down()`.

### Migration History Table

`__EFMigrationsHistory` tracks applied migrations:

```sql
SELECT * FROM __EFMigrationsHistory;
-- MigrationId                              ProductVersion
-- 20240101_InitialCreate                   8.0.0
-- 20240215_AddCustomers                    8.0.0
-- 20240315_AddOrderStatus                  8.0.0
```

`Database.MigrateAsync()` reads this table and applies any migrations whose `MigrationId` is not present — skipping already-applied ones.

### Applying Migrations

```csharp
// On startup — applies all pending migrations
await app.Services.GetRequiredService<AppDbContext>()
         .Database.MigrateAsync();
// ⚠️ Risky in production: long migrations can cause startup timeouts.
// Prefer explicit migration scripts or migration bundles.
```

```bash
# CLI
dotnet ef database update

# Apply up to a specific migration
dotnet ef database update AddOrderStatus

# Rollback one migration
dotnet ef database update PreviousMigrationName
```

### Idempotent SQL Script — CI/CD Safe

```bash
# Generate a script that can be run multiple times safely
dotnet ef migrations script --idempotent --output migrations.sql

# From a specific migration to latest
dotnet ef migrations script 20240215_AddCustomers --idempotent
```

Generated script structure:
```sql
-- EF Core wraps each migration in IF NOT EXISTS
IF NOT EXISTS(SELECT * FROM [__EFMigrationsHistory]
              WHERE [MigrationId] = '20240315_AddOrderStatus')
BEGIN
    ALTER TABLE [Orders] ADD [Status] nvarchar(20) NOT NULL DEFAULT N'Pending';
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20240315_AddOrderStatus', N'8.0.0');
END;
```

This script is safe to run in CI/CD pipelines even if the migration was already applied.

### Migration Bundles (.NET 6+)

Migration bundles are self-contained executables that apply migrations:

```bash
# Create a bundle
dotnet ef migrations bundle --output ./efbundle

# Apply in CD pipeline (no .NET SDK required in the target environment)
./efbundle --connection "Server=prod-server;Database=App;"
```

Bundles are the recommended approach for production deployments — no startup-time migration risk.

## Code Example

```csharp
// Safe startup migration with health check guard
public static async Task ApplyMigrationsAsync(this WebApplication app)
{
    await using var scope = app.Services.CreateAsyncScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

    // Check if there are pending migrations before applying
    var pending = (await db.Database.GetPendingMigrationsAsync()).ToList();
    if (pending.Count == 0)
    {
        app.Logger.LogInformation("No pending EF Core migrations");
        return;
    }

    app.Logger.LogInformation(
        "Applying {Count} pending migration(s): {Migrations}",
        pending.Count,
        string.Join(", ", pending));

    await db.Database.MigrateAsync();
    app.Logger.LogInformation("Migrations applied successfully");
}
```

```bash
# Common migration CLI commands
dotnet ef migrations add <MigrationName> --project Infrastructure --startup-project Api
dotnet ef migrations list
dotnet ef migrations remove                          # remove last migration (if not applied)
dotnet ef database update                            # apply all pending
dotnet ef database update 0                          # roll back all migrations
dotnet ef migrations script --idempotent             # CI/CD safe SQL output
dotnet ef migrations bundle --self-contained         # self-contained executable
```

## Common Follow-up Questions

- Why should you not run `Database.MigrateAsync()` at application startup in production?
- How do you handle migrations in a multi-instance Kubernetes deployment where multiple pods start simultaneously?
- What happens to data when you drop a column via a migration — is it recoverable?
- How do you write custom raw SQL in a migration (e.g., to seed data or migrate existing data)?
- How do migration bundles differ from idempotent scripts — when would you prefer each?

## Common Mistakes / Pitfalls

- **Committing the `ModelSnapshot` changes without the migration**: `Add-Migration` generates both the migration file and updates the snapshot. Forgetting to commit the snapshot causes the next `Add-Migration` to generate incorrect deltas.
- **Running `Database.MigrateAsync()` at startup in multi-instance deployments**: two instances starting simultaneously can both try to apply the same migration — EF Core uses an advisory lock on SQL Server to serialize this, but it can cause startup delays.
- **Deleting migrations that have been applied to any database**: if a migration was applied to dev/staging, deleting it leaves those databases in an inconsistent state with the snapshot. Use `Down()` to reverse, or create a new migration to fix the schema.
- **Not testing `Down()` migrations**: `Down()` is often auto-generated and wrong for destructive changes (dropping data). Test rollback paths before relying on them.

## References

- [EF Core migrations overview — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/)
- [Migrations in team environments — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/teams)
- [Migration bundles — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying)
- [See: migrations-in-production.md](./migrations-in-production.md)
- [See: zero-downtime-migrations.md](./zero-downtime-migrations.md)
