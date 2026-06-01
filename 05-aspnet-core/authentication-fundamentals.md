# Authentication Fundamentals in ASP.NET Core

**Category:** ASP.NET Core / Authentication & Authorization
**Difficulty:** 🟢 Junior
**Tags:** `authentication`, `IAuthenticationService`, `scheme`, `challenge`, `forbid`, `ClaimsPrincipal`

## Question

> What is the difference between authentication and authorization in ASP.NET Core? How does the authentication pipeline work?

## Short Answer

**Authentication** answers "who are you?" — it establishes the caller's identity (a `ClaimsPrincipal`). **Authorization** answers "are you allowed?" — it decides whether the authenticated identity can access a resource. In ASP.NET Core, `UseAuthentication()` middleware calls `IAuthenticationService.AuthenticateAsync()` for the default scheme and attaches the resulting `ClaimsPrincipal` to `HttpContext.User`. `UseAuthorization()` then checks policies/roles against that user.

## Detailed Explanation

### The three core authentication operations

| Operation | `IAuthenticationService` method | When triggered |
|---|---|---|
| Authenticate | `AuthenticateAsync(scheme)` | On every request; populates `HttpContext.User` |
| Challenge | `ChallengeAsync(scheme)` | When a resource requires authentication; 401 or redirect-to-login |
| Forbid | `ForbidAsync(scheme)` | When an authenticated user lacks permission; 403 |

### Authentication pipeline order

```
UseRouting()
UseAuthentication()   ← reads token/cookie, sets HttpContext.User
UseAuthorization()    ← checks [Authorize] policies against HttpContext.User
MapControllers() / MapGet(...)
```

> **Critical:** `UseAuthentication()` must come **before** `UseAuthorization()` and before any middleware that reads `HttpContext.User`.

### Authentication schemes

A scheme is a named configuration of an authentication handler:

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer()           // scheme name: "Bearer"
    .AddCookie();             // scheme name: "Cookies"
```

Multiple schemes can coexist. The default scheme (first argument to `AddAuthentication`) is used when no scheme is explicitly specified.

### `ClaimsPrincipal` and claims

```csharp
// After authentication, HttpContext.User is a ClaimsPrincipal
var userId = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
var email  = context.User.FindFirst(ClaimTypes.Email)?.Value;
var roles  = context.User.FindAll(ClaimTypes.Role).Select(c => c.Value);
bool isAuth = context.User.Identity?.IsAuthenticated ?? false;
```

### Authentication result

`AuthenticateAsync` returns an `AuthenticateResult`:
- **Success** — `result.Principal` populated, `result.Succeeded = true`
- **NoResult** — handler cannot determine identity (no token/cookie present)
- **Failure** — invalid credentials; contains `result.Failure` exception

### Challenge vs Forbid

```
Request → [Authorize]
  ├── User not authenticated → ChallengeAsync → 401 (API) or redirect to /login (cookie)
  └── User authenticated, lacks permission → ForbidAsync → 403
```

## Code Example

```csharp
// Program.cs — multi-scheme setup
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts =>
    {
        opts.Authority = "https://login.myidp.com";
        opts.Audience = "my-api";
    })
    .AddCookie(CookieAuthenticationDefaults.AuthenticationScheme, opts =>
    {
        opts.LoginPath = "/account/login";
        opts.AccessDeniedPath = "/account/forbidden";
        opts.SlidingExpiration = true;
    });

builder.Services.AddAuthorization();

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
```

```csharp
// Manual challenge from a controller
[ApiController]
public class AccountController(IAuthenticationService auth) : ControllerBase
{
    [HttpGet("test-auth")]
    public async Task<IActionResult> TestAuth()
    {
        // Manually authenticate with a specific scheme
        var result = await auth.AuthenticateAsync(
            HttpContext, JwtBearerDefaults.AuthenticationScheme);

        if (!result.Succeeded)
        {
            await auth.ChallengeAsync(
                HttpContext, JwtBearerDefaults.AuthenticationScheme, null);
            return new EmptyResult();
        }

        return Ok(new { User = result.Principal?.Identity?.Name });
    }
}
```

## Common Follow-up Questions

- What is the difference between `[AllowAnonymous]` and not applying `[Authorize]`?
- How do you configure a fallback policy that requires authentication for all endpoints by default?
- What is `IClaimsTransformation` and when would you use it?
- How does the authentication middleware handle multiple schemes on the same endpoint?
- What does `HttpContext.User.Identity?.IsAuthenticated` return before `UseAuthentication()` runs?

## Common Mistakes / Pitfalls

- **Placing `UseAuthorization()` before `UseAuthentication()`** — `HttpContext.User` is not populated when authorization runs; all requests appear unauthenticated.
- **Confusing 401 and 403** — 401 means "not authenticated" (challenge); 403 means "authenticated but forbidden". ASP.NET Core respects this via `ChallengeAsync`/`ForbidAsync`.
- **Not setting a default authentication scheme** — without a default, `[Authorize]` without an explicit scheme doesn't know which handler to call and throws at runtime.
- **Using `HttpContext.User` in middleware before `UseAuthentication()`** — returns an anonymous identity with `IsAuthenticated = false`.
- **Expecting `AddAuthentication()` to also protect endpoints** — `AddAuthentication` only registers the pipeline; you must add `[Authorize]` or a fallback policy to actually restrict access.

## References

- [Microsoft Learn — Overview of ASP.NET Core authentication](https://learn.microsoft.com/aspnet/core/security/authentication/?view=aspnetcore-8.0)
- [Microsoft Learn — Authentication vs authorization](https://learn.microsoft.com/aspnet/core/security/authorization/introduction?view=aspnetcore-8.0)
- [Microsoft — IAuthenticationService source](https://github.com/dotnet/aspnetcore/blob/main/src/Security/Authentication/Core/src/IAuthenticationService.cs)
- [Andrew Lock — Auth in ASP.NET Core](https://andrewlock.net/tag/authentication/) (verify URL)
