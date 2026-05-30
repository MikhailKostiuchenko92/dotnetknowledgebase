# Migration Rollback Strategies

**Category:** Data Access / Migrations & Schema Management
**Difficulty:** 🔴 Senior
**Tags:** `migrations`, `rollback`, `Down()`, `point-in-time-restore`, `expand-contract`, `disaster-recovery`

## Question

> Why is EF Core's auto-generated `Down()` method unreliable for production rollback? What are safer rollback strategies for database schema changes — point-in-time restore, forward-only migrations, and the expand-contract approach?

## Short Answer

EF Core's auto-generated `Down()` methods are unreliable for production rollback because: (1) `Down()` for a `DROP COLUMN` migration does NOT restore the data that was deleted; (2) complex custom migrations (data transforms, stored procedures) have hand-written `Up()` but auto-generated `Down()` that may be incorrect or destructive; (3) `Down()` is almost never tested. The safe rollback strategies are: **point-in-time database restore** (for catastrophic failures), **expand-contract migrations** (for planned zero-downtime changes), and **forward-only compensating migrations** (write a new migration that undoes the previous change, preserving data).

## Detailed Explanation

### Why `Down()` Is Dangerous

```csharp
// Migration: Add Status column + populate it
protected override void Up(MigrationBuilder m)
{
    m.AddColumn<string>("Status", "Orders", nullable: false, defaultValue: "New");
    m.Sql("UPDATE Orders SET Status = 'Pending' WHERE CreatedDate < '2024-01-01'");
    m.Sql("UPDATE Orders SET Status = 'Active' WHERE CreatedDate >= '2024-01-01'");
}

// Auto-generated Down() — drops the column, DESTROYING all Status data
protected override void Down(MigrationBuilder m)
{
    m.DropColumn("Status", "Orders");
    // ← 10 million rows of Status data, gone forever
}
```

Even if `Down()` is syntactically correct, it loses the data that `Up()` wrote.

### Strategy 1: Point-in-Time Restore

For Azure SQL or SQL Server with automated backups, rollback = restore the database to a point before the migration ran:

```
T-30min: Database backup / automated restore point taken by Azure
T-0: Migration applied + new app deployed
T+5min: Critical bug discovered — data corruption
T+6min: Database restored to T-30min snapshot
T+8min: Previous app version redeployed
```

**Pros**: complete rollback of both schema and data  
**Cons**: all data written after the restore point is lost (orders, payments, user actions between T-30min and T+6min are gone)

This is appropriate for catastrophic failures but not routine deployments.

### Strategy 2: Forward-Only Compensating Migration

Instead of running `Down()`, write a new migration that undoes the change:

```csharp
// Original migration failed or needs rollback
// 20240315_AddBadColumn.cs → created column, bad idea

// ❌ Don't run Down() in production
// ✅ Write a compensating migration
// 20240316_RemoveBadColumn.cs
protected override void Up(MigrationBuilder m)
{
    // This is the "rollback" — a forward migration that undoes the previous one
    m.DropColumn("BadColumn", "Orders");
    // Restore any data that was transformed, if possible
}

protected override void Down(MigrationBuilder m)
{
    // Re-apply the original change if needed
    m.AddColumn<string>("BadColumn", "Orders", nullable: true);
}
```

**Pros**: explicit, tested, tracked in migration history  
**Cons**: migration history shows the "mistake" — but that's better than data loss

### Strategy 3: Expand-Contract (Prevents the Need for Rollback)

The best rollback strategy is designing migrations so rollback is rarely needed:
- **Expand phase** (additive only): run before deployment. Old code still works.
- If the deployment fails: run the **Contract** migration to clean up (pure DROP, no data loss because data was never moved).

```csharp
// Expand: add new nullable column — safe to roll back by dropping it
protected override void Up(MigrationBuilder m)
    => m.AddColumn<string>("NewReference", "Orders", nullable: true);

// If deploy fails, roll back by removing the empty column (no data loss)
protected override void Down(MigrationBuilder m)
    => m.DropColumn("NewReference", "Orders");
```

The `Down()` method is only valid for **expand-phase migrations** (adding empty new structures). For data-transforming migrations, rollback requires a compensating forward migration.

### Decision Tree

```
Did the migration transform data?
├── Yes → Point-in-time restore OR compensating migration (data may be lossy)
└── No (additive only: add column, add table, add index)
    └── Run Down() OR compensating migration (safe, no data loss)
```

### Testing Rollback in Staging

```csharp
// Integration test: verify Down() is correct (for additive migrations)
[Fact]
public async Task Down_RemovesAddedColumn()
{
    await using var scope = _factory.Services.CreateAsyncScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

    // Apply Up
    await db.Database.MigrateAsync();

    // Run Down (in test environment only — never in production)
    var migrator = db.GetService<IMigrator>();
    await migrator.MigrateAsync("PreviousMigrationName");

    // Verify column is gone
    var columns = await db.Database
        .SqlQueryRaw<string>(
            "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Orders'")
        .ToListAsync();
    Assert.DoesNotContain("Status", columns);
}
```

## Code Example

```csharp
// Safe migration with explicit rollback documentation
[Description("Adds OrderPriority column. Rollback: see 20240402_RemoveOrderPriority.cs")]
public class AddOrderPriority : Migration
{
    protected override void Up(MigrationBuilder m)
    {
        // Expand: nullable column — safe rollback by dropping (no data loss)
        m.AddColumn<int>("Priority", "Orders", nullable: true, defaultValue: null);
    }

    protected override void Down(MigrationBuilder m)
    {
        // Safe: column was nullable, no data loss
        m.DropColumn("Priority", "Orders");
    }
}

// Data migration — Down() CANNOT restore transformed data
[Description("Populates OrderPriority. Rollback: compensating migration 20240403_ClearOrderPriority.cs")]
public class BackfillOrderPriority : Migration
{
    protected override void Up(MigrationBuilder m)
    {
        m.Sql("""
            UPDATE Orders
            SET Priority = CASE
                WHEN Total > 1000 THEN 1
                WHEN Total > 100  THEN 2
                ELSE 3
            END
            """);
    }

    protected override void Down(MigrationBuilder m)
    {
        // ⚠️ Data is non-recoverable — we don't know original values
        // Compensating migration must handle this case explicitly
        // m.Sql("UPDATE Orders SET Priority = NULL"); -- only if null = acceptable rollback
        throw new NotSupportedException(
            "This migration cannot be automatically reversed. " +
            "Use compensating migration 20240403_ClearOrderPriority.");
    }
}
```

## Common Follow-up Questions

- How do you implement database backup before each migration run in CI/CD?
- When should you use `migrationBuilder.Sql(...)` inside a transaction, and when should you avoid it?
- How does SQL Server's `BEGIN/ROLLBACK TRANSACTION` around DDL statements work — can you always wrap migrations in a transaction?
- What is the `CHECKDB` command, and when would you run it as part of a rollback assessment?
- How does Azure SQL's "accelerated database recovery" affect long transaction rollback scenarios?

## Common Mistakes / Pitfalls

- **Assuming `Down()` is always tested**: auto-generated `Down()` methods often have bugs or are destructive. Teams discover this only after running them in production. Integration test `Down()` for every migration.
- **Using `Down()` to roll back a data migration**: `Down()` can restore schema structure, but it cannot restore data that was deleted, transformed, or overwritten by `Up()`. Use point-in-time restore for data recovery.
- **Not testing rollback scenarios at all**: most teams only test the "happy path" (migration applied). Rollback is tested for the first time during an incident — the worst possible moment.
- **Wrapping all DDL in one transaction**: SQL Server supports transactional DDL for most operations, but some (`CREATE FULLTEXT INDEX`, partitioning operations) cannot run inside a transaction. Check compatibility before relying on rollback via transaction.

## References

- [Applying EF Core migrations — rollback — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying)
- [Point-in-time restore — Azure SQL — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-sql/database/recovery-using-backups)
- [See: zero-downtime-migrations.md](./zero-downtime-migrations.md)
- [See: migrations-in-production.md](./migrations-in-production.md)
