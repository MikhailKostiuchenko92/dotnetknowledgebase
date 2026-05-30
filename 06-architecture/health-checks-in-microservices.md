# Health Checks in Microservices

**Category:** Architecture / Microservices
**Difficulty:** 🟡 Middle
**Tags:** `health-checks`, `ASP.NET-Core`, `readiness`, `liveness`, `startup-probe`, `Kubernetes`, `IHealthCheck`

## Question

> How do you implement health checks in ASP.NET Core microservices? What is the difference between readiness, liveness, and startup probes, and how does Kubernetes use them?

## Short Answer

ASP.NET Core's `IHealthCheck` interface and `AddHealthChecks()` provide endpoints for infrastructure monitoring. **Liveness**: is the process alive? Returns 200 if the process is running (even if degraded). **Readiness**: is the service ready to accept traffic? Checks DB, external dependencies — returns 503 if not ready (Kubernetes stops routing traffic). **Startup**: has the service finished initializing? Only checked during startup; prevents liveness/readiness being checked too early. Kubernetes kubelet calls these endpoints; YARP and load balancers use them for routing decisions.

## Detailed Explanation

### ASP.NET Core Health Check Registration

```csharp
builder.Services.AddHealthChecks()
    .AddDbContextCheck<AppDbContext>("database", tags: ["ready"])
    .AddUrlGroup(new Uri("http://inventory-svc/health/live"), "inventory-service", tags: ["ready"])
    .AddRedis(builder.Configuration["Redis:ConnectionString"]!, "redis-cache", tags: ["ready"])
    .AddCheck<CustomBusinessRuleHealthCheck>("custom-rule", tags: ["ready"]);

// Separate endpoints for different probe types
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false,  // ← only checks the process is up (no dependency checks)
    ResponseWriter = (ctx, report) =>
    {
        ctx.Response.ContentType = "application/json";
        return ctx.Response.WriteAsync("{\"status\":\"Healthy\"}");
    }
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),  // ← all dependencies
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});

app.MapHealthChecks("/health/startup", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("startup"),
});
```

### Custom Health Check

```csharp
public class DatabaseQueueDepthCheck(AppDbContext db) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext ctx, CancellationToken ct)
    {
        // Example: warn if outbox queue is backing up
        var pendingMessages = await db.OutboxMessages
            .CountAsync(m => m.Status == OutboxStatus.Pending, ct);

        return pendingMessages switch
        {
            < 100  => HealthCheckResult.Healthy($"Outbox queue: {pendingMessages} messages"),
            < 1000 => HealthCheckResult.Degraded($"Outbox queue backing up: {pendingMessages}"),
            _      => HealthCheckResult.Unhealthy($"Outbox queue critical: {pendingMessages}")
        };
    }
}
```

### Kubernetes Probe Configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  template:
    spec:
      containers:
        - name: order-service
          image: order-service:latest
          ports:
            - containerPort: 8080

          # Startup probe: checked until it succeeds; prevents liveness/readiness during init
          startupProbe:
            httpGet:
              path: /health/startup
              port: 8080
            failureThreshold: 30    # ← give up after 30*10s = 5 minutes
            periodSeconds: 10

          # Liveness probe: is the process still running? Restart if fails
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 0  # ← startup probe already handled delay
            periodSeconds: 30
            failureThreshold: 3

          # Readiness probe: ready to accept traffic? Remove from load balancer if fails
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            periodSeconds: 10
            failureThreshold: 3
```

### Probe Semantics

| Probe | Fails → | Use for |
|-------|---------|---------|
| **Liveness** | Container restarts | Deadlock detection, OOM — unrecoverable state |
| **Readiness** | Remove from load balancer | Downstream dependency unavailable — recoverable |
| **Startup** | Container marked not started | Long warm-up (EF Core migrations, cache population) |

> **Important**: Never fail liveness for transient dependency issues (DB momentarily unavailable). Liveness failure causes a restart which won't fix a DB outage — use readiness instead.

### Health Check UI

```csharp
// NuGet: AspNetCore.HealthChecks.UI + AspNetCore.HealthChecks.UI.InMemory.Storage
builder.Services.AddHealthChecksUI(settings =>
    settings.AddHealthCheckEndpoint("Order Service", "http://localhost:5000/health/ready"))
    .AddInMemoryStorage();

app.MapHealthChecksUI(options => options.UIPath = "/health-dashboard");
```

## Code Example

```csharp
// Full registration including all common dependency checks
builder.Services.AddHealthChecks()
    // Database
    .AddDbContextCheck<AppDbContext>("sql-server", tags: ["ready"])
    // Message bus
    .AddRabbitMQ(sp => sp.GetRequiredService<IConnection>(), "rabbitmq", tags: ["ready"])
    // Redis cache
    .AddRedis(builder.Configuration["Redis:Connection"]!, "redis", tags: ["ready"])
    // External HTTP dependency
    .AddUrlGroup(
        new Uri("http://payment-gateway/health"),
        name: "payment-gateway",
        tags: ["ready"],
        configureClient: (sp, c) => c.Timeout = TimeSpan.FromSeconds(5))
    // Custom business rule check
    .AddCheck<DatabaseQueueDepthCheck>("outbox-queue", tags: ["ready"]);
```

## Common Follow-up Questions

- How do you avoid health check cascading failures when a non-critical dependency is down?
- How do you implement rolling deployments with readiness probes in Kubernetes?
- What is the difference between a health check and a monitoring endpoint (metrics)?
- How do you test health checks in integration tests?
- Should a health check write to the database to verify connectivity?

## Common Mistakes / Pitfalls

- **Heavy dependency checks in liveness probes**: calling a database in the liveness probe means a DB outage causes all pods to restart in a loop — compounding the failure. Liveness should only check the process is alive.
- **Same endpoint for liveness and readiness**: combining all checks into `/health` means a Redis outage triggers a container restart instead of just removing from load balancing.
- **No startup probe for slow-starting services**: without a startup probe, Kubernetes may kill a container before it finishes running EF Core migrations or warming up the JIT.
- **Health check queries that are too expensive**: a health check `SELECT COUNT(*) FROM Orders` can timeout under load, causing a readiness failure cascade. Use simple connectivity checks.

## References

- [Health checks in ASP.NET Core — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks)
- [Kubernetes probes — Kubernetes Docs](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [AspNetCore.Diagnostics.HealthChecks — GitHub](https://github.com/Xabaril/AspNetCore.Diagnostics.HealthChecks)
- [See: service-discovery.md](./service-discovery.md)
