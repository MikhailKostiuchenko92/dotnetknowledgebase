# EF Core Logging and Diagnostics

**Category:** Data Access / EF Core
**Difficulty:** 🟡 Middle
**Tags:** `ef-core`, `logging`, `diagnostics`, `interceptors`, `sql-logging`, `MiniProfiler`, `sensitive-data`

## Question

> How do you log and diagnose SQL queries executed by EF Core? What options exist for SQL logging, query tagging, interceptors, and integrating with profiling tools like MiniProfiler?

## Short Answer

EF Core integrates with the standard .NET `ILogger` infrastructure — set the `Microsoft.EntityFrameworkCore.Database.Command` log level to `Information` to see all SQL in the application log. For development you can call `EnableSensitiveDataLogging()` to include parameter values. Query tags (`TagWith`) add comments to the SQL so queries are identifiable in the database's slow-query log or execution plan tools. `IDbCommandInterceptor` and `ISaveChangesInterceptor` provide programmatic hooks for auditing, caching, or telemetry. MiniProfiler integrates via its EF Core provider and shows per-request query counts and timing in the toolbar.

## Detailed Explanation

### Standard ILogger Integration

EF Core emits log events in several categories:

| Category | What it logs |
|----------|-------------|
| `Microsoft.EntityFrameworkCore.Database.Command` | SQL text + duration |
| `Microsoft.EntityFrameworkCore.Database.Connection` | Connection open/close |
| `Microsoft.EntityFrameworkCore.Query` | LINQ translation warnings, client evaluation |
| `Microsoft.EntityFrameworkCore.Update` | Batched UPDATE/INSERT/DELETE |

Set in `appsettings.Development.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Microsoft.EntityFrameworkCore.Database.Command": "Information"
    }
  }
}
```

### Sensitive Data Logging

By default, EF Core masks parameter values (shows `@p0 = '?'`) to prevent secrets appearing in logs. Enable parameter values in development only:

```csharp
services.AddDbContext<AppDb>(opt =>
    opt.UseSqlServer(connStr)
       .EnableSensitiveDataLogging()       // shows actual parameter values
       .EnableDetailedErrors());           // better exception messages for nulls
```

> **Warning:** Never enable `EnableSensitiveDataLogging` in production. Parameter values may include PII or credentials that end up in log sinks (Seq, Application Insights, Splunk).

### Simple Console Logging in Tests / Utilities

```csharp
// Quick setup without full DI — useful in unit tests
var options = new DbContextOptionsBuilder<AppDb>()
    .UseSqlServer(connStr)
    .LogTo(Console.WriteLine, LogLevel.Information)
    .EnableSensitiveDataLogging()
    .Options;
```

### Query Tagging — `TagWith`

Add a SQL comment to a query so it shows up in the database's slow-query log or profiler:

```csharp
var orders = await db.Orders
    .TagWith("GetPendingOrders - OrdersController.GetAsync")
    .Where(o => o.Status == "Pending")
    .ToListAsync(ct);
// Generated SQL begins with: -- GetPendingOrders - OrdersController.GetAsync
```

> Tip: Use `TagWithCallSite()` (EF Core 8+) to automatically embed the file name and line number of the calling code as a SQL comment.

### `IDbCommandInterceptor` — Programmatic Query Hooks

Intercept every SQL command before and after execution — useful for slow-query alerting, forced query hints, or custom telemetry:

```csharp
public sealed class SlowQueryInterceptor : DbCommandInterceptor
{
    private const int SlowMs = 500;

    public override async ValueTask<DbDataReader> ReaderExecutedAsync(
        DbCommand command,
        CommandExecutedEventData data,
        DbDataReader result,
        CancellationToken ct = default)
    {
        if (data.Duration.TotalMilliseconds > SlowMs)
        {
            // Log or alert — don't use db.X.QueryAsync here (recursion risk)
            Log.Warning("Slow query ({Ms}ms): {Sql}", (int)data.Duration.TotalMilliseconds, command.CommandText);
        }
        return result;
    }
}

// Registration
services.AddDbContext<AppDb>(opt =>
    opt.UseSqlServer(connStr)
       .AddInterceptors(new SlowQueryInterceptor()));
```

### `ISaveChangesInterceptor` — Audit Trail

Hook into `SaveChanges`/`SaveChangesAsync` before and after persistence:

```csharp
public sealed class AuditInterceptor(ICurrentUserService users) : SaveChangesInterceptor
{
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData data,
        InterceptionResult<int> result,
        CancellationToken ct)
    {
        if (data.Context is null) return new(result);

        var now = DateTimeOffset.UtcNow;
        foreach (var entry in data.Context.ChangeTracker.Entries<IAuditable>())
        {
            if (entry.State == EntityState.Added)
                entry.Entity.CreatedAt = now;
            if (entry.State is EntityState.Added or EntityState.Modified)
                entry.Entity.UpdatedAt = now;
        }
        return new(result);
    }
}
```

[See: savechanges-interceptors.md](./savechanges-interceptors.md)

### MiniProfiler Integration

MiniProfiler shows per-request SQL query count and timing in the browser dev toolbar:

```csharp
// NuGet: MiniProfiler.AspNetCore.Mvc + MiniProfiler.EntityFrameworkCore
services.AddMiniProfiler(opt =>
{
    opt.RouteBasePath = "/profiler";
    opt.ColorScheme = ColorScheme.Dark;
}).AddEntityFramework();  // intercepts EF Core queries automatically

// In Program.cs pipeline:
app.UseMiniProfiler();
```

After this setup, each request displays an inline summary (e.g., "14 SQL queries, 23ms") and clicking it shows each query with timing, duplicates highlighted.

## Code Example

```csharp
// appsettings.Development.json — minimal safe setup
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft.EntityFrameworkCore.Database.Command": "Information",
      "Microsoft.EntityFrameworkCore.Query": "Warning"  // warn on client evaluation
    }
  }
}

// Program.cs — enhanced dev-time diagnostics
builder.Services.AddDbContext<AppDb>(opt =>
{
    opt.UseSqlServer(builder.Configuration.GetConnectionString("Default"));

    if (builder.Environment.IsDevelopment())
    {
        opt.EnableSensitiveDataLogging();
        opt.EnableDetailedErrors();
        opt.LogTo(
            message => Debug.WriteLine(message),
            [DbLoggerCategory.Database.Command.Name],
            LogLevel.Information,
            DbContextLoggerOptions.UtcTime | DbContextLoggerOptions.SingleLine);
    }
});

// Controller — query tag for traceability
[HttpGet("{id}")]
public async Task<OrderDto?> GetAsync(int id, CancellationToken ct) =>
    await db.Orders
        .TagWithCallSite()                   // EF Core 8: adds file/line comment
        .Where(o => o.Id == id)
        .Select(o => new OrderDto(o.Id, o.Customer.Name, o.Total))
        .FirstOrDefaultAsync(ct);
```

## Common Follow-up Questions

- How does `TagWith` differ from `TagWithCallSite`, and when should you use each?
- Can you intercept queries to add a `NOLOCK` hint globally? What are the risks?
- How do you integrate EF Core query logs with Application Insights or OpenTelemetry?
- What is `DbContextLoggerOptions.SingleLine` and when is it useful?
- How do you detect and alert on duplicate queries (potential N+1) programmatically via interceptors?

## Common Mistakes / Pitfalls

- **Enabling `EnableSensitiveDataLogging` in production**: Logs parameter values including passwords, tokens, and PII. This is a security and compliance violation in most regulated environments.
- **Logging at `Information` globally in production**: Setting `Microsoft.EntityFrameworkCore` to `Information` floods logs with every query and connection event — use `Warning` in production, `Information` in development only.
- **Not using `TagWith` in shared services**: When multiple code paths execute similar queries, the SQL log shows identical statements. Tags are the only way to identify which call site produced a slow query.
- **Writing to the database inside an interceptor**: Calling `db.Something` inside an `IDbCommandInterceptor` creates a recursive loop — the interceptor's own query triggers itself. Use a separate `IServiceScope`/connection if you must persist from an interceptor.
- **MiniProfiler in production without auth guard**: MiniProfiler exposes full SQL including parameter values at `/profiler/results-index`. Always require an authorization policy on the MiniProfiler route in non-development environments.

## References

- [Logging — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/logging-events-diagnostics/simple-logging)
- [Interceptors — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/logging-events-diagnostics/interceptors)
- [Query tags — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/querying/tags)
- [MiniProfiler for EF Core — MiniProfiler docs](https://miniprofiler.com/dotnet/HowTo/ProfileEFCore)
- [See: savechanges-interceptors.md](./savechanges-interceptors.md)
