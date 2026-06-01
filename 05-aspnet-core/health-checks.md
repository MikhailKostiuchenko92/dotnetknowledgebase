# Health Checks in ASP.NET Core

**Category:** ASP.NET Core / Hosting
**Difficulty:** 🟡 Middle
**Tags:** `health-checks`, `IHealthCheck`, `readiness`, `liveness`, `Kubernetes`

## Question

> How do you implement health checks in ASP.NET Core? What is the difference between readiness and liveness probes?

## Short Answer

ASP.NET Core's health check framework lets you register `IHealthCheck` implementations via `AddHealthChecks()` and expose them on HTTP endpoints with `MapHealthChecks()`. A **liveness** probe tells the orchestrator whether the process is alive and should be restarted; a **readiness** probe tells it whether the instance is ready to serve traffic. You use tags and filtered endpoints to expose them separately.

## Detailed Explanation

### Core interfaces and registration

```csharp
// Simple inline registration
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy("Running"))
    .AddSqlServer(connectionString, name: "database", tags: ["db", "ready"])
    .AddRedis(redisConn, name: "redis",   tags: ["cache", "ready"]);
```

`AddHealthChecks()` returns an `IHealthChecksBuilder` that accepts:
- **Inline delegates** — `AddCheck("name", () => HealthCheckResult.Healthy(...))`
- **Typed checks** — `AddCheck<THealthCheck>("name")`
- **Extension methods** — from `AspNetCore.HealthChecks.*` NuGet packages (SqlServer, Redis, RabbitMQ, etc.)

### `IHealthCheck` interface

```csharp
public interface IHealthCheck
{
    Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default);
}
```

`HealthCheckResult` status values:

| Status | HTTP Status (default) | Meaning |
|---|---|---|
| `Healthy` | 200 | All good |
| `Degraded` | 200 | Functional but impaired |
| `Unhealthy` | 503 | Cannot serve traffic |

### Liveness vs Readiness

| Probe | Question | Tags | Restart on fail? |
|---|---|---|---|
| **Liveness** | Is the process alive? | `["live"]` | Yes — kill and restart container |
| **Readiness** | Can it serve requests? | `["ready"]` | No — remove from load balancer pool |

Map them to separate endpoints using `Predicate`:

```csharp
app.MapHealthChecks("/healthz/live",  new HealthCheckOptions
{
    Predicate = hc => hc.Tags.Contains("live")
});

app.MapHealthChecks("/healthz/ready", new HealthCheckOptions
{
    Predicate = hc => hc.Tags.Contains("ready")
});
```

### Health check publisher (`IHealthCheckPublisher`)

Publishers run on a background timer and push results to external systems (Prometheus, Application Insights, etc.):

```csharp
builder.Services.Configure<HealthCheckPublisherOptions>(opts =>
    opts.Delay = TimeSpan.FromSeconds(15));
```

### Custom response writer

Return JSON with details instead of plain text:

```csharp
app.MapHealthChecks("/healthz", new HealthCheckOptions
{
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse // from HealthChecks.UI
});
```

## Code Example

```csharp
// DatabaseHealthCheck.cs
namespace MyApp.HealthChecks;

public sealed class DatabaseHealthCheck(AppDbContext db) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Simple connectivity check — avoids full table scan
            await db.Database.ExecuteSqlRawAsync("SELECT 1", cancellationToken);
            return HealthCheckResult.Healthy("Database connection OK");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Database unreachable", ex);
        }
    }
}
```

```csharp
// Program.cs
builder.Services.AddHealthChecks()
    .AddCheck<DatabaseHealthCheck>("database",
        failureStatus: HealthStatus.Unhealthy,
        tags: ["ready", "db"])
    .AddCheck("self", () => HealthCheckResult.Healthy(),
        tags: ["live"]);

var app = builder.Build();

// Kubernetes liveness probe — just checks process is alive
app.MapHealthChecks("/healthz/live", new HealthCheckOptions
{
    Predicate = hc => hc.Tags.Contains("live"),
    AllowCachingResponses = false
}).RequireHost("*:8080"); // optionally restrict to internal port

// Kubernetes readiness probe — checks dependencies too
app.MapHealthChecks("/healthz/ready", new HealthCheckOptions
{
    Predicate = hc => hc.Tags.Contains("ready"),
    ResultStatusCodes =
    {
        [HealthStatus.Healthy]   = StatusCodes.Status200OK,
        [HealthStatus.Degraded]  = StatusCodes.Status200OK,   // keep in pool
        [HealthStatus.Unhealthy] = StatusCodes.Status503ServiceUnavailable
    }
});

app.Run();
```

```yaml
# Kubernetes deployment excerpt
livenessProbe:
  httpGet:
    path: /healthz/live
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /healthz/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 15
```

## Common Follow-up Questions

- How do you add a startup probe (third Kubernetes probe type) in ASP.NET Core?
- How do you add caching to health checks to avoid hammering the database on every probe poll?
- How do you secure the health check endpoint so it is not publicly accessible?
- How do you report degraded vs unhealthy differently to Kubernetes (should degraded keep the pod in the load balancer)?
- What is the `HealthChecks.UI` package and when would you use it?

## Common Mistakes / Pitfalls

- **Mixing liveness and readiness on a single endpoint** — if a database is down the liveness probe fails, Kubernetes restarts the pod, but the database is still down — causing a restart loop. Keep them separate.
- **Doing expensive work in health checks** — a health check that runs a full `SELECT COUNT(*) FROM LargeTable` can cause cascading load. Use lightweight queries like `SELECT 1`.
- **Not setting `AllowCachingResponses = false`** — health check responses should not be cached by reverse proxies; set this explicitly if your CDN/proxy respects cache headers.
- **Registering health check dependencies with Transient lifetime** — `IHealthCheck` implementations are registered as Singletons by default; injecting Scoped services causes captive dependency issues.
- **Forgetting to tag checks** — without tags you cannot distinguish liveness vs readiness, forcing you to expose all checks to all probes.

## References

- [Microsoft Learn — Health checks in ASP.NET Core](https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks?view=aspnetcore-8.0)
- [Andrew Lock — Series on health checks](https://andrewlock.net/tag/health-checks/) (verify URL)
- [AspNetCore.Diagnostics.HealthChecks — community packages](https://github.com/Xabaril/AspNetCore.Diagnostics.HealthChecks)
- [Kubernetes — Configure Liveness, Readiness, Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Microsoft Learn — IHealthCheckPublisher](https://learn.microsoft.com/dotnet/api/microsoft.extensions.diagnostics.healthchecks.ihealthcheckpublisher?view=dotnet-plat-ext-8.0)
