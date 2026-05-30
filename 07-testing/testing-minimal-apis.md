# How Do You Test Minimal API Endpoints Without a Full Integration Test?

**Category:** Testing / Advanced Topics
**Difficulty:** 🔴 Senior
**Tags:** `Minimal APIs`, `ASP.NET Core`, `testing`, `WebApplicationFactory`, `endpoint-filters`

## Question
> How do you test Minimal API endpoints in ASP.NET Core without a full integration test?

## Short Answer
For unit-level tests, extract the endpoint handler logic into a static or instance method and test it directly — no HTTP plumbing needed. For lightweight integration tests, use `WebApplicationFactory` with `CreateClient()`, or the newer **`HttpContext` injection testing** pattern where you configure a minimal test host and send requests in-process.

## Detailed Explanation

### Option 1: Extract Handler Logic (Unit Test)
Move the lambda body to a static method:
```csharp
// Production
app.MapGet("/products/{id}", ProductEndpoints.GetById);

// Endpoint class
public static class ProductEndpoints
{
    public static async Task<IResult> GetById(int id, IProductService service) =>
        await service.FindAsync(id) is { } product
            ? Results.Ok(product)
            : Results.NotFound();
}
```

```csharp
// Unit test — no HTTP at all
[Fact]
public async Task GetById_ExistingId_ReturnsOk()
{
    var service = Mock.Of<IProductService>(s =>
        s.FindAsync(1) == Task.FromResult<Product?>(new Product { Id = 1 }));

    var result = await ProductEndpoints.GetById(1, service);

    result.Should().BeOfType<Ok<Product>>();
}
```

### Option 2: Lightweight `WebApplicationFactory` Integration Test
```csharp
public class ProductEndpointsTests(WebApplicationFactory<Program> factory)
    : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task GetProduct_Returns200()
    {
        var client = factory.CreateClient();
        var response = await client.GetAsync("/products/1");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
```

### Option 3: `Microsoft.AspNetCore.Http.HttpContext` Directly (Filter Tests)
Test endpoint filters by constructing a fake `DefaultHttpContext`:
```csharp
[Fact]
public async Task ValidationFilter_InvalidRequest_Returns400()
{
    var ctx = new DefaultHttpContext();
    var filter = new ValidationEndpointFilter();
    EndpointFilterInvocationContext context = // construct as needed
    var next = (EndpointFilterInvocationContext _) => ValueTask.FromResult<object?>(null);

    var result = await filter.InvokeAsync(context, next);

    ((IResult)result!).Should().BeOfType<BadRequest<string>>();
}
```

### Option 4: `MapGet` with a Test Host (Lightweight)
```csharp
[Fact]
public async Task ProductRoute_MatchesAndReturns()
{
    var app = WebApplication.CreateBuilder().Build();
    app.MapGet("/test", () => Results.Ok("hello"));
    app.Urls.Add("http://127.0.0.1:0");
    await app.StartAsync();

    using var client = new HttpClient { BaseAddress = new Uri(app.Urls.First()) };
    var response = await client.GetAsync("/test");
    response.StatusCode.Should().Be(HttpStatusCode.OK);

    await app.StopAsync();
}
```

> ⚠️ For serious testing, prefer `WebApplicationFactory` over spinning up a real listener.

### Testing `Results.Ok<T>` Type Directly
.NET 7+ `IResult` implementations are concrete types:
```csharp
var result = Results.Ok(new { Name = "test" });
result.Should().BeOfType<Ok<object>>();
((Ok<object>)result).Value.Should().BeEquivalentTo(new { Name = "test" });
```

## Code Example
```csharp
// Endpoint defined as a static method — testable without HTTP
public static class CartEndpoints
{
    public static async Task<IResult> AddToCart(
        int productId, int quantity,
        ICartService cart, ClaimsPrincipal user)
    {
        if (quantity <= 0)
            return Results.BadRequest("Quantity must be positive");

        var userId = user.GetUserId();
        var item = await cart.AddAsync(userId, productId, quantity);
        return Results.Created($"/cart/{item.Id}", item);
    }
}

// Tests
public class CartEndpointTests
{
    private readonly Mock<ICartService> _cart = new();

    [Fact]
    public async Task AddToCart_NegativeQuantity_ReturnsBadRequest()
    {
        var user = new ClaimsPrincipal(new ClaimsIdentity(
            [new Claim("sub", "user-1")]));

        var result = await CartEndpoints.AddToCart(1, -1, _cart.Object, user);

        result.Should().BeOfType<BadRequest<string>>();
    }

    [Fact]
    public async Task AddToCart_ValidInput_Returns201()
    {
        var cartItem = new CartItem { Id = 99, ProductId = 1, Quantity = 2 };
        _cart.Setup(c => c.AddAsync("user-1", 1, 2)).ReturnsAsync(cartItem);
        var user = new ClaimsPrincipal(new ClaimsIdentity([new Claim("sub", "user-1")]));

        var result = await CartEndpoints.AddToCart(1, 2, _cart.Object, user);

        result.Should().BeOfType<Created<CartItem>>();
    }
}
```

## Common Follow-up Questions
- What is the difference between testing Minimal API endpoints and MVC controller actions?
- How do you test route constraints and parameter binding in Minimal APIs?
- How do you test endpoint filters and middleware in isolation?
- What is `IResult` and how does it differ from `ActionResult`?
- How do you test Minimal API endpoints that use route groups?

## Common Mistakes / Pitfalls
- **Putting all logic in the lambda** — untestable without HTTP; extract to methods.
- **Testing only the happy path** — add tests for `NotFound`, `BadRequest`, and auth failures.
- **Not testing validation filters** — filters often contain critical business rules.
- **Using `ObjectResult` assertions** — prefer strongly-typed `Results.Ok<T>` assertions over reflection-based assertions.

## References
- [Microsoft Learn — Minimal APIs](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/)
- [Microsoft Learn — Test Minimal APIs](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/test-min-api) (verify URL)
- [Andrew Lock — Testing Minimal APIs](https://andrewlock.net/series/exploring-dotnet-6/) (verify URL)
