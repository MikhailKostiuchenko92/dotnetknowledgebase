# How Do You Mock `HttpClient` for Unit Testing?

**Category:** Testing / Mocking
**Difficulty:** 🟡 Middle
**Tags:** `moq`, `HttpClient`, `HttpMessageHandler`, `DelegatingHandler`, `unit-testing`

## Question
> How do you mock `HttpClient` for unit testing?

## Short Answer
`HttpClient` is not an interface and cannot be directly mocked with Moq. The correct approach is to mock its inner `HttpMessageHandler` (specifically `SendAsync`), which is the extension point `HttpClient` delegates to. Inject `HttpClient` via a factory (`IHttpClientFactory`) to keep code testable without coupling to a concrete `new HttpClient()`.

## Detailed Explanation

### Why `HttpClient` Is Hard to Mock
`HttpClient` is a concrete class, not an interface. Its methods (`GetAsync`, `PostAsync`, etc.) are **not virtual**, so Moq cannot intercept them. Instead, all calls eventually route through `protected virtual Task<HttpResponseMessage> SendAsync(...)` on the inner `HttpMessageHandler`.

### Option 1: Mock `HttpMessageHandler.SendAsync` (Most Common)
```csharp
var handlerMock = new Mock<HttpMessageHandler>();
handlerMock.Protected()
           .Setup<Task<HttpResponseMessage>>(
               "SendAsync",
               ItExpr.IsAny<HttpRequestMessage>(),
               ItExpr.IsAny<CancellationToken>())
           .ReturnsAsync(new HttpResponseMessage
           {
               StatusCode = HttpStatusCode.OK,
               Content = new StringContent(@"{""id"": 1}")
           });

var client = new HttpClient(handlerMock.Object)
{
    BaseAddress = new Uri("https://api.example.com")
};
```

Uses `Moq.Protected()` because `SendAsync` is `protected`.

### Option 2: Custom Stub Handler (No Moq Dependency)
```csharp
public class FakeHttpMessageHandler : HttpMessageHandler
{
    private readonly HttpResponseMessage _response;

    public FakeHttpMessageHandler(HttpResponseMessage response)
        => _response = response;

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
        => Task.FromResult(_response);
}
```

Simpler, no Moq needed, easier to read.

### Option 3: `IHttpClientFactory` + Named Client
Production code requests a named client via `IHttpClientFactory.CreateClient(name)`. In tests, register a fake `IHttpClientFactory`:
```csharp
var factory = new Mock<IHttpClientFactory>();
factory.Setup(f => f.CreateClient("Orders"))
       .Returns(new HttpClient(new FakeHttpMessageHandler(response)));
```

Or use `MockHttpClient` libraries (see Options below).

### Third-Party Libraries: `RichardSzalay.MockHttp`
```csharp
var mockHttp = new MockHttpMessageHandler();
mockHttp.When("https://api.example.com/orders/*")
        .Respond("application/json", @"[{""id"":1}]");

var client = mockHttp.ToHttpClient();
client.BaseAddress = new Uri("https://api.example.com");
```

Much more fluent and supports method/header/body assertions.

| Approach | Pros | Cons |
|---|---|---|
| `Mock<HttpMessageHandler>` (Moq) | No extra dependencies | Verbose, requires `.Protected()` |
| Custom stub handler | Simple, readable | Boilerplate per test |
| `IHttpClientFactory` mock | Decoupled, production-like | Requires factory injection |
| `RichardSzalay.MockHttp` | Fluent, URL matching, assertions | Extra NuGet package |

> ⚠️ Always dispose `HttpResponseMessage` content if re-used across test cases; `StringContent` is not thread-safe.

## Code Example
```csharp
namespace Orders.Tests;

public class OrderApiClientTests
{
    [Fact]
    public async Task GetOrderAsync_ReturnsOrder_WhenApiSucceeds()
    {
        // Arrange — stub handler returns 200 with JSON
        var json = """{"id": 42, "status": "shipped"}""";
        var handler = new FakeHttpMessageHandler(new HttpResponseMessage
        {
            StatusCode = HttpStatusCode.OK,
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        });

        var client = new HttpClient(handler) { BaseAddress = new Uri("https://api.example.com/") };
        var sut = new OrderApiClient(client);

        // Act
        var order = await sut.GetOrderAsync(42);

        // Assert
        order.Should().NotBeNull();
        order!.Id.Should().Be(42);
        order.Status.Should().Be("shipped");
    }

    [Fact]
    public async Task GetOrderAsync_ThrowsHttpRequestException_WhenApiReturns500()
    {
        var handler = new FakeHttpMessageHandler(new HttpResponseMessage
        {
            StatusCode = HttpStatusCode.InternalServerError
        });

        var client = new HttpClient(handler) { BaseAddress = new Uri("https://api.example.com/") };
        var sut = new OrderApiClient(client);

        var act = async () => await sut.GetOrderAsync(1);
        await act.Should().ThrowAsync<HttpRequestException>();
    }
}

// Simple reusable stub
file sealed class FakeHttpMessageHandler(HttpResponseMessage response) : HttpMessageHandler
{
    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
        => Task.FromResult(response);
}
```

## Common Follow-up Questions
- Why can't you mock `HttpClient` methods directly with Moq?
- What is `IHttpClientFactory` and why does it improve testability?
- How do you verify that the correct URL or HTTP method was used?
- How does `RichardSzalay.MockHttp` differ from a manual stub?
- How do you test retry policies (Polly) with mocked `HttpClient`?
- How do you test that `Authorization` headers are sent correctly?

## Common Mistakes / Pitfalls
- **Trying to mock `GetAsync` directly** — `HttpClient.GetAsync` is not virtual; Moq cannot intercept it.
- **Forgetting `BaseAddress`** — relative URIs in production code fail if the test creates an `HttpClient` without `BaseAddress`.
- **Reusing the same `HttpResponseMessage` across tests** — the response content stream is consumed after the first read; create a new response per test.
- **Not asserting request details** — test only that the response was parsed, but forget to assert that the right URL/method/headers were used (use `RichardSzalay.MockHttp` or capture `HttpRequestMessage` in the stub).
- **Skipping `IHttpClientFactory`** — hardcoding `new HttpClient()` in the SUT makes injection and testing impossible.

## References
- [Microsoft Learn — Make HTTP requests with IHttpClientFactory](https://learn.microsoft.com/en-us/dotnet/core/extensions/httpclient-factory)
- [Moq — Protected members](https://github.com/devlooped/moq/wiki/Quickstart#protected-members)
- [RichardSzalay.MockHttp on GitHub](https://github.com/richardszalay/mockhttp)
- [NuGet — RichardSzalay.MockHttp](https://www.nuget.org/packages/RichardSzalay.MockHttp/)
- [Andrew Lock — Testing HttpClient](https://andrewlock.net/creating-a-mock-httpclient-unit-testing-c-sharp/) (verify URL)
