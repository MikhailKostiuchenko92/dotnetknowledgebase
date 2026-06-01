# API Key Authentication in ASP.NET Core

**Category:** ASP.NET Core / Authentication & Authorization
**Difficulty:** 🟡 Middle
**Tags:** `api-key`, `AuthenticationHandler`, `custom-scheme`, `IAuthenticationHandler`, `security`

## Question

> How do you implement API key authentication in ASP.NET Core using a custom `AuthenticationHandler<T>`?

## Short Answer

Create a class inheriting `AuthenticationHandler<AuthenticationSchemeOptions>`, override `HandleAuthenticateAsync` to extract the API key from the request (header, query, or cookie), validate it against a store, and return `AuthenticateResult.Success(ticket)` or `AuthenticateResult.Fail()`. Register the scheme with `AddScheme<TOptions, THandler>()`. Apply `[Authorize(AuthenticationSchemes = "ApiKey")]` on endpoints that should use it.

## Detailed Explanation

### Authentication handler lifecycle

```
Request
  ↓
UseAuthentication() middleware
  ↓
IAuthenticationService.AuthenticateAsync(scheme: "ApiKey")
  ↓
ApiKeyAuthHandler.HandleAuthenticateAsync()
  ↓
AuthenticateResult.Success(ticket) → ClaimsPrincipal → HttpContext.User
```

### Creating the handler

```csharp
public sealed class ApiKeyAuthHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    IApiKeyService apiKeyService)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "ApiKey";
    private const string HeaderName = "X-Api-Key";

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        // 1. Extract the key
        if (!Request.Headers.TryGetValue(HeaderName, out var keyValues))
            return AuthenticateResult.NoResult(); // no key present — let other schemes try

        var rawKey = keyValues.ToString();
        if (string.IsNullOrWhiteSpace(rawKey))
            return AuthenticateResult.Fail("Empty API key");

        // 2. Validate the key
        var principal = await apiKeyService.ValidateAsync(rawKey, Context.RequestAborted);
        if (principal is null)
            return AuthenticateResult.Fail("Invalid API key");

        // 3. Build success ticket
        var ticket = new AuthenticationTicket(principal, SchemeName);
        return AuthenticateResult.Success(ticket);
    }

    // Override to return 401 JSON instead of default WWW-Authenticate challenge
    protected override Task HandleChallengeAsync(AuthenticationProperties properties)
    {
        Response.StatusCode = StatusCodes.Status401Unauthorized;
        Response.ContentType = "application/problem+json";
        return Response.WriteAsJsonAsync(new ProblemDetails
        {
            Title = "Unauthorized",
            Detail = "API key is required",
            Status = 401
        });
    }
}
```

### Registration

```csharp
builder.Services.AddAuthentication()
    .AddScheme<AuthenticationSchemeOptions, ApiKeyAuthHandler>(
        ApiKeyAuthHandler.SchemeName, _ => { });

builder.Services.AddScoped<IApiKeyService, ApiKeyService>();
```

### API key service

```csharp
public interface IApiKeyService
{
    Task<ClaimsPrincipal?> ValidateAsync(string rawKey, CancellationToken ct);
}

public sealed class ApiKeyService(IApiKeyRepository repo) : IApiKeyService
{
    public async Task<ClaimsPrincipal?> ValidateAsync(string rawKey, CancellationToken ct)
    {
        // Hash the incoming key before lookup (never store plaintext)
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(rawKey)));
        var apiKey = await repo.FindByHashAsync(hash, ct);
        if (apiKey is null || apiKey.ExpiresAt < DateTimeOffset.UtcNow)
            return null;

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, apiKey.ClientId),
            new Claim(ClaimTypes.Name, apiKey.ClientName),
            new Claim("api-key-id", apiKey.Id.ToString())
        };
        var identity = new ClaimsIdentity(claims, ApiKeyAuthHandler.SchemeName);
        return new ClaimsPrincipal(identity);
    }
}
```

### Applying to endpoints

```csharp
// Specific scheme only
[Authorize(AuthenticationSchemes = ApiKeyAuthHandler.SchemeName)]
[ApiController]
[Route("api/webhook")]
public class WebhookController : ControllerBase { ... }

// Accept both JWT AND API key (OR logic — either succeeds)
[Authorize(AuthenticationSchemes = $"{JwtBearerDefaults.AuthenticationScheme},{ApiKeyAuthHandler.SchemeName}")]
[HttpGet]
public IActionResult GetData() => Ok();
```

```csharp
// Minimal API
app.MapPost("/api/events", HandleEvent)
   .RequireAuthorization(new AuthorizeAttribute
   {
       AuthenticationSchemes = ApiKeyAuthHandler.SchemeName
   });
```

## Code Example

```csharp
// Attribute-based convenience
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class ApiKeyAuthorizeAttribute()
    : AuthorizeAttribute(ApiKeyAuthHandler.SchemeName);

// Usage
[ApiKeyAuthorize]
[ApiController]
[Route("api/[controller]")]
public class DataIngestController : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Ingest(IngestRequest req)
    {
        var clientId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        // process...
        return Accepted();
    }
}
```

## Common Follow-up Questions

- How do you rate-limit per API key?
- What is the difference between `AuthenticateResult.NoResult()` and `AuthenticateResult.Fail()`?
- How do you implement API key rotation (issue new key, graceful expiry of old)?
- How do you combine API key auth with JWT auth so either can be used on the same endpoint?
- How should API keys be stored in the database (hashed, not plaintext)?

## Common Mistakes / Pitfalls

- **Returning `AuthenticateResult.Fail()` instead of `NoResult()` when no key is present** — `Fail()` immediately ends authentication for the request, preventing other schemes from running. Use `NoResult()` when the scheme header/parameter is absent.
- **Storing API keys in plaintext in the database** — always store a hash (SHA-256 or bcrypt); display the key only once at creation time.
- **Including the API key in the URL query string for server-to-server calls** — query strings appear in server access logs; prefer HTTP headers (`X-Api-Key`).
- **Not scoping `IApiKeyService` correctly** — if the service accesses a database, it should be `Scoped`; making it `Singleton` can cause EF Core DbContext concurrency issues.
- **Overriding `HandleChallengeAsync` incorrectly** — the default challenge adds a `WWW-Authenticate` header; for JSON APIs, override it to return `application/problem+json` instead.

## References

- [Microsoft Learn — Custom authentication handler](https://learn.microsoft.com/aspnet/core/security/authentication/customize-identity-model?view=aspnetcore-8.0) (verify URL)
- [Microsoft Learn — AuthenticationHandler source](https://github.com/dotnet/aspnetcore/blob/main/src/Security/Authentication/Core/src/AuthenticationHandler.cs)
- [Andrew Lock — API key authentication](https://andrewlock.net/tag/api-key/) (verify URL)
- [Scott Brady — API key auth in ASP.NET Core](https://www.scottbrady91.com/aspnet-identity/api-key-authentication) (verify URL)
