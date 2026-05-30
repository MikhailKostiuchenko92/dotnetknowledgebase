# Microservices Testing Strategies

**Category:** Architecture / Microservices
**Difficulty:** 🔴 Senior
**Tags:** `microservices`, `testing`, `consumer-driven-contracts`, `Pact`, `test-pyramid`, `TestContainers`, `integration-testing`

## Question

> What does the testing pyramid look like for microservices? How do consumer-driven contract tests (Pact) work, and why are they better than end-to-end tests for verifying service integration?

## Short Answer

The microservices test pyramid inverts the top-level: unit tests remain the base, but integration tests grow in importance (each service should have integration tests against a real DB via TestContainers), while full end-to-end tests become expensive and brittle across service boundaries. **Consumer-driven contract tests** (Pact) fill the gap: the consumer defines what it expects from a service API, generating a contract file; the provider verifies it matches without needing both services running simultaneously. This replaces fragile, slow end-to-end tests with fast, isolated contract verification.

## Detailed Explanation

### Microservices Test Pyramid

```
         E2E Tests (cross-service, in environment)
          ╱━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╲
         ╱   Very few — expensive, environment-dependent  ╲
        ╱━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╲
       ╱   Contract Tests (Pact) — verifies service boundaries  ╲
      ╱━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╲
     ╱   Service Integration Tests (TestContainers — per service)  ╲
    ╱━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╲
   ╱                    Unit Tests (domain, application logic)        ╲
  ╱━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╲
```

### Consumer-Driven Contract Tests with Pact

**The Problem Without Pact**:
```
E2E test: starts OrderService + InventoryService → calls API → validates
  Problems:
  - Slow: spin up 5 services + databases = 10+ minutes
  - Flaky: any service misconfiguration breaks the test
  - Poor diagnosis: which service caused the failure?
  - Couples teams: OrderService team blocked on InventoryService team's stability
```

**Pact Solution**:
```
Step 1: Consumer (OrderService) writes a contract test
  → Defines: "I expect GET /api/stock/5 to return { productId: 5, available: true }"
  → Pact starts a mock server matching this contract
  → OrderService is tested against this mock — no real InventoryService needed
  → Pact generates a contract file: order-service-inventory-service.json

Step 2: Provider (InventoryService) verifies the contract
  → InventoryService starts with test data
  → Pact replays the contract against real InventoryService
  → Verifies the response matches what OrderService expects
  → Provider passes without running OrderService at all
```

### Pact Consumer Test (.NET)

```csharp
// NuGet: PactNet
public class InventoryApiConsumerTests : IAsyncLifetime
{
    private readonly IPactBuilderV4 _pact;
    private readonly int _mockPort = 9001;

    public InventoryApiConsumerTests()
    {
        var pact = Pact.V4("order-service", "inventory-service",
            new PactConfig { PactDir = "../pacts", LogLevel = PactLogLevel.Information });
        _pact = pact.WithHttpInteractions();
    }

    [Fact]
    public async Task GetStock_WhenProductExists_ReturnsStockInfo()
    {
        // Define the expected interaction
        _pact.UponReceiving("a request for product stock")
            .Given("product 5 is in stock")
            .WithRequest(HttpMethod.Get, "/api/stock/5")
            .WillRespond()
            .WithStatus(200)
            .WithJsonBody(new { productId = 5, available = true, quantity = 50 });

        await _pact.VerifyAsync(async ctx =>
        {
            // Test OrderService's InventoryClient against the Pact mock server
            var client = new InventoryHttpClient(
                new HttpClient { BaseAddress = ctx.MockServerUri });

            var stock = await client.GetStockAsync(5, CancellationToken.None);

            Assert.NotNull(stock);
            Assert.True(stock.Available);
        });
    }

    public Task InitializeAsync() => Task.CompletedTask;
    public Task DisposeAsync() => Task.CompletedTask;
}
```

### Pact Provider Verification

```csharp
// InventoryService: verifies all contracts from consumers
public class InventoryApiProviderTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public InventoryApiProviderTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
            b.ConfigureServices(services =>
                services.AddTestDb())); // TestContainers DB
    }

    [Fact]
    public void VerifyOrderServiceContract()
    {
        var config = new PactVerifierConfig
        {
            ProviderName = "inventory-service",
            PactBrokerUri = new Uri("http://pact-broker:9292"),
            // Or: load from local file
            // PactFiles = ["../pacts/order-service-inventory-service.json"]
        };

        new PactVerifier(config)
            .ServiceProvider("inventory-service", _factory.CreateClient())
            .WithProviderStateUrl(new Uri("http://localhost/provider-states"))
            .Verify();
    }
}
```

### Integration Tests Per Service (TestContainers)

Each service has its own integration tests that run a real DB in Docker:

```csharp
// TestContainers: real SQL Server for integration tests
public class OrderIntegrationTests : IAsyncLifetime
{
    private readonly MsSqlContainer _db = new MsSqlBuilder().Build();

    public async Task InitializeAsync()
    {
        await _db.StartAsync();
        // Run migrations, seed test data
    }

    [Fact]
    public async Task PlaceOrder_WithValidData_SavesOrderInDb()
    {
        var factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(b => b.UseSetting("ConnectionStrings:Default", _db.GetConnectionString()));
        var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/api/orders", new { CustomerId = 1, Total = 99.99 });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }

    public Task DisposeAsync() => _db.DisposeAsync().AsTask();
}
```

## Code Example

```csharp
// Summary: testing strategy per layer
// 1. Unit tests: domain aggregates, application handlers (mock repos)
// 2. Integration tests: full service + real DB (TestContainers)
// 3. Contract tests: service boundaries (Pact consumer + provider)
// 4. E2E: only happy-path smoke tests in staging, not in CI

// CI pipeline per service:
//   dotnet test --filter "Category=Unit"        ← fast, always run
//   dotnet test --filter "Category=Integration" ← slower, real DB
//   dotnet test --filter "Category=Contract"    ← pact consumer + provider
//   E2E in staging only — not in per-service CI
```

## Common Follow-up Questions

- How do you manage Pact contracts when the provider API changes?
- What is a Pact Broker, and when do you need one?
- How do you test service-to-service messaging (RabbitMQ, Azure Service Bus) in tests?
- How do you test a saga end-to-end without running all services?
- How do you handle test data isolation across microservice integration tests?

## Common Mistakes / Pitfalls

- **E2E tests as the primary integration verification**: E2E tests across 5+ services in CI are slow (10-20 min) and flaky. Contract tests (Pact) + per-service integration tests cover more, faster.
- **No contract tests, relying on "it works in staging"**: staging environments drift, are often shared, and breakages are discovered late. Contract tests catch incompatibilities on every CI run.
- **Testing implementation, not contracts**: Pact tests should test the API contract (shape of the response), not the provider's internal implementation.
- **No provider states in Pact**: provider states allow the provider to set up test data matching the consumer's assumptions. Without them, the provider can't reproduce the scenario the consumer tested against.

## References

- [Pact documentation for .NET](https://docs.pact.io/implementation_guides/net/)
- [Consumer-driven contract testing — Martin Fowler](https://martinfowler.com/articles/consumerDrivenContracts.html) (verify URL)
- [TestContainers for .NET](https://dotnet.testcontainers.org/)
- [See: health-checks-in-microservices.md](./health-checks-in-microservices.md)
