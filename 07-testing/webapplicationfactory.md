# What Is `WebApplicationFactory<TEntryPoint>` and What Does It Enable?

**Category:** Testing / Integration Testing in ASP.NET Core
**Difficulty:** 🟢 Junior
**Tags:** `WebApplicationFactory`, `integration-testing`, `ASP.NET Core`, `TestServer`

## Question
> What is `WebApplicationFactory<TEntryPoint>` and what does it enable?

## Short Answer
`WebApplicationFactory<TEntryPoint>` is an xUnit-friendly factory from `Microsoft.AspNetCore.Mvc.Testing` that bootstraps your ASP.NET Core application in-process for integration tests. It creates a `TestServer` using your real `Program.cs` / `Startup.cs`, giving you a real `HttpClient` that sends requests through the full middleware pipeline — including routing, filters, middleware, DI, and serialization — without starting a real HTTP socket.

## Detailed Explanation

### What It Does
- Spins up your application using the real `IHostBuilder` / `WebApplication` configuration.
- Replaces the real Kestrel HTTP server with an in-process `TestServer`.
- Returns an `HttpClient` that talks to the `TestServer` over named pipes (no network I/O).
- Allows overriding services, configuration, and environment for test isolation.

### Basic Setup
```csharp
// 1. Add the NuGet package
// Microsoft.AspNetCore.Mvc.Testing

// 2. Reference your web project from the test project

// 3. Write the test
public class OrdersApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public OrdersApiTests(WebApplicationFactory<Program> factory)
        => _client = factory.CreateClient();

    [Fact]
    public async Task GetOrders_Returns200()
    {
        var response = await _client.GetAsync("/api/orders");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
```

> ⚠️ For `Program` to be accessible from the test project, either make it `public` or add `InternalsVisibleTo` or use a partial class workaround.

### `CreateClient` Options
```csharp
// Default: follows redirects, handles cookies
var client = factory.CreateClient();

// Custom options:
var client = factory.CreateClient(new WebApplicationFactoryClientOptions
{
    AllowAutoRedirect = false,
    BaseAddress = new Uri("https://localhost")
});
```

### What It Tests
- Full request/response pipeline including:
  - Routing
  - Model binding and validation
  - Middleware (auth, CORS, rate limiting)
  - Filters (action filters, exception filters)
  - Response serialization

### What It Doesn't Test
- Real network behaviour (no socket, no TLS)
- Real production database (use Testcontainers or override with in-memory DB)
- External HTTP dependencies (mock with `RichardSzalay.MockHttp`)

### Why Use It vs. Unit Tests
Unit tests with controller mocks miss: middleware, routing, model binding errors, content negotiation. `WebApplicationFactory` catches all of these with nearly the same speed.

## Code Example
```csharp
namespace Integration.Tests;

public class HealthCheckTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    public HealthCheckTests(WebApplicationFactory<Program> factory)
        => _client = factory.CreateClient();

    [Fact]
    public async Task HealthEndpoint_ReturnsHealthy()
    {
        var response = await _client.GetAsync("/health");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await response.Content.ReadAsStringAsync();
        body.Should().Contain("Healthy");
    }
}

public class ProductsApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;
    public ProductsApiTests(WebApplicationFactory<Program> factory)
        => _client = factory.CreateClient();

    [Fact]
    public async Task GetProduct_InvalidId_Returns400()
    {
        var response = await _client.GetAsync("/api/products/not-an-id");
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task GetProduct_UnknownId_Returns404()
    {
        var response = await _client.GetAsync("/api/products/99999");
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }
}
```

## Common Follow-up Questions
- How do you override registered services in `WebApplicationFactory`?
- How do you share one `WebApplicationFactory` instance across multiple test classes?
- How do you handle authentication/authorization in integration tests with `WebApplicationFactory`?
- What is the difference between `WebApplicationFactory` and `TestServer` directly?
- How do you configure the test environment (e.g., use `appsettings.Test.json`)?
- How do you make `Program` accessible from a test assembly?

## Common Mistakes / Pitfalls
- **`Program` is inaccessible** — if `Program` is an implicit `internal` class (default in .NET 6+), add `<InternalsVisibleTo Include="Your.Tests"/>` in the web project.
- **Not disposing `HttpClient`** — when using `IClassFixture`, the factory (and its `HttpClient`) is disposed at the end; don't create/dispose manually inside each test.
- **Using real database** — the real DB from `appsettings.Development.json` is used unless explicitly overridden; override in `WithWebHostBuilder`.
- **Creating a new `WebApplicationFactory` per test** — this is very slow (rebuilds the entire host); share via `IClassFixture` or `ICollectionFixture`.
- **Forgetting `AllowAutoRedirect = false`** — if you want to assert on redirect status codes (301, 302), disable auto-redirect.

## References
- [Microsoft Learn — Integration tests in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests)
- [NuGet — Microsoft.AspNetCore.Mvc.Testing](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc.Testing/)
- [Andrew Lock — Integration testing with WebApplicationFactory](https://andrewlock.net/converting-integration-tests-to-net-core-3/) (verify URL)
