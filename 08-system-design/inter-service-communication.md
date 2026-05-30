# Inter-Service Communication

**Category:** System Design / Microservices
**Difficulty:** Middle
**Tags:** `rest`, `grpc`, `messaging`, `synchronous`, `asynchronous`, `coupling`

## Question

> What are the trade-offs between synchronous (REST/gRPC) and asynchronous (messaging) communication in a microservices architecture? When do you choose each?

- How does communication style affect service coupling and resilience?
- What is temporal coupling and why is it a problem?

## Short Answer

Synchronous communication (REST, gRPC) is simple and returns an immediate response, but creates **temporal coupling** — both services must be up simultaneously, and a slow downstream cascades into the upstream. Asynchronous messaging (Kafka, RabbitMQ, Azure Service Bus) decouples services in time: the sender publishes and continues; the receiver processes when ready. Use sync for user-facing request/response flows where the client needs an immediate answer; use async for cross-domain state propagation, long-running workflows, and anywhere temporal decoupling increases resilience.

## Detailed Explanation

### Synchronous Communication

#### REST (HTTP/JSON)

The dominant choice for external APIs and simple service-to-service calls.

**Pros**: universal tooling, human-readable, stateless, caches at HTTP layer.  
**Cons**: JSON serialisation overhead; HTTP/1.1 request-per-connection; verbose headers; no streaming (without SSE/WebSocket).

#### gRPC (HTTP/2 + Protobuf)

Binary protocol with code-generated strongly-typed clients.

**Pros**: 2–7× faster serialisation than JSON; HTTP/2 multiplexing (many calls per connection); bidirectional streaming; contract-first via `.proto`.  
**Cons**: not human-readable; browser unfriendly (requires gRPC-Web proxy); `.proto` file coupling (both sides must regenerate on schema change).

| | REST | gRPC |
|--|------|------|
| Serialisation | JSON (text) | Protobuf (binary) |
| Typing | Runtime | Compile-time (generated) |
| Streaming | No (SSE/WS workaround) | Native (server, client, bidirectional) |
| Browser native | ✅ | ❌ (needs gRPC-Web) |
| Performance | Moderate | High |
| Best for | External APIs, simple integration | Internal high-throughput, streaming |

### Asynchronous Communication

#### Message Brokers (RabbitMQ, Kafka, Azure Service Bus)

The sender publishes a message to a broker; the receiver subscribes and processes independently. See [pub-sub-vs-message-queue.md](./pub-sub-vs-message-queue.md) for broker comparison.

**Pros**: temporal decoupling; natural load levelling (broker buffers bursts); retry with DLQ; fan-out to multiple consumers.  
**Cons**: eventual consistency (receiver processes after some delay); harder to debug (no direct call stack); infrastructure to operate.

### Temporal Coupling

When Service A calls Service B synchronously, A cannot proceed until B responds. This means:

- If B is slow (p99 = 3 s), A's response time degrades to 3 s+.
- If B is down, A returns an error — even if A's operation doesn't logically need B's response immediately.
- A chain A → B → C → D multiplies latency and compounds availability: 99.9%³ = 99.7%.

**Async breaks temporal coupling**: A publishes an event and returns immediately. B processes when it's ready, even if it was restarted in the interim.

### Decision Framework

```
Does the client need an immediate answer?
├── YES → Is the downstream service a first-party internal service?
│         ├── YES + high throughput → gRPC
│         └── YES + standard use   → REST
└── NO  → Is this cross-domain state propagation / long-running?
          └── YES → Async messaging (Kafka / Service Bus)

Special cases:
- Downstream is a legacy system                → REST (most compatible)
- Internal service, streaming / bidirectional  → gRPC
- Fire-and-forget side effects                 → Async (email, audit log)
- Distributed transaction / saga               → Async + choreography
- Real-time push to clients                    → WebSocket / SSE
```

### Combining Sync + Async: Saga Pattern

A common pattern: the user-facing API call is synchronous; downstream cross-service coordination is asynchronous (choreography-based saga):

```
POST /orders → Orders Service (sync)
   ├── Persist order (status=PENDING)
   ├── Return 202 Accepted to client
   └── Publish OrderPlaced event → Kafka
                                      ↓
                              Inventory Service (async)
                              → Reserve stock
                              → Publish InventoryReserved
                                              ↓
                                    Shipping Service (async)
                                    → Create shipment
                                    → Publish ShipmentScheduled
```

The client polls `GET /orders/{id}` or receives a webhook when the order reaches `CONFIRMED`.

### gRPC in .NET

```csharp
// product.proto
syntax = "proto3";
service ProductService {
    rpc GetProduct (GetProductRequest) returns (Product);
    rpc GetProducts (GetProductsRequest) returns (stream Product); // server streaming
}
message GetProductRequest { string id = 1; }
message Product { string id = 1; string name = 2; int32 price_cents = 3; }
```

```csharp
// Server — ASP.NET Core
public class ProductGrpcService(IProductRepository repo) : ProductService.ProductServiceBase
{
    public override async Task<Product> GetProduct(
        GetProductRequest request, ServerCallContext ctx)
    {
        var p = await repo.GetAsync(Guid.Parse(request.Id), ctx.CancellationToken);
        return new Product { Id = p.Id.ToString(), Name = p.Name, PriceCents = p.PriceCents };
    }
}

// Client — injected via HttpClient factory
builder.Services.AddGrpcClient<ProductService.ProductServiceClient>(o =>
    o.Address = new Uri("https://products-service"));
```

### Resilience for Sync Calls

Synchronous calls must handle downstream failures gracefully:

```csharp
// Polly v8 / Microsoft.Extensions.Resilience
services.AddHttpClient<IProductsClient, ProductsHttpClient>()
    .AddResilienceHandler("products", pipeline =>
    {
        pipeline.AddRetry(new RetryStrategyOptions<HttpResponseMessage>
        {
            MaxRetryAttempts = 3,
            Delay            = TimeSpan.FromMilliseconds(200),
            BackoffType      = DelayBackoffType.Exponential,
        });
        pipeline.AddCircuitBreaker(new CircuitBreakerStrategyOptions<HttpResponseMessage>
        {
            FailureRatio     = 0.5,
            BreakDuration    = TimeSpan.FromSeconds(10),
        });
        pipeline.AddTimeout(TimeSpan.FromSeconds(3)); // always set a timeout
    });
```

> **Warning:** Never make a synchronous inter-service call without a timeout. Without one, a hung downstream holds a thread until the request is cancelled externally — under load this exhausts the thread pool.

## Common Follow-up Questions

- How does the choice of sync vs async affect your ability to do distributed transactions?
- What is the "two generals' problem" and how does it relate to exactly-once delivery in async systems?
- You need to make a cross-service call that must be consistent with a local DB write. How do you do this safely?
- How do you test a service that communicates asynchronously — you can't mock a Kafka topic easily in unit tests?
- What is backpressure in the context of async messaging, and how does Kafka handle it compared to RabbitMQ?

## Common Mistakes / Pitfalls

- **Synchronous chain of 5+ services**: every link multiplies failure probability and adds latency; flatten with async or use an aggregation service.
- **No timeout on outbound HTTP clients**: `HttpClient` has no default timeout in .NET 8; set `Timeout` explicitly or use Polly.
- **Using REST for internal high-frequency calls (>1K RPS)**: JSON serialisation overhead is measurable at scale; consider gRPC or at minimum MessagePack.
- **Treating messaging as fire-and-forget**: unhandled consumer exceptions without a DLQ lead to silent message loss; always configure a dead-letter queue.
- **Async all the things**: user-facing flows that need immediate feedback (checkout, auth) are awkward and confusing with pure async; use sync for the happy path, async for side effects.
- **Generating gRPC clients at runtime instead of build time**: always generate clients at build time from `.proto` files; runtime generation makes versioning fragile.

## References

- [gRPC in .NET — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/grpc/)
- [Building Microservices — Sam Newman (Chapter: Communication)](https://samnewman.io/books/building_microservices/)
- [.NET gRPC Performance blog — Microsoft](https://devblogs.microsoft.com/dotnet/grpc-performance-improvements-in-net-5/)
- [See: pub-sub-vs-message-queue.md](./pub-sub-vs-message-queue.md)
- [See: at-least-once-vs-exactly-once.md](./at-least-once-vs-exactly-once.md)
- [See: circuit-breaker-pattern.md](./circuit-breaker-pattern.md)
