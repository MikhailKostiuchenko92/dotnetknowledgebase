# Migrations in Production

**Category:** Data Access / Migrations & Schema Management
**Difficulty:** 🟡 Middle
**Tags:** `EF Core`, `migrations`, `production`, `CD`, `migration-bundles`, `idempotent`, `startup`

## Question

> What are the risks of running `Database.MigrateAsync()` at application startup in production? What are the safer alternatives — migration bundles, idempotent scripts, and pre-deployment steps?

## Short Answer

Calling `Database.MigrateAsync()` at startup works for development but creates three production risks: (1) in multi-instance deployments (Kubernetes), multiple pods may race to apply the same migration; (2) long-running migrations block startup health checks, causing orchestrators to kill and restart the pod; (3) if the migration fails midway, the app starts with a partially-migrated schema. The safe production alternatives: **migration bundles** (self-contained executables) or **idempotent SQL scripts** run as a deployment step before rolling out new application instances. Both approaches separate schema migration from application deployment.

## Detailed Explanation

### The Startup Migration Problem

```csharp
// ❌ Risky in production
var app = builder.Build();
await app.Services.GetRequiredService<AppDbContext>().Database.MigrateAsync();
app.Run();
```

**Problem 1 — Race condition in multi-instance deployments**:
When K8s scales up 3 pods simultaneously, all 3 call `MigrateAsync`. EF Core uses an advisory lock (`sp_getapplock`) on SQL Server to serialize this, but the two waiting pods are blocked during startup → health checks fail → orchestrator kills them.

**Problem 2 — Long migration blocks startup**:
Adding a non-nullable column with a default to a 100M-row table takes minutes. During this time, the pod's liveness probe fails → pod is restarted → migration is killed → database may be in an inconsistent state.

**Problem 3 — Failed migration leaves app running against wrong schema**:
If the migration succeeds but the new code has a bug that prevents startup, you now have a migrated database but the old code is still deployed on healthy pods.

### Solution 1: Migration Bundles (Recommended for .NET 6+)

```bash
# Generate a self-contained migration bundle executable
dotnet ef migrations bundle \
    --project Infrastructure \
    --startup-project Api \
    --output ./efbundle \
    --self-contained           # includes .NET runtime — no SDK needed in target

# Run as a pre-deployment step in the CD pipeline (Dockerfile, K8s Job, etc.)
./efbundle --connection "Server=prod-sql;Database=App;..."
```

**Kubernetes pre-deployment Job:**
```yaml
# k8s/migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ef-migrations
spec:
  template:
    spec:
      containers:
        - name: migrations
          image: myapp-migrations:1.2.0
          env:
            - name: ConnectionStrings__Default
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: connection-string
      restartPolicy: OnFailure
```

The migration Job completes before the new Deployment rolls out — pods start against an already-migrated database.

### Solution 2: Idempotent SQL Script

```bash
# Generate idempotent script — safe to run multiple times
dotnet ef migrations script --idempotent --output migrations.sql
```

Run the script in the CD pipeline via `sqlcmd` or Azure DevOps SQL task:
```yaml
# Azure Pipelines step
- task: SqlAzureDacpacDeployment@1
  inputs:
    sqlFile: 'migrations.sql'
    serverName: '$(SQL_SERVER)'
    databaseName: '$(SQL_DB)'
    sqlUsername: '$(SQL_USER)'
    sqlPassword: '$(SQL_PASS)'
```

### Solution 3: Conditional Startup Migration (Last Resort)

If you must migrate at startup, add safeguards:

```csharp
// Migrate only in single-instance development/test scenarios
// Use a distributed lock for multi-instance scenarios
public static class MigrationExtensions
{
    public static async Task RunMigrationsAsync(this WebApplication app)
    {
        await using var scope = app.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var logger = scope.ServiceProvider
            .GetRequiredService<ILogger<AppDbContext>>();

        var pending = await db.Database.GetPendingMigrationsAsync();
        if (!pending.Any()) return;

        logger.LogInformation(
            "Applying {Count} pending migration(s)...", pending.Count());

        var sw = Stopwatch.StartNew();
        await db.Database.MigrateAsync();
        logger.LogInformation("Migrations applied in {Elapsed}ms", sw.ElapsedMilliseconds);
    }
}
```

### Comparison of Approaches

| Approach | Multi-instance safe | Long migration safe | Rollback | Complexity |
|----------|--------------------|--------------------|---------|------------|
| `MigrateAsync()` at startup | ⚠️ (advisory lock) | ❌ | Manual | Low |
| Migration bundle | ✅ (run once in Job) | ✅ | Manual | Medium |
| Idempotent SQL script | ✅ (idempotent) | ✅ | Manual | Medium |
| DbUp / Flyway | ✅ | ✅ | ✅ (versioned) | Medium |

## Code Example

```dockerfile
# Dockerfile — separate stage for migrations
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS migration-builder
WORKDIR /src
COPY . .
RUN dotnet ef migrations bundle \
    --project src/Infrastructure \
    --startup-project src/Api \
    --output /out/efbundle \
    --self-contained

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS migrations
WORKDIR /app
COPY --from=migration-builder /out/efbundle .
ENTRYPOINT ["./efbundle"]

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS app
# ... normal app build
```

```csharp
// Program.cs — never run migrations at startup in production; use environment check
if (app.Environment.IsDevelopment())
{
    // Convenient for local development — apply migrations automatically
    await app.RunMigrationsAsync();
}
// In production: migration bundle or script handles it in the CD pipeline
```

## Common Follow-up Questions

- How do you handle rolling deployments (Blue/Green, canary) when both old and new code are running against the same database schema?
- What is the "expand-contract" migration pattern, and how does it enable zero-downtime deployments?
- How do you run EF Core migrations in Azure App Service or Azure Container Apps?
- How do you test that a migration script runs correctly in an integration test?
- What is the difference between `dotnet ef database update` and a migration bundle?

## Common Mistakes / Pitfalls

- **Running migrations at startup in production without a distributed lock**: on Kubernetes with 3 replicas, the advisory lock in EF Core may work, but network timeouts or slow migrations can still cause pods to be recycled.
- **Generating migration bundles without `--self-contained` in environments without .NET SDK**: the bundle without `--self-contained` requires a matching .NET runtime installed — use `--self-contained` for Docker-based deployment.
- **Not validating the migration script in staging before production**: always run the idempotent script against a staging database that mirrors production data volume — a 5-minute migration on 1GB staging may take 45 minutes on 50GB production.
- **Using `Down()` migrations as a rollback strategy in production**: EF Core's auto-generated `Down()` often loses data (it drops columns, tables). Prefer point-in-time database restore or new forward-only migrations for rollback.

## References

- [Applying migrations — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying)
- [Migration bundles — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying#bundles)
- [EF Core migrations in CI/CD — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying#idempotent-sql-scripts)
- [See: ef-core-migrations-deep-dive.md](./ef-core-migrations-deep-dive.md)
- [See: zero-downtime-migrations.md](./zero-downtime-migrations.md)
