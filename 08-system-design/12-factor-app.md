# The 12-Factor App

**Category:** System Design / Cloud-Native
**Difficulty:** Middle
**Tags:** `12-factor`, `cloud-native`, `configuration`, `stateless`, `portability`, `dotnet`

## Question

> What is the 12-Factor App methodology? Which factors are most important for a .NET developer building cloud-native services? How does a typical ASP.NET Core application comply or violate these factors?

- What does "stateless processes" mean and why does it matter for horizontal scaling?
- How does 12-Factor config management differ from `appsettings.json`?

## Short Answer

The 12-Factor App is a methodology for building SaaS applications that are portable, resilient, and scalable. Its core ideas for .NET developers are: store config in environment variables (not `appsettings.json` in the image), treat the app as one or more stateless processes (no session in memory, no local files), declare dependencies explicitly (NuGet packages), and treat backing services (DB, cache, queue) as attached resources that can be swapped by changing a URL. Most ASP.NET Core applications satisfy many factors by default; the most common violations are storing per-user state in memory and baking environment-specific config into the container image.

## Detailed Explanation

### The 12 Factors — .NET Lens

| # | Factor | .NET implication |
|---|--------|-----------------|
| 1 | **Codebase** | One repo per service; one codebase, many deployments |
| 2 | **Dependencies** | All .NET dependencies declared in `.csproj`; no shared GAC assumptions |
| 3 | **Config** | Config in env vars / Key Vault, not `appsettings.json` baked into image |
| 4 | **Backing services** | DB, Redis, queue accessed via URL from config — swappable |
| 5 | **Build/Release/Run** | Build once → promote same artifact through staging → production |
| 6 | **Processes** | Stateless; no in-memory sessions; share-nothing |
| 7 | **Port binding** | Kestrel self-hosts on `$PORT`; no dependency on IIS |
| 8 | **Concurrency** | Scale by adding process replicas (horizontal), not threads |
| 9 | **Disposability** | Fast startup, graceful shutdown on `SIGTERM` |
| 10 | **Dev/prod parity** | Same Docker image, same config mechanism in all environments |
| 11 | **Logs** | Write to stdout; let the platform aggregate |
| 12 | **Admin processes** | Migrations run as one-off processes, not during app startup |

### Factor 3: Config in the Environment

The key insight: config that differs between deployments (staging vs production) must come from the environment, not from files baked into the container image.

```csharp
// ❌ Anti-pattern: environment-specific values in appsettings.json (baked into image)
// appsettings.Production.json:
// { "ConnectionStrings": { "Default": "Host=prod-db.internal;..." } }

// ✅ 12-Factor: config from environment variables
// appsettings.json has defaults; env vars override at runtime
builder.Configuration
    .AddJsonFile("appsettings.json", optional: false)      // default values only
    .AddEnvironmentVariables();                             // runtime override
// Kubernetes injects: ConnectionStrings__Default=Host=...
```

The double-underscore `__` separator maps to the `:` hierarchy separator in .NET configuration — `ConnectionStrings__Default` maps to `ConnectionStrings:Default`.

This enables the same Docker image to run in:
- Local dev (env vars from `.env` file or `dotnet user-secrets`)
- Staging (Kubernetes ConfigMap)
- Production (Kubernetes Secret / Key Vault)

### Factor 6: Stateless Processes

A 12-factor process stores nothing in memory that it expects to be there on the next request:

```csharp
// ❌ Anti-pattern: in-memory session stores state that's lost on pod restart
builder.Services.AddSession(o =>
{
    o.Cookie.HttpOnly = true;
    // This stores session in the process's memory — not visible to other pods!
});

// ✅ 12-Factor: stateless process with distributed session or no session
builder.Services.AddStackExchangeRedisCache(o =>
    o.Configuration = builder.Configuration["Redis:ConnectionString"]);

builder.Services.AddSession(o => { ... });  // backed by Redis — shared across all pods
```

Why it matters: with 3 pod replicas, round-robin load balancing means the second request hits a different pod. If session is in memory, the user loses their state. Stateless design eliminates this entirely.

**Common stateful anti-patterns in .NET:**
- `static Dictionary<Guid, SomeState>` — lost on pod restart, not visible to other pods.
- In-memory `IDistributedCache` (registered as singleton) — not distributed; pod-local only.
- Writing to `/tmp` or any local path — ephemeral pod filesystem.

### Factor 9: Disposability — Fast Startup and Graceful Shutdown

Kubernetes restarts pods frequently (rolling updates, node evictions, autoscaling). Fast startup reduces recovery time; graceful shutdown prevents in-flight requests from being dropped:

```csharp
// Graceful shutdown: stop accepting new connections, drain in-flight requests
builder.Services.Configure<HostOptions>(options =>
{
    options.ShutdownTimeout = TimeSpan.FromSeconds(30);
});

// Register cleanup logic
builder.Services.AddHostedService<BackgroundQueueWorker>();

// BackgroundQueueWorker.StopAsync is called on SIGTERM — finish current item, then stop
```

**Fast startup tips for .NET:**
- Avoid running EF Core migrations at startup (Factor 12 — run as a separate job).
- Use `AddSingleton<T>` with lazy initialization for expensive resources.
- Use AOT compilation (`dotnet publish --aot`) for cold-start-sensitive scenarios (e.g., Azure Functions).

### Factor 11: Logs as Event Streams

Write logs to stdout only — the platform (Kubernetes/Fluent Bit/Datadog agent) collects and routes them:

```csharp
// ✅ Write to stdout — Kubernetes forwards to log aggregator
builder.Logging.ClearProviders();
builder.Logging.AddConsole(o =>
{
    o.FormatterName = "json";  // structured JSON to stdout
});

// Or with Serilog:
builder.Host.UseSerilog((ctx, log) =>
    log.WriteTo.Console(new CompactJsonFormatter()));

// ❌ Don't write to files inside the container — ephemeral, not centrally searchable
// log.WriteTo.File("/logs/app.log")  — breaks Factor 11
```

### Factor 12: Admin Processes

Database migrations should run as a one-off job, not at application startup:

```csharp
// ❌ Anti-pattern: migrations at startup (blocks startup, risky in multi-replica deployments)
app.Services.GetRequiredService<AppDbContext>().Database.MigrateAsync().GetAwaiter().GetResult();

// ✅ 12-Factor: migration as a separate command or Kubernetes Job
// CLI entry point:
if (args.Contains("--migrate"))
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();
    return;
}
```

```yaml
# Kubernetes Job for migrations (runs before Deployment rolls out)
apiVersion: batch/v1
kind: Job
metadata:
  name: orders-migration-v1-2-0
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: orders-api:v1.2.0
          args: ["--migrate"]
          envFrom:
            - secretRef:
                name: orders-secrets
```

### Factor 4: Backing Services as Attached Resources

The database, Redis instance, and message queue are all "attached resources" — the app should be able to swap from a local Postgres to a managed Azure PostgreSQL Flexible Server by changing a single environment variable:

```csharp
// ✅ Same code, different backing service in each environment
var connStr = builder.Configuration.GetConnectionString("Default");
// Local dev:   "Host=localhost;Database=orders_dev;..."
// Production:  "Host=orders-db.postgres.database.azure.com;Database=orders;..."

builder.Services.AddDbContext<AppDbContext>(o => o.UseNpgsql(connStr));
```

> **Warning:** Factor 3 (config in environment) and Factor 6 (stateless processes) are the most commonly violated in .NET applications. Check for: `appsettings.Production.json` baked into the image, `AddDistributedMemoryCache()` used in a multi-replica deployment, and any code writing to local filesystem paths.

## Code Example

```csharp
// 12-Factor compliant ASP.NET Core setup
var builder = WebApplication.CreateBuilder(args);

// Factor 3: config from env vars (ConfigMap / Key Vault in production)
builder.Configuration
    .AddJsonFile("appsettings.json")
    .AddEnvironmentVariables();

// Factor 4: backing services via config
builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Postgres")));

builder.Services.AddStackExchangeRedisCache(o =>
    o.Configuration = builder.Configuration["Redis:Connection"]);

// Factor 6: no in-memory session (backed by Redis)
builder.Services.AddSession();

// Factor 9: graceful shutdown
builder.Services.Configure<HostOptions>(o => o.ShutdownTimeout = TimeSpan.FromSeconds(25));

// Factor 11: structured logs to stdout only
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

var app = builder.Build();

// Factor 12: migrations via separate job, not here
app.Run();
```

## Common Follow-up Questions

- How does Factor 5 (build/release/run separation) map to a CI/CD pipeline?
- What is the difference between `IDistributedCache` backed by memory vs Redis, and which is 12-Factor compliant?
- How do you handle secrets (Factor 3) without putting them in environment variables in plain text?
- How does AOT compilation affect 12-Factor compliance (Factor 2: dependencies)?
- How does Feature Flag management relate to 12-Factor config?

## Common Mistakes / Pitfalls

- **`appsettings.Production.json` in the Docker image**: baking production config into the image violates Factor 3 and ties the image to a specific environment; promote the same image and inject config externally.
- **`AddDistributedMemoryCache()` in production**: named "distributed" but is in-process memory — not distributed at all; each replica has a different cache state, breaking session and idempotency.
- **Running migrations at startup in a multi-replica deployment**: two pods starting simultaneously both attempt `MigrateAsync()` — can cause double migrations or deadlocks; use a Kubernetes Job with `initContainers` or `helm hooks`.
- **Writing structured data to local files**: EF Core SQLite, Serilog file sink, local file uploads — all break Factor 6 (stateless) and Factor 9 (disposability).
- **Ignoring Factor 9 (graceful shutdown)**: if `ShutdownTimeout` is 0 or not set, ASP.NET Core may kill in-flight requests mid-response when Kubernetes sends SIGTERM.

## References

- [The Twelve-Factor App — Adam Wiggins](https://12factor.net/)
- [.NET in containers best practices — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/core/docker/container-best-practices)
- [ASP.NET Core configuration — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/)
- [EF Core migrations in production — Microsoft Docs](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying)
- [See: containers-and-orchestration.md](./containers-and-orchestration.md)
- [See: kubernetes-for-dotnet-devs.md](./kubernetes-for-dotnet-devs.md)
