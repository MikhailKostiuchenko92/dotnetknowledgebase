# Service Discovery

**Category:** Architecture / Microservices
**Difficulty:** 🟡 Middle
**Tags:** `service-discovery`, `Consul`, `Kubernetes`, `health-checks`, `client-side-discovery`, `server-side-discovery`

## Question

> What is service discovery in microservices? Compare client-side vs server-side discovery, and explain how Kubernetes DNS and Consul work for service registration and lookup.

## Short Answer

**Service discovery** solves the problem of dynamically finding where a service is running when instances can start, stop, or move at any time. **Client-side discovery**: the calling service queries a service registry (Consul) and picks an instance itself, handling load balancing in the client. **Server-side discovery**: a load balancer or DNS handles routing — the client just calls a stable name (`http://order-service/api/orders`). In Kubernetes, server-side discovery via DNS is the default: a Service resource provides a stable DNS name and virtual IP, and kube-proxy routes to healthy pods.

## Detailed Explanation

### The Problem

Without service discovery:

```csharp
// ❌ Hardcoded IP — fails when container restarts
var client = new HttpClient { BaseAddress = new Uri("http://192.168.1.45:8080/") };
// Container gets new IP on every restart → ConfigMaps need updating → fragile
```

With Kubernetes DNS (server-side):
```csharp
// ✅ Stable DNS name — Kubernetes resolves to current healthy pods
var client = new HttpClient { BaseAddress = new Uri("http://order-service.orders.svc.cluster.local/") };
// or simply: http://order-service/ (within same namespace)
```

### Client-Side Discovery with Consul

```
[Service A starts]
    → registers itself: { service: "order-service", address: "10.0.0.5", port: 8080, check: "http://10.0.0.5:8080/health" }
    → Consul stores registration

[Service B calls Order Service]
    → queries Consul: GET /v1/catalog/service/order-service
    → Consul returns: [{ address: "10.0.0.5", port: 8080 }, { address: "10.0.0.6", port: 8080 }]
    → Service B picks one (round-robin, random, etc.) and calls it directly
```

```csharp
// .NET: register with Consul using Consul.NET library
builder.Services.Configure<ConsulServiceOptions>(o =>
{
    o.ServiceName = "order-service";
    o.ServicePort = 8080;
    o.HealthCheckUrl = "http://order-service/health";
    o.ConsulAddress = new Uri("http://consul:8500");
});

builder.Services.AddHostedService<ConsulRegistrationService>();

// Discovery: HttpClient factory with Consul-backed address resolution
builder.Services.AddHttpClient("inventory-service")
    .AddServiceDiscovery(); // Steeltoe or custom Consul-based resolver
```

### Server-Side Discovery (Kubernetes DNS)

Kubernetes creates a DNS entry for every `Service` resource:

```yaml
# Kubernetes Service for OrderService
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: orders
spec:
  selector:
    app: order-service       # ← selects pods with this label
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP            # ← stable internal IP, DNS: order-service.orders.svc.cluster.local
```

```csharp
// .NET service calling order-service in Kubernetes
builder.Services.AddHttpClient("order-service", c =>
    c.BaseAddress = new Uri("http://order-service/")); // ← Kubernetes DNS resolves this

// Or use Microsoft.Extensions.ServiceDiscovery (net9 feature)
builder.Services.AddServiceDiscovery();
builder.Services.ConfigureHttpClientDefaults(c => c.AddServiceDiscovery());

// In appsettings.json (net9 service discovery config):
{
  "Services": {
    "order-service": { "https": [ { "host": "order-service", "port": 443 } ] }
  }
}
```

### Health Check Integration

Service discovery relies on health checks to route traffic only to healthy instances:

```csharp
// ASP.NET Core health checks
builder.Services.AddHealthChecks()
    .AddDbContextCheck<AppDbContext>("database")
    .AddUrlGroup(new Uri("http://inventory-service/health"), "inventory-dependency");

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false  // ← liveness: always returns 200 if process is up
});
```

### Comparison

| | Kubernetes DNS | Consul |
|--|---------------|--------|
| **Type** | Server-side | Client-side |
| **Load balancing** | kube-proxy (round-robin) | Client-configured |
| **Setup** | Zero (built-in) | Consul cluster required |
| **Multi-datacenter** | No (per-cluster only) | Yes (datacenter federation) |
| **Non-Kubernetes** | No | Yes |
| **Service mesh** | Works with Istio/Linkerd | Works with Consul Connect |

## Code Example

```csharp
// .NET 9 Microsoft.Extensions.ServiceDiscovery
// Resolves service addresses from config, Consul, Kubernetes endpoints, or DNS

builder.Services.AddServiceDiscovery();

builder.Services.AddHttpClient<IOrderServiceClient, OrderServiceHttpClient>(c =>
    c.BaseAddress = new Uri("http://order-service/"))  // ← logical name
    .AddServiceDiscovery();  // ← resolves actual address at runtime

// DI: in Kubernetes → Kubernetes endpoint resolver; in dev → appsettings.json config
```

## Common Follow-up Questions

- How does Kubernetes handle service discovery for services in different namespaces?
- What is a headless service in Kubernetes, and when do you need it?
- How do you implement circuit breaking in combination with service discovery?
- How does service discovery work in a local development environment?
- What is the difference between a Kubernetes Service and an Ingress?

## Common Mistakes / Pitfalls

- **Caching service addresses too aggressively**: caching a service's resolved IP for 10 minutes means traffic goes to a dead pod for up to 10 minutes after it's replaced.
- **No health check endpoint**: a service registered in Consul or Kubernetes without a health check will continue receiving traffic even after it crashes.
- **DNS caching in .NET HttpClient**: the default `HttpClient` caches DNS resolution indefinitely. Use `SocketsHttpHandler.PooledConnectionLifetime = TimeSpan.FromMinutes(1)` to force periodic re-resolution.
- **Service discovery for everything**: in a Kubernetes cluster, stable service names (ClusterIP DNS) work without any extra library. Only add Consul when you need multi-datacenter federation or non-Kubernetes environments.

## References

- [Microsoft.Extensions.ServiceDiscovery — .NET 9](https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-9/runtime#service-discovery)
- [Kubernetes Service networking](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Consul service discovery documentation](https://developer.hashicorp.com/consul/docs/discovery/services)
- [See: health-checks-in-microservices.md](./health-checks-in-microservices.md)
