# SignalR Overview in ASP.NET Core

**Category:** ASP.NET Core / Performance & Diagnostics
**Difficulty:** 🔴 Senior
**Tags:** `SignalR`, `Hub`, `IHubContext`, `groups`, `backplane`, `Redis`, `WebSocket`, `SSE`

## Question

> What is SignalR and when should you use it over alternatives like WebSockets or Server-Sent Events? How do you scale SignalR across multiple servers?

## Short Answer

SignalR is a real-time communication library built on top of WebSockets (with SSE and Long Polling as fallbacks). It provides a **Hub** abstraction for RPC-style server↔client communication, automatic transport negotiation, reconnection, and group/user addressing. Use it for chat, dashboards, notifications, and collaborative editing. For multi-node scaling, add a **backplane** (Redis Pub/Sub via `AddStackExchangeRedis`) so messages published on one node fan out to clients connected to other nodes.

## Detailed Explanation

### Hub — the core abstraction

```csharp
public sealed class ChatHub(ILogger<ChatHub> logger) : Hub
{
    // Called by clients: await connection.invoke("SendMessage", "Alice", "Hello")
    public async Task SendMessage(string user, string message)
    {
        logger.LogInformation("{User}: {Message}", user, message);

        // Broadcast to all connected clients
        await Clients.All.SendAsync("ReceiveMessage", user, message);
    }

    // Send to a specific group
    public async Task JoinRoom(string room)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, room);
        await Clients.Group(room).SendAsync("UserJoined", Context.ConnectionId);
    }

    public override async Task OnConnectedAsync()
    {
        logger.LogInformation("Client connected: {ConnectionId}", Context.ConnectionId);
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        logger.LogInformation("Client disconnected: {ConnectionId}", Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }
}
```

### Registration

```csharp
builder.Services.AddSignalR(opts =>
{
    opts.MaximumReceiveMessageSize = 64 * 1024; // 64 KB
    opts.EnableDetailedErrors = builder.Environment.IsDevelopment();
    opts.ClientTimeoutInterval = TimeSpan.FromSeconds(30);
    opts.KeepAliveInterval = TimeSpan.FromSeconds(15);
});

var app = builder.Build();
app.MapHub<ChatHub>("/hubs/chat");
```

### `IHubContext<T>` — send from outside the Hub (server push)

```csharp
public sealed class OrderService(IHubContext<OrderHub> hub)
{
    public async Task FulfillAsync(Order order)
    {
        await ProcessFulfillmentAsync(order);

        // Notify specific user's clients
        await hub.Clients
            .User(order.CustomerId)
            .SendAsync("OrderFulfilled", order.Id, order.Status);
    }
}
```

### Transports and negotiation

| Transport | Full duplex | Browser support | Fallback order |
|---|---|---|---|
| WebSocket | ✅ | ✅ Modern | 1st choice |
| Server-Sent Events | Server→client only | ✅ | 2nd |
| Long Polling | ✅ (simulated) | Universal | 3rd |

### Scaling with a Redis backplane

Without a backplane, a client connected to Node A cannot receive messages sent to Node B:

```bash
dotnet add package Microsoft.AspNetCore.SignalR.StackExchangeRedis
```

```csharp
builder.Services.AddSignalR()
    .AddStackExchangeRedis(builder.Configuration.GetConnectionString("Redis")!,
        opts => opts.Configuration.ChannelPrefix = RedisChannel.Literal("SignalR"));
```

All hubs on all nodes subscribe to the same Redis channels; messages fan out via Redis Pub/Sub.

### Authentication and authorization

```csharp
app.MapHub<ChatHub>("/hubs/chat").RequireAuthorization();

// In hub — access authenticated user
public Task SendMessage(string message)
{
    var userId = Context.UserIdentifier;           // ClaimTypes.NameIdentifier
    var userName = Context.User?.Identity?.Name;
    return Clients.All.SendAsync("ReceiveMessage", userName, message);
}
```

For JWT tokens with SignalR (JS client can't set Authorization header for WebSocket):

```csharp
opts.Events = new JwtBearerEvents
{
    OnMessageReceived = ctx =>
    {
        var token = ctx.Request.Query["access_token"];
        if (!string.IsNullOrEmpty(token) && ctx.Request.Path.StartsWithSegments("/hubs"))
            ctx.Token = token;
        return Task.CompletedTask;
    }
};
```

## Code Example

```csharp
// Strongly-typed hub interface (prevents string typos)
public interface IChatClient
{
    Task ReceiveMessage(string user, string message);
    Task UserJoined(string connectionId);
}

public sealed class ChatHub : Hub<IChatClient>
{
    public Task SendMessage(string message) =>
        Clients.Group("global").ReceiveMessage(
            Context.User?.Identity?.Name ?? "Anonymous", message);

    public async Task JoinRoom(string room)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, room);
        await Clients.Group(room).UserJoined(Context.ConnectionId);
    }
}

// Server-side push via IHubContext<THub, TClient>
public class DashboardUpdater(IHubContext<DashboardHub, IDashboardClient> hub)
{
    public Task BroadcastMetricsAsync(SystemMetrics metrics) =>
        hub.Clients.All.UpdateMetrics(metrics);
}
```

## Common Follow-up Questions

- How does the SignalR connection ID differ from an authenticated user identifier?
- What happens when a client loses connection? Does SignalR reconnect automatically?
- How do you send a message to all connections of a specific user (multiple browser tabs)?
- What are the limitations of the Redis backplane under very high message throughput?
- How do you unit-test code that uses `IHubContext<T>`?

## Common Mistakes / Pitfalls

- **Calling long-running operations directly in a Hub method** — Hub methods run synchronously per connection; long-running work blocks the connection. Offload to background services using `IHubContext<T>`.
- **Not using a backplane in multi-node deployments** — without Redis, messages are local to one node; clients on other nodes never receive them.
- **Storing state directly in the Hub class** — `Hub` instances are created per-invocation; they're not singletons. Use `IMemoryCache`, `IDistributedCache`, or the `Context.Items` dictionary for per-connection state.
- **Passing the JWT token in the URL for non-WebSocket transports** — tokens in query strings appear in server logs. SSE and Long Polling support Authorization headers; only WebSocket requires the query string workaround.
- **Not configuring `KeepAliveInterval` and `ClientTimeoutInterval`** — defaults may be too long for mobile clients; tune based on expected network quality and reconnection UX requirements.

## References

- [Microsoft Learn — SignalR overview](https://learn.microsoft.com/aspnet/core/signalr/introduction?view=aspnetcore-8.0)
- [Microsoft Learn — SignalR scale out (Redis backplane)](https://learn.microsoft.com/aspnet/core/signalr/redis-backplane?view=aspnetcore-8.0)
- [Microsoft Learn — SignalR authentication](https://learn.microsoft.com/aspnet/core/signalr/authn-and-authz?view=aspnetcore-8.0)
- [Microsoft — Hub source](https://github.com/dotnet/aspnetcore/blob/main/src/SignalR/server/Core/src/Hub.cs)
