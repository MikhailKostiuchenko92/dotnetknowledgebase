# Service Discovery

**Category:** System Design / Microservices
**Difficulty:** Middle
**Tags:** `service-discovery`, `consul`, `kubernetes`, `dns`, `health-checks`, `load-balancing`

## Question

> Explain service discovery in a microservices architecture. What is the difference between client-side and server-side discovery? How does Kubernetes DNS differ from Consul?

- How do services register themselves and how are failures detected?
- What happens when a service instance crashes before it deregisters?

## Short Answer

Service discovery is the mechanism by which services find each other's network addresses at runtime, without hardcoded IPs. In **client-side discovery**, the caller queries a registry (Consul, etcd) and load-balances itself. In **server-side discovery**, the caller routes to a load balancer or service mesh that resolves the destination. Kubernetes DNS provides server-side discovery out of the box via `ClusterIP` services and kube-proxy; Consul provides richer health checking and multi-cloud support. Crash detection relies on health check TTLs or TCP heartbeats — failed instances are removed from the registry within seconds.

## Detailed Explanation

### Why Service Discovery?

In a static deployment, you hardcode `http://payments-server-1:8080`. In a dynamic cloud environment, containers are scheduled on arbitrary hosts, auto-scaled, and replaced on failure. IPs change constantly. Service discovery provides a **stable name** (`http://payments`) that always resolves to a healthy instance.

### Client-Side Discovery

The client queries the service registry directly, receives a list of healthy endpoints, and applies a load-balancing strategy (round-robin, least-connections) itself.

```
Client → Registry (Consul / Eureka): "give me healthy instances of 'payments'"
       ← [10.0.1.5:8080, 10.0.1.6:8080, 10.0.1.7:8080]
Client picks 10.0.1.6 → sends request directly
```

**Pros**: full control over load balancing strategy; no extra network hop.  
**Cons**: every client language/framework needs its own discovery library; registry failures affect clients directly.

### Server-Side Discovery

The client sends a request to a fixed stable endpoint (load balancer, API gateway, or service mesh sidecar). The infrastructure resolves and routes to a healthy instance.

```
Client → Load Balancer / Ingress: "POST http://payments/charge"
       ← Load balancer resolves to 10.0.1.6:8080 internally
Client never sees instance IPs
```

**Pros**: client is simple; discovery logic centralised; clients don't need registry libraries.  
**Cons**: extra network hop; load balancer itself must be highly available.

| | Client-side | Server-side |
|--|-------------|-------------|
| Load balance logic | In client | In infra |
| Client complexity | Higher | Lower |
| Discovery library | Required per language | Not required |
| Example | Netflix Eureka + Ribbon | Kubernetes, Nginx, Consul Connect |

### Kubernetes DNS (Server-Side, Built-in)

Every Kubernetes `Service` gets a DNS entry: `<service-name>.<namespace>.svc.cluster.local`. kube-proxy creates virtual IP (ClusterIP) rules on every node; traffic to the ClusterIP is DNAT'd to a healthy pod IP.

```yaml
# Service definition
apiVersion: v1
kind: Service
metadata:
  name: payments
  namespace: default
spec:
  selector:
    app: payments
  ports:
    - port: 80
      targetPort: 8080
```

Pods resolve `http://payments` (or `http://payments.default`) inside the cluster. kube-proxy keeps endpoint lists up to date via the Endpoints API; when a pod fails its readiness probe, it is removed from the endpoint slice within seconds.

### Consul (Client-Side or Server-Side)

Consul maintains a distributed key-value store and service catalogue. Each service instance registers with the local Consul agent, which forwards to the Consul server cluster (3–5 nodes, Raft consensus).

**Service registration** (agent sidecar):
```json
{
  "service": {
    "name": "payments",
    "address": "10.0.1.6",
    "port": 8080,
    "check": {
      "http": "http://localhost:8080/health/live",
      "interval": "10s",
      "deregister_critical_service_after": "30s"
    }
  }
}
```

Consul performs the health check every 10 s. If the check fails, the instance is marked critical. After 30 s of critical status, it is **deregistered automatically** — solving the "crashed before deregister" problem.

### Crash Detection & Deregistration

A service that crashes abruptly cannot deregister itself. Two mechanisms handle this:

1. **TTL-based heartbeat**: service calls `PUT /agent/check/pass/service:payments` every 10 s. If the TTL expires (20 s with no heartbeat), Consul marks it critical.
2. **Active HTTP/TCP check**: Consul agent polls `GET /health/live` every 10 s. On crash, TCP connection fails → immediate failure.
3. **Auto-deregister**: `deregister_critical_service_after` removes the entry from DNS after a configurable window.

In Kubernetes, the readiness probe handles this — a pod that fails readiness is removed from the Service endpoint list within 5–10 s.

### Health Checks in ASP.NET Core

See [health-checks-in-aspnet-core.md](./health-checks-in-aspnet-core.md) for full details. The key distinction for service discovery:

- **Liveness probe** (`/health/live`): is the process alive? Should it be restarted? (JVM deadlock, infinite loop)
- **Readiness probe** (`/health/ready`): is the service able to handle traffic? (DB connection ready, cache warm)

Service discovery registries should use the **readiness** endpoint to gate traffic — a service that has started but whose DB is unreachable should not receive requests.

### .NET Integration with Consul

```csharp
// Steeltoe or direct Consul SDK
builder.Services.AddConsul(consulOptions =>
{
    consulOptions.Address = new Uri("http://consul:8500");
});

builder.Services.AddConsulServiceRegistration(serviceOptions =>
{
    serviceOptions.ServiceName = "payments";
    serviceOptions.ServiceAddress = builder.Configuration["Pod:IP"];
    serviceOptions.ServicePort = 8080;
    serviceOptions.HealthCheckPath = "/health/ready";
    serviceOptions.HealthCheckInterval = "10s";
    serviceOptions.DeregisterCriticalServiceAfter = "30s";
});
```

### Comparison: Kubernetes DNS vs Consul

| Feature | Kubernetes DNS | Consul |
|---------|:--------------:|:------:|
| Built-in | ✅ | ❌ (separate deployment) |
| Multi-cloud / multi-cluster | ❌ | ✅ |
| Rich health checking | Limited (probes) | ✅ (HTTP, TCP, script, TTL) |
| Service mesh integration | Via Istio/Linkerd | Consul Connect (mTLS) |
| KV store | ❌ | ✅ |
| DNS-based discovery | ✅ | ✅ |
| Best for | Kubernetes-only | Hybrid / multi-platform |

> **Warning:** Running Consul inside Kubernetes when you don't need multi-cloud or advanced health checking adds operational complexity for little gain. Kubernetes DNS + readiness probes covers 90% of use cases.

## Code Example

```csharp
// HttpClient with Kubernetes service discovery (DNS-based — simplest approach)
// No library needed; the service DNS name is stable

var builder = WebApplication.CreateBuilder(args);

// Register typed HTTP client pointing to stable Kubernetes Service DNS name
builder.Services.AddHttpClient<IPaymentsClient, PaymentsHttpClient>(client =>
{
    // Resolves via Kubernetes DNS → kube-proxy → healthy pod
    client.BaseAddress = new Uri("http://payments.default.svc.cluster.local");
    client.Timeout = TimeSpan.FromSeconds(10);
});

// With Polly resilience (retry + circuit breaker)
builder.Services.AddHttpClient<IPaymentsClient, PaymentsHttpClient>(client =>
    client.BaseAddress = new Uri("http://payments"))
    .AddResilienceHandler("payments-resilience", builder =>
    {
        builder.AddRetry(new RetryStrategyOptions<HttpResponseMessage>
        {
            MaxRetryAttempts = 2,
            Delay            = TimeSpan.FromMilliseconds(200),
            BackoffType      = DelayBackoffType.Exponential,
            ShouldHandle     = args => args.Outcome.Result?.StatusCode
                                    is HttpStatusCode.ServiceUnavailable
                                    or HttpStatusCode.GatewayTimeout
                               ? new ValueTask<bool>(true)
                               : new ValueTask<bool>(false),
        });
        builder.AddCircuitBreaker(new CircuitBreakerStrategyOptions<HttpResponseMessage>
        {
            FailureRatio      = 0.5,
            SamplingDuration  = TimeSpan.FromSeconds(15),
            MinimumThroughput = 5,
            BreakDuration     = TimeSpan.FromSeconds(10),
        });
    });

// Consul-based discovery with Steeltoe (multi-cloud scenario)
builder.Services.AddServiceDiscovery(options =>
    options.UseConsul());

builder.Services.AddHttpClient<IPaymentsClient, PaymentsHttpClient>(client =>
    // Steeltoe intercepts the address and resolves via Consul
    client.BaseAddress = new Uri("https://payments"));
```

## Common Follow-up Questions

- How does service discovery interact with blue-green or canary deployments — how do you gradually shift traffic?
- What is a service mesh, and how does it extend service discovery with mTLS, observability, and traffic policies?
- How do you handle service discovery in a multi-region active-active deployment?
- If Consul itself has a split-brain failure, what happens to in-flight service registrations?
- How does client-side load balancing (gRPC) differ from proxy-based load balancing?

## Common Mistakes / Pitfalls

- **Hardcoding service IPs or ports in environment variables**: defeats the purpose of service discovery; use DNS names and let the registry handle resolution.
- **Not configuring auto-deregister TTL**: a crashed service remains in the registry, causing intermittent 503s until someone manually cleans it up.
- **Using liveness probe for traffic routing**: a service that is alive but not ready (e.g., DB connection initialising) should not receive traffic; use readiness probe for load balancer health.
- **Polling the registry on every request**: cache discovery results for 5–30 s; continuous polling overloads the registry and adds latency to every call.
- **Deploying Consul without a 3-node quorum**: a single-node Consul loses all registrations on restart; always deploy a 3 or 5 node cluster.
- **Not handling DNS caching in JVM/.NET**: some runtimes cache DNS results aggressively; set TTL appropriately or use Consul SDK instead of pure DNS.

## References

- [Service Discovery at Netflix — Eureka](https://netflixtechblog.com/eureka-the-netflix-service-discovery-framework-the-b51c3c80d1) (verify URL)
- [Consul Service Discovery](https://developer.hashicorp.com/consul/docs/concepts/service-discovery)
- [Kubernetes Services and DNS](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Steeltoe Service Discovery for .NET](https://docs.steeltoe.io/api/v3/discovery/)
- [See: sidecar-pattern.md](./sidecar-pattern.md)
- [See: health-checks-in-aspnet-core.md](./health-checks-in-aspnet-core.md) (§9)
