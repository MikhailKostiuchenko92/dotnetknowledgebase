# Health Checks in ASP.NET Core

**Category:** System Design / Observability
**Difficulty:** Middle
**Tags:** `health-checks`, `liveness`, `readiness`, `startup`, `kubernetes`, `aspnet-core`

## Question

> How do you implement health checks in ASP.NET Core? What is the difference between liveness, readiness, and startup probes? How do Kubernetes probes integrate with the health check middleware?

- What should a readiness probe check that a liveness probe should not?
- How do you implement a custom `IHealthCheck` for a downstream dependency?

## Short Answer

ASP.NET Core's `IHealthCheck` interface and middleware expose `/health/live`, `/health/ready`, and `/health/startup` endpoints. A **liveness probe** answers "is the process stuck?" — it should only fail if the process must be restarted (deadlock, unrecoverable error). A **readiness probe** answers "is the service ready to accept traffic?" — it should check dependent resources (DB connections, cache, downstream APIs). Kubernetes uses these endpoints to route traffic (readiness) and restart pods (liveness). The startup probe buys extra time for slow-starting containers before liveness checks kick in.

## Detailed Explanation

### Three Probe Types

| Probe | Kubernetes action on failure | What to check |
|-------|------------------------------|---------------|
| **Liveness** | Kill pod and restart it | Is the process deadlocked or hung? Self-diagnosis only — no external deps |
| **Readiness** | Remove pod from Service endpoint slice (no traffic) | Can the service handle requests? DB pool, cache, downstream APIs |
| **Startup** | Kill pod and restart it (only during startup window) | Is the app finished initialising? (warm caches, DB migrations) |

> **Warning:** Never check external dependencies in a **liveness** probe. If your database goes down, liveness fails → Kubernetes restarts all your pods → they all try to reconnect simultaneously → thundering herd. A DB outage should cause readiness failure (stop traffic), not pod restart.

### Basic Setup

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHealthChecks()
    // Built-in checks from AspNetCore.HealthChecks.* NuGet packages
    .AddSqlServer(
        connectionString: builder.Configuration.GetConnectionString("Default")!,
        name: "sql-server",
        tags: ["ready"])                    // only included in readiness endpoint
    .AddRedis(
        redisConnectionString: "localhost:6379",
        name: "redis",
        tags: ["ready"])
    .AddCheck<ExternalPaymentApiCheck>(
        name: "payment-api",
        tags: ["ready"])
    .AddCheck<SelfCheck>(
        name: "self",
        tags: ["live"]);                    // only included in liveness endpoint

var app = builder.Build();

// Liveness: is the process alive and not stuck?
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("live"),
    ResponseWriter = WriteJsonResponse,
});

// Readiness: can we handle traffic?
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
    ResponseWriter = WriteJsonResponse,
});

// Startup: has the app finished initialising?
app.MapHealthChecks("/health/startup", new HealthCheckOptions
{
    Predicate = _ => true,   // all checks must pass before receiving traffic
    ResponseWriter = WriteJsonResponse,
});

app.Run();

static Task WriteJsonResponse(HttpContext ctx, HealthReport report)
{
    ctx.Response.ContentType = "application/json";
    var result = JsonSerializer.Serialize(new
    {
        status  = report.Status.ToString(),
        checks  = report.Entries.Select(e => new
        {
            name        = e.Key,
            status      = e.Value.Status.ToString(),
            description = e.Value.Description,
            durationMs  = e.Value.Duration.TotalMilliseconds,
        }),
        totalDurationMs = report.TotalDuration.TotalMilliseconds,
    });
    return ctx.Response.WriteAsync(result);
}
```

### Custom `IHealthCheck`

```csharp
// Check that a downstream payment API is reachable
public sealed class ExternalPaymentApiCheck(IHttpClientFactory httpFactory) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext ctx, CancellationToken ct = default)
    {
        try
        {
            using var client = httpFactory.CreateClient("payment-api");
            // Use HEAD or a lightweight ping endpoint — not a real transaction
            using var response = await client.GetAsync("/ping",
                HttpCompletionOption.ResponseHeadersRead, ct);

            return response.IsSuccessStatusCode
                ? HealthCheckResult.Healthy("Payment API reachable")
                : HealthCheckResult.Degraded(
                    $"Payment API returned {(int)response.StatusCode}");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Payment API unreachable", ex);
        }
    }
}

// Liveness: detect application-level stuck state
public sealed class SelfCheck : IHealthCheck
{
    private static int _consecutiveSlowResponses;

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext ctx, CancellationToken ct = default)
    {
        // Example: check in-memory circuit breaker state
        // A real liveness check is very lightweight — no I/O
        return Task.FromResult(
            _consecutiveSlowResponses > 100
                ? HealthCheckResult.Unhealthy("Too many slow responses — process may be stuck")
                : HealthCheckResult.Healthy());
    }
}
```

### Kubernetes Probe Configuration

```yaml
containers:
  - name: orders-api
    image: orders-api:latest
    ports:
      - containerPort: 8080
    startupProbe:
      httpGet:
        path: /health/startup
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 10
      failureThreshold: 12       # up to 12×10=120s for slow starts (DB migrations)
    livenessProbe:
      httpGet:
        path: /health/live
        port: 8080
      periodSeconds: 10
      failureThreshold: 3        # restart after 3 consecutive failures (30s)
      timeoutSeconds: 5
    readinessProbe:
      httpGet:
        path: /health/ready
        port: 8080
      periodSeconds: 5
      failureThreshold: 3        # remove from load balancer after 3 failures (15s)
      successThreshold: 2        # require 2 successes to re-add after failure
      timeoutSeconds: 3
```

### Health Check UI (AspNetCore.HealthChecks.UI)

For dashboards during development or non-Kubernetes environments:

```csharp
builder.Services.AddHealthChecksUI(setup =>
{
    setup.SetEvaluationTimeInSeconds(15);
    setup.AddHealthCheckEndpoint("orders-api", "/health/ready");
}).AddInMemoryStorage();

app.MapHealthChecksUI(options => options.UIPath = "/health-ui");
```

### Performance Considerations

- Health check endpoints are called frequently (every 5–10 s by Kubernetes × number of pods). Keep checks lightweight.
- Cache expensive check results (e.g., external API ping): use `HealthCheckOptions.ResultStatusCodes` or add a 10 s TTL in the check.
- Avoid database write operations in health checks — read-only `SELECT 1` is sufficient to verify connectivity.

## Common Follow-up Questions

- How do you implement a health check that verifies a background worker is processing messages (e.g., Kafka consumer lag)?
- A readiness check failure on one pod causes Kubernetes to stop sending it traffic. What happens if ALL pods fail readiness simultaneously?
- How do you expose health check results to a monitoring system (Prometheus metric from health check status)?
- Should you authenticate health check endpoints? What are the security trade-offs?
- How do you handle a dependency that is temporarily unavailable during a planned maintenance window?

## Common Mistakes / Pitfalls

- **Checking external dependencies in liveness**: a DB outage causes liveness failures → pod restart loop → recovery is slower than if the pod stayed up and waited for the DB.
- **No `tags` filtering**: a single `/health` endpoint that checks everything is used as both liveness and readiness, causing pods to be restarted when a downstream service is slow.
- **No timeout in `IHealthCheck.CheckHealthAsync`**: a hung HTTP client in a health check blocks the check indefinitely; always pass `ct` and set `HttpClient.Timeout`.
- **Reusing the same `HttpClient` instance in health checks**: if the health check's `HttpClient` exhausts its connection pool, the check fails even though the service is healthy.
- **Not securing health endpoints**: `/health/ready` can reveal internal service names, connection strings (in error messages), and topology. Add IP allowlist or auth for detailed responses in production.

## References

- [Health checks in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks)
- [AspNetCore.Diagnostics.HealthChecks — GitHub](https://github.com/Xabaril/AspNetCore.Diagnostics.HealthChecks)
- [Kubernetes Probe Configuration](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [See: observability-three-pillars.md](./observability-three-pillars.md)
- [See: service-discovery.md](./service-discovery.md)
