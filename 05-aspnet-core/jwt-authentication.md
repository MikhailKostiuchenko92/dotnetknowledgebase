# JWT Authentication in ASP.NET Core

**Category:** ASP.NET Core / Authentication & Authorization
**Difficulty:** 🟢 Junior
**Tags:** `JWT`, `JwtBearer`, `AddJwtBearer`, `TokenValidationParameters`, `bearer`, `HMAC`, `RSA`

## Question

> How do you configure JWT Bearer authentication in ASP.NET Core? What does `TokenValidationParameters` validate, and how do you choose between HMAC and RSA signing?

## Short Answer

Add `AddJwtBearer()` with `TokenValidationParameters` specifying issuer, audience, and signing key. The middleware extracts the `Authorization: Bearer <token>` header, validates the JWT signature and claims, and populates `HttpContext.User` on success. **HMAC-SHA256** (symmetric) uses a single shared secret — simpler but the secret must be kept on all parties. **RSA** (asymmetric) uses a public key for validation and a private key for signing — preferred when the token issuer (e.g., identity server) is separate from the resource server (API).

## Detailed Explanation

### JWT structure recap

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9   // Header (alg, typ)
.eyJzdWIiOiJ1c2VyMTIzIiwiZXhwIjoxNzAw}  // Payload (claims)
.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c  // Signature
```

### Minimal setup (HMAC symmetric key)

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts =>
    {
        opts.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = "https://myapp.com",

            ValidateAudience = true,
            ValidAudience = "my-api",

            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Secret"]!)),

            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(5) // allow 5-min clock drift
        };
    });
```

### RSA asymmetric key (production-recommended)

```csharp
opts.TokenValidationParameters = new TokenValidationParameters
{
    ValidateIssuer = true,
    ValidIssuer = "https://idp.mycompany.com",
    ValidateAudience = true,
    ValidAudience = "api1",
    ValidateIssuerSigningKey = true,
    IssuerSigningKey = new RsaSecurityKey(rsa), // RSA public key for validation
    ValidateLifetime = true
};
```

### Authority-based setup (OIDC/OAuth2 well-known endpoint)

For an external identity provider (IdentityServer, Entra ID, Auth0):

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts =>
    {
        opts.Authority = "https://login.microsoftonline.com/{tenantId}/v2.0";
        opts.Audience = "api://my-app-id";
        // Framework auto-fetches signing keys from Authority's .well-known/openid-configuration
    });
```

Setting `Authority` causes the middleware to auto-discover signing keys via `/.well-known/openid-configuration` — no manual key configuration needed.

### `TokenValidationParameters` key properties

| Property | Default | Purpose |
|---|---|---|
| `ValidateIssuer` | `true` | Check `iss` claim matches `ValidIssuer` |
| `ValidateAudience` | `true` | Check `aud` claim matches `ValidAudience` |
| `ValidateIssuerSigningKey` | `false` | Verify signature with `IssuerSigningKey` |
| `ValidateLifetime` | `true` | Check `exp` and `nbf` claims |
| `ClockSkew` | 5 minutes | Grace period for clock drift |
| `RoleClaimType` | `ClaimsIdentity.DefaultRoleClaimType` | Which claim maps to user roles |
| `NameClaimType` | `ClaimsIdentity.DefaultNameClaimType` | Which claim is `User.Identity.Name` |

### Issuing a JWT (API or token endpoint)

```csharp
private string GenerateToken(string userId, string email)
{
    var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Secret"]!));
    var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

    var claims = new[]
    {
        new Claim(JwtRegisteredClaimNames.Sub, userId),
        new Claim(JwtRegisteredClaimNames.Email, email),
        new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
    };

    var token = new JwtSecurityToken(
        issuer: "https://myapp.com",
        audience: "my-api",
        claims: claims,
        expires: DateTime.UtcNow.AddHours(1),
        signingCredentials: credentials);

    return new JwtSecurityTokenHandler().WriteToken(token);
}
```

### HMAC vs RSA

| | HMAC-SHA256 (HS256) | RSA (RS256) |
|---|---|---|
| Key type | Symmetric (one secret) | Asymmetric (private + public) |
| Signing | Same key as verification | Private key signs, public key verifies |
| Secret sharing | Both issuer and resource server need the secret | Resource server only needs public key |
| Key rotation | Must update all parties | Rotate private key; public key in JWKS endpoint |
| Use when | Monolith / same team | Microservices / external IDP |

## Code Example

```csharp
// Complete setup with events for debugging
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts =>
    {
        opts.Authority = builder.Configuration["Auth:Authority"];
        opts.Audience = builder.Configuration["Auth:Audience"];
        opts.TokenValidationParameters = new TokenValidationParameters
        {
            NameClaimType = JwtRegisteredClaimNames.Sub,
            RoleClaimType = "roles",
            ClockSkew = TimeSpan.FromMinutes(2)
        };

        // Map custom role claim
        opts.MapInboundClaims = false; // disable Microsoft claim name mapping

        opts.Events = new JwtBearerEvents
        {
            OnAuthenticationFailed = ctx =>
            {
                var logger = ctx.HttpContext.RequestServices
                    .GetRequiredService<ILogger<Program>>();
                logger.LogWarning(ctx.Exception, "JWT authentication failed");
                return Task.CompletedTask;
            },
            OnTokenValidated = ctx =>
            {
                var userId = ctx.Principal?.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;
                ctx.HttpContext.Items["UserId"] = userId;
                return Task.CompletedTask;
            }
        };
    });
```

## Common Follow-up Questions

- What is `MapInboundClaims = false` and why should you set it?
- How do you refresh expired JWT tokens in a SPA + ASP.NET Core API setup?
- What is a JWKS (JSON Web Key Set) endpoint and how does `Authority` use it?
- How do you validate additional custom claims in a JWT (e.g., tenant ID)?
- What is the difference between `JwtRegisteredClaimNames.Sub` and `ClaimTypes.NameIdentifier`?

## Common Mistakes / Pitfalls

- **Setting `ValidateIssuerSigningKey = false`** — disables signature verification entirely; any tampered token is accepted. Never do this in production.
- **Using a short/weak HMAC secret** — HMAC-SHA256 is only as strong as the secret key. Use at least 32 cryptographically random bytes.
- **Not setting `MapInboundClaims = false`** — by default, ASP.NET Core's JWT handler maps standard claim names (e.g., `sub` → `ClaimTypes.NameIdentifier`). This can cause confusion when expecting `sub` in claims.
- **Ignoring `ClockSkew`** — the default is 5 minutes; tokens look expired in between server clock drift. Keep `ClockSkew` small (1–5 minutes) rather than setting it to zero.
- **Storing JWT in `localStorage`** — exposes it to XSS attacks. Prefer `httpOnly` secure cookies for web apps, or short-lived tokens with refresh rotation.

## References

- [Microsoft Learn — JWT bearer authentication](https://learn.microsoft.com/aspnet/core/security/authentication/jwt-authn?view=aspnetcore-8.0)
- [Microsoft Learn — TokenValidationParameters](https://learn.microsoft.com/dotnet/api/microsoft.identitymodel.tokens.tokenvalidationparameters)
- [jwt.io — JWT debugger and documentation](https://jwt.io/)
- [Andrew Lock — JWT authentication in ASP.NET Core](https://andrewlock.net/tag/jwt/) (verify URL)
- [RFC 7519 — JSON Web Token](https://datatracker.ietf.org/doc/html/rfc7519)
