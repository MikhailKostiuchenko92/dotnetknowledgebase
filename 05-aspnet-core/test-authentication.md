# Test Authentication in ASP.NET Core Integration Tests

**Category:** ASP.NET Core / Testing
**Difficulty:** 🟡 Middle
**Tags:** `test-authentication`, `JWT`, `ClaimsPrincipal`, `TestAuthHandler`, `integration-testing`

## Question

> How do you test authenticated and authorized ASP.NET Core endpoints in integration tests — without setting up a real identity provider or creating real JWT tokens?

## Short Answer

In integration tests, register a custom `TestAuthHandler` that implements `AuthenticationHandler<AuthenticationSchemeOptions>` and sets a fake `ClaimsPrincipal` with the claims your tests need. This bypasses real token validation entirely. You then call `CreateClient()` with a default request header that activates the test scheme, or add the header per request.

## Detailed Explanation

### Why not just use real JWTs?

Real JWT tests require a running identity provider or manual token signing. That ties tests to external infrastructure and key management. A `TestAuthHandler` is deterministic, fast, and fully controllable.

### Implementing `TestAuthHandler`

```csharp
public sealed class TestAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "TestScheme";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        // Build a fake principal from the request header
        var userId = Request.Headers["X-Test-UserId"].FirstOrDefault() ?? "test-user-1";
        var role = Request.Headers["X-Test-Role"].FirstOrDefault() ?? "User";

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userId),
            new Claim(ClaimTypes.Email, $"{userId}@test.com"),
            new Claim(ClaimTypes.Role, role),
        };

        var identity = new ClaimsIdentity(claims, SchemeName);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

### Registering in the test factory

```csharp
protected override void ConfigureWebHost(IWebHostBuilder builder)
{
    builder.ConfigureServices(services =>
    {
        // Replace real auth with the test handler
        services.AddAuthentication(TestAuthHandler.SchemeName)
            .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(
                TestAuthHandler.SchemeName, _ => { });
    });
}
```

### Using in tests

```csharp
public sealed class SecureEndpointTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public SecureEndpointTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
        // Default: all requests use the test auth handler
    }

    [Fact]
    public async Task GetMyProfile_AsAuthenticatedUser_ReturnsOk()
    {
        // Provide identity via headers
        _client.DefaultRequestHeaders.Add("X-Test-UserId", "user-42");
        _client.DefaultRequestHeaders.Add("X-Test-Role", "User");

        var response = await _client.GetAsync("/profile");

        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task AdminEndpoint_AsRegularUser_Returns403()
    {
        _client.DefaultRequestHeaders.Add("X-Test-UserId", "user-42");
        _client.DefaultRequestHeaders.Add("X-Test-Role", "User"); // Not Admin

        var response = await _client.GetAsync("/admin/users");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
}
```

### Per-request identity (no shared client state)

```csharp
// Safer: create fresh client per test, or use HttpRequestMessage
var request = new HttpRequestMessage(HttpMethod.Get, "/orders");
request.Headers.Add("X-Test-UserId", "admin-1");
request.Headers.Add("X-Test-Role", "Admin");
var response = await _client.SendAsync(request);
```

### Testing unauthenticated requests

```csharp
// Create a client that sends NO auth header
var anonymousClient = _factory.CreateClient(new WebApplicationFactoryClientOptions
{
    AllowAutoRedirect = false
});

var response = await anonymousClient.GetAsync("/profile");
Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
```

## Code Example

```csharp
// Complete test: role-based authorization
[Fact]
public async Task DeleteProduct_AsAdmin_Returns204()
{
    var client = _factory.CreateClient();
    client.DefaultRequestHeaders.Add("X-Test-UserId", "admin-1");
    client.DefaultRequestHeaders.Add("X-Test-Role", "Admin");

    var response = await client.DeleteAsync("/products/1");

    Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
}

[Fact]
public async Task DeleteProduct_AsUser_Returns403()
{
    var client = _factory.CreateClient();
    client.DefaultRequestHeaders.Add("X-Test-UserId", "user-1");
    client.DefaultRequestHeaders.Add("X-Test-Role", "User");

    var response = await client.DeleteAsync("/products/1");

    Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
}

[Fact]
public async Task DeleteProduct_Unauthenticated_Returns401()
{
    var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
    {
        AllowAutoRedirect = false
    });

    var response = await client.DeleteAsync("/products/1");

    Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
}
```

## Common Follow-up Questions

- How do you test resource-based authorization (policy + `IAuthorizationService`) in integration tests?
- How do you test claims-transformed identities (custom `IClaimsTransformation`)?
- How would you generate real, signed JWT tokens for integration tests against a real JWT validation stack?
- What is the `WithWebHostBuilder` factory method and how does it differ from overriding `ConfigureWebHost`?
- How do you test anti-forgery token validation in integration tests?

## Common Mistakes / Pitfalls

- **Sharing `DefaultRequestHeaders` between tests via shared client** — mutations to `DefaultRequestHeaders` persist; use per-request `HttpRequestMessage` or create fresh clients for each test.
- **Forgetting `AllowAutoRedirect = false`** — a `401` redirect to `/login` becomes `200` on the login page, masking the actual auth failure.
- **Not removing the real auth scheme** — if both the real JWT handler and `TestAuthHandler` are registered, the real one may run first and reject the request.
- **Relying solely on the test auth handler without testing the real auth path** — your integration tests should also include at least one test that exercises the real JWT/cookie validation to catch configuration regressions.

## References

- [Microsoft Learn — Test auth in integration tests](https://learn.microsoft.com/aspnet/core/test/integration-tests?view=aspnetcore-8.0#mock-authentication)
- [Andrew Lock — Authenticated integration test clients](https://andrewlock.net/creating-a-test-user-using-mocked-authentication-in-asp-net-core/) (verify URL)
- [Chris Klug — Faking authentication in ASP.NET Core integration tests](https://chriskl.com) (verify URL)
