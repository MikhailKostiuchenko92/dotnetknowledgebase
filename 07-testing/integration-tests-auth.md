# How Do You Handle Authentication/Authorization in Integration Tests?

**Category:** Testing / Integration Testing in ASP.NET Core
**Difficulty:** 🟡 Middle
**Tags:** `WebApplicationFactory`, `authentication`, `JWT`, `fake-auth`, `integration-testing`

## Question
> How do you handle authentication/authorization in integration tests (e.g., fake JWT)?

## Short Answer
The cleanest approach is to add a custom `AuthenticationHandler` that always returns an authenticated identity with configurable claims, bypassing real token validation. Register this in `ConfigureTestServices` to replace the real JWT bearer handler. Alternatively, generate a real JWT signed with a test key. Both approaches let you test authorization logic (roles, policies, claims) without a real identity provider.

## Detailed Explanation

### Option 1: Fake Authentication Handler (Recommended)
```csharp
public class FakeAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public FakeAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger, UrlEncoder encoder)
        : base(options, logger, encoder) { }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = new[]
        {
            new Claim(ClaimTypes.Name, "test-user"),
            new Claim(ClaimTypes.NameIdentifier, "user-1"),
            new Claim(ClaimTypes.Role, "Admin")
        };
        var identity = new ClaimsIdentity(claims, "FakeScheme");
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, "FakeScheme");
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
```

Register in the test factory:
```csharp
builder.ConfigureTestServices(services =>
{
    services.AddAuthentication(defaultScheme: "FakeScheme")
            .AddScheme<AuthenticationSchemeOptions, FakeAuthHandler>("FakeScheme", _ => { });
});
```

### Option 2: Real JWT with Test Key
```csharp
// Generate a JWT in the test:
var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("test-secret-key-32-chars-long!!"));
var token = new JwtSecurityTokenHandler().WriteToken(new JwtSecurityToken(
    issuer: "test",
    audience: "test",
    claims: [new Claim(ClaimTypes.Name, "user")],
    expires: DateTime.UtcNow.AddHours(1),
    signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256)));

// Configure the factory to use the same test key:
builder.ConfigureAppConfiguration((ctx, config) =>
    config.AddInMemoryCollection(new Dictionary<string, string?>
    {
        ["Jwt:Key"] = "test-secret-key-32-chars-long!!",
        ["Jwt:Issuer"] = "test"
    }));
```

### Option 3: Disable Authorization for Non-Auth Tests
```csharp
builder.ConfigureTestServices(services =>
    services.AddSingleton<IAuthorizationHandler, AllowAnonymousAuthorizationHandler>());
```
Where `AllowAnonymousAuthorizationHandler` always returns success. Use sparingly — it bypasses authorization policy testing entirely.

### Testing Different Roles
Make the fake handler configurable via a custom `AuthTestOptions`:
```csharp
public class FakeAuthHandler : AuthenticationHandler<FakeAuthOptions>
{
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var claims = Options.Claims.ToList();
        // ...
    }
}

// In tests, create factory variant with different role:
var adminFactory = factory.WithWebHostBuilder(b =>
    b.ConfigureTestServices(s =>
        s.Configure<FakeAuthOptions>("FakeScheme", o =>
            o.Claims = [new Claim(ClaimTypes.Role, "Admin")])));
```

## Code Example
```csharp
namespace Auth.Integration.Tests;

public class FakeAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger, UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public static IEnumerable<Claim> Claims { get; set; } = DefaultClaims();

    private static IEnumerable<Claim> DefaultClaims() =>
    [
        new(ClaimTypes.NameIdentifier, "user-1"),
        new(ClaimTypes.Name, "Test User"),
        new(ClaimTypes.Role, "User")
    ];

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var identity = new ClaimsIdentity(Claims, "FakeScheme");
        var ticket = new AuthenticationTicket(new ClaimsPrincipal(identity), "FakeScheme");
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}

public class AuthTestWebAppFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureTestServices(services =>
        {
            services.AddAuthentication(defaultScheme: "FakeScheme")
                    .AddScheme<AuthenticationSchemeOptions, FakeAuthHandler>("FakeScheme", _ => { });
        });
    }
}

[Collection("AuthIntegration")]
public class AdminEndpointTests : IClassFixture<AuthTestWebAppFactory>
{
    private readonly HttpClient _client;
    public AdminEndpointTests(AuthTestWebAppFactory factory)
        => _client = factory.CreateClient();

    [Fact]
    public async Task GetAdminResource_WithAdminRole_Returns200()
    {
        FakeAuthHandler.Claims =
        [
            new(ClaimTypes.NameIdentifier, "admin-1"),
            new(ClaimTypes.Role, "Admin")
        ];

        var response = await _client.GetAsync("/api/admin/users");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task GetAdminResource_WithUserRole_Returns403()
    {
        FakeAuthHandler.Claims = [new(ClaimTypes.Role, "User")];

        var response = await _client.GetAsync("/api/admin/users");

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }
}
```

## Common Follow-up Questions
- What is the difference between using a fake auth handler and generating a real JWT in tests?
- How do you test authorization policies (not just roles) in integration tests?
- How do you test unauthenticated (anonymous) access in integration tests?
- How do you test OAuth2 / OpenID Connect flows in integration tests?
- How do you pass the JWT Bearer token from the test client?
- How do you test resource-based authorization (`IAuthorizationService`) in integration tests?

## Common Mistakes / Pitfalls
- **Not replacing the scheme name** — if production uses `"Bearer"`, the test factory must configure the same default scheme or policies referencing `"Bearer"` will fail silently.
- **Static `Claims` property on handler** — works for single-threaded tests, but parallel tests will race on the shared static; use `IOptionsMonitor` or per-client state.
- **Disabling all authorization instead of testing it** — `AllowAnonymousAuthorizationHandler` makes authorization tests meaningless.
- **Forgetting `AddAuthentication` before `AddScheme`** — the scheme must be registered as the default; without it, the `[Authorize]` filter won't trigger.
- **Testing auth separately from business logic** — include auth and logic in the same integration test to catch integration bugs between the two layers.

## References
- [Microsoft Learn — Integration tests — Authentication](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests#mock-authentication)
- [ASP.NET Core — Custom authentication handler](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/customize-identity-model)
- [NuGet — Microsoft.AspNetCore.Mvc.Testing](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc.Testing/)
