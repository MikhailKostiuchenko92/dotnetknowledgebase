# WebApplicationFactory Basics

**Category:** ASP.NET Core / Testing
**Difficulty:** 🟢 Junior
**Tags:** `WebApplicationFactory`, `integration-testing`, `TestServer`, `HttpClient`

## Question

> What is `WebApplicationFactory<TEntryPoint>` and how do you use it to write integration tests for an ASP.NET Core application?

## Short Answer

`WebApplicationFactory<TEntryPoint>` (in `Microsoft.AspNetCore.Mvc.Testing`) bootstraps your real ASP.NET Core application in-process against a `TestServer`, without binding a real TCP port. `CreateClient()` returns an `HttpClient` wired directly to the test server. This gives you real middleware, real routing, real DI, and real serialization in tests without the overhead of a running HTTP server.

## Detailed Explanation

### How it works

`WebApplicationFactory` calls `WebApplication.CreateBuilder()` using your real `Program.cs` entry point, replaces `KestrelServer` with `TestServer` (in-memory transport), and exposes an `HttpClient` that speaks directly to it. No port binding, no network round-trip.

### Basic setup

```csharp
// MyApiTests.csproj
// <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="8.*" />

public sealed class WeatherForecastTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public WeatherForecastTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetWeatherForecast_ReturnsOk()
    {
        var response = await _client.GetAsync("/weatherforecast");

        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync();
        Assert.NotEmpty(json);
    }
}
```

> **Tip:** Use `IClassFixture<WebApplicationFactory<Program>>` so the factory (and `TestServer`) is shared across tests in the class — not re-created per test.

### Making `Program` accessible

If `Program.cs` uses top-level statements, the `Program` class is `internal` by default. Expose it for the test project:

```csharp
// Program.cs (bottom of file)
public partial class Program { } // Makes Program visible to test assembly
```

Or in `MyApi.csproj`:

```xml
<ItemGroup>
  <InternalsVisibleTo Include="MyApi.IntegrationTests" />
</ItemGroup>
```

### Customizing the factory

Override `ConfigureWebHost` to replace services for tests:

```csharp
public sealed class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Replace the real DbContext with an in-memory one
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseInMemoryDatabase("TestDb"));
        });

        builder.UseEnvironment("Testing");
    }
}
```

### Verifying status codes and response bodies

```csharp
[Fact]
public async Task CreateProduct_Returns201()
{
    var payload = new CreateProductRequest("Widget", 9.99m);
    var response = await _client.PostAsJsonAsync("/products", payload);

    Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    var product = await response.Content.ReadFromJsonAsync<ProductDto>();
    Assert.NotNull(product);
    Assert.Equal("Widget", product!.Name);
}
```

## Code Example

```csharp
// Minimal WebApplicationFactory integration test
public sealed class ProductsIntegrationTests
    : IClassFixture<WebApplicationFactory<Program>>,
      IDisposable
{
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public ProductsIntegrationTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
            b.UseEnvironment("Testing"));
        _client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
    }

    [Fact]
    public async Task GetProducts_ReturnsJsonArray()
    {
        var response = await _client.GetAsync("/products");

        response.EnsureSuccessStatusCode();
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
    }

    public void Dispose() => _client.Dispose();
}
```

## Common Follow-up Questions

- How do you share a `WebApplicationFactory` instance across multiple test classes?
- What is the difference between `WithWebHostBuilder()` and creating a custom subclass of `WebApplicationFactory`?
- How do you configure an authenticated `HttpClient` in integration tests?
- What is `TestServer.Handler` and when would you use it directly instead of `CreateClient()`?
- How does `WebApplicationFactory` interact with `IHostedService` — does it run background services?

## Common Mistakes / Pitfalls

- **Not using `IClassFixture`** — creating a new `WebApplicationFactory` per test method rebuilds the host, slowing tests significantly.
- **Not exposing `Program` as `public partial class Program`** — the test assembly can't reference the entry point and you get a compile error.
- **Not setting `AllowAutoRedirect = false`** — the client will silently follow redirects, masking 301/302 responses your test should assert.
- **Assuming in-memory services persist across tests** — test isolation requires resetting shared state (e.g., in-memory database) between tests.

## References

- [Microsoft Learn — Integration tests in ASP.NET Core](https://learn.microsoft.com/aspnet/core/test/integration-tests?view=aspnetcore-8.0)
- [Microsoft.AspNetCore.Mvc.Testing package on NuGet](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc.Testing)
- [Andrew Lock — Customising WebApplicationFactory](https://andrewlock.net/customising-aspnetcore-5-0-webapplicationfactory/) (verify URL)
