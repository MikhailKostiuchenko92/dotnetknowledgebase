# Sidecar and Ambassador Patterns

**Category:** Architecture / Microservices
**Difficulty:** 🟡 Middle
**Tags:** `sidecar`, `ambassador`, `Dapr`, `Envoy`, `cross-cutting`, `service-mesh`, `proxy`

## Question

> What are the Sidecar and Ambassador container patterns? How do they handle cross-cutting concerns like retries, logging, and mTLS? How does Dapr use the sidecar pattern in .NET?

## Short Answer

The **Sidecar** pattern deploys a helper container alongside the main service container in the same Pod — the sidecar handles cross-cutting concerns (mTLS, metrics, logging, secret injection) without the application code knowing about them. The **Ambassador** pattern is a specialized sidecar that acts as a proxy for outbound requests — the application calls `localhost:8080/inventory` and the ambassador container forwards it to the real inventory service with retries, circuit breaking, and authentication. **Dapr** implements the sidecar pattern in .NET: every application gets a Dapr sidecar that handles service invocation, pub/sub, state management, and secrets via a local HTTP/gRPC API.

## Detailed Explanation

### Sidecar Pattern

```
Pod (Kubernetes)
┌─────────────────────────────────────────────────┐
│  Container: OrderService (.NET app)             │
│    - Business logic                             │
│    - Listens on :8080                           │
│                                                 │
│  Sidecar Container: Envoy Proxy                 │
│    - mTLS termination/origination               │
│    - Distributed tracing (Jaeger, Zipkin)       │
│    - Metrics collection (Prometheus)            │
│    - Access control policies                   │
│                                                 │
│  Shared: network namespace, localhost           │
└─────────────────────────────────────────────────┘
```

The application code is completely unaware of the sidecar — it just receives and makes plain HTTP calls. The sidecar intercepts these on the shared loopback network.

### Ambassador Pattern

The ambassador sidecar handles outbound calls:

```
OrderService calls: http://localhost:8888/inventory/check-stock

Ambassador container (Envoy):
  - Routes to http://inventory-service.internal:8080/check-stock
  - Adds retry (3x with exponential backoff)
  - Adds circuit breaker
  - Adds mTLS certificate
  - Injects correlation ID header
  - Records metrics

OrderService code: completely agnostic to routing, retry, mTLS
```

```csharp
// Application code: calls localhost ambassador — no retry, auth, or routing logic needed
public class OrderService(IInventoryClient inventory)
{
    public async Task<bool> CheckStockAsync(int productId, int qty, CancellationToken ct)
    {
        // Ambassador handles: retry, circuit breaker, mTLS, tracing
        return await inventory.CheckStockAsync(productId, qty, ct);
    }
}

// IInventoryClient implementation calls through localhost ambassador
public class AmbassadorInventoryClient(HttpClient http) : IInventoryClient
{
    public Task<bool> CheckStockAsync(int productId, int qty, CancellationToken ct)
        => http.GetFromJsonAsync<bool>($"/inventory/check?productId={productId}&qty={qty}", ct);
}

// Registered with ambassador base address
services.AddHttpClient<IInventoryClient, AmbassadorInventoryClient>(c =>
    c.BaseAddress = new Uri("http://localhost:8888/")); // ← ambassador on localhost
```

### Dapr Sidecar in .NET

Dapr (Distributed Application Runtime) uses the sidecar pattern to provide building blocks:

```csharp
// NuGet: Dapr.AspNetCore
builder.Services.AddDaprClient();

// Service invocation: call another Dapr-enabled service
public class OrderService(DaprClient dapr)
{
    public async Task<StockInfo?> CheckStockAsync(int productId, CancellationToken ct)
        => await dapr.InvokeMethodAsync<StockInfo>(
            HttpMethod.Get,
            "inventory-service",     // ← Dapr app ID
            $"stock/{productId}",    // ← method path
            ct);
}

// Pub/Sub: publish event via Dapr sidecar
public async Task PublishOrderSubmittedAsync(Order order, CancellationToken ct)
    => await dapr.PublishEventAsync(
        "pubsub",                     // ← Dapr component name
        "order-submitted",            // ← topic name
        new OrderSubmittedEvent(order.Id.Value),
        ct);

// Subscribe to topic — Dapr sidecar delivers to this endpoint
app.MapPost("/order-confirmed", async ([FromBody] OrderConfirmedEvent e, DaprClient dapr) =>
{
    // Process the event
});
app.MapSubscribeHandler(); // ← registers Dapr subscription endpoint
```

### Dapr State Management

```csharp
// Dapr state store: abstracts Redis, Cosmos, SQL Server, etc.
// Change backend in Dapr config — no code changes
await dapr.SaveStateAsync("statestore", $"order-{orderId}", orderState, ct: ct);
var state = await dapr.GetStateAsync<OrderState>("statestore", $"order-{orderId}", ct: ct);
```

## Code Example

```csharp
// Full Dapr integration: ASP.NET Core + Dapr sidecar
// No service discovery, no retry config, no pub/sub infrastructure code in the app

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDaprClient();
builder.Services.AddControllers().AddDapr();

var app = builder.Build();
app.UseCloudEvents();    // ← Dapr CloudEvents middleware
app.MapControllers();
app.MapSubscribeHandler(); // ← Dapr subscription registration endpoint

// Controller: publish + invoke
[ApiController, Route("api/orders")]
public class OrdersController(DaprClient dapr) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Place(PlaceOrderRequest req, CancellationToken ct)
    {
        var stockOk = await dapr.InvokeMethodAsync<bool>(HttpMethod.Get, "inventory-svc",
            $"check?productId={req.ProductId}", ct);
        if (!stockOk) return Conflict("Out of stock");

        await dapr.PublishEventAsync("pubsub", "order-placed",
            new OrderPlacedEvent(req.ProductId, req.Qty), ct);
        return Accepted();
    }
}
```

## Common Follow-up Questions

- What is the performance overhead of the Dapr sidecar, and is it significant in production?
- How does Dapr differ from a service mesh like Istio or Linkerd?
- How do you test code that uses DaprClient in unit tests?
- When would you choose Dapr over a direct Polly + MassTransit setup?
- How does the Sidecar pattern relate to the service mesh control plane/data plane split?

## Common Mistakes / Pitfalls

- **Putting business logic in the sidecar**: sidecars handle infrastructure concerns only. Routing rules, business validation, or domain logic in an Envoy Lua filter is an anti-pattern.
- **Dapr for everything including simple internal calls**: Dapr adds latency for every service invocation. Direct HTTP calls within the same pod or very simple deployments don't need Dapr.
- **Not mocking DaprClient in unit tests**: code using `DaprClient` directly is hard to unit test. Wrap Dapr calls in an interface (`IEventPublisher`, `IStateStore`) for testability.
- **Ignoring Dapr sidecar resource limits**: each Dapr sidecar runs as a container and consumes CPU/memory. In high-density deployments, sidecar resource limits need explicit configuration.

## References

- [Dapr documentation for .NET](https://docs.dapr.io/developing-applications/sdks/dotnet/)
- [Sidecar pattern — Microsoft Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/sidecar)
- [Ambassador pattern — Microsoft Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/ambassador)
- [See: service-mesh-basics.md](./service-mesh-basics.md)
