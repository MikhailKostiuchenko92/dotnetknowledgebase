# What Is the `TestServer` Class and How Does It Relate to `WebApplicationFactory`?

**Category:** Testing / Integration Testing in ASP.NET Core
**Difficulty:** 🟡 Middle
**Tags:** `TestServer`, `WebApplicationFactory`, `in-process`, `HttpClient`, `ASP.NET Core`

## Question
> What is the `TestServer` class and how does it relate to `WebApplicationFactory`?

## Short Answer
`TestServer` is the lower-level component in `Microsoft.AspNetCore.TestHost` that hosts an ASP.NET Core application in memory without a real network socket. `WebApplicationFactory<T>` builds on top of `TestServer` to provide a higher-level xUnit-friendly API with automatic app bootstrapping from `Program.cs`. Most test code should use `WebApplicationFactory` — `TestServer` is for advanced scenarios where direct access to the host or services is needed.

## Detailed Explanation

### `TestServer` — The Lower-Level API
```csharp
var builder = WebApplication.CreateBuilder(args);
// ... configure services
var app = builder.Build();
// ... configure pipeline

var testServer = new TestServer(new WebHostBuilder()
    .UseStartup<Startup>());

var client = testServer.CreateClient();
var response = await client.GetAsync("/health");
```

`TestServer` integrates directly into the DI container and middleware pipeline, routing all HTTP traffic through an in-memory channel.

### `WebApplicationFactory<T>` — Built on `TestServer`
`WebApplicationFactory` uses `TestServer` internally. It:
1. Calls `WebApplication.CreateBuilder()` (your real `Program.cs`)
2. Calls `ConfigureWebHost` / `ConfigureTestServices` for test overrides
3. Wraps everything in `TestServer`
4. Returns `HttpClient` via `CreateClient()`

### Direct `TestServer` Access from `WebApplicationFactory`
```csharp
var server = factory.Server; // exposes the underlying TestServer

// Create HttpClient manually from TestServer
var client = server.CreateClient();

// Access the DI container directly
var service = server.Services.GetRequiredService<IMyService>();
```

### When to Access `TestServer.Services` Directly
```csharp
using var scope = factory.Services.CreateScope();
var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
await db.Database.EnsureCreatedAsync();
db.Orders.Add(new Order { Id = 1, Amount = 100m });
await db.SaveChangesAsync();
```
This is useful for seeding data or inspecting state after a request.

### Comparison

| | `TestServer` | `WebApplicationFactory<T>` |
|---|---|---|
| Level | Low-level | High-level wrapper |
| Bootstrapping | Manual | Automatic from `Program.cs` |
| xUnit integration | None | `IClassFixture<T>` ready |
| Override services | Manually | `WithWebHostBuilder` / `ConfigureTestServices` |
| Access `IServiceProvider` | `testServer.Services` | `factory.Services` |
| Use case | Advanced / custom hosting | Standard integration tests |

### `CreateDefaultClient` vs `CreateClient`
```csharp
// Creates client that targets the TestServer base address
var client = factory.CreateClient(); // wraps CreateDefaultClient

// Advanced: access raw server
var client = factory.Server.CreateClient();
```

## Code Example
```csharp
namespace Integration.Tests;

public class ServiceResolutionTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;
    public ServiceResolutionTests(WebApplicationFactory<Program> factory)
        => _factory = factory;

    // Access the DI container via factory.Services (not factory.Server.Services)
    [Fact]
    public void CriticalServices_AreRegistered()
    {
        using var scope = _factory.Services.CreateScope();
        var sp = scope.ServiceProvider;

        // Verify key services resolve without exception
        sp.GetRequiredService<IOrderRepository>().Should().NotBeNull();
        sp.GetRequiredService<IPaymentGateway>().Should().NotBeNull();
    }

    // Seed test data via TestServer's DI, then verify via HTTP
    [Fact]
    public async Task GetOrder_AfterSeeding_ReturnsSeededData()
    {
        // Seed via DI
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Orders.Add(new Order { Id = 999, Amount = 42m });
            await db.SaveChangesAsync();
        }

        // Verify via HTTP
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/orders/999");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var order = await response.Content.ReadFromJsonAsync<OrderDto>();
        order!.Amount.Should().Be(42m);
    }
}
```

## Common Follow-up Questions
- What is `TestServer.CreateClient()` vs `WebApplicationFactory.CreateClient()`?
- How do you access the DI container from `WebApplicationFactory`?
- Can you use `TestServer` without `WebApplicationFactory`?
- What is `factory.Services` vs `factory.Server.Services`?
- How do you add middleware or inspect requests at the `TestServer` level?
- What is `CreateDefaultClient` and how does it differ from `CreateClient`?

## Common Mistakes / Pitfalls
- **Confusing `factory.Services` with per-request scope** — `factory.Services` is the root scope; always create a new `scope` to resolve scoped services.
- **Using `TestServer` directly when `WebApplicationFactory` would suffice** — the higher-level API requires less boilerplate and handles lifecycle correctly.
- **Not disposing `TestServer`** — `TestServer` is `IDisposable`; if not using `WebApplicationFactory`, dispose it with `using`.
- **Mutating server state from one test affecting another** — seeding or modifying data via `factory.Services` persists in shared state; use transactions or Respawn.
- **Using `factory.Server` before `factory.CreateClient()`** — the `TestServer` is lazily created; calling `factory.Server` before the first `CreateClient()` can cause ordering issues.

## References
- [Microsoft Learn — TestHost / TestServer](https://learn.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.testhost.testserver)
- [Microsoft Learn — Integration tests in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests)
- [NuGet — Microsoft.AspNetCore.Mvc.Testing](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc.Testing/)
