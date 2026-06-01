# Mocking HttpClient in ASP.NET Core Tests

**Category:** ASP.NET Core / Testing
**Difficulty:** 🟡 Middle
**Tags:** `HttpClient`, `HttpMessageHandler`, `IHttpClientFactory`, `mocking`, `integration-testing`

## Question

> How do you mock or stub `HttpClient` in ASP.NET Core unit and integration tests? What is the role of `IHttpClientFactory` and how do you fake outbound HTTP calls?

## Short Answer

`HttpClient` is not directly mockable because its key methods are not virtual. The correct approach is to mock the **`HttpMessageHandler`** it uses internally, or use a library like `RichardSzalay.MockHttp`. For named/typed clients registered via `IHttpClientFactory`, inject a fake handler in tests by calling `AddHttpClient().ConfigurePrimaryHttpMessageHandler(() => fakeHandler)`. In integration tests with `WebApplicationFactory`, use `ConfigureTestServices` to replace the primary handler.

## Detailed Explanation

### Why you can't mock `HttpClient` directly

`HttpClient.SendAsync()` is not virtual — you can't create a `Mock<HttpClient>` with Moq and override it. The `HttpClient` delegates all calls to an `HttpMessageHandler`, so the correct seam to mock is the handler.

### Option 1: `FakeHttpMessageHandler` (manual)

```csharp
public sealed class FakeHttpMessageHandler(
    HttpStatusCode statusCode,
    string responseBody)
    : HttpMessageHandler
{
    public List<HttpRequestMessage> Requests { get; } = [];

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        Requests.Add(request);
        return Task.FromResult(new HttpResponseMessage(statusCode)
        {
            Content = new StringContent(responseBody, Encoding.UTF8, "application/json")
        });
    }
}

// Usage in unit test
var handler = new FakeHttpMessageHandler(HttpStatusCode.OK, """{"id":1,"name":"Widget"}""");
var httpClient = new HttpClient(handler) { BaseAddress = new Uri("https://api.example.com") };

var service = new ProductService(httpClient);
var product = await service.GetProductAsync(1);
Assert.Equal("Widget", product.Name);
```

### Option 2: `RichardSzalay.MockHttp` (fluent DSL)

```bash
dotnet add package RichardSzalay.MockHttp
```

```csharp
var mockHttp = new MockHttpMessageHandler();

mockHttp
    .When(HttpMethod.Get, "https://api.example.com/products/1")
    .Respond("application/json", """{"id":1,"name":"Widget"}""");

var httpClient = mockHttp.ToHttpClient();
httpClient.BaseAddress = new Uri("https://api.example.com");

// Verify the request was made
mockHttp.VerifyNoOutstandingExpectation();
```

### Option 3: Mocking via `IHttpClientFactory` (DI replacement)

```csharp
// In tests: replace the named client's handler
services.AddHttpClient("ExternalApi", c =>
    c.BaseAddress = new Uri("https://api.example.com"))
    .ConfigurePrimaryHttpMessageHandler(() =>
        new FakeHttpMessageHandler(HttpStatusCode.OK, """{"status":"ok"}"""));
```

### Option 4: Integration test with `WebApplicationFactory`

```csharp
public sealed class IntegrationTestFactory : WebApplicationFactory<Program>
{
    public FakeHttpMessageHandler ExternalApiHandler { get; } =
        new(HttpStatusCode.OK, """{"id": 1, "available": true}""");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.AddHttpClient("ExternalApi")
                .ConfigurePrimaryHttpMessageHandler(() => ExternalApiHandler);
        });
    }
}

// Test
[Fact]
public async Task GetProductAvailability_CallsExternalApi()
{
    var response = await _client.GetAsync("/products/1/availability");

    response.EnsureSuccessStatusCode();
    Assert.Single(_factory.ExternalApiHandler.Requests);
    Assert.Equal("/products/1", _factory.ExternalApiHandler.Requests[0].RequestUri?.PathAndQuery);
}
```

### Using WireMock.Net for real HTTP stub (advanced)

```bash
dotnet add package WireMock.Net
```

```csharp
var server = WireMockServer.Start();
server
    .Given(Request.Create().WithPath("/products/1").UsingGet())
    .RespondWith(Response.Create()
        .WithStatusCode(200)
        .WithBodyAsJson(new { id = 1, name = "Widget" }));

// Point HttpClient at the WireMock server
var client = new HttpClient { BaseAddress = new Uri(server.Url!) };
```

WireMock.Net is useful for testing retries, timeouts, and partial failures.

## Code Example

```csharp
// Unit test with MockHttp
public sealed class ProductServiceTests
{
    [Fact]
    public async Task GetProduct_WhenApiReturns200_ReturnsParsedProduct()
    {
        var mock = new MockHttpMessageHandler();
        mock.When(HttpMethod.Get, "https://api.example.com/products/42")
            .Respond(HttpStatusCode.OK, "application/json",
                """{"id":42,"name":"Gadget","price":19.99}""");

        var httpClient = mock.ToHttpClient();
        httpClient.BaseAddress = new Uri("https://api.example.com");

        var service = new ProductApiClient(httpClient);
        var product = await service.GetProductAsync(42);

        Assert.Equal(42, product.Id);
        Assert.Equal("Gadget", product.Name);
        mock.VerifyNoOutstandingExpectation();
    }

    [Fact]
    public async Task GetProduct_WhenApiReturns404_ReturnsNull()
    {
        var mock = new MockHttpMessageHandler();
        mock.When("https://api.example.com/products/99")
            .Respond(HttpStatusCode.NotFound);

        var httpClient = mock.ToHttpClient();
        httpClient.BaseAddress = new Uri("https://api.example.com");

        var service = new ProductApiClient(httpClient);
        var product = await service.GetProductAsync(99);

        Assert.Null(product);
    }
}
```

## Common Follow-up Questions

- What is the difference between `ConfigureTestServices` and `ConfigureServices` in `WebApplicationFactory`?
- How do you test `HttpClient` retry policies (Polly) — do you need a real HTTP endpoint?
- When would you choose WireMock.Net over `MockHttpMessageHandler`?
- How do you assert that specific HTTP headers were sent in outbound requests?
- How does `IHttpMessageHandlerBuilderFilter` work, and can you use it to intercept all HTTP calls in tests?

## Common Mistakes / Pitfalls

- **Mocking `HttpClient` with `Mock<HttpClient>()`** — `SendAsync` is not virtual and cannot be mocked; always mock the handler.
- **Creating `HttpClient` directly in service constructors instead of injecting it** — this bypasses `IHttpClientFactory` and makes the handler unreplaceable in tests.
- **Not disposing `MockHttpMessageHandler`** — some versions leak resources; dispose at end of test or use `using`.
- **Not verifying that the outbound request URL was correct** — a fake handler that always returns `200` passes tests even if the URL is wrong; assert `Requests[0].RequestUri`.

## References

- [Microsoft Learn — HttpClient guidelines](https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines)
- [RichardSzalay.MockHttp on GitHub](https://github.com/richardszalay/mockhttp)
- [WireMock.Net on GitHub](https://github.com/WireMock-Net/WireMock.Net)
- [Microsoft Learn — Integration tests — inject mock services](https://learn.microsoft.com/aspnet/core/test/integration-tests?view=aspnetcore-8.0#inject-mock-services)
