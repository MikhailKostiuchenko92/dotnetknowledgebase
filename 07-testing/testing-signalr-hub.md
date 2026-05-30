# How Do You Test a SignalR Hub?

**Category:** Testing / Advanced Topics
**Difficulty:** 🔴 Senior
**Tags:** `SignalR`, `Hub`, `testing`, `WebApplicationFactory`, `integration-testing`, `IHubContext`

## Question
> How do you test a SignalR hub?

## Short Answer
For unit tests, mock `IHubCallerClients` and `IGroupManager` and test the hub methods directly (hubs are plain C# classes). For integration tests, use `WebApplicationFactory` with the `Microsoft.AspNetCore.SignalR.Client` NuGet package to connect a real `HubConnection` and assert received messages.

## Detailed Explanation

### SignalR Hub as a Plain C# Class
```csharp
public class ChatHub(IMessageStore store) : Hub
{
    public async Task SendMessage(string user, string message)
    {
        await store.SaveAsync(user, message);
        await Clients.All.SendAsync("ReceiveMessage", user, message);
    }
}
```

### Unit Test: Mock `IHubCallerClients`
```csharp
[Fact]
public async Task SendMessage_CallsClientsAll()
{
    var store = new Mock<IMessageStore>();
    var clients = new Mock<IHubCallerClients>();
    var allClients = new Mock<IClientProxy>();
    clients.Setup(c => c.All).Returns(allClients.Object);

    var hub = new ChatHub(store.Object) { Clients = clients.Object };

    await hub.SendMessage("Alice", "Hello!");

    allClients.Verify(c => c.SendCoreAsync(
        "ReceiveMessage",
        new object[] { "Alice", "Hello!" },
        default), Times.Once);
    store.Verify(s => s.SaveAsync("Alice", "Hello!"), Times.Once);
}
```

### Unit Test: Groups
```csharp
[Fact]
public async Task JoinRoom_AddsToGroup()
{
    var groups = new Mock<IGroupManager>();
    var hub = new ChatHub(Mock.Of<IMessageStore>())
    {
        Groups = groups.Object,
        Context = MockHubContext("conn-1")
    };

    await hub.JoinRoom("room-42");

    groups.Verify(g => g.AddToGroupAsync("conn-1", "room-42", default), Times.Once);
}

private static HubCallerContext MockHubContext(string connectionId)
{
    var ctx = new Mock<HubCallerContext>();
    ctx.Setup(c => c.ConnectionId).Returns(connectionId);
    return ctx.Object;
}
```

### Integration Test: Real `HubConnection`
Install:
```shell
dotnet add package Microsoft.AspNetCore.SignalR.Client
```

```csharp
[Fact]
public async Task SendMessage_IsReceivedByAllClients()
{
    await using var factory = new WebApplicationFactory<Program>();
    var server = factory.Server;

    var connection = new HubConnectionBuilder()
        .WithUrl("http://localhost/chathub",
            o => o.HttpMessageHandlerFactory = _ => server.CreateHandler())
        .Build();

    var received = new List<string>();
    connection.On<string, string>("ReceiveMessage", (user, msg) =>
        received.Add($"{user}: {msg}"));

    await connection.StartAsync();
    await connection.InvokeAsync("SendMessage", "Alice", "Hello!");
    await Task.Delay(100); // allow message delivery

    received.Should().Contain("Alice: Hello!");
    await connection.StopAsync();
}
```

### Testing `IHubContext<T>` Injection
When code injects `IHubContext<ChatHub>`:
```csharp
// Stub in unit tests
var hubContext = new Mock<IHubContext<ChatHub>>();
var clients = new Mock<IHubClients>();
var allClients = new Mock<IClientProxy>();
hubContext.Setup(h => h.Clients).Returns(clients.Object);
clients.Setup(c => c.All).Returns(allClients.Object);

var sut = new NotificationService(hubContext.Object);
await sut.BroadcastAsync("alert!");

allClients.Verify(c => c.SendCoreAsync("Notify", new object[] { "alert!" }, default), Times.Once);
```

## Code Example
```csharp
// Integration: Assert that group members receive messages
[Fact]
public async Task SendToGroup_OnlyGroupMembersReceive()
{
    await using var factory = new WebApplicationFactory<Program>();

    async Task<HubConnection> Connect()
    {
        var conn = new HubConnectionBuilder()
            .WithUrl("http://localhost/chathub",
                o => o.HttpMessageHandlerFactory = _ => factory.Server.CreateHandler())
            .Build();
        await conn.StartAsync();
        return conn;
    }

    var alice = await Connect();
    var bob = await Connect();

    var aliceMessages = new List<string>();
    alice.On<string>("RoomMessage", m => aliceMessages.Add(m));

    await alice.InvokeAsync("JoinRoom", "room-1");
    await alice.InvokeAsync("SendToRoom", "room-1", "Hello room!");
    await Task.Delay(100);

    aliceMessages.Should().Contain("Hello room!");
    // Bob (not in room-1) should NOT have received it
    // (requires separate bob message list assertion)

    await alice.StopAsync();
    await bob.StopAsync();
}
```

## Common Follow-up Questions
- How do you test `OnConnectedAsync` and `OnDisconnectedAsync` hub events?
- How do you test streaming hub methods (server → client streaming)?
- How do you authenticate SignalR connections in integration tests?
- What is the difference between `IHubContext<T>` and `Clients` inside a hub?
- How do you test a SignalR hub that uses backplane (Redis/Azure)?

## Common Mistakes / Pitfalls
- **Not awaiting `StopAsync`** — connection disposal without stopping leaks resources.
- **Using `Thread.Sleep` instead of `Task.Delay`** — blocks the test runner thread.
- **Not handling `On` before connecting** — subscribe to events before `StartAsync`.
- **Asserting on timing** — use `await Task.Delay` or a `SemaphoreSlim` to await the expected message instead of a fixed delay.

## References
- [Microsoft Learn — Test SignalR](https://learn.microsoft.com/en-us/aspnet/core/signalr/unit-testing)
- [Microsoft Learn — SignalR Hubs](https://learn.microsoft.com/en-us/aspnet/core/signalr/hubs)
- [Microsoft.AspNetCore.SignalR.Client NuGet](https://www.nuget.org/packages/Microsoft.AspNetCore.SignalR.Client/)
