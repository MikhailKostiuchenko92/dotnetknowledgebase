# gRPC in .NET

**Category:** System Design / APIs
**Difficulty:** 🟡 Middle
**Tags:** `gRPC`, `Protobuf`, `streaming`, `deadlines`, `ASP.NET-Core`, `Grpc.AspNetCore`, `HTTP2`

## Question

> How does gRPC work in .NET? Explain Protobuf contracts, the four streaming modes (unary, server streaming, client streaming, bidirectional), deadlines vs timeouts, and key .NET-specific considerations.

## Short Answer

gRPC in .NET is built on `Grpc.AspNetCore` (server) and `Grpc.Net.Client` (client). Services are defined in `.proto` files using Protocol Buffers; `Grpc.Tools` generates strongly-typed C# stubs at build time. gRPC supports four call types: unary (request/response), server streaming (one request, stream of responses), client streaming (stream of requests, one response), and bidirectional streaming. Deadlines (absolute timestamps) are preferred over timeouts (relative durations) because they correctly propagate across service hops. HTTP/2 is required.

## Detailed Explanation

### How gRPC Works

1. Define the service contract in a `.proto` file (shared between client and server).
2. `Grpc.Tools` generates C# code: a base class for the server and a stub for the client.
3. The server inherits the base class and overrides methods.
4. The client creates a `GrpcChannel` and instantiates the generated stub.
5. Calls are serialised as Protobuf binary over HTTP/2. Multiple calls multiplex over one TCP connection.

### Protobuf Basics

```proto
syntax = "proto3";
package orders;

service OrderService {
  rpc GetOrder   (GetOrderRequest)   returns (OrderResponse);
  rpc ListOrders (ListOrdersRequest) returns (stream OrderResponse);  // server streaming
  rpc CreateOrders (stream CreateOrderRequest) returns (OrderSummary); // client streaming
  rpc SyncOrders (stream OrderEvent) returns (stream OrderAck);        // bidirectional
}

message GetOrderRequest  { int32 order_id = 1; }
message OrderResponse    { int32 id = 1; string status = 2; double total = 3; }
message ListOrdersRequest { string customer_id = 1; }
message CreateOrderRequest { string product_id = 1; int32 quantity = 2; }
message OrderSummary       { int32 created_count = 1; }
message OrderEvent         { string event_type = 1; string payload = 2; }
message OrderAck           { bool success = 1; }
```

**Field numbering rules:**
- Field numbers 1–15 use 1 byte on the wire (reserve for most-used fields).
- Field numbers 16–2047 use 2 bytes.
- Never reuse or remove a field number — use `reserved` keyword instead.
- `optional` / `repeated` are safe to add (backward-compatible).

### The Four Streaming Modes

| Mode | Client sends | Server sends | Use case |
|------|-------------|-------------|----------|
| **Unary** | One message | One message | Standard request/response (most common) |
| **Server streaming** | One message | Stream | Real-time updates, log tailing, paginated large results |
| **Client streaming** | Stream | One message | Bulk upload, aggregation of client data |
| **Bidirectional** | Stream | Stream | Chat, real-time sync, game state |

### Deadlines vs Timeouts

A **timeout** is a relative duration ("wait 5 seconds"). A **deadline** is an absolute point in time ("respond by 2pm+5s").

**Why deadlines are better for distributed systems:**

```
Client calls Service A (timeout: 5s)
  Service A calls Service B (new timeout: 5s? or remaining time?)
  Service B calls Service C (5s again? → total possible wait: 15s)
```

With a deadline: the original deadline propagates. Service A passes `deadline - elapsed` to Service B, which passes the remainder to Service C. The total is still bounded by the original deadline.

In .NET, deadlines are set via `CallOptions`:

```csharp
var deadline = DateTime.UtcNow.AddSeconds(5);
var options  = new CallOptions(deadline: deadline);
var response = await client.GetOrderAsync(request, options);
```

`CancellationToken` propagation also works: when the deadline expires, gRPC automatically cancels outstanding calls.

### gRPC Status Codes

gRPC uses its own status codes (not HTTP):

| gRPC Status | Meaning |
|-------------|---------|
| `OK` | Success |
| `CANCELLED` | Deadline exceeded or client cancelled |
| `DEADLINE_EXCEEDED` | Server exceeded the deadline |
| `NOT_FOUND` | Resource not found |
| `ALREADY_EXISTS` | Duplicate |
| `PERMISSION_DENIED` | Authorisation failure |
| `RESOURCE_EXHAUSTED` | Rate limited / quota exceeded |
| `UNAVAILABLE` | Service temporarily unavailable; safe to retry |
| `INTERNAL` | Internal server error |

Throw `RpcException` on the server:
```csharp
throw new RpcException(new Status(StatusCode.NotFound, $"Order {id} not found"));
```

### .NET-Specific Considerations

- **HTTP/2 required**: configure Kestrel to accept HTTP/2. In development, use `grpc://` or enable HTTP/2 over TLS.
- **Interceptors**: server and client interceptors are the gRPC equivalent of ASP.NET Core middleware — use for logging, tracing, auth token injection, retry logic.
- **gRPC-Web**: for browser or non-HTTP/2 environments, add `Grpc.AspNetCore.Web` and `app.UseGrpcWeb()`. Routes to `/grpc-web/` format.
- **Transcoding**: `grpc-gateway` approach — expose REST endpoints from gRPC service using `google.api.http` annotations in `.proto`.
- **Health checks**: `Grpc.HealthCheck` implements the standard gRPC health checking protocol for Kubernetes probes.
- **Reflection**: `Grpc.AspNetCore.Server.Reflection` allows tools like `grpcui` and `grpcurl` to introspect services without the `.proto` file.

## Code Example

```csharp
// Complete gRPC server + client — all four streaming modes
// .NET 8, Grpc.AspNetCore, Grpc.Net.Client

// ── SERVER (Program.cs) ───────────────────────────────────────────────
using Grpc.Core;
using Orders;   // generated from orders.proto

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.ConfigureKestrel(k => k.ListenLocalhost(5001, o => o.Protocols = HttpProtocols.Http2));
builder.Services.AddGrpc(options =>
{
    options.EnableDetailedErrors = builder.Environment.IsDevelopment();
    options.MaxReceiveMessageSize = 4 * 1024 * 1024;   // 4 MB
});

var app = builder.Build();
app.MapGrpcService<OrderGrpcService>();
app.Run();

public class OrderGrpcService : OrderService.OrderServiceBase
{
    // 1. Unary
    public override Task<OrderResponse> GetOrder(GetOrderRequest req, ServerCallContext ctx)
    {
        ctx.CancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(new OrderResponse { Id = req.OrderId, Status = "Pending", Total = 99.99 });
    }

    // 2. Server streaming — push rows as they arrive
    public override async Task ListOrders(
        ListOrdersRequest req,
        IServerStreamWriter<OrderResponse> stream,
        ServerCallContext ctx)
    {
        for (int i = 1; i <= 10 && !ctx.CancellationToken.IsCancellationRequested; i++)
        {
            await stream.WriteAsync(new OrderResponse { Id = i, Status = "Pending", Total = i * 10.0 });
            await Task.Delay(100, ctx.CancellationToken);   // simulate real data source
        }
    }

    // 3. Client streaming — receive a batch, return summary
    public override async Task<OrderSummary> CreateOrders(
        IAsyncStreamReader<CreateOrderRequest> requestStream,
        ServerCallContext ctx)
    {
        int count = 0;
        await foreach (var req in requestStream.ReadAllAsync(ctx.CancellationToken))
        {
            count++;
            // persist req to DB
        }
        return new OrderSummary { CreatedCount = count };
    }

    // 4. Bidirectional streaming — echo acks as events arrive
    public override async Task SyncOrders(
        IAsyncStreamReader<OrderEvent> requestStream,
        IServerStreamWriter<OrderAck> responseStream,
        ServerCallContext ctx)
    {
        await foreach (var evt in requestStream.ReadAllAsync(ctx.CancellationToken))
        {
            await responseStream.WriteAsync(new OrderAck { Success = true });
        }
    }
}

// ── CLIENT ────────────────────────────────────────────────────────────
using Grpc.Net.Client;
using Orders;

using var channel = GrpcChannel.ForAddress("https://localhost:5001");
var client = new OrderService.OrderServiceClient(channel);

// Unary with deadline
var deadline = DateTime.UtcNow.AddSeconds(5);
var order = await client.GetOrderAsync(
    new GetOrderRequest { OrderId = 1 },
    new CallOptions(deadline: deadline));
Console.WriteLine($"Order status: {order.Status}");

// Server streaming
using var serverStream = client.ListOrders(new ListOrdersRequest { CustomerId = "c1" });
await foreach (var o in serverStream.ResponseStream.ReadAllAsync())
    Console.WriteLine($"Streamed order: {o.Id}");

// Client streaming
using var clientStream = client.CreateOrders();
for (int i = 0; i < 5; i++)
    await clientStream.RequestStream.WriteAsync(new CreateOrderRequest { ProductId = "p1", Quantity = i + 1 });
await clientStream.RequestStream.CompleteAsync();
var summary = await clientStream;
Console.WriteLine($"Created: {summary.CreatedCount} orders");
```

## Common Follow-up Questions

- How do you pass authentication tokens in gRPC calls from client to server?
- How do interceptors work in gRPC, and how are they different from ASP.NET Core middleware?
- How do you implement retry logic for `UNAVAILABLE` gRPC errors?
- How do you expose a gRPC service as a REST API using transcoding in ASP.NET Core?
- What is the difference between `CancellationToken` propagation and a gRPC deadline?
- How does gRPC handle large payloads, and what are the limits on message size?

## Common Mistakes / Pitfalls

- **Not configuring HTTP/2 on Kestrel**: gRPC requires HTTP/2. The default Kestrel config may use HTTP/1.1 — always set `Protocols = HttpProtocols.Http2` or `Http1AndHttp2`.
- **Reusing or removing Protobuf field numbers**: changing or reassigning field numbers causes silent data corruption on the wire. Use `reserved` for removed fields and never repurpose numbers.
- **Using `Thread.Sleep` or sync waits inside streaming handlers**: gRPC streaming handlers are async — blocking the thread starves the I/O thread pool. Always use `await Task.Delay(...)`.
- **Not handling `RpcException` on the client**: unhandled `RpcException` crashes the caller. Always catch and inspect `Status.StatusCode` before deciding whether to retry or propagate.
- **Ignoring deadlines in internal calls**: a gRPC server method that calls another gRPC service should pass the remaining deadline (`ctx.Deadline`) to the downstream call, not set a new independent timeout.
- **Using gRPC for browser-to-server communication without gRPC-Web**: standard gRPC requires full HTTP/2 trailer support that browsers don't provide. Use `Grpc.AspNetCore.Web` or expose a REST facade.

## References

- [gRPC in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/aspnet/core/grpc/)
- [Protobuf language guide (proto3)](https://protobuf.dev/programming-guides/proto3/)
- [gRPC concepts — grpc.io](https://grpc.io/docs/what-is-grpc/core-concepts/)
- [Performance best practices with gRPC — Microsoft Learn](https://learn.microsoft.com/aspnet/core/grpc/performance)
- [See: rest-vs-grpc-vs-graphql.md](./rest-vs-grpc-vs-graphql.md) — trade-off comparison
