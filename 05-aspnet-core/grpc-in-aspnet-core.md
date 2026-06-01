# gRPC in ASP.NET Core

**Category:** ASP.NET Core / Web API Design
**Difficulty:** 🔴 Senior
**Tags:** `gRPC`, `Grpc.AspNetCore`, `Protobuf`, `HTTP/2`, `streaming`, `transcoding`, `gRPC-Web`

## Question

> How do you implement a gRPC service in ASP.NET Core? What are the four communication patterns, and how do you handle browser clients?

## Short Answer

`Grpc.AspNetCore` integrates gRPC into the ASP.NET Core pipeline. You define services in `.proto` files, run the Protobuf compiler to generate C# base classes, then inherit and implement them. gRPC supports four patterns: **unary** (request/response), **server streaming**, **client streaming**, and **bidirectional streaming**. Browser clients can't use gRPC over HTTP/2 natively; use `grpc-dotnet`'s gRPC-Web support or gRPC transcoding (HTTP/JSON gateway) to bridge.

## Detailed Explanation

### Setup

```bash
dotnet add package Grpc.AspNetCore
```

```xml
<!-- .csproj -->
<ItemGroup>
    <Protobuf Include="Protos\*.proto" GrpcServices="Server" />
</ItemGroup>
```

### .proto service definition

```protobuf
// Protos/products.proto
syntax = "proto3";
option csharp_namespace = "MyApi.Grpc";

package products;

service ProductService {
    rpc GetById (GetProductRequest) returns (ProductResponse);         // unary
    rpc ListAll (ListRequest)       returns (stream ProductResponse);  // server streaming
    rpc Upload  (stream UploadChunk) returns (UploadResult);          // client streaming
    rpc Chat    (stream ChatMessage) returns (stream ChatMessage);     // bidirectional
}

message GetProductRequest { int32 id = 1; }
message ProductResponse { int32 id = 1; string name = 2; double price = 3; }
message ListRequest {}
message UploadChunk { bytes data = 1; }
message UploadResult { int32 bytesReceived = 1; }
message ChatMessage { string text = 1; }
```

### Implementing the service

```csharp
public sealed class ProductGrpcService(IProductRepository repo) 
    : ProductService.ProductServiceBase
{
    // Unary
    public override async Task<ProductResponse> GetById(
        GetProductRequest request, ServerCallContext context)
    {
        var product = await repo.GetByIdAsync(request.Id, context.CancellationToken);
        if (product is null) throw new RpcException(new Status(StatusCode.NotFound, "Not found"));
        return new ProductResponse { Id = product.Id, Name = product.Name, Price = (double)product.Price };
    }

    // Server streaming
    public override async Task ListAll(
        ListRequest request, 
        IServerStreamWriter<ProductResponse> responseStream, 
        ServerCallContext context)
    {
        await foreach (var p in repo.StreamAllAsync(context.CancellationToken))
        {
            await responseStream.WriteAsync(new ProductResponse
            {
                Id = p.Id, Name = p.Name, Price = (double)p.Price
            });
        }
    }

    // Client streaming
    public override async Task<UploadResult> Upload(
        IAsyncStreamReader<UploadChunk> requestStream, ServerCallContext context)
    {
        int totalBytes = 0;
        await foreach (var chunk in requestStream.ReadAllAsync(context.CancellationToken))
            totalBytes += chunk.Data.Length;
        return new UploadResult { BytesReceived = totalBytes };
    }
}
```

### Registration

```csharp
builder.Services.AddGrpc(opts =>
{
    opts.MaxReceiveMessageSize = 4 * 1024 * 1024; // 4 MB
    opts.EnableDetailedErrors = builder.Environment.IsDevelopment();
});

var app = builder.Build();

// gRPC requires HTTP/2
app.MapGrpcService<ProductGrpcService>();
```

### Kestrel HTTP/2 requirement

```csharp
builder.WebHost.ConfigureKestrel(opts =>
{
    opts.ListenLocalhost(5001, o => o.Protocols = HttpProtocols.Http2);
});
```

> **Warning:** gRPC over HTTP/1.1 is not supported. In production, TLS with ALPN is required for HTTP/2 negotiation.

### gRPC-Web (browser support)

```bash
dotnet add package Grpc.AspNetCore.Web
```

```csharp
app.UseGrpcWeb(); // must be after UseRouting

app.MapGrpcService<ProductGrpcService>()
   .EnableGrpcWeb(); // individual service
// or app.MapGrpcService<...>() for all with UseGrpcWeb(new GrpcWebOptions { DefaultEnabled = true })
```

### gRPC transcoding (HTTP/JSON ↔ gRPC)

Adds a REST-like JSON API that translates to gRPC internally:

```protobuf
import "google/api/annotations.proto";

service ProductService {
    rpc GetById (GetProductRequest) returns (ProductResponse) {
        option (google.api.http) = { get: "/api/products/{id}" };
    }
}
```

```csharp
builder.Services.AddGrpc().AddJsonTranscoding();
```

### Four communication patterns compared

| Pattern | Use case | HTTP analogy |
|---|---|---|
| Unary | Single request, single response | REST GET/POST |
| Server streaming | Server pushes many responses | SSE |
| Client streaming | Client uploads many chunks | chunked upload |
| Bidirectional | Real-time duplex (chat, telemetry) | WebSocket |

## Code Example

```csharp
// Full server setup
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddGrpc(opts => opts.EnableDetailedErrors = true);
builder.Services.AddGrpcReflection(); // for grpcurl / BloomRPC
builder.Services.AddScoped<IProductRepository, ProductRepository>();

builder.WebHost.ConfigureKestrel(k =>
{
    k.ListenLocalhost(5001, o => o.Protocols = HttpProtocols.Http2);        // gRPC
    k.ListenLocalhost(5000, o => o.Protocols = HttpProtocols.Http1AndHttp2); // REST + gRPC-Web
});

var app = builder.Build();

app.UseGrpcWeb();

app.MapGrpcService<ProductGrpcService>().EnableGrpcWeb();

if (app.Environment.IsDevelopment())
    app.MapGrpcReflectionService(); // exposes service descriptors for tools

app.Run();
```

## Common Follow-up Questions

- How do you handle authentication (JWT bearer) in a gRPC service?
- What is gRPC reflection and when would you enable it in production?
- How do you implement deadlines and cancellation in gRPC calls?
- How does `Grpc.Net.Client` (client library) interact with `IHttpClientFactory`?
- What are the performance advantages of gRPC over REST for internal service-to-service communication?

## Common Mistakes / Pitfalls

- **Forgetting HTTP/2 requirement** — attempting to call gRPC over HTTP/1.1 results in a protocol mismatch error. Configure Kestrel or use a reverse proxy (nginx/Envoy) with HTTP/2.
- **Not setting `option csharp_namespace` in .proto** — without it, generated classes land in the global namespace, causing naming conflicts in large projects.
- **Using `new Status(StatusCode.OK, ...)` to signal errors** — always throw `RpcException` for error conditions; returning an OK status with error details is not standard and breaks client error handling.
- **Enabling gRPC reflection in production** — reflection exposes all service descriptors (effectively an API schema); disable in production unless needed for monitoring tools.
- **Large messages without adjusting `MaxReceiveMessageSize`** — default limit is 4 MB; large payloads (file uploads, bulk data) should use client streaming rather than increasing the limit.

## References

- [Microsoft Learn — gRPC in ASP.NET Core](https://learn.microsoft.com/aspnet/core/grpc?view=aspnetcore-8.0)
- [Microsoft Learn — gRPC-Web](https://learn.microsoft.com/aspnet/core/grpc/grpcweb?view=aspnetcore-8.0)
- [Microsoft Learn — gRPC JSON transcoding](https://learn.microsoft.com/aspnet/core/grpc/json-transcoding?view=aspnetcore-8.0)
- [grpc.io — Core concepts](https://grpc.io/docs/what-is-grpc/core-concepts/)
- [James Newton-King — gRPC blog](https://james.newtonking.com/) (verify URL)
