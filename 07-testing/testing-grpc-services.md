# How Do You Test gRPC Services in .NET?

**Category:** Testing / Advanced Topics
**Difficulty:** 🔴 Senior
**Tags:** `gRPC`, `testing`, `.NET`, `WebApplicationFactory`, `Grpc.Core`, `Grpc.Net.Client`

## Question
> How do you test gRPC services in .NET?

## Short Answer
For unit tests, test the gRPC service class directly by calling its methods (they are plain C# methods). For integration tests, use `WebApplicationFactory` with `Grpc.Net.ClientFactory` to create a typed gRPC client that communicates with the in-process test server over HTTP/2.

## Detailed Explanation

### gRPC Service as a Plain C# Class
Generated gRPC service base classes are abstract C# classes. Your implementation is testable directly:

```csharp
// Your implementation
public class OrderGrpcService : OrderService.OrderServiceBase
{
    private readonly IOrderRepository _repo;
    public OrderGrpcService(IOrderRepository repo) => _repo = repo;

    public override async Task<GetOrderResponse> GetOrder(
        GetOrderRequest request, ServerCallContext context)
    {
        var order = await _repo.FindAsync(request.OrderId);
        return order is null
            ? throw new RpcException(new Status(StatusCode.NotFound, "Order not found"))
            : new GetOrderResponse { OrderId = order.Id, Total = (double)order.Total };
    }
}
```

### Unit Test (Direct Method Call)
```csharp
[Fact]
public async Task GetOrder_ExistingId_ReturnsResponse()
{
    var repo = new Mock<IOrderRepository>();
    repo.Setup(r => r.FindAsync(1)).ReturnsAsync(new Order { Id = 1, Total = 99m });

    var sut = new OrderGrpcService(repo.Object);

    var response = await sut.GetOrder(
        new GetOrderRequest { OrderId = 1 },
        TestServerCallContext.Create()); // helper from Grpc.Core.Testing

    response.OrderId.Should().Be(1);
    response.Total.Should().Be(99.0);
}
```

`Grpc.Core.Testing.TestServerCallContext.Create()` creates a mock `ServerCallContext`.

Install:
```shell
dotnet add package Grpc.Core.Testing
```

### Integration Test via `WebApplicationFactory`
```csharp
public class OrderGrpcIntegrationTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task GetOrder_ViaGrpcClient_Returns200()
    {
        // WebApplicationFactory supports HTTP/2
        var channel = GrpcChannel.ForAddress(factory.Server.BaseAddress,
            new GrpcChannelOptions { HttpHandler = factory.Server.CreateHandler() });

        var client = new OrderService.OrderServiceClient(channel);

        var response = await client.GetOrderAsync(new GetOrderRequest { OrderId = 1 });
        response.OrderId.Should().Be(1);
    }
}
```

Configure the test server for HTTP/2:
```csharp
factory.WithWebHostBuilder(b =>
    b.UseKestrel(o => o.ConfigureEndpointDefaults(e =>
        e.Protocols = HttpProtocols.Http2)));
```

### Testing Streaming gRPC
```csharp
[Fact]
public async Task ListOrders_ServerStreaming_ReturnsAll()
{
    // Arrange: mock repo returning 3 orders
    var call = client.ListOrders(new ListOrdersRequest { CustomerId = "cust-1" });

    var orders = new List<GetOrderResponse>();
    await foreach (var item in call.ResponseStream.ReadAllAsync())
        orders.Add(item);

    orders.Should().HaveCount(3);
}
```

## Code Example
```csharp
// Unit test using TestServerCallContext
public class GreeterServiceTests
{
    [Fact]
    public async Task SayHello_ReturnsGreeting()
    {
        var sut = new GreeterService();
        var context = TestServerCallContext.Create(
            method: "SayHello",
            host: "localhost",
            deadline: DateTime.UtcNow.AddMinutes(1),
            requestHeaders: [],
            cancellationToken: CancellationToken.None,
            peer: "127.0.0.1",
            authContext: null,
            contextPropagationToken: null,
            writeHeadersFunc: _ => Task.CompletedTask,
            writeOptionsGetter: () => null,
            writeOptionsSetter: _ => { });

        var response = await sut.SayHello(new HelloRequest { Name = "World" }, context);
        response.Message.Should().Be("Hello World");
    }
}
```

## Common Follow-up Questions
- How do you test bidirectional streaming gRPC methods?
- How do you set gRPC metadata (headers) in tests?
- How do you test gRPC deadline/cancellation handling?
- What is `GrpcChannel.ForAddress` and how does it differ from `new Channel(...)`?
- How do you mock `ServerCallContext.CancellationToken`?

## Common Mistakes / Pitfalls
- **Using HTTP/1.1 in test server** — gRPC requires HTTP/2; configure Kestrel accordingly in integration tests.
- **Not testing RpcException paths** — test both success and `StatusCode.NotFound`/`StatusCode.InvalidArgument` responses.
- **Forgetting to dispose the channel** — `GrpcChannel` implements `IDisposable`; use `using`.
- **Testing generated proto code** — focus tests on your implementation class, not the Protobuf-generated stubs.

## References
- [Microsoft Learn — Test gRPC services](https://learn.microsoft.com/en-us/aspnet/core/grpc/test-services)
- [Grpc.Core.Testing NuGet](https://www.nuget.org/packages/Grpc.Core.Testing/)
- [Grpc.Net.ClientFactory documentation](https://learn.microsoft.com/en-us/aspnet/core/grpc/clientfactory)
