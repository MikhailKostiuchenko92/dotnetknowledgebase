# Authentication vs Authorization

**Category:** System Design / Security
**Difficulty:** Junior
**Tags:** `authentication`, `authorization`, `authn`, `authz`, `asp.net-core`, `jwt`, `claims`

## Question

> What is the difference between authentication and authorization? How does ASP.NET Core implement each?

- Can you be authenticated but not authorized? Give an example.
- What is claims-based identity and how does it relate to both?

## Short Answer

Authentication (AuthN) answers "who are you?" — it verifies identity by checking credentials (password, token, certificate). Authorization (AuthZ) answers "what are you allowed to do?" — it checks whether a verified identity has permission to access a resource. In ASP.NET Core, authentication middleware runs first to establish identity (`HttpContext.User`); authorization middleware then evaluates policies against that identity before the controller action executes. You can absolutely be authenticated but not authorized — for example, a logged-in user trying to access an admin-only endpoint.

## Detailed Explanation

### Conceptual Difference

| | Authentication (AuthN) | Authorization (AuthZ) |
|--|----------------------|----------------------|
| Question | "Who are you?" | "What can you do?" |
| Input | Credentials (password, token, cert) | Identity + resource + action |
| Output | Identity / principal | Allow or Deny |
| When it fails | 401 Unauthorized | 403 Forbidden |
| Example | Validating a JWT signature | Checking `role == "Admin"` |

> **Common confusion:** HTTP 401 is named "Unauthorized" but semantically means *unauthenticated* — the request lacks valid credentials. HTTP 403 Forbidden means *unauthorized* — the identity is known but lacks permission. ASP.NET Core returns the correct status codes automatically.

### Claims-Based Identity

ASP.NET Core uses a claims-based identity model. After successful authentication, the middleware creates a `ClaimsPrincipal` attached to `HttpContext.User`:

- **Claim**: a statement about the user — e.g., `{ type: "email", value: "alice@example.com" }` or `{ type: ClaimTypes.Role, value: "Admin" }`.
- **ClaimsIdentity**: a collection of claims with an authentication type (e.g., `"Bearer"`).
- **ClaimsPrincipal**: one or more `ClaimsIdentity` objects (supports multi-scheme login).

Both authentication and authorization operate on claims:
- **AuthN** creates and populates claims from the credential (e.g., reads the JWT payload into claims).
- **AuthZ** evaluates those claims against policy requirements.

### ASP.NET Core: Authentication Pipeline

```csharp
// Program.cs
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority  = "https://login.example.com";   // OIDC discovery endpoint
        options.Audience   = "my-api";
        options.TokenValidationParameters = new()
        {
            ValidateIssuer           = true,
            ValidateAudience         = true,
            ValidateLifetime         = true,
            ValidateIssuerSigningKey = true,
        };
    });

// Order matters: Authentication MUST come before Authorization
app.UseAuthentication();  // Sets HttpContext.User if a valid token is present
app.UseAuthorization();   // Checks policies — runs AFTER identity is established
```

### ASP.NET Core: Authorization

ASP.NET Core offers three flavours of authorization:

**1. Simple role check (`[Authorize(Roles = "Admin")]`)**

```csharp
[Authorize(Roles = "Admin,Manager")]
public IActionResult DeleteUser(Guid userId) { ... }
```

**2. Policy-based authorization** (recommended — decouples rules from controllers)

```csharp
// Register policy
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("CanDeleteUsers", policy =>
        policy.RequireRole("Admin")
              .RequireClaim("department", "IT", "HR"));

    options.AddPolicy("MinimumAge18", policy =>
        policy.Requirements.Add(new MinimumAgeRequirement(18)));
});

// Use in controller
[Authorize(Policy = "CanDeleteUsers")]
public IActionResult DeleteUser(Guid userId) { ... }
```

**3. Resource-based authorization** (imperative, for per-instance checks)

```csharp
public async Task<IActionResult> EditPost(Guid postId)
{
    var post = await _posts.FindAsync(postId);
    if (post is null) return NotFound();

    // Check if THIS user can edit THIS post
    var result = await _authz.AuthorizeAsync(User, post, "EditPolicy");
    if (!result.Succeeded) return Forbid();

    return View(post);
}
```

### Custom Requirement + Handler Example

```csharp
// Requirement (data only)
public record MinimumAgeRequirement(int MinimumAge) : IAuthorizationRequirement;

// Handler (logic)
public sealed class MinimumAgeHandler : AuthorizationHandler<MinimumAgeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        MinimumAgeRequirement requirement)
    {
        var dobClaim = context.User.FindFirst("birthdate");
        if (dobClaim is null || !DateOnly.TryParse(dobClaim.Value, out var dob))
            return Task.CompletedTask;  // don't call Succeed — requirement not met

        if (DateOnly.FromDateTime(DateTime.UtcNow).Year - dob.Year >= requirement.MinimumAge)
            context.Succeed(requirement);

        return Task.CompletedTask;
    }
}

// Register
builder.Services.AddSingleton<IAuthorizationHandler, MinimumAgeHandler>();
```

### Authenticated but Not Authorized: Real Example

```
User: Alice (authenticated, role = "Employee")
Resource: DELETE /api/users/{id} (requires role = "Admin")

1. Request arrives with valid JWT → UseAuthentication() sets User = Alice with role "Employee"
2. Controller has [Authorize(Roles = "Admin")] → authorization check fails
3. Response: 403 Forbidden  (NOT 401 — Alice IS authenticated, just not authorized)
```

### Authentication Schemes

ASP.NET Core supports multiple auth schemes simultaneously (cookie + JWT + API key):

```csharp
builder.Services.AddAuthentication()
    .AddJwtBearer("jwt", ...)       // API clients
    .AddCookie("cookie", ...)       // Browser clients
    .AddApiKeyScheme("apikey", ...);// Machine-to-machine

// Use specific scheme per endpoint
[Authorize(AuthenticationSchemes = "jwt,apikey")]
public IActionResult GetData() { ... }
```

## Code Example

```csharp
// Minimal full example: JWT authentication + policy-based authorization
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.Authority = builder.Configuration["Jwt:Authority"];
        o.Audience  = builder.Configuration["Jwt:Audience"];
    });

builder.Services.AddAuthorization(options =>
{
    // Default policy: must be authenticated
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();

    options.AddPolicy("AdminOnly",   p => p.RequireRole("Admin"));
    options.AddPolicy("ReadOrders",  p => p.RequireClaim("scope", "orders:read"));
    options.AddPolicy("WriteOrders", p => p.RequireClaim("scope", "orders:write"));
});

var app = builder.Build();
app.UseAuthentication();  // ← must come first
app.UseAuthorization();

app.MapGet("/orders",         () => "order list")   .RequireAuthorization("ReadOrders");
app.MapPost("/orders",        () => "order created").RequireAuthorization("WriteOrders");
app.MapDelete("/users/{id}",  () => "deleted")      .RequireAuthorization("AdminOnly");
app.MapGet("/health",         () => "ok")           .AllowAnonymous();  // exempt

app.Run();
```

## Common Follow-up Questions

- What is the difference between `[Authorize]` and `[AllowAnonymous]`?
- How does OpenID Connect (OIDC) relate to OAuth 2.0? Which handles authentication and which handles authorization?
- How do you implement row-level security (per-resource authorization) efficiently?
- How do you refresh an expired JWT without logging the user out?
- What are the risks of storing authorization data (roles, permissions) in the JWT vs querying the database on each request?

## Common Mistakes / Pitfalls

- **Calling `UseAuthorization()` before `UseAuthentication()`**: authorization runs without an established identity — all `[Authorize]` endpoints return 401 or 403 spuriously.
- **Returning 401 for authorization failures**: 401 means "you need to authenticate"; 403 means "you are authenticated but not allowed". Using 401 for both leaks security information.
- **Trusting client-supplied roles in the JWT without validation**: always validate the JWT signature; never let the client craft their own claims.
- **Using only role-based authorization for fine-grained control**: roles like `Admin` become catch-alls. Prefer permission/scope claims (`orders:delete`) for granular control.
- **Caching authorization decisions across users**: `IAuthorizationService` results must not be cached in a shared static field — results are per-user and per-resource.

## References

- [Authentication in ASP.NET Core — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/)
- [Authorization in ASP.NET Core — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/introduction)
- [Policy-based authorization — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/policies)
- [Resource-based authorization — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/resourcebased)
- [See: jwt-design-considerations.md](./jwt-design-considerations.md)
- [See: oauth2-flows-compared.md](./oauth2-flows-compared.md)
