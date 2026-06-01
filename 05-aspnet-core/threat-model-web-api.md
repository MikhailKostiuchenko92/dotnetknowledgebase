# Threat Modeling a Web API (OWASP API Top 10)

**Category:** ASP.NET Core / Security Best Practices
**Difficulty:** 🔴 Senior
**Tags:** `OWASP`, `threat-model`, `API-security`, `BOLA`, `mass-assignment`, `SSRF`, `rate-limiting`

## Question

> How do you threat-model a .NET Web API using the OWASP API Top 10? Walk through the key risks — Broken Object Level Authorization, mass assignment, and SSRF — and their mitigations in ASP.NET Core.

## Short Answer

The OWASP API Top 10 is a ranked list of the most critical API security risks. In .NET APIs, the highest-impact items are: **BOLA** (Broken Object Level Authorization) — an authenticated user accessing another user's data by guessing IDs; **Broken Function Level Authorization** — calling admin endpoints as a regular user; **Excessive Data Exposure** / **Mass Assignment** — exposing or accepting too many fields; and **SSRF** (Server-Side Request Forgery) — tricking the server into fetching internal resources. Each has a specific mitigation pattern in ASP.NET Core.

## Detailed Explanation

### OWASP API Top 10 2023 overview

| # | Risk | .NET Signal |
|---|---|---|
| API1 | Broken Object Level Authorization (BOLA) | Missing per-resource ownership check |
| API2 | Broken Authentication | Weak JWT validation, missing `aud`/`iss` checks |
| API3 | Broken Object Property Level Authorization | Returning/accepting too many properties (mass assignment) |
| API4 | Unrestricted Resource Consumption | No rate limiting, no request size limits |
| API5 | Broken Function Level Authorization | Admin endpoints reachable by regular users |
| API6 | Unrestricted Access to Sensitive Business Flows | No bot protection on checkout/registration |
| API7 | Server-Side Request Forgery (SSRF) | User-supplied URLs fetched by server |
| API8 | Security Misconfiguration | Debug endpoints, verbose errors, CORS `*` |
| API9 | Improper Inventory Management | Undocumented/shadow endpoints |
| API10 | Unsafe Consumption of APIs | Trusting third-party API responses |

### API1: Broken Object Level Authorization (BOLA)

The most common API vulnerability. A user is authorized in general but can access another user's objects by manipulating IDs.

```csharp
// ❌ VULNERABLE — only checks IsAuthenticated, not ownership
[HttpGet("orders/{orderId}")]
[Authorize]
public async Task<IActionResult> GetOrder(int orderId)
{
    var order = await _db.Orders.FindAsync(orderId);
    return Ok(order); // Any authenticated user can read any order
}

// ✅ FIXED — always check that the resource belongs to the caller
[HttpGet("orders/{orderId}")]
[Authorize]
public async Task<IActionResult> GetOrder(int orderId)
{
    var userId = User.FindFirst(ClaimTypes.NameIdentifier)!.Value;
    var order = await _db.Orders
        .Where(o => o.Id == orderId && o.UserId == userId) // Ownership check in query
        .FirstOrDefaultAsync();

    if (order is null) return NotFound(); // 404, not 403 — don't leak existence
    return Ok(order);
}
```

> **Critical:** Return `404 Not Found` rather than `403 Forbidden` for inaccessible resources — `403` leaks that the resource exists.

### API3: Broken Object Property Level Authorization (mass assignment / over-exposure)

See [input-validation-security.md](input-validation-security.md) for the mass assignment detail. For **over-exposure**:

```csharp
// ❌ VULNERABLE — returns all user properties including sensitive ones
return Ok(user); // Includes PasswordHash, SecurityStamp, IsAdmin

// ✅ FIXED — explicit projection / DTO
return Ok(new UserResponse(user.Id, user.DisplayName, user.Email));
```

Use `[JsonIgnore]` as a fallback:

```csharp
public sealed class User
{
    public string Id { get; set; } = "";
    public string Email { get; set; } = "";

    [JsonIgnore]                    // Never serialized in API responses
    public string PasswordHash { get; set; } = "";
}
```

### API4: Unrestricted Resource Consumption — rate limiting

```csharp
// Program.cs
builder.Services.AddRateLimiter(opts =>
{
    opts.AddFixedWindowLimiter("api", limiterOpts =>
    {
        limiterOpts.PermitLimit = 100;
        limiterOpts.Window = TimeSpan.FromMinutes(1);
        limiterOpts.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        limiterOpts.QueueLimit = 0;
    });
    opts.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});

app.UseRateLimiter();

[HttpPost("register")]
[EnableRateLimiting("api")]
public IActionResult Register(...)
```

Also: set request body size limits:

```csharp
builder.Services.Configure<KestrelServerOptions>(opts =>
    opts.Limits.MaxRequestBodySize = 10 * 1024 * 1024); // 10 MB
```

### API7: Server-Side Request Forgery (SSRF)

SSRF occurs when a user can supply a URL that the server fetches, allowing access to internal services (metadata endpoints, `http://localhost`, AWS IMDS).

```csharp
// ❌ VULNERABLE — fetches user-supplied URL
[HttpPost("webhook-test")]
public async Task<IActionResult> TestWebhook([FromBody] WebhookRequest req)
{
    var response = await _httpClient.GetAsync(req.Url); // Attacker sends "http://169.254.169.254/latest/meta-data/"
    return Ok(await response.Content.ReadAsStringAsync());
}

// ✅ FIXED — allowlist of valid hosts
private static readonly HashSet<string> AllowedHosts = ["hooks.example.com", "api.partner.com"];

[HttpPost("webhook-test")]
public async Task<IActionResult> TestWebhook([FromBody] WebhookRequest req)
{
    if (!Uri.TryCreate(req.Url, UriKind.Absolute, out var uri)
        || (uri.Scheme != "https")
        || !AllowedHosts.Contains(uri.Host))
    {
        return BadRequest("Invalid webhook URL");
    }

    var response = await _httpClient.GetAsync(uri);
    return Ok(await response.Content.ReadAsStringAsync());
}
```

### API8: Security Misconfiguration

```csharp
// Disable verbose errors in production
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/error"); // Returns ProblemDetails without stack trace
    app.UseHsts();
}

// Use ProblemDetails for structured error responses
builder.Services.AddProblemDetails(opts =>
{
    opts.CustomizeProblemDetails = ctx =>
    {
        // Never expose exception details in production
        if (!ctx.HttpContext.RequestServices
                .GetRequiredService<IHostEnvironment>().IsDevelopment())
        {
            ctx.ProblemDetails.Extensions.Remove("exception");
            ctx.ProblemDetails.Extensions.Remove("traceId"); // optional
        }
    };
});
```

## Code Example

```csharp
// ResourceOwnershipExtension — reusable BOLA check
public static class QueryExtensions
{
    public static IQueryable<T> OwnedBy<T>(
        this IQueryable<T> query,
        string userId)
        where T : IOwnedEntity
    {
        return query.Where(e => e.UserId == userId);
    }
}

// Usage
var order = await _db.Orders
    .OwnedBy(currentUserId)
    .Where(o => o.Id == orderId)
    .FirstOrDefaultAsync();

if (order is null) return NotFound();
```

## Common Follow-up Questions

- What is the difference between BOLA and BFLA (Broken Function Level Authorization)?
- How does OAuth2 scope-based authorization relate to BFLA mitigation?
- What is the AWS IMDS endpoint and why is it the canonical SSRF target in cloud environments?
- How would you detect BOLA vulnerabilities during a code review or penetration test?
- What threat modeling frameworks (STRIDE, PASTA, LINDDUN) apply to API design?

## Common Mistakes / Pitfalls

- **Checking `[Authorize]` but not ownership** — authentication ≠ authorization; always verify the resource belongs to the caller.
- **Returning `403` for inaccessible resources instead of `404`** — `403` leaks the resource's existence, enabling enumeration.
- **No rate limiting on authentication endpoints** — password-spray and credential-stuffing attacks exploit unlimited `/login` retries.
- **Fetching user-supplied URLs without host allowlisting** — even if the URL scheme is checked, an attacker can use DNS rebinding to bypass IP-based checks; an explicit host allowlist is safer.
- **Assuming internal network isolation prevents SSRF exploitation** — cloud metadata endpoints (`169.254.169.254`) are accessible from any workload regardless of VPC security groups.

## References

- [OWASP API Security Top 10 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [OWASP — SSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
- [Microsoft Learn — Rate limiting in ASP.NET Core](https://learn.microsoft.com/aspnet/core/performance/rate-limit?view=aspnetcore-8.0)
- [OWASP — Mass Assignment Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html)
- [Scott Brady — OWASP API Security in ASP.NET Core](https://www.scottbrady91.com) (verify URL)
