# Contract Testing in ASP.NET Core

**Category:** ASP.NET Core / Testing
**Difficulty:** 🔴 Senior
**Tags:** `contract-testing`, `Pact`, `consumer-driven`, `API-contract`, `OpenAPI`

## Question

> What is contract testing and how do you implement consumer-driven contract tests for ASP.NET Core APIs? Explain the difference from integration tests and OpenAPI-based contract validation.

## Short Answer

**Contract testing** verifies that an API provider and consumer agree on request/response format. Unlike integration tests (which test behavior), contract tests verify the *shape* of the API. **Consumer-driven contract testing** (Pact) lets the API consumer define what it expects; the provider verifies it can satisfy those expectations. This decouples consumer and provider test cycles. **OpenAPI contract validation** is a lighter approach: validate that real responses conform to the OpenAPI specification.

## Detailed Explanation

### Three layers of API contract testing

| Approach | What it tests | Tools |
|---|---|---|
| Unit tests | Business logic | xUnit + Moq |
| Integration tests | Full request/response + behavior | WebApplicationFactory |
| Contract tests | API shape agreed between teams | Pact, OpenAPI validation |

### Consumer-Driven Contract Testing (Pact)

In Pact, the **consumer** (client app) writes a "pact" (JSON file) describing what it sends and expects. The **provider** (ASP.NET Core API) verifies it can satisfy those pacts.

```bash
dotnet add package PactNet          # Consumer project
dotnet add package PactNet.Native   # Provider project
```

#### Consumer side (generates the pact)

```csharp
public sealed class ProductApiConsumerTests : IDisposable
{
    private readonly IPactBuilderV4 _pactBuilder;

    public ProductApiConsumerTests()
    {
        var pact = Pact.V4("ShopUI", "ProductApi", new PactConfig
        {
            PactDir = "../pacts"
        });
        _pactBuilder = pact.WithHttpInteractions();
    }

    [Fact]
    public async Task GetProduct_Returns200WithExpectedShape()
    {
        _pactBuilder
            .UponReceiving("a GET request for product 1")
            .WithRequest(HttpMethod.Get, "/products/1")
            .WillRespond()
            .WithStatus(HttpStatusCode.OK)
            .WithHeader("Content-Type", "application/json; charset=utf-8")
            .WithJsonBody(new
            {
                id = Match.Integer(1),
                name = Match.Type("Widget"),
                price = Match.Decimal(9.99m)
            });

        await _pactBuilder.VerifyAsync(async ctx =>
        {
            var client = new ProductApiClient(new HttpClient
            {
                BaseAddress = ctx.MockServerUri
            });
            var product = await client.GetProductAsync(1);
            Assert.Equal("Widget", product.Name);
        });
    }

    public void Dispose() => _pactBuilder.Dispose();
}
```

This generates `../pacts/ShopUI-ProductApi.json`.

#### Provider side (verifies the pact)

```csharp
public sealed class ProductApiProviderTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public ProductApiProviderTests(WebApplicationFactory<Program> factory)
        => _factory = factory;

    [Fact]
    public void VerifyPactsFromConsumers()
    {
        var verifier = new PactVerifier(new PactVerifierConfig());

        verifier
            .ServiceProvider("ProductApi", _factory.Server.CreateHandler())
            .WithFileSource(new FileInfo("../pacts/ShopUI-ProductApi.json"))
            .WithRequestTimeout(TimeSpan.FromSeconds(5))
            .Verify();
    }
}
```

### OpenAPI response validation (lighter approach)

If full Pact setup is overkill, validate that API responses match the OpenAPI spec:

```bash
dotnet add package Microsoft.OpenApi.Readers
dotnet add package Shouldly
```

```csharp
// Validate response structure against the OpenAPI schema
[Fact]
public async Task GetProduct_ResponseMatchesOpenApiSchema()
{
    var openApiDoc = await LoadOpenApiDocAsync(); // from /swagger/v1/swagger.json
    var response = await _client.GetAsync("/products/1");
    var json = await response.Content.ReadAsStringAsync();

    // Validate against the schema for GET /products/{id} 200 response
    var schema = openApiDoc.Paths["/products/{id}"]
        .Operations[OperationType.Get]
        .Responses["200"]
        .Content["application/json"]
        .Schema;

    // Use a schema validator library here
    // e.g., Corvus.Json.Validator or custom JsonSchema validation
}
```

### Schema snapshot testing

A simpler contract test: serialize the DTO and compare to a stored snapshot file:

```csharp
[Fact]
public async Task GetProduct_ResponseShapeIsStable()
{
    var response = await _client.GetAsync("/products/1");
    var json = await response.Content.ReadAsStringAsync();

    // Normalize and compare to snapshot
    var snapshot = await File.ReadAllTextAsync("Snapshots/get-product-response.json");
    var expected = JsonSerializer.Deserialize<JsonElement>(snapshot);
    var actual = JsonSerializer.Deserialize<JsonElement>(json);

    Assert.Equal(expected.EnumerateObject().Select(p => p.Name),
                 actual.EnumerateObject().Select(p => p.Name));
}
```

## Code Example

```csharp
// Provider state setup for Pact — provider states let consumer describe preconditions
[Fact]
public void VerifyPacts_WithProviderStates()
{
    var verifier = new PactVerifier(new PactVerifierConfig());

    verifier
        .ServiceProvider("ProductApi", _factory.Server.CreateHandler())
        .WithFileSource(new FileInfo("pacts/ShopUI-ProductApi.json"))
        .WithProviderStateUrl(new Uri("http://localhost/provider-states"))
        .Verify();
}

// Provider state endpoint — seed database based on consumer's described state
app.MapPost("/provider-states", (ProviderState state) =>
{
    switch (state.State)
    {
        case "product 1 exists":
            SeedProduct(new Product { Id = 1, Name = "Widget", Price = 9.99m });
            break;
        case "no products exist":
            ClearProducts();
            break;
    }
    return Results.Ok();
});
```

## Common Follow-up Questions

- How does Pact Broker work and why is it needed for CI/CD integration?
- What is bi-directional contract testing and how does Pact support it?
- How do you handle breaking changes in API contracts when consumers and providers are in different repositories?
- What is the difference between `Match.Type()`, `Match.Regex()`, and `Match.Integer()` in Pact matchers?
- How do OpenAPI specification linters (Spectral) relate to contract testing?

## Common Mistakes / Pitfalls

- **Writing provider tests without provider states** — if the test database doesn't have the required data, all pact verifications fail even if the API is correct.
- **Including too much detail in pact definitions** — overly strict matchers make contracts brittle; use `Match.Type()` for flexible matching instead of exact value matching.
- **Not storing pact files in version control** — pact files are the contract; losing them breaks the provider verification pipeline.
- **Confusing integration tests with contract tests** — contract tests verify shape, not behavior; a contract test should not assert on business logic.

## References

- [Pact Foundation — .NET documentation](https://docs.pact.io/implementation_guides/dotnet)
- [PactNet on GitHub](https://github.com/pact-foundation/pact-net)
- [Pact Broker](https://docs.pact.io/pact_broker)
- [OWASP — API Contract Testing](https://owasp.org/www-project-api-security/) (verify URL)
