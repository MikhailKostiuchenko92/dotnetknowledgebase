# OAuth 2.0 Flows Compared

**Category:** System Design / Security
**Difficulty:** Middle
**Tags:** `oauth2`, `authorization-code`, `pkce`, `client-credentials`, `openid-connect`, `flows`

## Question

> What are the main OAuth 2.0 authorization flows? When should you use each one? How does PKCE improve the Authorization Code flow for public clients?

- What is the difference between OAuth 2.0 and OpenID Connect?
- How does a .NET service-to-service call authenticate using OAuth 2.0?

## Short Answer

OAuth 2.0 defines several grant types (flows) for different client scenarios: Authorization Code + PKCE for user-facing apps (browser/mobile), Client Credentials for machine-to-machine, and Refresh Token for obtaining new access tokens without re-login. OpenID Connect (OIDC) is an identity layer on top of OAuth 2.0 that adds an `id_token` (JWT about the user), enabling authentication; OAuth 2.0 alone only handles authorization (access to resources). In .NET, `Microsoft.Identity.Web` and `IdentityModel.AspNetCore` handle most of this automatically.

## Detailed Explanation

### OAuth 2.0: The Problem It Solves

Before OAuth, granting a third-party app access to your resources meant giving it your password. OAuth 2.0 solves this with **delegated authorization**: the user grants permission to the third party via a consent screen; the third party receives an access token scoped to specific permissions — never the user's credentials.

### The Four Main Flows

#### 1. Authorization Code + PKCE (Browser/Mobile Apps)

The most secure flow for any client where the user is present. PKCE (Proof Key for Code Exchange) eliminates the risk of authorization code interception for public clients (which cannot safely store a `client_secret`):

```
Browser/App                Auth Server             API
     │                          │                    │
     │─── 1. Redirect to /auth with code_challenge ──│
     │       (code_verifier hashed, stored locally)  │
     │                          │                    │
     │◄── 2. User consents ──────                    │
     │       Redirect back with authorization_code   │
     │                          │                    │
     │─── 3. POST /token ────────                    │
     │       { code, code_verifier }  (proves ownership)
     │◄── 4. access_token + refresh_token ──────────  │
     │                          │                    │
     │─── 5. GET /orders ───────────────────────────►│
     │       Authorization: Bearer <access_token>    │
```

**Use when**: SPAs, mobile apps, desktop apps, any flow with a real user.

```csharp
// ASP.NET Core web app consuming an API on behalf of a user (OIDC + Authorization Code)
builder.Services.AddAuthentication(OpenIdConnectDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApp(builder.Configuration.GetSection("AzureAd"))
    .EnableTokenAcquisitionToCallDownstreamApi(["https://graph.microsoft.com/.default"])
    .AddInMemoryTokenCaches();
```

#### 2. Client Credentials (Machine-to-Machine)

No user involved. The client (a backend service) authenticates using its own `client_id` + `client_secret` (or mTLS certificate) and receives an access token scoped to service-level permissions:

```
Service A                Auth Server              Service B
    │                         │                       │
    │─── POST /token ──────────                       │
    │    grant_type=client_credentials                │
    │    client_id=svc-a, client_secret=***           │
    │    scope=orders:read                            │
    │◄── access_token ─────────                       │
    │                                                 │
    │─── GET /internal/orders ───────────────────────►│
    │    Authorization: Bearer <access_token>         │
```

**Use when**: microservice-to-microservice calls, background jobs, CLI tools, batch processors.

```csharp
// Service A calling Service B with client credentials (IdentityModel)
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("orders-service", client =>
    {
        client.TokenEndpoint = "https://auth.example.com/connect/token";
        client.ClientId      = "svc-reporting";
        client.ClientSecret  = builder.Configuration["Auth:ClientSecret"];
        client.Scope         = "orders:read";
    });

builder.Services.AddHttpClient<IOrdersApiClient, OrdersApiClient>()
    .AddClientCredentialsTokenHandler("orders-service");
    // Token is cached and auto-refreshed by the token management library
```

#### 3. Refresh Token Grant

Not a primary flow — used to obtain a new access token when the current one expires, without re-prompting the user:

```
Client                    Auth Server
   │                          │
   │─── POST /token ───────────
   │    grant_type=refresh_token
   │    refresh_token=<stored-token>
   │◄── new access_token + new refresh_token
   │    (rotate refresh token)
```

Refresh tokens are long-lived and must be stored securely. Compromise requires immediate revocation.

#### 4. Implicit Flow (Deprecated)

Returned access tokens directly in the URL fragment — no code exchange. **Never use for new applications.** Superseded by Authorization Code + PKCE, which is equally browser-friendly but far more secure (tokens aren't exposed in URLs or referrer headers).

### OAuth 2.0 vs OpenID Connect

| | OAuth 2.0 | OpenID Connect (OIDC) |
|--|----------|----------------------|
| Purpose | **Authorization** — access to resources | **Authentication** — verify user identity |
| Token returned | `access_token` | `access_token` + **`id_token`** |
| `id_token` | Not defined | JWT containing user identity claims |
| Scopes | Resource-specific (e.g., `orders:read`) | `openid`, `profile`, `email` |
| Standard | RFC 6749 | Built on OAuth 2.0 |
| Question answered | "Can this app access resource Y?" | "Who is this user?" |

**Rule of thumb**: if you're implementing "Login with Google" — that's OIDC. If you're issuing tokens for API access — that's OAuth 2.0.

### Token Endpoint Security

For confidential clients (server-side apps), authenticate to the token endpoint with:

1. **Client Secret Basic**: `Authorization: Basic base64(client_id:client_secret)` (most common)
2. **Client Secret Post**: `client_id` + `client_secret` in POST body
3. **Private Key JWT** (`client_assertion`): sign a JWT with your private key — strongest; no shared secret
4. **mTLS** (mutual TLS): client certificate — used for high-security B2B scenarios

```csharp
// Private Key JWT client authentication with IdentityModel
var clientAssertion = CreateClientAssertionJwt(clientId, tokenEndpoint, privateKey);

var request = new ClientCredentialsTokenRequest
{
    Address      = tokenEndpoint,
    ClientId     = clientId,
    ClientAssertion = new ClientAssertion
    {
        Type  = OidcConstants.ClientAssertionTypes.JwtBearer,
        Value = clientAssertion,
    },
    Scope = "orders:read",
};
```

### Scope Design

Scopes define what an access token is allowed to do. Design them as `resource:action`:

```
orders:read      — read all orders
orders:write     — create/update orders
orders:delete    — delete orders
payments:process — initiate payments
admin:users      — manage user accounts
```

The auth server includes consented scopes in the token; the API validates them on every request:

```csharp
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("CanReadOrders",  p => p.RequireClaim("scope", "orders:read"));
    options.AddPolicy("CanWriteOrders", p => p.RequireClaim("scope", "orders:write"));
});
```

> **Warning:** Do not use OAuth 2.0 Client Credentials to identify specific *users* — it identifies the *service*. For service calls on behalf of a user (token exchange), use the On-Behalf-Of (OBO) flow or pass the user context as a separate claim.

## Code Example

```csharp
// Client Credentials cache + auto-renewal with Duende.IdentityModel
using Duende.AccessTokenManagement;

var builder = WebApplication.CreateBuilder(args);

// Register token management (caches and auto-refreshes tokens)
builder.Services.AddDistributedMemoryCache();
builder.Services.AddClientCredentialsTokenManagement()
    .AddClient("catalog", client =>
    {
        client.TokenEndpoint = "https://auth.example.com/connect/token";
        client.ClientId      = "inventory-svc";
        client.ClientSecret  = builder.Configuration["Auth:Secret"];
        client.Scope         = "catalog:read";
    });

// Named HttpClient that automatically attaches the access token
builder.Services.AddHttpClient<ICatalogClient, CatalogHttpClient>(http =>
    http.BaseAddress = new Uri("https://catalog-api"))
    .AddClientCredentialsTokenHandler("catalog");

// ICatalogClient calls now automatically include "Authorization: Bearer <token>"
// Token is cached until 60s before expiry, then silently renewed
```

## Common Follow-up Questions

- What is the Device Authorization Grant and when is it used?
- How does the On-Behalf-Of (OBO) flow work in microservices?
- How do you validate that an `access_token` was issued for your specific API (audience validation)?
- How do you implement single sign-out (backchannel logout) with OIDC?
- What is token introspection and when is it preferable to self-validation?

## Common Mistakes / Pitfalls

- **Using Implicit flow** for new SPAs: Authorization Code + PKCE is supported in all modern browsers and is vastly more secure.
- **Storing client secrets in frontend code**: mobile apps and SPAs are public clients; they must use PKCE (no client secret). Anyone can decompile a mobile app and extract a hard-coded secret.
- **Not validating `aud` (audience) on access tokens**: a token issued for `payments-api` must not be accepted by `orders-api`; always check the audience claim.
- **Putting user PII in access tokens**: access tokens may be logged by proxies, API gateways, and load balancers. Put PII only in the `id_token` (short-lived, used client-side only) or don't include it at all.
- **Not rotating refresh tokens**: each use of a refresh token should issue a new one and invalidate the old one, limiting the exposure window of a stolen refresh token.

## References

- [OAuth 2.0 specification — RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)
- [PKCE — RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636)
- [OpenID Connect Core specification](https://openid.net/specs/openid-connect-core-1_0.html)
- [OAuth 2.0 Security Best Practices — RFC 9700](https://www.rfc-editor.org/rfc/rfc9700) (verify URL)
- [Duende.AccessTokenManagement for .NET](https://docs.duendesoftware.com/foss/accesstokenmanagement/)
- [See: jwt-design-considerations.md](./jwt-design-considerations.md)
- [See: authentication-vs-authorization.md](./authentication-vs-authorization.md)
