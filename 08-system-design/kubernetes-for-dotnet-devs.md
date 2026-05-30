# Kubernetes for .NET Developers

**Category:** System Design / Cloud-Native
**Difficulty:** Middle
**Tags:** `kubernetes`, `configmap`, `secrets`, `resource-limits`, `probes`, `rolling-update`, `aks`, `dotnet`

## Question

> What Kubernetes concepts are most important for a .NET developer deploying to AKS or similar? How do you configure ConfigMaps, Secrets, resource limits, and health probes correctly? What happens during a rolling update?

- How do you inject app settings from ConfigMap into an ASP.NET Core application?
- How do you prevent OOM kills and CPU throttling in production?

## Short Answer

A .NET developer deploying to Kubernetes needs to understand: injecting configuration via `ConfigMap` and `Secret` (mapped to environment variables or file mounts), sizing `resources.requests/limits` to prevent OOM kills and CPU throttling, and wiring `livenessProbe`/`readinessProbe` to ASP.NET Core health check endpoints so Kubernetes can restart unhealthy pods and safely route traffic during rolling updates. Getting probes wrong causes silent 503s; getting resource limits wrong causes hard-to-diagnose OOM kills. These three areas cause the majority of production incidents for .NET teams new to Kubernetes.

## Detailed Explanation

### Configuration Injection

ASP.NET Core's layered configuration system works naturally with Kubernetes:

```yaml
# ConfigMap — non-sensitive settings
apiVersion: v1
kind: ConfigMap
metadata:
  name: orders-api-config
  namespace: production
data:
  ASPNETCORE_ENVIRONMENT: "Production"
  Logging__LogLevel__Default: "Information"   # __ maps to : in .NET config
  FeatureFlags__NewCheckout: "true"
  ConnectionStrings__Redis: "redis-service:6379"
```

Two injection styles:

**1. Environment variables** (simple, visible in pod inspect):

```yaml
spec:
  containers:
    - name: orders-api
      envFrom:
        - configMapRef:
            name: orders-api-config   # injects ALL keys as env vars
      env:
        - name: DB_PASSWORD           # individual override from Secret
          valueFrom:
            secretKeyRef:
              name: orders-secrets
              key: DB_PASSWORD
```

**2. Volume mount as appsettings file** (supports hot-reload):

```yaml
spec:
  volumes:
    - name: config-volume
      configMap:
        name: orders-api-config
  containers:
    - name: orders-api
      volumeMounts:
        - name: config-volume
          mountPath: /app/config      # ConfigMap keys become files
```

```csharp
// ASP.NET Core reads the mounted file as a JSON config source
builder.Configuration
    .AddJsonFile("/app/config/appsettings.json", optional: true, reloadOnChange: true);
    // reloadOnChange: true = picks up ConfigMap updates without restart
```

### Resource Requests and Limits

**Requests**: the amount the scheduler reserves for this pod on the node — determines scheduling.  
**Limits**: the hard ceiling the runtime enforces — violations cause throttling (CPU) or OOM kill (memory).

```yaml
resources:
  requests:
    memory: "256Mi"   # scheduler will only place pod on node with ≥256Mi free
    cpu: "250m"       # 0.25 vCPU reserved
  limits:
    memory: "512Mi"   # pod killed (OOM) if it exceeds 512Mi
    cpu: "1000m"      # CPU throttled (NOT killed) if it exceeds 1 vCPU
```

**Sizing guidance for .NET services:**

| Service type | Memory request | Memory limit | CPU request | CPU limit |
|-------------|---------------|-------------|------------|----------|
| Small API (<10 req/s) | 128Mi | 256Mi | 100m | 500m |
| Medium API | 256Mi | 512Mi | 250m | 1000m |
| High-throughput API | 512Mi | 1Gi | 500m | 2000m |

> **Warning:** .NET's server GC by default assumes it can use all available memory. In a container with a memory limit, set `DOTNET_GCHeapHardLimit` (bytes) or `DOTNET_GCHeapHardLimitPercent` to tell the GC to respect the container limit, otherwise it won't trigger collections until it's already been OOM-killed.

```yaml
env:
  - name: DOTNET_GCHeapHardLimitPercent
    value: "75"    # GC will hard-limit the heap to 75% of container memory limit
```

### Liveness and Readiness Probes

**Liveness**: "Is this pod alive?" — if it fails, Kubernetes **restarts** the container.  
**Readiness**: "Is this pod ready to serve traffic?" — if it fails, Kubernetes **removes it from the Service endpoints** (no restart).  
**Startup**: "Has this pod finished starting?" — disables liveness until startup succeeds (for slow-starting apps).

```yaml
livenessProbe:
  httpGet:
    path: /healthz/live
    port: 8080
  initialDelaySeconds: 15     # wait before first check (give app time to start)
  periodSeconds: 20            # check every 20s
  failureThreshold: 3          # restart after 3 consecutive failures (60s window)
  timeoutSeconds: 5

readinessProbe:
  httpGet:
    path: /healthz/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 2          # remove from load balancer after 2 failures (20s)
  successThreshold: 1

startupProbe:                   # use for apps with slow init (EF Core migrations etc.)
  httpGet:
    path: /healthz/live
    port: 8080
  failureThreshold: 30          # allow up to 5 minutes to start (30 × 10s)
  periodSeconds: 10
```

```csharp
// ASP.NET Core: map health check endpoints to probe paths
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy(), tags: ["live"])
    .AddNpgsql(connStr, name: "postgres", tags: ["ready"])
    .AddRedis(redisConnStr, name: "redis", tags: ["ready"]);

app.MapHealthChecks("/healthz/live",  new() { Predicate = c => c.Tags.Contains("live")  });
app.MapHealthChecks("/healthz/ready", new() { Predicate = c => c.Tags.Contains("ready") });
```

**Liveness vs Readiness decision tree:**
- DB connection down? → readiness fails (pod removed from load balancer) — not a reason to restart.
- Application deadlocked / infinite loop? → liveness fails → restart.
- Startup migration running? → readiness fails — traffic held until complete.

### Rolling Updates

When you apply a new image version, Kubernetes performs a rolling update:

```
Before: 3 pods running v1
Step 1: start 1 pod with v2 (maxSurge: 1 → up to 4 pods temporarily)
Step 2: v2 pod passes readiness → added to Service endpoints
Step 3: 1 v1 pod removed from endpoints + terminated (maxUnavailable: 1)
Step 4: repeat until all 3 pods are v2
```

**Zero-downtime requirements:**
1. Readiness probe must pass before traffic is sent to the new pod.
2. Old pods receive a `SIGTERM` → graceful shutdown period → `SIGKILL`.

```csharp
// ASP.NET Core: respect the graceful shutdown signal from Kubernetes
// (SIGTERM → stop accepting new requests → drain in-flight → exit)
builder.Services.Configure<HostOptions>(options =>
{
    options.ShutdownTimeout = TimeSpan.FromSeconds(30); // match terminationGracePeriodSeconds
});
```

```yaml
spec:
  terminationGracePeriodSeconds: 30   # Kubernetes waits this long after SIGTERM before SIGKILL
```

### Namespace Isolation and RBAC

Namespaces provide logical separation within a cluster:

```bash
# Deploy to a specific namespace
kubectl apply -f orders-deployment.yaml -n production

# Each namespace can have its own resource quotas
kubectl create namespace staging
kubectl apply -f resource-quota.yaml -n staging
```

```yaml
# Resource quota per namespace — prevents runaway deployments consuming all cluster resources
apiVersion: v1
kind: ResourceQuota
metadata:
  name: staging-quota
  namespace: staging
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    pods: "20"
```

## Code Example

```csharp
// Full production-ready Program.cs for Kubernetes deployment
var builder = WebApplication.CreateBuilder(args);

// Read config from ConfigMap-mounted env vars (__ = : in .NET config hierarchy)
builder.Configuration.AddEnvironmentVariables();

// GC respects container memory limit
// (set DOTNET_GCHeapHardLimitPercent=75 in Kubernetes env)

builder.Services.AddHealthChecks()
    .AddCheck("self",     () => HealthCheckResult.Healthy(), tags: ["live"])
    .AddNpgsql(builder.Configuration.GetConnectionString("Default")!, tags: ["ready"])
    .AddRedis(builder.Configuration["Redis:ConnectionString"]!,       tags: ["ready"]);

// Graceful shutdown — drain in-flight requests before exiting
builder.Services.Configure<HostOptions>(o => o.ShutdownTimeout = TimeSpan.FromSeconds(25));

var app = builder.Build();

// Map probes BEFORE other middleware — probes must respond even if app is initializing
app.MapHealthChecks("/healthz/live",  new() { Predicate = c => c.Tags.Contains("live")  });
app.MapHealthChecks("/healthz/ready", new() { Predicate = c => c.Tags.Contains("ready") });

// Rest of middleware...
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

## Common Follow-up Questions

- How does the Horizontal Pod Autoscaler (HPA) use CPU metrics to scale?
- What is a `PodDisruptionBudget` and why is it important for zero-downtime deployments?
- How do you run EF Core database migrations safely in a Kubernetes rolling update?
- What is `terminationGracePeriodSeconds` and how does it relate to `ShutdownTimeout` in .NET?
- How do you debug a pod that is crash-looping (`CrashLoopBackOff`)?

## Common Mistakes / Pitfalls

- **Liveness probe hitting a dependency (DB/Redis)**: if the DB is down, the liveness probe fails and Kubernetes restarts all pods — the restart doesn't fix the DB and causes a restart storm. Liveness should only check the application process itself.
- **`initialDelaySeconds` too short**: if the liveness probe fires before .NET has JIT-compiled and started listening, the pod is killed and restarts immediately; set `initialDelaySeconds` ≥ 15s or use a startup probe.
- **No `DOTNET_GCHeapHardLimitPercent`**: the GC sees the node's full memory (e.g., 32GB) rather than the container limit (512Mi) and doesn't collect aggressively enough, causing OOM kills.
- **ConfigMap changes not reflected**: if you change a ConfigMap and the pod doesn't restart, the environment variable injection is stale; use volume mounts with `reloadOnChange: true` for hot-reload, or trigger a rolling restart with `kubectl rollout restart`.
- **Not setting `UpdateStrategy.maxUnavailable`**: the default of 25% means up to 75% of a small deployment (3 pods → 2 max unavailable in some interpretations) can be down simultaneously during updates.

## References

- [Configure containers — Kubernetes Docs](https://kubernetes.io/docs/tasks/configure-pod-container/)
- [Liveness, Readiness and Startup Probes — Kubernetes Docs](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [.NET container best practices — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/core/docker/container-best-practices)
- [GC configuration in containers — .NET Docs](https://learn.microsoft.com/en-us/dotnet/core/runtime-config/garbage-collector#heap-hard-limit)
- [See: containers-and-orchestration.md](./containers-and-orchestration.md)
- [See: health-checks-in-aspnet-core.md](./health-checks-in-aspnet-core.md)
