# Sidecar Pattern

**Category:** System Design / Microservices
**Difficulty:** Middle
**Tags:** `sidecar`, `service-mesh`, `dapr`, `istio`, `observability`, `proxy`

## Question

> What is the sidecar pattern in microservices? How does it relate to a service mesh? When would you use Dapr vs Istio vs in-process libraries in a .NET application?

- What cross-cutting concerns does a sidecar handle?
- What are the trade-offs of injecting a sidecar vs embedding the logic in the application?

## Short Answer

The sidecar pattern deploys a helper container alongside the main application container in the same pod (or VM), sharing its network namespace and localhost address space. The sidecar intercepts all inbound/outbound network traffic, providing cross-cutting concerns — mTLS, retries, circuit breaking, distributed tracing, metrics — without modifying application code. Istio/Envoy is a transparent network-layer sidecar; Dapr is an explicit programming-model sidecar accessed via HTTP/gRPC from the app. Use Dapr when you want portability and a rich building-block API; use Istio for transparent infrastructure-level policies across a heterogeneous fleet.

## Detailed Explanation

### What the Sidecar Handles

| Concern | In-Process Library | Sidecar |
|---------|:-----------------:|:-------:|
| mTLS between services | App must include cert code | Transparent (Envoy) |
| Distributed tracing | `OpenTelemetry` NuGet | Auto-injected spans |
| Retries / circuit breaking | Polly | Envoy / Dapr |
| Service discovery | Steeltoe / DNS | Envoy + control plane |
| Rate limiting | Custom / Redis | Envoy |
| Language heterogeneity | One library per language | Single sidecar for all |

### Istio (Envoy Proxy Sidecar)

Istio automatically injects an Envoy proxy container into every pod in a namespace. The app is completely unaware:

```
Pod
├── app container     (port 8080)
└── envoy sidecar    (intercepts all traffic via iptables rules)
     ├── inbound:  decrypt mTLS, validate JWT, trace, apply policy → forward to :8080
     └── outbound: intercept app's HTTP calls, encrypt mTLS, retry, circuit-break
```

The **control plane** (istiod) distributes routing rules, certificates, and policies via xDS API.

**Pros**: zero code changes; works for any language; fine-grained traffic policies (canary, fault injection).  
**Cons**: complex to operate; ~50–100 ms latency overhead; difficult to debug; large operational blast radius.

### Dapr (Distributed Application Runtime)

Dapr is an explicit sidecar: the app calls it deliberately via HTTP or gRPC on `localhost:3500`. Dapr exposes **building blocks** — stable APIs for common distributed system patterns — backed by pluggable components.

```
App container → HTTP GET localhost:3500/v1.0/state/statestore/key
             ← Dapr sidecar → (Redis, Azure Blob, DynamoDB, etc.)
```

| Building Block | Dapr API |
|----------------|---------|
| State management | `/v1.0/state/{store}` |
| Pub/Sub | `/v1.0/publish/{pubsub}/{topic}` |
| Service invocation | `/v1.0/invoke/{appId}/method/{method}` |
| Secrets | `/v1.0/secrets/{store}/{name}` |
| Bindings (cron, S3…) | `/v1.0/bindings/{name}` |

**Pros**: portable across clouds (swap Redis for Azure Storage by changing config); rich .NET SDK; no service mesh required.  
**Cons**: explicit API dependency; sidecar process adds memory (~20 MB) and latency (~1 ms extra hop).

### Dapr in .NET (SDK)

```csharp
using Dapr.Client;

var client = new DaprClientBuilder().Build();

// State store (Redis / Azure CosmosDB / SQL — all via same API)
await client.SaveStateAsync("statestore", $"order:{orderId}", order);
var saved = await client.GetStateAsync<Order>("statestore", $"order:{orderId}");

// Pub/Sub (RabbitMQ / Kafka / Azure Service Bus)
await client.PublishEventAsync("pubsub", "orders-created", order);
```

### In-Process vs Sidecar — Decision Matrix

| Factor | In-Process (Polly, OpenTelemetry) | Sidecar (Dapr/Istio) |
|--------|:---------------------------------:|:--------------------:|
| Language homogeneity (.NET only) | ✅ preferred | Overkill |
| Polyglot fleet | ❌ per-language work | ✅ |
| Infrastructure team owns policies | ❌ | ✅ |
| Low latency critical path | ✅ (no extra hop) | ⚠️ |
| Cloud portability | ❌ provider SDK | ✅ (Dapr) |
| K8s only | Fine | Istio/Dapr both |

> **Warning:** Running both Istio and Dapr on the same cluster doubles the sidecar containers per pod and can cause mTLS conflicts. Choose one layer for traffic management. Dapr + in-process Polly is a common pragmatic choice that avoids full Istio complexity.

## Code Example

```csharp
// Dapr sidecar integration — .NET SDK
// Orders service publishes an event; Inventory service subscribes
// Both use the same Dapr pub/sub API regardless of underlying broker

// --- Orders Service: Publisher ---
using Dapr.Client;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDaprClient();

var app = builder.Build();

app.MapPost("/orders", async (CreateOrderRequest req, DaprClient dapr) =>
{
    var order = new Order(Guid.NewGuid(), req.ProductId, req.Quantity);

    // Save state
    await dapr.SaveStateAsync("statestore", $"order:{order.Id}", order);

    // Publish event (broker = Kafka / RabbitMQ / ASB — configured in component YAML)
    await dapr.PublishEventAsync("pubsub", "order-created", order);

    return Results.Created($"/orders/{order.Id}", order);
});

// --- Inventory Service: Subscriber ---
// Dapr pushes events to this endpoint automatically (topic subscription)
app.MapPost("/order-created", async (Order order, DaprClient dapr) =>
{
    // Reserve inventory
    var stock = await dapr.GetStateAsync<int>("statestore", $"stock:{order.ProductId}");
    if (stock < order.Quantity)
        return Results.Conflict("Insufficient stock");

    await dapr.SaveStateAsync("statestore", $"stock:{order.ProductId}", stock - order.Quantity);
    return Results.Ok();
})
.WithTopic("pubsub", "order-created"); // Dapr routing attribute

app.Run();
```

```yaml
# Dapr component: swap Redis → Azure CosmosDB with no code change
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.redis
  version: v1
  metadata:
    - name: redisHost
      value: redis-master:6379
```

## Common Follow-up Questions

- How does a sidecar affect pod startup time and rolling deployment speed?
- Dapr's sidecar adds ~1 ms per call. For a service making 1000 calls/s, is that acceptable?
- How does Istio handle certificate rotation for mTLS without restarting application pods?
- What happens to in-flight requests when the sidecar container is restarted during a pod update?
- How would you migrate an existing .NET service from using Polly directly to Dapr's resiliency building block?

## Common Mistakes / Pitfalls

- **Running Istio and Dapr together without coordination**: they can conflict on mTLS; disable Istio mTLS for Dapr ports or configure Istio to skip Dapr sidecar ports.
- **Using Dapr for greenfield without a portability need**: if you're 100% on Azure and will stay there, Azure SDK is simpler; Dapr adds value when cloud portability is real.
- **Ignoring sidecar resource limits**: each Envoy/Dapr sidecar consumes CPU and RAM; on a 1000-pod cluster the cumulative overhead is significant — set `resources.requests/limits`.
- **Trusting app traffic because mTLS is on the mesh**: mTLS authenticates services (machine identity), not users. Application-level authorisation is still required.
- **Not injecting sidecar in test environments**: if your tests bypass the sidecar entirely, you won't catch Dapr serialisation or topic routing issues until production.

## References

- [Dapr Documentation](https://docs.dapr.io/concepts/overview/)
- [Dapr .NET SDK](https://docs.dapr.io/developing-applications/sdks/dotnet/)
- [Istio Architecture](https://istio.io/latest/docs/ops/deployment/architecture/)
- [Sidecar Pattern — Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/sidecar)
- [See: service-discovery.md](./service-discovery.md)
- [See: service-mesh-vs-api-gateway.md](./service-mesh-vs-api-gateway.md)
