# Containers and Orchestration

**Category:** System Design / Cloud-Native
**Difficulty:** Junior
**Tags:** `docker`, `kubernetes`, `containers`, `orchestration`, `pod`, `deployment`, `service`

## Question

> What is a container and why is it useful? What problem does Kubernetes solve that Docker alone does not? What are the key Kubernetes resources a .NET developer needs to know?

- What is the difference between a Docker image and a container?
- How does a Kubernetes Service expose a Deployment?

## Short Answer

A container packages an application with all its dependencies (runtime, libraries, config) into an isolated, portable unit — solving "works on my machine" by making the execution environment reproducible. Docker builds and runs individual containers; Kubernetes orchestrates many containers across many nodes: scheduling, scaling, self-healing, networking, and rolling updates. A .NET developer needs to understand: `Deployment` (declares desired state), `Pod` (the running container), `Service` (stable DNS and load balancing), `ConfigMap`/`Secret` (config injection), and `Ingress` (HTTP routing).

## Detailed Explanation

### Why Containers?

Before containers, deploying a .NET application meant:
- Install the correct .NET version on every server.
- Configure environment-specific settings by hand.
- "It worked in staging" bugs caused by OS library differences.

Containers fix this with a **layered file system** (OCI image format): every dependency is baked into the image, and the container runtime provides isolation via Linux namespaces and cgroups.

```
Host OS kernel
├── Container A (orders-api, .NET 9, Ubuntu 22.04 layer)
├── Container B (payments-api, .NET 8, Debian layer)
└── Container C (postgres:16)
Each container sees its own filesystem, network, and process tree
```

Key properties:
- **Portable**: build once, run anywhere with a compatible container runtime.
- **Immutable**: the image is never modified; config/secrets are injected at runtime.
- **Isolated**: each container gets its own network interface, filesystem, and PID namespace.

### Docker Essentials for .NET

```dockerfile
# Multi-stage build — separates build tools from runtime image
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY ["Orders.Api/Orders.Api.csproj", "Orders.Api/"]
RUN dotnet restore "Orders.Api/Orders.Api.csproj"

COPY . .
WORKDIR "/src/Orders.Api"
RUN dotnet publish -c Release -o /app/publish --no-restore

# Runtime image — much smaller; no SDK
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
EXPOSE 8080

# Run as non-root user (security best practice)
USER app

COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Orders.Api.dll"]
```

```bash
docker build -t orders-api:v1.2.0 .
docker run -p 8080:8080 -e ASPNETCORE_ENVIRONMENT=Production orders-api:v1.2.0
```

### Why Kubernetes?

Docker handles a single container on a single host. Production needs:

| Need | Docker alone | Kubernetes |
|------|-------------|-----------|
| Run on multiple nodes | Manual | ✅ Scheduler assigns pods to nodes |
| Restart failed containers | ❌ | ✅ Self-healing (liveness probes) |
| Scale to N replicas | Manual | ✅ `replicas: 5` or HPA |
| Rolling updates | Manual | ✅ Built-in with configurable strategy |
| Service discovery | ❌ (manual /etc/hosts) | ✅ DNS-based via `Service` |
| Secrets/config injection | Manual | ✅ `ConfigMap`, `Secret` |
| Health-based routing | ❌ | ✅ Readiness probes |

### Key Kubernetes Resources

#### Pod

The smallest deployable unit — one or more containers sharing a network namespace and storage:

```yaml
# Usually created by Deployment, not directly
apiVersion: v1
kind: Pod
metadata:
  name: orders-api-pod
spec:
  containers:
    - name: orders-api
      image: orders-api:v1.2.0
      ports:
        - containerPort: 8080
```

#### Deployment

Declares the desired state (image version, replica count, update strategy):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: orders-api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1      # at most 1 pod down during update
      maxSurge: 1            # at most 1 extra pod during update
  template:
    metadata:
      labels:
        app: orders-api
    spec:
      containers:
        - name: orders-api
          image: myregistry.azurecr.io/orders-api:v1.2.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"    # 0.1 vCPU
            limits:
              memory: "256Mi"
              cpu: "500m"
          env:
            - name: ASPNETCORE_ENVIRONMENT
              value: "Production"
          livenessProbe:
            httpGet:
              path: /healthz/live
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 15
          readinessProbe:
            httpGet:
              path: /healthz/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
```

#### Service

Provides a stable DNS name and IP for a set of pods (selected by label):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: orders-api
spec:
  selector:
    app: orders-api          # routes to all pods with this label
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP            # ClusterIP = internal only; LoadBalancer = external
```

Now any pod in the cluster can call `http://orders-api/` — Kubernetes DNS resolves `orders-api` to the Service's virtual IP, which load-balances across healthy pods.

#### ConfigMap and Secret

```yaml
# ConfigMap: non-sensitive config
apiVersion: v1
kind: ConfigMap
metadata:
  name: orders-config
data:
  FEATURE_NEW_UI: "true"
  LOG_LEVEL: "Information"

---
# Secret: base64-encoded sensitive data (use Key Vault CSI driver in production)
apiVersion: v1
kind: Secret
metadata:
  name: orders-secrets
type: Opaque
stringData:
  DB_PASSWORD: "supersecret"   # stored encrypted in etcd (if encryption configured)
```

Reference from a Deployment:

```yaml
envFrom:
  - configMapRef:
      name: orders-config
  - secretRef:
      name: orders-secrets
```

#### Ingress

Routes external HTTP/HTTPS traffic to Services:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orders-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: orders.example.com
      http:
        paths:
          - path: /api/orders
            pathType: Prefix
            backend:
              service:
                name: orders-api
                port:
                  number: 80
  tls:
    - hosts:
        - orders.example.com
      secretName: orders-tls-cert
```

> **Warning:** Kubernetes Secrets are only base64-encoded by default, not encrypted. Enable etcd encryption-at-rest or use the Secrets Store CSI Driver with Azure Key Vault for production.

## Code Example

```csharp
// ASP.NET Core health check endpoints for Kubernetes probes
builder.Services.AddHealthChecks()
    .AddNpgsql(builder.Configuration.GetConnectionString("Default")!, name: "postgres")
    .AddRedis(builder.Configuration["Redis:ConnectionString"]!, name: "redis");

var app = builder.Build();

// Liveness: is the process alive? (restarts pod if fails)
app.MapHealthChecks("/healthz/live", new HealthCheckOptions
{
    Predicate = _ => false  // no checks — just "am I running?"
});

// Readiness: is the pod ready to serve traffic? (removes from load balancer if fails)
app.MapHealthChecks("/healthz/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});

app.Run();
```

## Common Follow-up Questions

- What is the difference between `requests` and `limits` for CPU and memory in Kubernetes?
- How does the Kubernetes scheduler decide which node to place a pod on?
- What is a `StatefulSet` and when should you use it instead of a `Deployment`?
- How does horizontal pod autoscaling (HPA) work?
- What is a namespace in Kubernetes and how does it relate to isolation?

## Common Mistakes / Pitfalls

- **No resource requests or limits**: without `resources.requests`, the scheduler can over-commit nodes causing OOM kills; without `limits`, one runaway pod can starve others.
- **Running as root in the container**: a container breakout exploit gives the attacker root on the node; use `USER app` in the Dockerfile and `securityContext.runAsNonRoot: true` in the pod spec.
- **Not setting readiness probes**: without readiness, Kubernetes routes traffic to a pod that hasn't finished startup — causes 503s during rolling updates.
- **Using `:latest` tag**: `latest` is mutable and can silently pull a different version; always use specific immutable tags (e.g., `v1.2.3` or SHA digest).
- **Storing state in pod local filesystem**: pods are ephemeral — local files are lost on restart. Use persistent volumes, external databases, or object storage.

## References

- [Docker multi-stage builds — Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/core/docker/build-container)
- [Kubernetes Deployments — kubernetes.io](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes Services — kubernetes.io](https://kubernetes.io/docs/concepts/services-networking/service/)
- [ASP.NET Core on Kubernetes — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/kubernetes/)
- [See: kubernetes-for-dotnet-devs.md](./kubernetes-for-dotnet-devs.md)
- [See: health-checks-in-aspnet-core.md](./health-checks-in-aspnet-core.md)
