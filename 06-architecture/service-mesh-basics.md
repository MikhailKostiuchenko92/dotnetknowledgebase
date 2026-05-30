# Service Mesh Basics

**Category:** Architecture / Microservices
**Difficulty:** 🟡 Middle
**Tags:** `service-mesh`, `Istio`, `Linkerd`, `mTLS`, `traffic-management`, `observability`, `sidecar`

## Question

> What is a service mesh? Describe the control plane and data plane, how Istio or Linkerd handle mTLS and traffic management, and when a service mesh is the right choice vs application-level resilience (Polly).

## Short Answer

A **service mesh** is an infrastructure layer that manages service-to-service communication through sidecar proxies (Envoy for Istio, micro-proxy for Linkerd). The **data plane** handles every network packet (mTLS, retries, circuit breaking, load balancing, distributed tracing). The **control plane** (Istio's Istiod, Linkerd's controller) distributes configuration to the sidecars. A service mesh is the right choice when you have many services across multiple teams and want to enforce security (mTLS), observability (automatic tracing), and traffic policies without requiring each application to implement them individually.

## Detailed Explanation

### Architecture

```
Data Plane (per pod):
  ┌─────────────────────────────────────────────────────┐
  │  App Container          │  Envoy Proxy (sidecar)    │
  │  (business logic)       │  - mTLS origination       │
  │                         │  - mTLS termination       │
  │                   ←───→ │  - Retries / timeouts     │
  │                         │  - Circuit breaking       │
  │                         │  - Load balancing         │
  │                         │  - Distributed tracing    │
  └─────────────────────────────────────────────────────┘

Control Plane (cluster-wide):
  Istiod (Istio) or Linkerd controller:
  - Distributes TLS certificates to sidecars
  - Pushes routing rules (VirtualService, DestinationRule)
  - Aggregates telemetry
  - Enforces authorization policies (PeerAuthentication, AuthorizationPolicy)
```

### mTLS (Mutual TLS)

Service mesh provides mTLS automatically — no application code changes:

```yaml
# Istio: require mTLS for all services in the namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # ← all services must use mTLS; plain HTTP rejected
```

mTLS means both the client and server present certificates — cryptographically verifying service identity. Without a mesh, you'd need to manage TLS certificates in every application.

### Traffic Management (Istio)

```yaml
# Canary deployment: route 10% of traffic to v2
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: order-service
spec:
  hosts: [order-service]
  http:
    - route:
        - destination: { host: order-service, subset: v1 }
          weight: 90
        - destination: { host: order-service, subset: v2 }
          weight: 10

---
# Retry and timeout policy
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: inventory-service
spec:
  hosts: [inventory-service]
  http:
    - timeout: 2s
      retries:
        attempts: 3
        perTryTimeout: 500ms
        retryOn: "5xx,reset"
      route:
        - destination: { host: inventory-service }
```

### Service Mesh vs Application-Level Resilience

| | Service Mesh (Istio/Linkerd) | App-Level (Polly) |
|--|----------------------------|-------------------|
| **Language/runtime** | Language-agnostic | .NET only |
| **Setup** | Kubernetes + mesh install | NuGet package |
| **mTLS** | Automatic, zero-code | Manual cert management |
| **Observability** | Automatic traces, metrics | Must instrument each service |
| **Retries** | Configured in YAML | Configured in code |
| **Circuit breaking** | Mesh policy | Polly `CircuitBreakerStrategy` |
| **Overhead** | Sidecar CPU/memory + latency (~2ms) | Minimal |
| **Best for** | Multi-language, 10+ services | Single-language, smaller scale |

### Linkerd vs Istio

| | Linkerd | Istio |
|--|---------|-------|
| **Complexity** | Lower — simpler to operate | Higher — more features |
| **Performance** | Very low overhead (Rust proxy) | Higher (Envoy) |
| **Features** | mTLS, retries, observability | Everything + traffic management, WASM |
| **Multi-cluster** | Supported | Full multi-cluster |
| **Best for** | Simplicity, security | Full traffic control, canary |

## Code Example

```csharp
// With service mesh: zero resilience code in the application
// Retries, timeouts, circuit breaking handled by the sidecar

public class InventoryClient(HttpClient http) : IInventoryClient
{
    // No Polly, no retry, no timeout — mesh handles it
    public Task<StockInfo?> GetStockAsync(int productId, CancellationToken ct)
        => http.GetFromJsonAsync<StockInfo>($"/api/stock/{productId}", ct);
}

// Comparison: same service WITHOUT mesh — needs Polly
public class InventoryClientWithPolly(IHttpClientFactory factory) : IInventoryClient
{
    public async Task<StockInfo?> GetStockAsync(int productId, CancellationToken ct)
    {
        var client = factory.CreateClient("inventory");
        // Retry and circuit breaker configured in DI (see resilience-architecture section)
        return await client.GetFromJsonAsync<StockInfo>($"/api/stock/{productId}", ct);
    }
}
```

## Common Follow-up Questions

- How do you observe mesh traffic — what dashboards/tools does Istio provide?
- What is a `DestinationRule` in Istio, and when do you need one?
- How do you implement authorization (not just authentication) policies in a service mesh?
- What is the Ambient Mesh mode in Istio, and how does it differ from sidecar mode?
- How do you migrate from Polly-based resilience to mesh-managed resilience?

## Common Mistakes / Pitfalls

- **Deploying a service mesh for 3–5 services**: the operational overhead (learning curve, debugging, resource cost) of a service mesh only pays off at 10+ services / multiple teams.
- **Double retries**: if both the mesh (3 retries) and Polly (3 retries) are configured, a single failure can produce 9 upstream calls. Disable one layer of retries when using both.
- **Not understanding data plane latency**: Envoy adds ~1–3ms per hop. For latency-sensitive synchronous call chains, this compounds.
- **Ignoring certificate rotation**: service mesh certificates expire. Istio manages rotation automatically, but you need monitoring alerts for rotation failures.

## References

- [Istio documentation](https://istio.io/latest/docs/)
- [Linkerd documentation](https://linkerd.io/2.14/overview/)
- [Service Mesh — Microsoft Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/microservices/design/service-mesh) (verify URL)
- [See: sidecar-and-ambassador-patterns.md](./sidecar-and-ambassador-patterns.md)
