# API Contract Testing

**Category:** Architecture / API Design
**Difficulty:** 🔴 Senior
**Tags:** `Pact`, `consumer-driven-contracts`, `CDC`, `provider-verification`, `contract-testing`, `microservices-testing`

## Question

> What is consumer-driven contract testing with Pact? How does it differ from integration and E2E tests, and how do you implement provider verification in a .NET service?

## Short Answer

Consumer-driven contract testing: the **consumer** (e.g., OrderService calling InventoryService) writes a test that defines exactly what it expects from the provider API and records it as a **Pact** (contract file). The **provider** (InventoryService) verifies it can satisfy all registered consumer contracts — without the consumer needing to run at all. Compared to E2E tests: CDC tests are fast, isolated, run per-service in CI, and pinpoint exactly which consumer a provider change breaks. Use `PactNet` for .NET; the Pact Broker centralizes contract discovery.

## Detailed Explanation

### The Problem CDC Solves

```
Traditional integration test problem:
  ├── Consumer: OrderService
  └── Provider: InventoryService
  
  To test: spin up both services + DB + message bus → slow, flaky, hard to own

  When provider changes break consumer:
  → Only discovered in E2E suite or production → late, expensive to fix

Consumer-driven contracts:
  ├── Consumer test: "I call GET /products/42 and expect { id: 42, stockLevel: 100 }"
  │   → runs fast, in-memory, creates pact.json
  └── Provider test: "Does InventoryService fulfill OrderService's pact?"
      → runs against real provider, no consumer needed
      → fails immediately when provider change breaks contract
```

### Consumer Side (PactNet)

```csharp
// NuGet: PactNet (≥5.0 for .NET 8)
// Consumer test: OrderService expects InventoryService to match this contract

public class InventoryClientTests : IDisposable
{
    private readonly IPactBuilderV4 _pact;
    private readonly Mock<HttpClient> _httpClient;

    public InventoryClientTests()
    {
        // Pact file will be written to ./pacts/OrderService-InventoryService.json
        var pact = Pact.V4("OrderService", "InventoryService", new PactConfig
        {
            PactDir = "./pacts",
            LogLevel = PactLogLevel.Debug
        });
        _pact = pact.WithHttpInteractions();
    }

    [Fact]
    public async Task CheckStock_WhenProductExists_ReturnsAvailability()
    {
        // Define expected interaction with provider
        _pact
            .UponReceiving("a request to check stock for product 42")
            .WithRequest(HttpMethod.Get, "/api/products/42/stock")
            .WithQuery("quantity", "10")
            .WillRespond()
            .WithStatus(200)
            .WithJsonBody(new
            {
                productId = 42,
                available = true,
                stockLevel = Match.Type(100)  // ← match on type (int), not exact value
            });

        await _pact.VerifyAsync(async ctx =>
        {
            // Use mock server URL provided by Pact
            var client = new InventoryHttpClient(new HttpClient { BaseAddress = ctx.MockServerUri });
            var result = await client.CheckStockAsync(42, quantity: 10);

            Assert.True(result.Available);
            Assert.IsType<int>(result.StockLevel);
        });
        // ↑ After this, ./pacts/OrderService-InventoryService.json is written
    }

    public void Dispose() => _pact.Dispose();
}
```

### Provider Verification Side

```csharp
// Provider test: InventoryService verifies all consumer contracts
// Run in InventoryService's test project
public class InventoryPactProviderTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task VerifyConsumerContracts()
    {
        var pactVerifier = new PactVerifier(new PactVerifierConfig
        {
            LogLevel = PactLogLevel.Warn
        });

        // Option A: load pact from local file (CI: share via artifact)
        // Option B: load from Pact Broker (recommended for teams)
        pactVerifier
            .ServiceProvider("InventoryService", factory.Server.BaseAddress)
            .WithHttpEndpoints(endpoints =>
                endpoints.FromPactBroker(new Uri("https://pactbroker.mycompany.com"),
                    new PactBrokerOptions
                    {
                        ConsumerVersionSelectors = new[] { new ConsumerVersionSelector { Latest = true } }
                    }))
            // Or local file:
            // .WithFileSource(new FileInfo("./pacts/OrderService-InventoryService.json"))
            .WithProviderStateUrl(new Uri($"{factory.Server.BaseAddress}provider-states"))
            .Verify();
        // ↑ Throws if InventoryService doesn't satisfy any consumer contract
    }
}

// Provider states endpoint: sets up data for each test scenario
[ApiController, Route("provider-states")]
public class ProviderStateController(IDbContext db) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> SetState([FromBody] ProviderState state)
    {
        if (state.State == "product 42 exists with stock")
        {
            db.Products.Add(new Product(42, "Widget", stockLevel: 100));
            await db.SaveChangesAsync();
        }
        return Ok();
    }
}
```

### CDC vs Other Test Types

| | Unit | Integration | Contract (CDC) | E2E |
|--|------|-------------|----------------|-----|
| **Speed** | ✅ Fast | 🟡 Medium | ✅ Fast | ❌ Slow |
| **Isolation** | ✅ Full | 🟡 Partial | ✅ Per service | ❌ Full stack |
| **Finds contract breaks** | ❌ No | 🟡 Sometimes | ✅ Yes | ✅ Yes |
| **Ownership** | ✅ Single team | 🟡 Shared | ✅ Per service | ❌ Shared/unclear |
| **CI speed** | ✅ Seconds | 🟡 Minutes | ✅ Minutes | ❌ Hours |

### Pact Broker

```yaml
# docker-compose.yml — local Pact Broker for development
services:
  pact-broker:
    image: pactfoundation/pact-broker:latest
    ports: ["9292:9292"]
    environment:
      PACT_BROKER_DATABASE_URL: postgres://pact:pact@db/pact
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: pact
      POSTGRES_PASSWORD: pact
      POSTGRES_DB: pact
```

## Code Example

```csharp
// Full consumer pact test with PactNet 5.x + .NET 8
// NuGet: PactNet (≥5.0)

[Collection("Pact")]
public class OrderServiceContractTests : IDisposable
{
    private readonly IPactBuilderV4 _pact;

    public OrderServiceContractTests()
    {
        _pact = Pact.V4("OrderService", "InventoryService", new PactConfig
        {
            PactDir = Path.Join(Directory.GetCurrentDirectory(), "pacts")
        }).WithHttpInteractions();
    }

    [Fact]
    public async Task GetStock_ProductNotFound_Returns404()
    {
        _pact
            .UponReceiving("a stock check for a non-existent product")
            .WithRequest(HttpMethod.Get, "/api/products/999/stock")
            .WillRespond()
            .WithStatus(404);

        await _pact.VerifyAsync(async ctx =>
        {
            var client = new InventoryClient(ctx.MockServerUri);
            var result = await client.CheckStockAsync(999, 1);
            Assert.Null(result);
        });
    }

    public void Dispose() => _pact.Dispose();
}
```

## Common Follow-up Questions

- How do you share Pact files between consumer and provider in a CI/CD pipeline without a Pact Broker?
- What is "can-i-deploy" in the Pact Broker, and how does it prevent unsafe deployments?
- How do you handle provider state setup for complex scenarios (e.g., orders with specific statuses)?
- Can Pact test asynchronous message-based contracts (e.g., Kafka events)?
- When is CDC testing NOT the right tool (e.g., for testing a public API consumed by unknown clients)?

## Common Mistakes / Pitfalls

- **Tight coupling via exact value matching**: using `Match.Equality(42)` instead of `Match.Type(42)` means the consumer test breaks whenever the provider changes the stock level, even though the consumer only cares about type — not value.
- **Provider state not resetting between tests**: if provider state setup doesn't isolate data per test, tests become order-dependent and flaky.
- **Not running provider verification in CI**: pact files are worthless if providers never verify them. Every provider's CI must run `VerifyConsumerContracts()` against all known consumer pacts.
- **Using Pact for public APIs**: CDC testing requires both consumer and provider to be under your control. For public APIs consumed by external clients, versioned OpenAPI specs + backward-compatibility tests are more appropriate.

## References

- [Pact documentation](https://docs.pact.io/)
- [PactNet GitHub](https://github.com/pact-foundation/pact-net)
- [Pact Broker](https://docs.pact.io/pact_broker)
- [See: microservices-testing-strategies.md](./microservices-testing-strategies.md)
