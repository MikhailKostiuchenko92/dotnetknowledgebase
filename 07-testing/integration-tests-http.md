# How Do You Send HTTP Requests and Assert Responses in ASP.NET Core Integration Tests?

**Category:** Testing / Integration Testing in ASP.NET Core
**Difficulty:** 🟡 Middle
**Tags:** `WebApplicationFactory`, `HttpClient`, `integration-testing`, `ASP.NET Core`, `assertions`

## Question
> How do you send HTTP requests and assert responses in ASP.NET Core integration tests?

## Short Answer
Use the `HttpClient` from `factory.CreateClient()`. Send requests with `GetAsync`, `PostAsJsonAsync`, `PutAsJsonAsync`, etc. Deserialize the response with `ReadFromJsonAsync<T>`. Assert on `StatusCode`, response headers, and deserialized body using FluentAssertions or xUnit `Assert`.

## Detailed Explanation

### Sending Common Requests
```csharp
// GET
var response = await _client.GetAsync("/api/orders/1");

// POST with JSON body
var body = new CreateOrderRequest { Amount = 100m };
var response = await _client.PostAsJsonAsync("/api/orders", body);

// PUT
var response = await _client.PutAsJsonAsync("/api/orders/1", updateBody);

// DELETE
var response = await _client.DeleteAsync("/api/orders/1");

// PATCH
var patch = JsonContent.Create(new { Status = "Cancelled" });
var response = await _client.PatchAsync("/api/orders/1", patch);
```

> Use `System.Net.Http.Json` (built-in since .NET 5) for `PostAsJsonAsync`, `ReadFromJsonAsync`, etc.

### Asserting Status Codes
```csharp
response.StatusCode.Should().Be(HttpStatusCode.OK);
response.EnsureSuccessStatusCode(); // throws if not 2xx
```

### Deserializing Response Body
```csharp
var order = await response.Content.ReadFromJsonAsync<OrderDto>();
order.Should().NotBeNull();
order!.Id.Should().Be(1);
order.Status.Should().Be("Confirmed");
```

### Asserting Headers
```csharp
response.Headers.Location.Should().NotBeNull();
response.Headers.Location!.ToString().Should().Contain("/api/orders/");
response.Content.Headers.ContentType?.MediaType.Should().Be("application/json");
```

### Reading Raw JSON for Flexible Assertions
```csharp
var json = await response.Content.ReadAsStringAsync();
json.Should().Contain("\"status\":\"Confirmed\"");
// Or parse with JsonDocument:
using var doc = JsonDocument.Parse(json);
doc.RootElement.GetProperty("id").GetInt32().Should().Be(1);
```

### Asserting Created Resource URL
```csharp
var response = await _client.PostAsJsonAsync("/api/orders", body);
response.StatusCode.Should().Be(HttpStatusCode.Created);
response.Headers.Location.Should().NotBeNull();
var location = response.Headers.Location!.ToString();
location.Should().MatchRegex(@"/api/orders/\d+");
```

### Custom Request Headers (Auth, Correlation IDs)
```csharp
var request = new HttpRequestMessage(HttpMethod.Get, "/api/orders");
request.Headers.Add("X-Correlation-ID", "test-123");
request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", jwtToken);
var response = await _client.SendAsync(request);
```

## Code Example
```csharp
namespace Integration.Tests;

[Collection("WebApp")]
public class OrdersApiTests(WebAppFixture fixture)
{
    private readonly HttpClient _client = fixture.Client;

    [Fact]
    public async Task GetOrder_ExistingId_ReturnsOrder()
    {
        var response = await _client.GetAsync("/api/orders/1");

        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var order = await response.Content.ReadFromJsonAsync<OrderDto>();
        order.Should().NotBeNull();
        order!.Id.Should().Be(1);
        order.Status.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task CreateOrder_ValidBody_Returns201WithLocation()
    {
        var body = new CreateOrderRequest
        {
            CustomerId = 1,
            Items = [new() { ProductId = 5, Quantity = 2 }]
        };

        var response = await _client.PostAsJsonAsync("/api/orders", body);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        response.Headers.Location.Should().NotBeNull();

        var created = await response.Content.ReadFromJsonAsync<OrderDto>();
        created!.Id.Should().BeGreaterThan(0);
    }

    [Fact]
    public async Task CreateOrder_InvalidBody_Returns400WithValidationErrors()
    {
        var body = new CreateOrderRequest { CustomerId = 0, Items = [] }; // invalid

        var response = await _client.PostAsJsonAsync("/api/orders", body);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var problem = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        problem!.Errors.Should().ContainKey("CustomerId");
    }

    [Fact]
    public async Task GetOrder_NonExistentId_Returns404()
    {
        var response = await _client.GetAsync("/api/orders/99999");
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }
}
```

## Common Follow-up Questions
- What is `ReadFromJsonAsync<T>` and where does it come from?
- How do you test validation error responses (ProblemDetails)?
- How do you send multipart form data in integration tests?
- How do you assert on response headers like `Content-Type` or `Location`?
- How do you handle cookies and session state in integration tests?
- How do you test paginated endpoints?

## Common Mistakes / Pitfalls
- **Not calling `EnsureSuccessStatusCode()`** — silent 400/500 responses pass the test if you only assert the body without checking the status.
- **Reusing `HttpResponseMessage` content** — the response stream can only be read once; read it fully before asserting.
- **Asserting raw JSON strings** — brittle against whitespace/ordering changes; prefer `ReadFromJsonAsync<T>`.
- **Not adding `System.Net.Http.Json` using** — `PostAsJsonAsync`, `ReadFromJsonAsync` require the correct `using System.Net.Http.Json;`.
- **Using hard-coded IDs that may not exist** — seed deterministic test data or create resources in the test before querying them.

## References
- [Microsoft Learn — Integration tests in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests)
- [Microsoft Learn — System.Net.Http.Json](https://learn.microsoft.com/en-us/dotnet/api/system.net.http.json)
- [NuGet — Microsoft.AspNetCore.Mvc.Testing](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc.Testing/)
