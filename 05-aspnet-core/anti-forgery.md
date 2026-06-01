# Anti-Forgery (CSRF) in ASP.NET Core

**Category:** ASP.NET Core / Authentication & Authorization
**Difficulty:** 🟡 Middle
**Tags:** `CSRF`, `anti-forgery`, `IAntiforgery`, `ValidateAntiForgeryToken`, `SameSite`, `SPA`

## Question

> What is CSRF and how does ASP.NET Core protect against it? How does `[ValidateAntiForgeryToken]` work, and how do you handle anti-forgery validation in SPAs?

## Short Answer

**CSRF (Cross-Site Request Forgery)** tricks an authenticated user's browser into making unintended requests to your site using the user's credentials (e.g., cookies). ASP.NET Core uses the **double-submit cookie pattern**: a random token is embedded in both a cookie and the form/header; on submit, the server verifies both match. `[ValidateAntiForgeryToken]` applies this check to MVC actions. For SPAs (React, Angular), read the token from the `XSRF-TOKEN` cookie and send it back in the `X-XSRF-TOKEN` request header — the server validates the header token against the cookie.

## Detailed Explanation

### Why CSRF is possible

```
1. User logs into bank.com → receives session cookie
2. User visits evil.com
3. evil.com auto-submits a hidden form to bank.com/transfer
4. Browser includes the bank.com session cookie automatically
5. Bank server processes the transfer (victim authenticated!)
```

The browser's same-origin policy prevents reading responses cross-origin, but it does NOT prevent sending requests.

### The double-submit cookie pattern

```
Server generates random token:
  - Stores in encrypted anti-forgery cookie (HttpOnly=false for SPA reads)
  - Embeds in HTML form hidden field <input type="hidden" value="token" />

On form submit:
  - Browser sends both: cookie value + form field value
  - Server decrypts cookie, compares with form field → must match
  - Attacker on evil.com can't read the cookie (SameSite/HttpOnly) → can't forge valid token
```

### MVC (Razor Pages / server-rendered forms)

```csharp
// Razor form — token auto-injected by Tag Helper
<form method="post" asp-action="Transfer">
    @Html.AntiForgeryToken() // or use <form asp-antiforgery="true">
    ...
</form>

// Controller — validate the token
[HttpPost]
[ValidateAntiForgeryToken]
public IActionResult Transfer(TransferRequest req) { ... }
```

Enable globally for all POST actions:

```csharp
builder.Services.AddControllersWithViews(opts =>
    opts.Filters.Add(new AutoValidateAntiforgeryTokenAttribute()));
```

### SPA (React, Angular, Blazor WebAssembly)

For API-consumed by SPAs using cookies:

**Step 1 — Server writes the token to a readable cookie:**

```csharp
app.Use((ctx, next) =>
{
    var antiforgery = ctx.RequestServices.GetRequiredService<IAntiforgery>();
    var tokens = antiforgery.GetAndStoreTokens(ctx);
    ctx.Response.Cookies.Append("XSRF-TOKEN", tokens.RequestToken!,
        new CookieOptions { HttpOnly = false }); // readable by JavaScript
    return next(ctx);
});
```

**Step 2 — Client reads the cookie and sends the header:**

```typescript
// Angular does this automatically via HttpClientXsrfModule
// React:
const getToken = () => document.cookie
    .split('; ')
    .find(row => row.startsWith('XSRF-TOKEN='))
    ?.split('=')[1];

fetch('/api/transfer', {
    method: 'POST',
    headers: { 'X-XSRF-TOKEN': getToken() ?? '' },
    body: JSON.stringify(data)
});
```

**Step 3 — Server validates the header:**

```csharp
builder.Services.AddAntiforgery(opts =>
{
    opts.HeaderName = "X-XSRF-TOKEN"; // match client header
    opts.Cookie.Name = "XSRF-TOKEN";
    opts.Cookie.HttpOnly = false;     // must be readable by JS
});
```

### When CSRF protection is NOT needed

- **API endpoints using JWT Bearer tokens only** — Bearer tokens must be explicitly set by JavaScript; they cannot be sent by the browser automatically. Use `[IgnoreAntiforgeryToken]` on these endpoints.
- **Endpoints protected with `SameSite=Strict` cookies exclusively** — strict same-site cookies are never sent cross-origin.

```csharp
[HttpPost("api/products")]
[IgnoreAntiforgeryToken] // JWT-only endpoint — no CSRF risk
public Task<IActionResult> Create(CreateProductRequest req) { ... }
```

### `IAntiforgery` service

```csharp
public class AntiForgeryController(IAntiforgery antiforgery) : ControllerBase
{
    [HttpGet("csrf-token")]
    [IgnoreAntiforgeryToken]
    public IActionResult GetToken()
    {
        var tokens = antiforgery.GetAndStoreTokens(HttpContext);
        return Ok(new { token = tokens.RequestToken });
    }

    [HttpPost("transfer")]
    public async Task<IActionResult> Transfer(TransferRequest req)
    {
        await antiforgery.ValidateRequestAsync(HttpContext); // manual validation
        // ...
    }
}
```

## Code Example

```csharp
// Full setup for a hybrid app (MVC forms + SPA endpoints)
builder.Services.AddAntiforgery(opts =>
{
    opts.HeaderName = "X-XSRF-TOKEN";
    opts.Cookie.Name = "__Host-XSRF";  // __Host- prefix for extra security
    opts.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    opts.Cookie.SameSite = SameSiteMode.Strict;
    opts.Cookie.HttpOnly = false; // SPA must read it
});

builder.Services.AddControllersWithViews(opts =>
    opts.Filters.Add(new AutoValidateAntiforgeryTokenAttribute()));

var app = builder.Build();

// Inject XSRF token on every request (single-page app approach)
app.Use(async (ctx, next) =>
{
    if (ctx.Request.Path.StartsWithSegments("/api"))
    {
        await next(ctx);
        return;
    }

    var antiforgery = ctx.RequestServices.GetRequiredService<IAntiforgery>();
    antiforgery.GetAndStoreTokens(ctx); // writes cookie
    await next(ctx);
});
```

## Common Follow-up Questions

- Why doesn't CSRF protection apply to JWT Bearer API endpoints?
- How does `SameSite=Strict` or `SameSite=Lax` reduce CSRF risk without anti-forgery tokens?
- What is the `__Host-` cookie prefix and what security properties does it enforce?
- How does Angular's `HttpClientXsrfModule` handle the anti-forgery token automatically?
- Can you use `[AutoValidateAntiforgeryToken]` on API controllers that also accept `application/json`?

## Common Mistakes / Pitfalls

- **Setting anti-forgery cookie to `HttpOnly = true`** — the JavaScript SPA cannot read an `HttpOnly` cookie; the token must be readable by the client script.
- **Applying `[ValidateAntiForgeryToken]` to JSON API endpoints without configuring the header** — by default, ASP.NET Core looks for the form token, not the header; set `opts.HeaderName` to accept the token from a header.
- **Forgetting `[IgnoreAntiforgeryToken]` on API endpoints that only use Bearer tokens** — if `AutoValidateAntiforgeryTokenAttribute` is global, your JSON API endpoints break unless explicitly excluded.
- **Using CSRF protection as the sole defense against unauthorized mutations** — CSRF only prevents cross-site attacks; always combine with authorization (`[Authorize]`, policies).
- **Not using `SameSite` cookies alongside anti-forgery** — `SameSite=Lax/Strict` provides a first layer of CSRF defense; anti-forgery adds a second layer for `Lax` (which still allows cross-site GETs).

## References

- [Microsoft Learn — Anti-request forgery](https://learn.microsoft.com/aspnet/core/security/anti-request-forgery?view=aspnetcore-8.0)
- [Microsoft Learn — Configure anti-forgery for SPAs](https://learn.microsoft.com/aspnet/core/security/anti-request-forgery?view=aspnetcore-8.0#javascript-ajax-and-spas)
- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
- [MDN — SameSite cookies](https://developer.mozilla.org/docs/Web/HTTP/Headers/Set-Cookie/SameSite)
