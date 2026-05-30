# EF Core Migrations

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `migrations`, `schema`, `database-versioning`, `ci-cd`, `migration-bundles`

## Question

> How do EF Core migrations work? What files are created by `Add-Migration`, and what is the model snapshot? How do you safely apply migrations in a CI/CD pipeline and production deployment?

## Short Answer

EF Core migrations are C# classes that record incremental schema changes as `Up()` and `Down()` methods. When you run `Add-Migration`, EF Core compares your current model against the `ModelSnapshot` — a complete representation of the last known model state — and generates only the delta. Migrations are applied with `Update-Database` locally or `dotnet ef database update` in pipelines; for production, the recommended approach is to generate an idempotent SQL script (`--idempotent`) or use **migration bundles** — a self-contained executable that applies pending migrations safely.

## Detailed Explanation

### What `Add-Migration` Produces

Running `dotnet ef migrations add AddOrderTable` creates three files:

```
Migrations/
  20240115120000_AddOrderTable.cs          ← Up() / Down()
  20240115120000_AddOrderTable.Designer.cs ← metadata snapshot at this migration
  AppDbContextModelSnapshot.cs             ← updated full-model snapshot
```

**The migration file:**

```csharp
public partial class AddOrderTable : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "Orders",
            columns: table => new
            {
                Id        = table.Column<int>(nullable: false)
                                 .Annotation("SqlServer:Identity", "1, 1"),
                Reference = table.Column<string>(maxLength: 50, nullable: false),
                Total     = table.Column<decimal>(precision: 19, scale: 4, nullable: false),
            },
            constraints: table => table.PrimaryKey("PK_Orders", x => x.Id));
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "Orders");
    }
}
```

**The model snapshot** (`AppDbContextModelSnapshot.cs`) is the authoritative record of what EF Core thinks the database looks like after all migrations are applied. `Add-Migration` diffs your current model against the snapshot — not against the live database.

### The `__EFMigrationsHistory` Table

EF Core creates a table called `__EFMigrationsHistory` in the target database. Each applied migration gets a row with its name and EF Core version. `Update-Database` checks this table to determine which migrations are pending.

### Applying Migrations: Options

| Method | Use case | Risk |
|--------|----------|------|
| `database update` CLI / PMC | Local dev | Fine |
| `context.Database.MigrateAsync()` at startup | Small apps, Docker | Risky in scaled deployments (race condition) |
| Idempotent SQL script | CI/CD, DBA review | Safe — DBA can review before apply |
| **Migration bundle** | Production / K8s init container | ✅ Recommended for production |

> **Warning:** `MigrateAsync()` at application startup is convenient but dangerous in a scaled deployment: multiple instances race to apply the same migration simultaneously, causing duplicate key errors in `__EFMigrationsHistory` or corrupted schema. Use a dedicated migration job (K8s Job, Azure DevOps task) instead.

### Idempotent SQL Script

```bash
dotnet ef migrations script --idempotent --output migrations.sql
```

Generates SQL with `IF NOT EXISTS` guards around each migration, making it safe to re-run. Ideal for review by DBAs before applying to production.

### Migration Bundles (EF Core 6+)

A bundle is a self-contained executable that applies pending migrations:

```bash
dotnet ef migrations bundle --output migrate.exe
```

Deploy `migrate.exe` alongside the application. Run it as an init container in Kubernetes or a pre-deployment step in Azure DevOps:

```yaml
# Kubernetes init container
initContainers:
  - name: migrate
    image: myapp:latest
    command: ["/app/migrate"]
    env:
      - name: ConnectionStrings__Default
        valueFrom:
          secretKeyRef: { name: db-secret, key: conn }
```

The bundle respects `__EFMigrationsHistory` — it only applies pending migrations.

### Rolling Back Migrations

**In development:**

```bash
dotnet ef database update <previous-migration-name>  # runs Down() methods
dotnet ef migrations remove                          # deletes the last migration file
```

**In production**: `Down()` methods are often incomplete or incorrect — especially for data migrations. The preferred strategy is:

1. Apply a new forward migration that undoes the change (expand-contract).
2. Use point-in-time database restore for catastrophic failures.

### Structuring Migrations in CI/CD

```yaml
# Azure DevOps example
steps:
  - script: |
      dotnet ef migrations bundle --project src/Infrastructure --startup-project src/Api \
        --output $(Build.ArtifactStagingDirectory)/migrate
    displayName: Build migration bundle

  - task: PublishBuildArtifacts@1
    inputs:
      pathToPublish: $(Build.ArtifactStagingDirectory)/migrate

# Release pipeline: run migrate before deploying application
```

## Code Example

```csharp
// ❌ Risky: MigrateAsync at startup in a multi-replica deployment
var app = builder.Build();
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();   // race condition with other replicas
}

// ✅ Safe: dedicated migration step via bundle or EnsureCreated for dev-only
// In dev/test only (no migrations needed, schema recreated each time):
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.EnsureCreatedAsync();  // dev only — does NOT use migrations
}

// Adding a data migration inside a schema migration:
public partial class SeedInitialData : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        // Schema change first
        migrationBuilder.AddColumn<string>(
            name: "Status",
            table: "Orders",
            maxLength: 20,
            nullable: false,
            defaultValue: "Pending");

        // Data backfill via raw SQL (safe in migrations — runs in same transaction)
        migrationBuilder.Sql("""
            UPDATE Orders
            SET    Status = 'Completed'
            WHERE  CompletedAt IS NOT NULL
            """);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(name: "Status", table: "Orders");
    }
}
```

## Common Follow-up Questions

- What is the difference between `EnsureCreated` and `Migrate`/`MigrateAsync`, and when should you use each?
- How do you handle long-running data migrations that cannot fit in a single transaction without locking the table?
- What happens if two developers create migrations from the same snapshot — how do you resolve the conflict?
- How do you run migrations against multiple databases (e.g., in a multi-tenant scenario with per-tenant DBs)?
- What is the expand-contract pattern for zero-downtime schema changes?

## Common Mistakes / Pitfalls

- **`MigrateAsync` in multi-instance startup**: Race condition between instances applying the same migration. Use a pre-deployment migration step.
- **Editing migration files after they've been applied**: If a migration is already in `__EFMigrationsHistory`, changing its `Up()` has no effect and confuses the snapshot. Create a new migration instead.
- **Merging conflicting migrations**: When two branches both add migrations from the same snapshot, `Add-Migration` on merge will generate a migration with no changes or incorrect deltas — you must manually merge and re-snapshot.
- **Long-running data migrations in `Up()`**: A data migration touching millions of rows inside `Up()` holds a transaction lock for the entire duration, causing timeouts. Run large data migrations as a separate offline step.
- **Relying on `Down()` for production rollback**: EF Core generates `Down()` for schema rollbacks, but it doesn't reverse data migrations or handle complex rename operations — never rely on `Down()` as your rollback strategy in production.

## References

- [Migrations overview — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/)
- [Applying migrations — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying)
- [Migration bundles — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying#bundles)
- [See: zero-downtime-migrations.md](./zero-downtime-migrations.md)
- [See: migrations-in-production.md](./migrations-in-production.md)
