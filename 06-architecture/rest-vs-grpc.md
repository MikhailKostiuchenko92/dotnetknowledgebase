# REST vs gRPC

**Category:** Architecture / API Design
**Difficulty:** 🟢 Junior
**Tags:** `REST`, `gRPC`, `HTTP2`, `Protobuf`, `JSON`, `streaming`, `browser-compatibility`, `performance`

## Question

> What are the key differences between REST (HTTP/1.1 + JSON) and gRPC (HTTP/2 + Protobuf)? When does gRPC win over REST, and what are its limitations?

## Short Answer

REST uses HTTP/1.1 with JSON — human-readable, universally supported, easy to debug. gRPC uses HTTP/2 with Protocol Buffers — binary, ~5x smaller payloads, ~3x faster serialization, strongly typed contracts from `.proto` files. gRPC wins for: internal microservice communication (performance matters), streaming (server/client/bidirectional), code generation for multiple languages. REST wins for: public APIs, browser-facing APIs, simplicity, and when interoperability with non-.NET clients matters. gRPC requires HTTP/2 and gRPC-Web for browser support.

## Detailed Explanation

### REST: Key Characteristics

```
Protocol:   HTTP/1.1 (or HTTP/2)
Format:     JSON (text) — human-readable
Contract:   OpenAPI/Swagger (optional)
Transport:  Request-response only
Browser:    Native support via fetch() / XMLHttpRequest
Debugging:  curl, Postman, browser DevTools
Tooling:    Universal — any language, any framework
```

```csharp
// REST in ASP.NET Core
[HttpGet("{id:int}")]
public async Task<ActionResult<OrderDto>> Get(int id, CancellationToken ct)
    => await _sender.Send(new GetOrderByIdQuery(id), ct) is { } order ? Ok(order) : NotFound();
```

### gRPC: Key Characteristics

```
Protocol:   HTTP/2 (required)
Format:     Protocol Buffers (binary) — compact, fast
Contract:   .proto file — strongly typed, required
Transport:  Unary + 3 streaming modes
Browser:    Requires gRPC-Web (not native gRPC)
Debugging:  Harder — binary format requires tools (grpcurl, BloomRPC)
Tooling:    Good .NET support; polyglot via .proto code generation
```

```protobuf
// inventory.proto — service contract (generates C# client + server code)
syntax = "proto3";
package inventory;

service InventoryService {
  rpc CheckStock (StockRequest) returns (StockResponse);
  rpc WatchStockLevels (WatchRequest) returns (stream StockUpdate); // server streaming
}

message StockRequest { int32 product_id = 1; int32 quantity = 2; }
message StockResponse { bool available = 1; int32 current_level = 2; }
message StockUpdate { int32 product_id = 1; int32 level = 2; google.protobuf.Timestamp updated_at = 3; }
```

```csharp
// gRPC server in ASP.NET Core
// NuGet: Grpc.AspNetCore
public class InventoryGrpcService(IInventoryRepository inventory) : InventoryServiceBase
{
    public override async Task<StockResponse> CheckStock(StockRequest req, ServerCallContext ctx)
    {
        var level = await inventory.GetStockLevelAsync(req.ProductId, ctx.CancellationToken);
        return new StockResponse { Available = level >= req.Quantity, CurrentLevel = level };
    }

    // Server streaming: push stock updates to client
    public override async Task WatchStockLevels(WatchRequest req,
        IServerStreamWriter<StockUpdate> stream, ServerCallContext ctx)
    {
        await foreach (var update in _stockMonitor.WatchAsync(ctx.CancellationToken))
            await stream.WriteAsync(new StockUpdate { ProductId = update.ProductId, Level = update.Level });
    }
}

// gRPC client in another service
builder.Services.AddGrpcClient<InventoryService.InventoryServiceClient>(options =>
    options.Address = new Uri("https://inventory-svc:5001"));

public class OrderService(InventoryService.InventoryServiceClient inventory)
{
    public async Task<bool> CheckStockAsync(int productId, int qty, CancellationToken ct)
    {
        var response = await inventory.CheckStockAsync(
            new StockRequest { ProductId = productId, Quantity = qty }, cancellationToken: ct);
        return response.Available;
    }
}
```

### Performance Comparison

| | REST/JSON | gRPC/Protobuf |
|--|----------|--------------|
| **Payload size** | Baseline | ~3-10x smaller |
| **Serialization speed** | Baseline | ~3-5x faster |
| **Parsing overhead** | JSON reflection | Compiled Protobuf |
| **Connection** | HTTP/1.1 (new connection per request) | HTTP/2 (multiplexed, persistent) |
| **Latency** | ~same for small payloads | Better for large payloads or high volume |

### Streaming Modes

```
gRPC supports 4 call types:
1. Unary:            client sends 1, server responds 1    (like REST)
2. Server streaming: client sends 1, server streams many  (stock feed, notifications)
3. Client streaming: client streams many, server responds 1 (bulk upload)
4. Bidirectional:    both sides stream simultaneously     (chat, real-time collaboration)
```

### When to Choose

| Use REST | Use gRPC |
|---------|---------|
| Public API for browser/mobile clients | Internal microservice-to-microservice |
| Third-party developers consuming your API | High-throughput, low-latency internal calls |
| Simple request-response without streaming | Real-time streaming (server push) |
| Team unfamiliar with Protobuf | Polyglot environment needing strong contracts |

## Code Example

```csharp
// gRPC fallback: gRPC for internal, REST facade for external
// gRPC: fast internal inventory check between services
app.MapGrpcService<InventoryGrpcService>();         // ← gRPC for microservices

// REST: public API for mobile/web clients
app.MapControllers();                               // ← REST for external consumers
// InventoryController calls the same application logic; gRPC just uses it directly
```

## Common Follow-up Questions

- How does gRPC-Web work in browsers, and what are the limitations?
- What is the difference between Protocol Buffers and JSON Schema?
- How do you version a gRPC API — what is the Protobuf backward compatibility story?
- When would you use REST with HTTP/2 instead of gRPC?
- How do you debug binary Protobuf traffic?

## Common Mistakes / Pitfalls

- **Using gRPC for public APIs**: most public API consumers (mobile apps, third-party developers) don't have gRPC tooling and expect REST. gRPC works well internally; use REST for public exposure.
- **gRPC without HTTP/2**: gRPC requires HTTP/2. Running on an HTTP/1.1 load balancer without HTTP/2 support breaks all gRPC traffic.
- **Forgetting to version Protobuf fields**: adding a new field in a `.proto` message is backward compatible (consumers ignore unknown fields). Removing or reusing a field number breaks deserialization.
- **Not enabling gRPC reflection in development**: without gRPC server reflection, you can't use tools like `grpcurl` or Postman to discover and call services — painful for debugging.

## References

- [gRPC in .NET — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/grpc/)
- [Protocol Buffers documentation](https://protobuf.dev/)
- [Compare gRPC services with HTTP APIs — Microsoft](https://learn.microsoft.com/en-us/aspnet/core/grpc/comparison)
- [See: inter-service-communication.md](./inter-service-communication.md)
