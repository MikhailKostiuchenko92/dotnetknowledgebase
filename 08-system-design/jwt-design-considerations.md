# JWT Design Considerations

**Category:** System Design / Security
**Difficulty:** Middle
**Tags:** `jwt`, `json-web-token`, `claims`, `token`, `authentication`, `signing`, `expiry`

## Question

> What are JWTs and what design decisions matter when using them in a distributed system? What are the common security pitfalls? How do you handle token revocation?

- What is the difference between signing (`JWS`) and encrypting (`JWE`) a JWT?
- How do you invalidate a JWT before it expires?

## Short Answer

A JWT (JSON Web Token) is a base64url-encoded, signed (and optionally encrypted) token that carries claims about the bearer, allowing stateless authentication without a server-side session store. Key design decisions are: choosing the right signing algorithm (RS256/ES256 over HS256 for multi-service systems), setting an appropriate expiry (15–60 minutes for access tokens), minimising the payload to avoid performance overhead, and planning for revocation — since JWTs are stateless, invalidation requires either a short expiry paired with refresh tokens or a distributed deny-list.

## Detailed Explanation

### JWT Structure

A JWT is three base64url-encoded sections separated by dots:

```
header.payload.signature

eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9      ← header (algorithm + type)
.eyJzdWIiOiJ1c2VyLTEyMyIsInJvbGUiOiJBZG1pbiIsImV4cCI6MTcwMDAwMDAwMH0  ← payload (claims)
.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c  ← signature
```

**Header** (always check `alg`):
```json
{ "alg": "RS256", "typ": "JWT" }
```

**Payload** (registered + custom claims):
```json
{
  "sub": "user-123",           // subject (user ID)
  "iss": "https://auth.example.com",  // issuer
  "aud": "my-api",             // audience
  "exp": 1700000000,           // expiry (Unix timestamp)
  "iat": 1699996400,           // issued at
  "jti": "uuid-v4",            // JWT ID (for revocation)
  "email": "alice@example.com",
  "roles": ["Admin"]
}
```

**Signature**: `RSASHA256(base64url(header) + "." + base64url(payload), privateKey)`.

### Signing Algorithm Choices

| Algorithm | Type | Key | Use case |
|-----------|------|-----|---------|
| **HS256** | Symmetric | Shared secret | Single-service (same service signs + validates) |
| **RS256** | Asymmetric RSA | Private/public key pair | Multi-service: auth server signs, APIs validate with public key |
| **ES256** | Asymmetric ECDSA | Private/public key pair | Same as RS256 but smaller signatures (preferred for mobile/IoT) |

> **Warning:** Never use `alg: none` — a historical vulnerability where servers accepted unsigned tokens. Explicitly allowlist algorithms; never trust the `alg` header blindly.

**Why asymmetric (RS256/ES256) for microservices?**
- Auth server holds the private key. Resource APIs only need the public key (from JWKS endpoint).
- Compromise of a resource API doesn't expose the signing key.
- Any service can validate a token without calling the auth server.

```csharp
// Validate JWT signature using public key from JWKS endpoint
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://auth.example.com"; // fetches /.well-known/openid-configuration + JWKS
        options.Audience  = "orders-api";
        options.TokenValidationParameters = new()
        {
            ValidateIssuer           = true,
            ValidateAudience         = true,
            ValidateLifetime         = true,     // checks exp claim
            ValidateIssuerSigningKey = true,     // checks signature
            ClockSkew                = TimeSpan.FromSeconds(30), // allow slight clock drift
        };
    });
```

### Access Token + Refresh Token Pattern

Short-lived access tokens limit exposure if stolen. Refresh tokens allow re-issue without re-login:

```
Access token:  15–60 minutes (short-lived, stateless)
Refresh token: 7–30 days     (long-lived, stored server-side = can be revoked)

Flow:
1. User logs in → auth server returns access_token + refresh_token
2. Client sends access_token in Authorization: Bearer header
3. API validates access_token signature — no server call needed
4. When access_token expires, client sends refresh_token to /token/refresh
5. Auth server looks up refresh_token in DB, validates, issues new access_token
6. To log out / revoke: delete refresh_token from DB → no new access tokens issued
```

```csharp
// Refresh token entity — stored in database (NOT stateless)
public sealed class RefreshToken
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public Guid UserId { get; init; }
    public string Token { get; init; } = Guid.NewGuid().ToString("N");
    public DateTimeOffset ExpiresAt { get; init; }
    public DateTimeOffset? RevokedAt { get; set; }
    public bool IsExpired  => DateTimeOffset.UtcNow > ExpiresAt;
    public bool IsRevoked  => RevokedAt.HasValue;
    public bool IsActive   => !IsExpired && !IsRevoked;
}
```

### Token Revocation Strategies

JWTs are stateless — the server cannot invalidate them before expiry. Strategies to work around this:

**1. Short expiry** (simplest): 5–15 minutes. Minimal revocation window.

**2. Refresh token revocation**: revoke the refresh token. Access tokens stay valid until expiry (up to 15 min), then can't be renewed.

**3. JWT deny-list** (Redis cache): store `jti` (JWT ID) of revoked tokens; check on every request:

```csharp
// Custom validator checks if jti is in deny list
public sealed class JtiDenyListValidator(IDistributedCache cache) :
    ISecurityTokenValidator  // Polly/custom middleware approach
{
    public ClaimsPrincipal ValidateToken(string token, TokenValidationParameters tvp,
        out SecurityToken validatedToken)
    {
        // ... standard validation ...
        var jti = principal.FindFirstValue(JwtRegisteredClaimNames.Jti);
        if (jti is not null && cache.GetString($"revoked-jti:{jti}") is not null)
            throw new SecurityTokenException("Token has been revoked");

        return principal;
    }
}
```

**Deny-list trade-off**: adds a cache lookup on every request (fast with Redis, ~1ms), but removes statelessness benefit. For high-security scenarios (healthcare, finance), this is acceptable.

### Payload Design Considerations

- **Minimal claims**: the JWT is sent on every request. 5kB base claims → 5kB of HTTP overhead per call.
- **No sensitive data in payload**: the payload is only base64url-encoded, not encrypted. Anyone with the token can decode it. Never put passwords, PII, or secrets in the payload (use JWE for encryption).
- **Avoid stale data**: role/permission claims baked at login time go stale if the user's permissions change. Options: short expiry, or query permissions from DB and add to claims at validation time via a `ClaimsTransformation`.

```csharp
// Enrich claims with fresh data from DB at request time
public sealed class FreshPermissionTransformer(IPermissionService perms) :
    IClaimsTransformation
{
    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var userId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (userId is null) return principal;

        var permissions = await perms.GetPermissionsAsync(Guid.Parse(userId));
        var identity = new ClaimsIdentity();
        identity.AddClaims(permissions.Select(p => new Claim("permission", p)));
        principal.AddIdentity(identity);
        return principal;
    }
}
```

### Issuing JWTs in .NET

```csharp
using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.Tokens;

public string IssueAccessToken(User user, SigningCredentials signing)
{
    var claims = new[]
    {
        new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
        new Claim(JwtRegisteredClaimNames.Email, user.Email),
        new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        new Claim(ClaimTypes.Role, user.Role),
    };

    var token = new JwtSecurityToken(
        issuer:   "https://auth.example.com",
        audience: "orders-api",
        claims:   claims,
        notBefore: DateTime.UtcNow,
        expires:   DateTime.UtcNow.AddMinutes(15),   // short-lived
        signingCredentials: signing);                 // RS256 private key

    return new JwtSecurityTokenHandler().WriteToken(token);
}
```

## Common Follow-up Questions

- How does OpenID Connect (OIDC) extend OAuth 2.0 to include identity (`id_token`)?
- What is the difference between `aud` (audience) claim and API gateway routing?
- How do you securely store JWTs in a browser (cookie vs localStorage)?
- What is token introspection and when should you use it instead of self-validation?
- How does a microservice know the JWKS public key has rotated without a restart?

## Common Mistakes / Pitfalls

- **Algorithm confusion attack (`alg: none`)**: always validate the `alg` claim and allowlist allowed algorithms explicitly; never accept `none`.
- **Long-lived access tokens**: a 24-hour access token is essentially a session cookie without revocation. Use 15–60 minutes.
- **Storing sensitive data in the payload**: the JWT body is base64-encoded, not encrypted. Any middleware, proxy, or log that captures the token can decode it.
- **Not validating `aud` (audience) claim**: a JWT issued for `payments-api` should not be accepted by `orders-api`. Validate audience to prevent token replay across services.
- **Not rotating refresh tokens**: each refresh should issue a *new* refresh token and invalidate the old one (refresh token rotation). This limits the window of a stolen refresh token.
- **Ignoring clock skew**: if the issuing server and validating server clocks differ by >0s, tokens may immediately appear expired. Set `ClockSkew = TimeSpan.FromSeconds(30)`.

## References

- [JWT specification — RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519)
- [JWT security best practices — IETF BCP](https://www.rfc-editor.org/rfc/rfc8725)
- [Authentication and JWT in ASP.NET Core — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/)
- [JwtBearer middleware — Microsoft.AspNetCore.Authentication.JwtBearer](https://learn.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.authentication.jwtbearer)
- [See: authentication-vs-authorization.md](./authentication-vs-authorization.md)
- [See: oauth2-flows-compared.md](./oauth2-flows-compared.md)
