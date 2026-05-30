# What Is Contract Testing and How Does Pact.NET Enable Consumer-Driven Contract Testing?

**Category:** Testing / Advanced Topics
**Difficulty:** 🟡 Middle
**Tags:** `Pact.NET`, `contract-testing`, `consumer-driven`, `microservices`, `API-testing`

## Question
> What is contract testing and how does Pact.NET enable consumer-driven contract testing?

## Short Answer
Contract testing verifies that a service consumer (e.g., a frontend or downstream API) and a provider (upstream API) agree on the interface without full integration tests. **Consumer-driven contract testing** means the consumer defines its expectations ("pacts"), and the provider verifies it can meet them. **Pact.NET** is the .NET implementation of this pattern, enabling decoupled deployment of microservices.

## Detailed Explanation

### The Problem Contract Testing Solves
In a microservices architecture, integration tests require all services to be running simultaneously — slow, fragile, and hard to maintain. Contract testing decouples this:

1. **Consumer** writes a pact (expected request/response) and publishes it to a Pact Broker
2. **Provider** verifies it can satisfy the pact on its side independently
3. Both can deploy independently once the pact passes

### Key Concepts

| Term | Meaning |
|---|---|
| **Consumer** | The service that calls the API |
| **Provider** | The service that exposes the API |
| **Pact** | JSON document recording consumer expectations |
| **Pact Broker** | Server (or PactFlow) that stores and shares pacts |
| **Verification** | Provider runs its real code against the pact |

### Consumer Test
```shell
dotnet add package PactNet
```

```csharp
public class ProductServiceConsumerTests : IDisposable
{
    private readonly IPactBuilderV4 _pact;

    public ProductServiceConsumerTests()
    {
        var pact = Pact.V4("ProductConsumer", "ProductService");
        _pact = pact.WithHttpInteractions();
    }

    [Fact]
    public async Task GetProduct_Returns_200()
    {
        _pact
            .UponReceiving("a request for product 1")
            .WithRequest(HttpMethod.Get, "/api/products/1")
            .WillRespond()
            .WithStatus(200)
            .WithJsonBody(new { Id = 1, Name = "Laptop" });

        await _pact.VerifyAsync(async ctx =>
        {
            var client = new ProductApiClient(ctx.MockServerUri);
            var product = await client.GetAsync(1);
            product.Name.Should().Be("Laptop");
        });
    }

    public void Dispose() => _pact.Dispose();
}
```

### Provider Verification
```csharp
public class ProductServiceProviderTests
{
    [Fact]
    public void VerifyPact()
    {
        var config = new PactVerifierConfig();
        new PactVerifier(config)
            .ServiceProvider("ProductService", new Uri("http://localhost:5001"))
            .WithPactBrokerSource(new Uri("https://pact-broker.example.com"),
                options => options.BasicAuthentication("user", "pass"))
            .Verify();
    }
}
```

### PactFlow / Pact Broker
PactFlow is the hosted pact broker (SaaS, with a free tier). Alternatively, run the open-source Pact Broker as a Docker container.

### When to Use Contract Testing
✅ Microservices with independent deployment cadences
✅ Teams that own separate services (consumer team ≠ provider team)
✅ Replacing fragile end-to-end integration tests

❌ Monolith where all code lives in one repo
❌ When consumer and provider always deploy together

## Code Example
```csharp
// Consumer: defines expected interaction
_pact.UponReceiving("create order")
     .WithRequest(HttpMethod.Post, "/api/orders")
     .WithJsonBody(new { ProductId = 1, Quantity = 2 })
     .WillRespond()
     .WithStatus(201)
     .WithHeader("Location", "/api/orders/99")
     .WithJsonBody(new { OrderId = 99 });

await _pact.VerifyAsync(async ctx =>
{
    var sut = new OrderClient(ctx.MockServerUri);
    var result = await sut.CreateAsync(new CreateOrderRequest { ProductId = 1, Quantity = 2 });
    result.OrderId.Should().Be(99);
});
// Pact file written to pacts/OrderConsumer-OrderService.json
```

## Common Follow-up Questions
- What is the difference between consumer-driven and provider-driven contract testing?
- How does PactFlow differ from a self-hosted Pact Broker?
- How do you integrate Pact tests into a CI/CD pipeline (can-i-deploy)?
- What are pact states (`ProviderState`) and how do they set up provider data?
- How does contract testing compare to OpenAPI/Swagger schema validation?

## Common Mistakes / Pitfalls
- **Testing business logic in pacts** — pacts define the interface contract, not business rules.
- **Not publishing pacts to a broker** — pact files in a local folder break when teams work independently.
- **Overly detailed pact matchers** — use flexible matchers (`like`, `eachLike`) instead of exact values to reduce fragility.
- **Confusing contract tests with integration tests** — they are complementary, not substitutes.

## References
- [Pact.NET GitHub](https://github.com/pact-foundation/pact-net)
- [Pact Foundation — Consumer-Driven Contracts](https://docs.pact.io/)
- [PactFlow (managed broker)](https://pactflow.io/)
