# Service Mesh vs API Gateway

**Category:** System Design / Microservices
**Difficulty:** Senior
**Tags:** `service-mesh`, `api-gateway`, `istio`, `dapr`, `east-west`, `north-south`

## Question

> What is the difference between a service mesh and an API gateway? Can you have both? When is a service mesh overkill?

- Explain the east-west vs north-south traffic distinction.
- How does Dapr relate to a service mesh?

## Short Answer

An **API gateway** manages **north-south traffic** — requests entering from external clients to the cluster. A **service mesh** manages **east-west traffic** — requests between services inside the cluster. The gateway is the public front door (auth, rate limiting, routing); the mesh is the private internal network layer (mTLS, retries, observability between services). You often have both: the gateway handles external concerns, the mesh handles internal reliability. A service mesh is overkill for small (<10 service) clusters where Polly + OpenTelemetry in-process covers the same needs with less operational overhead.

## Detailed Explanation

### North-South vs East-West

```
Internet
  │  (north-south traffic)
  ▼
[API Gateway / Ingress]   ← auth, rate limiting, routing, TLS termination
  │
  ▼
Cluster boundary
  │
  ├── Service A  ↔  Service B  ↔  Service C
  │        (east-west traffic)
  │        mTLS, retries, circuit breaking, tracing, policy
  │
  └── [Service Mesh control plane]  ← manages all east-west concerns
```

### API Gateway — Responsibilities

| Concern | Details |
|---------|---------|
| TLS termination | External HTTPS → internal HTTP |
| Authentication | JWT validation, OAuth2 token introspection |
| Rate limiting | Per-user, per-IP, per-tenant |
| Routing | Path-based, header-based, canary |
| Response transformation | Strip internal headers, normalise errors |
| Developer portal | OpenAPI docs, API keys |

**Examples**: Azure API Management, Kong, NGINX, YARP, AWS API Gateway

### Service Mesh — Responsibilities

| Concern | Details |
|---------|---------|
| mTLS | Automatic certificate issuance + rotation; all east-west traffic encrypted |
| Service identity | Each service has a SPIFFE/X.509 identity (workload identity) |
| Retries / timeouts | Configured in mesh policy, not application code |
| Circuit breaking | Per-destination in Envoy config |
| Distributed tracing | Auto-injected spans for all service-to-service calls |
| Traffic splitting | Canary between v1/v2 of an internal service |
| Policy enforcement | Authorisation policies (Service A may NOT call Service B's admin endpoint) |

**Examples**: Istio (Envoy proxy), Linkerd, Consul Connect

### When a Service Mesh Is Worth the Complexity

| Signal | Service Mesh Justified |
|--------|----------------------|
| Polyglot fleet (Go, Java, Python, .NET) | ✅ — one mesh policy, not per-language library |
| Strict compliance (PCI DSS, HIPAA) — must encrypt all east-west | ✅ — transparent mTLS |
| >20 services with complex traffic policies | ✅ |
| Dedicated platform/infra team to operate it | ✅ |
| Single language (.NET), Polly + OTel covers needs | ❌ — overkill |
| <10 services, small team | ❌ — operational overhead not worth it |
| Kubernetes-native app requiring fine-grained AuthZ | ✅ |

### Comparison Table

| Feature | API Gateway | Service Mesh |
|---------|:-----------:|:-----------:|
| Traffic direction | North-South (external) | East-West (internal) |
| mTLS | ❌ (terminates TLS externally) | ✅ (between every service pair) |
| Retries / circuit breaking | ✅ (to downstreams) | ✅ (transparent, all services) |
| Auth (JWT/OAuth2) | ✅ | ❌ (workload identity only) |
| Rate limiting (per-user) | ✅ | ❌ (can do connection-level) |
| Distributed tracing | ✅ (inject at ingress) | ✅ (auto all hops) |
| Sidecar per pod | ❌ | ✅ |
| Operational complexity | Medium | High |

### Dapr vs Service Mesh

Dapr is not a service mesh; it is a **runtime abstraction sidecar** that provides building blocks (state, pub/sub, service invocation). It sits at the application layer, not the network layer.

| | Dapr | Istio/Linkerd |
|--|------|---------------|
| Abstraction level | Application (building blocks) | Network (transport) |
| mTLS | ✅ (Dapr-to-Dapr) | ✅ (all TCP traffic) |
| Retries | ✅ (resiliency policy) | ✅ (VirtualService) |
| State management | ✅ | ❌ |
| Pub/Sub | ✅ | ❌ |
| App code change | Yes (use Dapr SDK / HTTP) | No (transparent) |
| Best with | .NET/polyglot needing portability | Large k8s fleet, strict network policies |

You CAN run Dapr alongside Istio (Dapr handles building blocks; Istio handles network policy) — but must disable mTLS conflicts on Dapr's ports.

### Typical Production Setup

**Small team (<15 services)**:
```
Internet → YARP API Gateway → Services (use Polly + OpenTelemetry in-process)
```
No service mesh; simple, effective.

**Medium/Large team (>20 services)**:
```
Internet → Azure APIM / Kong → Cluster Ingress
                                   │
                              Istio mesh (mTLS, tracing, traffic policy)
                                   │
                           Services (minimal resilience code — mesh handles it)
```

**Cloud-portable / polyglot**:
```
Internet → API Gateway → Dapr-enabled services
                         (Dapr: state, pub/sub, service invocation across clouds)
```

> **Warning:** Don't add a service mesh "for the observability". OpenTelemetry installed in your .NET services gives better application-level traces than mesh-injected spans, with no sidecar overhead. Add a mesh when you need network-level policy or mTLS compliance, not just metrics.

## Code Example

```csharp
// In a service mesh environment: application code simplified
// The mesh handles retries and mTLS — application just calls downstream

using System.Net.Http.Json;

namespace Orders.Application;

// No Polly retry here — Istio VirtualService defines retry policy:
// virtualservice.yaml: retries: attempts: 3, perTryTimeout: 2s, retryOn: 5xx
public sealed class InventoryClient(HttpClient http)
{
    // Plain HttpClient call — mesh intercepts and applies retry / mTLS / tracing
    public async Task<ReservationResult> ReserveAsync(
        Guid productId, int quantity, CancellationToken ct)
    {
        var response = await http.PostAsJsonAsync("/reserve",
            new { ProductId = productId, Quantity = quantity }, ct);

        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<ReservationResult>(ct)
            ?? throw new InvalidOperationException("Empty response");
    }
}

// Without mesh (in-process Polly):
// builder.Services.AddHttpClient<InventoryClient>()
//     .AddResilienceHandler("inventory", p => p.AddRetry(...).AddCircuitBreaker(...));

// With mesh (Istio/Linkerd):
// builder.Services.AddHttpClient<InventoryClient>(c =>
//     c.BaseAddress = new Uri("http://inventory-service")); // mesh handles the rest
```

```yaml
# Istio VirtualService — retry policy (replaces Polly for network-level retries)
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: inventory-service
spec:
  hosts:
    - inventory-service
  http:
    - retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,reset,connect-failure
      timeout: 8s
```

## Common Follow-up Questions

- If your service mesh handles retries, do you still need Polly in your .NET services?
- How does the mesh handle WebSocket traffic — does the sidecar proxy support long-lived connections?
- What is the cost (CPU, memory, latency) of adding Envoy sidecars across a 500-pod cluster?
- How does Istio's Authorisation Policy differ from RBAC in Kubernetes?
- How do you migrate from a no-mesh architecture to Istio without taking downtime?

## Common Mistakes / Pitfalls

- **Double retries**: if both Polly in the app and the mesh retry, a single failure triggers 3×3=9 attempts to the downstream. Decide who owns retries per layer and disable the other.
- **Treating the mesh as a security silver bullet**: mTLS encrypts transit; it doesn't stop a compromised service from making authorised requests. Combine with AuthZ policies.
- **Installing Istio before establishing observability baselines**: the Istio control plane itself needs monitoring; operators are often caught off-guard when istiod has issues.
- **Not setting resource requests on sidecars**: Envoy proxies without `resources.requests` will be scheduled on over-committed nodes and starved.
- **Using a mesh for north-south traffic**: mesh sidecars are not designed for the edge; use a dedicated ingress/gateway for external traffic even if the mesh has one.
- **Assuming Dapr replaces a service mesh**: Dapr does not provide network-level policy enforcement or compliance-grade mTLS for all traffic — it only covers Dapr-to-Dapr communication.

## References

- [Istio Architecture — istio.io](https://istio.io/latest/docs/ops/deployment/architecture/)
- [Linkerd vs Istio](https://linkerd.io/2024/01/linkerd-vs-istio/) (verify URL)
- [Dapr vs Service Mesh](https://docs.dapr.io/concepts/service-mesh/)
- [SPIFFE — Workload Identity Standard](https://spiffe.io/)
- [See: sidecar-pattern.md](./sidecar-pattern.md)
- [See: design-api-gateway.md](./design-api-gateway.md)
