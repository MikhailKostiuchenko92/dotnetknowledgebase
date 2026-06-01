# Cookie Authentication in ASP.NET Core

**Category:** ASP.NET Core / Authentication & Authorization
**Difficulty:** 🟡 Middle
**Tags:** `cookie-authentication`, `sliding-expiration`, `data-protection`, `SameSite`, `anti-forgery`, `session`

## Question

> How does cookie authentication work in ASP.NET Core? What is sliding expiration, and how does the Data Protection API protect the cookie?

## Short Answer

Cookie authentication stores a `ClaimsPrincipal` serialized into an encrypted, signed cookie using the **Data Protection API** (`IDataProtector`). On each request, the middleware decrypts the cookie and populates `HttpContext.User`. **Sliding expiration** extends the cookie's lifetime on each request if it's within the renewal threshold (default: `ExpireTimeSpan / 2`), so active users stay logged in. The Data Protection API uses a key ring managed by ASP.NET Core; sharing keys across load-balanced nodes requires a shared key store (Azure Blob, Redis, file share).

## Detailed Explanation

### How the cookie is protected

1. `SignInAsync` serializes `ClaimsPrincipal` → `AuthenticationTicket`
2. `IDataProtector.Protect()` encrypts + signs the ticket bytes with AES-256-GCM and HMAC
3. The protected bytes are Base64Url-encoded → cookie value
4. On each request: cookie → `IDataProtector.Unprotect()` → `AuthenticationTicket` → `ClaimsPrincipal`

If the Data Protection key is changed or lost, all existing cookies are invalidated (users logged out).

### Basic setup

```csharp
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(opts =>
    {
        opts.Cookie.Name = ".MyApp.Auth";
        opts.Cookie.HttpOnly = true;          // inaccessible to JavaScript
        opts.Cookie.SecurePolicy = CookieSecurePolicy.Always;  // HTTPS only
        opts.Cookie.SameSite = SameSiteMode.Lax;  // CSRF protection
        opts.LoginPath = "/account/login";
        opts.LogoutPath = "/account/logout";
        opts.AccessDeniedPath = "/account/forbidden";
        opts.ExpireTimeSpan = TimeSpan.FromHours(8);
        opts.SlidingExpiration = true;        // renew if accessed in last 4h
    });
```

### Sign in / sign out

```csharp
// Sign in
var claims = new[] { new Claim(ClaimTypes.Name, user.Email), new Claim(ClaimTypes.NameIdentifier, user.Id) };
var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
var principal = new ClaimsPrincipal(identity);

await HttpContext.SignInAsync(
    CookieAuthenticationDefaults.AuthenticationScheme,
    principal,
    new AuthenticationProperties { IsPersistent = true, ExpiresUtc = DateTimeOffset.UtcNow.AddDays(30) });

// Sign out
await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
```

### Sliding expiration explained

```
ExpireTimeSpan = 8h
RenewalThreshold = ExpireTimeSpan / 2 = 4h

Request at t=0h  → cookie set, expires at t=8h
Request at t=5h  → past half-life threshold → renewed, expires at t=13h
Request at t=6h  → still in renewed window → no re-issue (cookie already extended)
No request for 8h → cookie expired → user logged out
```

### `SameSite` and CSRF

| `SameSite` | Cookie sent with | CSRF protection |
|---|---|---|
| `Strict` | Same-site navigation only | ✅ Strong |
| `Lax` | Same-site + top-level cross-site GETs | ✅ Reasonable |
| `None` | All requests (requires Secure) | ❌ None (use anti-forgery) |

Use `Lax` for most web apps. For APIs called by other origins, use JWT (Bearer token) rather than cookies.

### Data Protection key storage for multi-node deployments

```csharp
// Azure Blob + Azure Key Vault
builder.Services.AddDataProtection()
    .PersistKeysToAzureBlobStorage(new Uri("https://..."), new DefaultAzureCredential())
    .ProtectKeysWithAzureKeyVault(new Uri("https://..."), new DefaultAzureCredential())
    .SetApplicationName("MyApp"); // must match across all nodes
```

### Validating the cookie principal against a database

Use `OnValidatePrincipal` to check if the user still exists or has been modified:

```csharp
opts.Events = new CookieAuthenticationEvents
{
    OnValidatePrincipal = async ctx =>
    {
        var userService = ctx.HttpContext.RequestServices.GetRequiredService<IUserService>();
        var userId = ctx.Principal?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var user = userId is not null ? await userService.FindByIdAsync(userId) : null;

        if (user is null || user.SecurityStamp != ctx.Principal?.FindFirst("securityStamp")?.Value)
        {
            ctx.RejectPrincipal(); // invalidate the cookie
            await ctx.HttpContext.SignOutAsync();
        }
    }
};
```

## Code Example

```csharp
// Complete cookie auth with Data Protection and validation events
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/shared/keys"))
    .SetApplicationName("MyApp")
    .SetDefaultKeyLifetime(TimeSpan.FromDays(90));

builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(opts =>
    {
        opts.Cookie.HttpOnly = true;
        opts.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        opts.Cookie.SameSite = SameSiteMode.Lax;
        opts.ExpireTimeSpan = TimeSpan.FromHours(8);
        opts.SlidingExpiration = true;
        opts.LoginPath = "/auth/login";

        opts.Events = new CookieAuthenticationEvents
        {
            OnSigningIn = ctx =>
            {
                // Can enrich ClaimsPrincipal before cookie is written
                return Task.CompletedTask;
            },
            OnValidatePrincipal = SecurityStampValidator.ValidatePrincipalAsync
            // Uses ASP.NET Core Identity's security stamp validation
        };
    });
```

## Common Follow-up Questions

- How do you force all existing sessions to expire (e.g., after a password change)?
- What is a security stamp and how does `SecurityStampValidator` use it?
- How do cookie auth and JWT auth differ for SPA (React/Angular) applications?
- How does the Data Protection key ring rotation affect active sessions?
- What is `AuthenticationProperties.IsPersistent` and how does it differ from `ExpireTimeSpan`?

## Common Mistakes / Pitfalls

- **Not sharing Data Protection keys across load-balanced nodes** — each node generates its own keys; cookies encrypted by node A cannot be decrypted by node B, causing random logouts.
- **Using `SameSite = None` without HTTPS** — browsers reject `SameSite=None` on non-HTTPS connections; always pair it with `SecurePolicy = CookieSecurePolicy.Always`.
- **Setting very long `ExpireTimeSpan` with `SlidingExpiration = true`** — if a user's account is deleted, the cookie remains valid until natural expiry unless you add `OnValidatePrincipal` validation.
- **Storing large claims in the cookie** — cookies have a 4KB limit; large `ClaimsPrincipal` objects (many roles, enriched claims) overflow this limit, causing authentication failures.
- **Confusing `IsPersistent` with `ExpireTimeSpan`** — `IsPersistent = true` makes the cookie persist after the browser closes (sets absolute expiry); `SlidingExpiration` extends it on activity. Both are independent.

## References

- [Microsoft Learn — Cookie authentication](https://learn.microsoft.com/aspnet/core/security/authentication/cookie?view=aspnetcore-8.0)
- [Microsoft Learn — Data Protection API](https://learn.microsoft.com/aspnet/core/security/data-protection/introduction?view=aspnetcore-8.0)
- [Microsoft Learn — SameSite cookies](https://learn.microsoft.com/aspnet/core/security/samesite?view=aspnetcore-8.0)
- [Andrew Lock — Cookie auth in depth](https://andrewlock.net/tag/cookie-authentication/) (verify URL)
