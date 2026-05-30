# Zero-Downtime Migrations

**Category:** Data Access / Migrations & Schema Management
**Difficulty:** 🟡 Middle
**Tags:** `migrations`, `zero-downtime`, `expand-contract`, `backwards-compatible`, `blue-green`, `rolling-deployment`

## Question

> How do you design database migrations that don't require taking the application offline? What is the expand-contract (parallel change) pattern, and what makes a migration "backwards-compatible"?

## Short Answer

Zero-downtime migrations require that both the **old and new version** of the application can run simultaneously against the same database. This is mandatory for rolling deployments (Kubernetes), Blue/Green, and canary releases. The **expand-contract** pattern splits a breaking migration into three phases: (1) **Expand** — add new structures without removing old ones (both versions work); (2) **Migrate** — deploy the new application version and backfill data; (3) **Contract** — remove old structures once the old version is fully gone. The key rule: never remove or rename a column in the same deployment that removes code using it.

## Detailed Explanation

### Why Standard Migrations Cause Downtime

A standard `ALTER TABLE Orders DROP COLUMN OldStatus` migration + new code deployment creates a window where:
- New code is deployed → queries that removed `OldStatus` succeed ✅
- Old code pods still running → queries that read `OldStatus` fail ❌ (column gone)

In a rolling deployment, old and new pods overlap for minutes or hours.

### The Expand-Contract Pattern

**Example: Rename `OrderStatus` to `Status` (breaking change)**

**Phase 1 — Expand (deploy migration alone, no code change)**:
```sql
-- Add the new column (old column still exists)
ALTER TABLE Orders ADD Status nvarchar(20) NOT NULL DEFAULT 'Pending';

-- Backfill: copy existing data to new column
UPDATE Orders SET Status = OrderStatus;

-- Optional trigger to keep both in sync during transition
CREATE TRIGGER tr_Orders_SyncStatus
ON Orders AFTER INSERT, UPDATE
AS
    UPDATE Orders
    SET Status = i.OrderStatus
    FROM Orders o JOIN inserted i ON o.Id = i.Id
    WHERE i.OrderStatus IS NOT NULL;
```

After this migration:
- Old code: reads `OrderStatus` ✅ (still there)
- New code (not yet deployed): reads `Status` ✅ (populated)

**Phase 2 — Deploy new application version**:

New code uses `Status` only. Old pods are gradually replaced. Both versions coexist briefly:
- Old pods: `SELECT OrderStatus FROM Orders` ✅
- New pods: `SELECT Status FROM Orders` ✅

**Phase 3 — Contract (after all old pods are gone)**:
```sql
-- Safe to remove after all old application instances are gone
DROP TRIGGER tr_Orders_SyncStatus;
ALTER TABLE Orders DROP COLUMN OrderStatus;
```

### Rules for Backwards-Compatible Migrations

| Migration | Backwards compatible? | Notes |
|----------|----------------------|-------|
| `ADD COLUMN NULL` | ✅ | Old code ignores new column |
| `ADD COLUMN NOT NULL DEFAULT x` | ✅ | Default handles old inserts |
| `ADD COLUMN NOT NULL` (no default) | ❌ | Old code inserts without the column → fails |
| `ADD TABLE` | ✅ | Old code doesn't know about new table |
| `DROP COLUMN` | ❌ | Old code still reads it |
| `RENAME COLUMN` | ❌ | Old code uses old name |
| `ADD INDEX` | ✅ (mostly) | Locking depends on `ONLINE = ON` |
| `DROP INDEX` | ✅ | Old code doesn't use index directly |
| `ADD CONSTRAINT NOT NULL` | ❌ | Old code may insert NULLs |
| `RENAME TABLE` | ❌ | Old code uses old name |

### Online Index Operations (SQL Server)

Index additions cause a schema modification lock that blocks reads/writes unless created with `ONLINE = ON`:

```sql
-- Blocking (default — takes schema lock, blocks reads/writes during build)
CREATE INDEX IX_Orders_Status ON Orders (Status);

-- ✅ Non-blocking — online build, reads/writes continue (Enterprise edition)
CREATE INDEX IX_Orders_Status ON Orders (Status) WITH (ONLINE = ON);
```

In EF Core migrations, use `migrationBuilder.Sql(...)` for custom DDL:
```csharp
protected override void Up(MigrationBuilder migrationBuilder)
{
    migrationBuilder.Sql(
        "CREATE INDEX IX_Orders_Status ON Orders (Status) WITH (ONLINE = ON)");
}
```

### EF Core — Adding a NOT NULL Column Safely

```csharp
// ❌ Breaking: adds NOT NULL column — old code can't insert (no default)
migrationBuilder.AddColumn<string>(
    name: "Reference",
    table: "Orders",
    nullable: false);

// ✅ Expand phase: nullable first (old code works)
migrationBuilder.AddColumn<string>(
    name: "Reference",
    table: "Orders",
    nullable: true,
    defaultValue: null);

// After all old code is replaced:
// Contract phase: add NOT NULL constraint in a subsequent migration
migrationBuilder.AlterColumn<string>(
    name: "Reference",
    table: "Orders",
    nullable: false,
    oldNullable: true);
```

## Code Example

```csharp
// Zero-downtime column rename: 3-migration approach
// Migration 1 (Expand): add Status, backfill from OrderStatus
public class AddStatusColumn : Migration
{
    protected override void Up(MigrationBuilder m)
    {
        m.AddColumn<string>("Status", "Orders", nullable: true);
        m.Sql("UPDATE Orders SET Status = OrderStatus");
        // Trigger to keep in sync during transition
        m.Sql("""
            CREATE TRIGGER tr_Orders_SyncStatus ON Orders AFTER INSERT, UPDATE AS
            UPDATE o SET o.Status = i.OrderStatus
            FROM Orders o INNER JOIN inserted i ON o.Id = i.Id
            """);
    }
    protected override void Down(MigrationBuilder m)
    {
        m.Sql("DROP TRIGGER IF EXISTS tr_Orders_SyncStatus");
        m.DropColumn("Status", "Orders");
    }
}

// After Phase 2 (app uses Status, all old pods retired):
// Migration 2 (Contract): remove old column + trigger
public class RemoveOrderStatusColumn : Migration
{
    protected override void Up(MigrationBuilder m)
    {
        m.Sql("DROP TRIGGER IF EXISTS tr_Orders_SyncStatus");
        m.DropColumn("OrderStatus", "Orders");
        // Make Status NOT NULL now that old code is gone
        m.AlterColumn<string>("Status", "Orders", nullable: false);
    }
}
```

## Common Follow-up Questions

- How do you handle zero-downtime migrations when the schema change requires a data transformation that takes hours?
- What is the "ghost table" pattern (used by gh-ost and pt-online-schema-change) and how does it compare to SQL Server's `ONLINE = ON`?
- How do you coordinate the three phases of expand-contract in a CI/CD pipeline?
- What is a "shadow column" and when is it used during zero-downtime renames?
- How do Blue/Green deployments change the expand-contract requirement compared to rolling updates?

## Common Mistakes / Pitfalls

- **Dropping a column and deploying the code change in the same pipeline stage**: this creates a downtime window even in "zero-downtime" deployments. Always separate the schema contract (drop) phase from the code change by at least one full deployment cycle.
- **Adding `NOT NULL` column without a default value**: SQL Server blocks the operation or requires a table rewrite (for older compatibility levels). Always add `DEFAULT` or use `NULL` first.
- **Forgetting to clean up the sync trigger**: a trigger left permanently in the database for a column migration that finished months ago wastes CPU on every INSERT/UPDATE.
- **Assuming Blue/Green deployments avoid expand-contract**: Blue and Green environments share the same database — both must be able to run simultaneously, so backwards compatibility is still required during the cutover window.

## References

- [Expand and Contract pattern — Microsoft Architecture blog](https://learn.microsoft.com/en-us/azure/architecture/patterns/) (verify URL)
- [Online index operations — SQL Server — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/perform-index-operations-online)
- [EF Core migration operations — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/operations)
- [See: migrations-in-production.md](./migrations-in-production.md)
- [See: migration-rollback-strategies.md](./migration-rollback-strategies.md)
