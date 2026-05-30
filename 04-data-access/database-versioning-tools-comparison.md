# Database Versioning Tools Comparison

**Category:** Data Access / Migrations & Schema Management
**Difficulty:** 🔴 Senior
**Tags:** `EF Core migrations`, `DbUp`, `Flyway`, `Liquibase`, `database-versioning`, `state-based`, `migration-based`

## Question

> How do EF Core Migrations, DbUp, Flyway, and Liquibase differ in their philosophy and approach to database schema management? What is the difference between state-based and migration-based database versioning?

## Short Answer

**Migration-based** tools (DbUp, Flyway, Liquibase, EF Core Migrations) apply sequential, versioned change scripts — the history of how the schema arrived at its current state is preserved. **State-based** tools (SSDT, Redgate SQL Compare) define the desired end-state and generate a diff script to transition from the current schema. Migration-based is better for teams with incremental changes and CI/CD pipelines. State-based is better for declaring schema as code without managing migration order. EF Core Migrations is migration-based but generates C# code from model diffs; DbUp/Flyway/Liquibase use plain SQL or DSL scripts — better for DBA-owned or polyglot (non-.NET) environments.

## Detailed Explanation

### Migration-Based vs State-Based

| Philosophy | Migration-based | State-based |
|-----------|----------------|------------|
| Source of truth | Ordered sequence of change scripts | Desired final schema state |
| How it applies changes | Run each migration once | Diff current vs desired → apply diff |
| Schema history | Preserved (audit trail) | Only final state |
| Conflict resolution | Merge conflicts in script files | Diff tool handles automatically |
| Examples | EF Core, DbUp, Flyway, Liquibase | SSDT, Redgate SQL Compare |
| CI/CD fit | ✅ (versioned scripts) | ✅ (but diff generation can fail) |
| DBA familiarity | Varies | High (visual diff tools) |

### Tool Comparison

| Feature | EF Core Migrations | DbUp | Flyway | Liquibase |
|---------|-------------------|------|--------|-----------|
| Language | C# (model diff) | SQL scripts | SQL / Java | SQL / XML / YAML / JSON |
| ORM coupling | Yes (EF Core required) | None | None | None |
| .NET first-class | ✅ | ✅ | ❌ (JVM) | ❌ (JVM) |
| Auto-generated migrations | ✅ | ❌ | ❌ | ❌ |
| Rollback support | `Down()` (unreliable) | Manual | ✅ (undo scripts) | ✅ (`rollback` command) |
| Multi-DB support | ✅ (EF Core providers) | ✅ | ✅ | ✅ |
| Script format | C# | `.sql` | `.sql` | `.sql`, `.xml`, `.yaml` |
| Journal / history table | `__EFMigrationsHistory` | `SchemaVersions` | `flyway_schema_history` | `DATABASECHANGELOG` |
| Team adoption curve | High (EF Core knowledge) | Low | Low | Medium |
| CI/CD pipeline integration | ✅ dotnet CLI | ✅ .NET API / CLI | ✅ CLI / Docker | ✅ CLI / Docker |

### Flyway (Most Widely Used in Polyglot Teams)

Flyway uses versioned SQL scripts with naming conventions:

```
db/migration/
├── V1__Create_schema.sql         ← versioned (run once)
├── V2__Add_orders_table.sql
├── V3__Add_status_column.sql
└── R__Refresh_reporting_view.sql ← repeatable (re-run when changed)
```

```bash
# Apply migrations via Docker (no JVM needed)
docker run --rm flyway/flyway:10 \
    -url=jdbc:sqlserver://sql-server:1433;databaseName=App \
    -user=sa -password=Secret1234 \
    -locations=filesystem:/sql \
    migrate
```

### When to Choose Each Tool

| Situation | Recommended tool |
|-----------|----------------|
| .NET app, EF Core ORM, developer-owned schema | EF Core Migrations |
| .NET app, Dapper/ADO.NET, developer writes SQL | DbUp |
| DBA-owned schema, team uses SQL IDEs | DbUp or Flyway |
| Polyglot team (.NET + Java + Python) | Flyway or Liquibase |
| Compliance-heavy environment with full audit trail | Liquibase |
| Complex rollback requirements | Flyway (undo scripts) or Liquibase |
| Greenfield .NET microservice | EF Core Migrations (default choice) |

### EF Core Migrations in Practice

EF Core Migrations are the default for .NET teams because:
- Schema changes come from model changes — no manual SQL to write
- Strongly typed, compile-time safe
- Integrated with `dotnet ef` CLI
- Good tooling support (SSMS, Rider, VS)

But EF Core Migrations struggle when:
- The database is shared with non-.NET applications
- DBAs need to review and approve SQL before deployment
- Migrations require complex T-SQL (cursors, temp tables, TVPs)

## Code Example

```csharp
// DbUp in .NET — alternative to EF Core Migrations for Dapper-based apps
public static class DatabaseMigrator
{
    public static void Upgrade(string connectionString)
    {
        EnsureDatabase.For.SqlDatabase(connectionString);

        var upgrader = DeployChanges.To
            .SqlDatabase(connectionString)
            // Load scripts from embedded resources in this assembly
            .WithScriptsEmbeddedInAssembly(
                typeof(DatabaseMigrator).Assembly,
                s => s.StartsWith("MyApp.Migrations."))
            .WithTransaction()
            .LogToConsole()
            .Build();

        var result = upgrader.PerformUpgrade();

        if (!result.Successful)
            throw new Exception($"Migration failed: {result.Error.Message}");

        Console.WriteLine("Migration successful");
    }
}
```

```dockerfile
# Flyway in CI/CD — no .NET SDK dependency
FROM flyway/flyway:10 AS flyway
COPY db/migration/ /flyway/sql/
ENTRYPOINT ["flyway", "migrate"]
```

## Common Follow-up Questions

- How do you handle branching in migration-based systems when two feature branches both add a migration?
- What is Liquibase's `changeset` concept, and how does it differ from Flyway's versioned scripts?
- How do you integrate Flyway or Liquibase with an Azure DevOps or GitHub Actions pipeline?
- What is the SSDT (SQL Server Data Tools) approach, and when is it preferred over migration scripts?
- How do you migrate from EF Core Migrations to DbUp in an existing project?

## Common Mistakes / Pitfalls

- **Editing an already-applied migration script (DbUp/Flyway)**: these tools track scripts by filename and checksum. Editing an applied script causes a checksum mismatch error on the next run — the script appears "corrupted". Never edit applied scripts; write a new one.
- **Assuming EF Core Migrations work without the EF Core ORM**: EF Core Migrations require the EF Core infrastructure. For Dapper-only apps, EF Core is a heavy dependency just for migration management — use DbUp instead.
- **Not committing migration scripts in the same PR as the code that requires them**: if code is deployed before its migration runs, the app starts against an incorrect schema. Always deploy migrations before application code.
- **Using EF Core Migrations in a DBA-controlled environment**: DBAs who don't know C# cannot review EF Core migration files effectively. Generating SQL scripts with `dotnet ef migrations script` for DBA review bridges the gap.

## References

- [EF Core Migrations — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/)
- [DbUp GitHub](https://github.com/DbUp/DbUp)
- [Flyway documentation](https://documentation.red-gate.com/flyway) (verify URL)
- [Liquibase documentation](https://docs.liquibase.com/) (verify URL)
- [See: dbup-and-fluentmigrator.md](./dbup-and-fluentmigrator.md)
- [See: migrations-in-production.md](./migrations-in-production.md)
