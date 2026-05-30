# REST vs gRPC vs GraphQL

**Category:** System Design / APIs
**Difficulty:** 🟡 Middle
**Tags:** `REST`, `gRPC`, `GraphQL`, `Protobuf`, `API-design`, `trade-offs`, `streaming`

## Question

> Compare REST, gRPC, and GraphQL. What are the trade-offs in payload size, contract enforcement, streaming support, browser compatibility, and .NET tooling? When would you choose each?

## Short Answer

REST is the most flexible and widely supported protocol, suited for public-facing APIs and simple CRUD operations. gRPC uses Protobuf for binary serialisation and strongly-typed contracts — it excels at high-throughput internal service-to-service communication and supports streaming. GraphQL gives clients control over the shape of data they receive, eliminating over-fetching, and is ideal for complex client-driven APIs. Each is a good fit for different contexts; most systems use all three.

## Detailed Explanation

### Protocol & Serialisation

| | REST | gRPC | GraphQL |
|--|------|------|---------|
| **Protocol** | HTTP/1.1 or HTTP/2 | HTTP/2 | HTTP/1.1 or HTTP/2 |
| **Serialisation** | JSON (default), XML | Protobuf (binary) | JSON |
| **Payload size** | Large (verbose JSON) | Small (~5–10× smaller than JSON) | Varies (client-selected fields) |
| **Schema** | Optional (OpenAPI) | Required (`.proto` file) | Required (GraphQL schema) |
| **Type safety** | Weak (runtime) | Strong (compile-time) | Strong (schema-validated) |

### Payload Size and Performance

Protobuf encodes fields by number (not name), uses variable-length encoding for integers, and skips null fields entirely. A simple user object might be 150 bytes as JSON vs 30 bytes as Protobuf.

Benchmarks (approximate, varies by payload):
- gRPC/Protobuf serialisation: ~3–5× faster than `System.Text.Json`
- Wire size: ~5–10× smaller than equivalent JSON
- gRPC uses HTTP/2 multiplexing: multiple requests share one TCP connection

> **Caveat:** For small payloads (< 1KB), the performance difference is negligible. Optimise where it actually matters.

### Contract & Schema

**REST**: schema is optional. You can add an OpenAPI spec, but the server doesn't enforce it at runtime. Clients can receive fields they don't expect; servers can receive malformed input.

**gRPC**: the `.proto` file is the contract. Code is generated from it for both client and server in any supported language. Any change must be backward-compatible (field numbers never reuse, new fields are optional). Breaking changes are caught at compile time.

**GraphQL**: the schema (SDL) is the contract. The GraphQL runtime validates queries against it. Strongly typed; introspection allows tooling to auto-complete queries.

### Streaming

| | REST | gRPC | GraphQL |
|--|------|------|---------|
| **Server → client stream** | SSE, long-polling, WebSocket | ✅ Native (server streaming) | Subscriptions (WebSocket) |
| **Client → server stream** | ❌ | ✅ Native (client streaming) | ❌ |
| **Bidirectional** | WebSocket (workaround) | ✅ Native (bidi streaming) | ❌ |

gRPC has first-class streaming built into the protocol — ideal for: real-time telemetry, file upload/download, live log tailing.

### Browser Support

| | REST | gRPC | GraphQL |
|--|------|------|---------|
| **Browser JS** | ✅ Native `fetch` | ⚠️ grpc-web (requires proxy) | ✅ Any HTTP client |
| **Mobile** | ✅ | ✅ | ✅ |
| **Firewall friendliness** | ✅ | ⚠️ Requires HTTP/2 | ✅ |

gRPC-Web is a browser-compatible variant that requires a proxy (Envoy or ASP.NET Core `MapGrpcReflection`) to translate between HTTP/1.1 and HTTP/2. Transcoding via `grpc-gateway` allows a gRPC service to also expose a REST interface.

### Over-fetching and Under-fetching

**REST problem**: a `GET /users/{id}` endpoint returns a fixed set of fields. Mobile clients that only need `name` and `avatar` still receive all 40 fields (over-fetching). Getting a user's orders requires a second call (under-fetching / N+1).

**GraphQL solution**: the client specifies exactly which fields it needs in the query. The server returns only those fields. One query can span multiple related entities:

```graphql
query {
  user(id: "42") {
    name
    avatar
    orders(last: 5) {
      id
      total
      status
    }
  }
}
```

No over-fetching, no N+1 — as long as the server implements DataLoader to batch sub-queries.

### When to Choose Each

| Use Case | Best Choice |
|----------|------------|
| Public-facing web API, browser clients | REST |
| Internal service-to-service (high throughput, low latency) | gRPC |
| Mobile-first or multi-client API (different clients need different fields) | GraphQL |
| Streaming telemetry, real-time data | gRPC |
| Simple CRUD with broad tooling support | REST |
| BFF (Backend for Frontend) aggregating multiple services | GraphQL |
| Third-party integrations (webhooks, partner APIs) | REST |

### .NET Tooling

- **REST**: minimal APIs + `System.Text.Json` + Swashbuckle/Scalar for OpenAPI — first-class support.
- **gRPC**: `Grpc.AspNetCore`, code generated from `.proto` files via `Grpc.Tools`, `dotnet-grpc` CLI — first-class support since .NET 3.
- **GraphQL**: `HotChocolate` (recommended), `GraphQL-dotnet` — community packages, not in the BCL.

## Code Example

```csharp
// Side-by-side: same "GetUser" operation implemented as REST, gRPC, and GraphQL endpoint
// .NET 8 — illustrating API surface differences

// ── REST (minimal API) ────────────────────────────────────────────────
app.MapGet("/api/users/{id}", async (int id, UserRepository repo) =>
{
    var user = await repo.GetAsync(id);
    return user is null ? Results.NotFound() : Results.Ok(user);   // returns ALL fields
});

// ── gRPC (users.proto contract) ──────────────────────────────────────
/*
// users.proto
syntax = "proto3";
service UserService {
  rpc GetUser (GetUserRequest) returns (UserResponse);
  rpc StreamUsers (google.protobuf.Empty) returns (stream UserResponse); // streaming
}
message GetUserRequest { int32 id = 1; }
message UserResponse   { int32 id = 1; string name = 2; string email = 3; }
*/

// Generated server implementation
using Grpc.Core;
using UserProto;

public class UserGrpcService(UserRepository repo) : UserService.UserServiceBase
{
    public override async Task<UserResponse> GetUser(GetUserRequest req, ServerCallContext ctx)
    {
        var user = await repo.GetAsync(req.Id)
            ?? throw new RpcException(new Status(StatusCode.NotFound, $"User {req.Id} not found"));

        return new UserResponse { Id = user.Id, Name = user.Name, Email = user.Email };
    }

    // Server streaming: push each user as they're read
    public override async Task StreamUsers(
        Google.Protobuf.WellKnownTypes.Empty _,
        IServerStreamWriter<UserResponse> stream,
        ServerCallContext ctx)
    {
        await foreach (var user in repo.GetAllAsync(ctx.CancellationToken))
            await stream.WriteAsync(new UserResponse { Id = user.Id, Name = user.Name });
    }
}

// ── GraphQL (HotChocolate) ────────────────────────────────────────────
// Client chooses exactly which fields to return — no over-fetching
[QueryType]
public class UserQuery
{
    public async Task<User?> GetUser(int id, [Service] UserRepository repo)
        => await repo.GetAsync(id);
}
// GraphQL query: { user(id: 42) { name } } — only "name" is returned, not email
```

## Common Follow-up Questions

- How do you handle versioning in gRPC? What are the rules for backward-compatible `.proto` changes?
- What is the N+1 problem in GraphQL, and how does DataLoader solve it?
- How does gRPC-Web differ from native gRPC, and when do you need it?
- How do you expose a gRPC service as a REST API using ASP.NET Core transcoding?
- When would GraphQL subscriptions be a better choice than WebSocket or SSE?
- How do you enforce pagination depth and query complexity limits in GraphQL to prevent abuse?

## Common Mistakes / Pitfalls

- **Using gRPC for browser-facing APIs**: native gRPC requires HTTP/2 with full trailer support — browsers don't support this. Use gRPC-Web or expose a REST/GraphQL facade.
- **GraphQL without DataLoader**: each nested `orders` field in a GraphQL query naively fires one DB query per user — creating the very N+1 problem GraphQL was supposed to solve. Always batch with DataLoader.
- **Reusing proto field numbers**: in Protobuf, field numbers identify fields on the wire. Changing or reusing field numbers breaks backward compatibility silently (no error, just wrong data).
- **Treating GraphQL mutations as GET-like**: GraphQL mutations should be used for state changes; queries for reads. Running mutations from queries bypasses caching and semantic correctness.
- **Assuming REST is "simpler"**: REST with proper versioning, OpenAPI docs, error contracts, and pagination can be as complex as gRPC. Simplicity depends on implementation discipline.
- **Not rate-limiting GraphQL queries**: a deeply nested or circular query (`users { friends { users { friends { ... } } } }`) can be an infinite-resource-consumption vector. Always enforce query depth and complexity limits.

## References

- [gRPC in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/aspnet/core/grpc/)
- [HotChocolate — .NET GraphQL server](https://chillicream.com/docs/hotchocolate/v14/)
- [Protocol Buffers language guide](https://protobuf.dev/programming-guides/proto3/)
- [gRPC vs REST performance comparison (2023)](https://learn.microsoft.com/aspnet/core/grpc/comparison)
- [See: grpc-in-dotnet.md](./grpc-in-dotnet.md) — deep dive on gRPC streaming and .NET specifics
