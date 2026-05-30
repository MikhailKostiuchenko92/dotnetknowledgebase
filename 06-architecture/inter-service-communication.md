# Inter-Service Communication

**Category:** Architecture / Microservices
**Difficulty:** 🟢 Junior
**Tags:** `microservices`, `REST`, `gRPC`, `async-messaging`, `RabbitMQ`, `Azure-Service-Bus`, `coupling`, `latency`

## Question

> What are the options for communication between microservices? Compare synchronous (REST, gRPC) and asynchronous (messaging) patterns — when would you use each, and what are the failure modes?

## Short Answer

Inter-service communication falls into two categories: **synchronous** (REST over HTTP/1.1, gRPC over HTTP/2) where the caller waits for a response, and **asynchronous** (message bus: RabbitMQ, Azure Service Bus, Kafka) where the caller publishes and moves on. Synchronous: simple, real-time, but creates temporal coupling — if the downstream service is down, the caller fails. Asynchronous: decouples services in time (publisher doesn't wait for consumer), but introduces eventual consistency and dead-letter queue management. Rule of thumb: **prefer async for commands** (fire-and-forget), **use sync for queries** where a real-time answer is required.

## Detailed Explanation

### Synchronous Communication

**REST (HTTP/JSON)**:
- Widely supported, easy to debug (curl, Postman)
- Human-readable payloads
- HTTP semantics (status codes, caching headers)
- Slower than binary protocols; no streaming

**gRPC (HTTP/2 + Protobuf)**:
- Binary protocol — 3-10x more efficient than JSON
- Strong contract (`.proto` files), code generation
- Bi-directional streaming
- Browser support limited (gRPC-Web required)

```csharp
// REST: HttpClient with named client
builder.Services.AddHttpClient("inventory-service", c =>
    c.BaseAddress = new Uri("http://inventory-svc:8080/"));

public class OrderService(IHttpClientFactory factory)
{
    public async Task<StockInfo?> CheckStockAsync(int productId, CancellationToken ct)
    {
        var client = factory.CreateClient("inventory-service");
        return await client.GetFromJsonAsync<StockInfo>($"/api/stock/{productId}", ct);
    }
}
```

```csharp
// gRPC: define contract in .proto, compile, consume generated client
// inventory.proto: rpc CheckStock (StockRequest) returns (StockResponse);
public class OrderService(InventoryService.InventoryServiceClient inventoryClient)
{
    public async Task<StockInfo> CheckStockAsync(int productId, CancellationToken ct)
    {
        var response = await inventoryClient.CheckStockAsync(
            new StockRequest { ProductId = productId }, cancellationToken: ct);
        return new StockInfo(productId, response.Available);
    }
}
```

### Asynchronous Communication

```csharp
// Publisher (OrderService): fire and forget
public class OrderSubmittedHandler(IMessageBus bus) : INotificationHandler<OrderSubmittedEvent>
{
    public async Task Handle(OrderSubmittedEvent e, CancellationToken ct)
    {
        // Publish integration event — InventoryService will consume it
        await bus.PublishAsync(new OrderSubmittedIntegrationEvent(
            OrderId: e.OrderId.Value,
            Lines: e.Lines.Select(l => new OrderLineDto(l.ProductId.Value, l.Quantity)).ToList()),
            ct);
    }
}

// Consumer (InventoryService): runs independently, processes when ready
public class ReserveInventoryConsumer(IInventoryRepository inventory)
    : IConsumer<OrderSubmittedIntegrationEvent>
{
    public async Task Consume(ConsumeContext<OrderSubmittedIntegrationEvent> ctx)
    {
        foreach (var line in ctx.Message.Lines)
            await inventory.ReserveAsync(line.ProductId, line.Quantity, ctx.CancellationToken);
    }
}
```

### Sync vs Async Decision Guide

| Factor | Sync (REST/gRPC) | Async (Messaging) |
|--------|-----------------|------------------|
| **Response needed?** | Yes → sync | No → async |
| **Temporal coupling** | Yes — caller blocked | None — decouple in time |
| **Failure isolation** | Caller fails if downstream down | Caller succeeds even if consumer down |
| **Latency** | Immediate | Eventually processed (ms to s) |
| **Delivery guarantee** | At-most-once (retry = duplicate risk) | At-least-once (idempotency required) |
| **Debugging** | Easier (request-response) | Harder (distributed tracing needed) |
| **Examples** | "Is product in stock?" query | "Order submitted" notification |

### Failure Modes

**Synchronous failure**: cascade — if InventoryService is down, OrderService calls fail:

```csharp
// Polly resilience: retry + circuit breaker
builder.Services.AddHttpClient("inventory-service")
    .AddResilienceHandler("inventory-pipeline", builder =>
    {
        builder.AddRetry(new HttpRetryStrategyOptions { MaxRetryAttempts = 3 });
        builder.AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
        {
            SamplingDuration = TimeSpan.FromSeconds(10),
            FailureRatio = 0.5,
            MinimumThroughput = 10
        });
    });
```

**Asynchronous failure**: dead-letter — if consumer fails, message goes to dead-letter queue:

```csharp
// MassTransit: configure dead-letter and retry
x.AddConsumer<ReserveInventoryConsumer>(c =>
{
    c.UseRetry(r => r.Intervals(100, 200, 500, 1000));
    c.UseDeadLetterQueue(); // ← failed messages after retries → DLQ for manual inspection
});
```

## Code Example

```csharp
// Outbox pattern + async messaging: reliably publish from command handler
// (see distributed-transaction-patterns.md for full Outbox)
public class PlaceOrderHandler(IOrderRepository orders, IOutbox outbox)
    : IRequestHandler<PlaceOrderCommand, int>
{
    public async Task<int> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(new CustomerId(cmd.CustomerId));
        order.Submit();
        await orders.AddAsync(order, ct);

        // Write integration event to Outbox in the same transaction
        await outbox.PublishAsync(new OrderSubmittedIntegrationEvent(
            order.Id.Value, order.Total.Amount), ct);

        // Background worker reads outbox and publishes to message bus
        // This ensures the event is not lost even if the bus is temporarily unavailable
        return order.Id.Value;
    }
}
```

## Common Follow-up Questions

- How do you handle idempotency for async message consumers?
- When should you use gRPC instead of REST for inter-service communication?
- What is the Outbox pattern, and why is it required for reliable async messaging?
- How do you implement saga choreography for multi-step workflows?
- How do you trace a request across multiple services (distributed tracing)?

## Common Mistakes / Pitfalls

- **Synchronous chains creating cascading failures**: OrderService → InventoryService → WarehouseService — if any link is down, the entire chain fails. Break chains with async messaging for non-real-time steps.
- **Publishing domain events directly to a message bus without Outbox**: if the bus publish fails after `SaveChanges`, the event is permanently lost. Outbox guarantees at-least-once delivery.
- **Ignoring idempotency for async consumers**: messages can be delivered more than once (at-least-once). Consumers must handle duplicate messages gracefully (check-and-skip).
- **Using REST for fire-and-forget operations**: calling `POST /inventory/reserve` synchronously and ignoring the response is REST anti-pattern — use async messaging instead.

## References

- [Microservices Communication — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/architect-microservice-container-applications/communication-in-microservice-architecture)
- [MassTransit — .NET messaging library](https://masstransit.io/)
- [See: distributed-transaction-patterns.md](./distributed-transaction-patterns.md)
- [See: outbox-pattern-architecture.md](./outbox-pattern-architecture.md)
