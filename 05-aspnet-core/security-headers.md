# Security Headers in ASP.NET Core

**Category:** ASP.NET Core / Security Best Practices
**Difficulty:** 🟡 Middle
**Tags:** `CSP`, `X-Frame-Options`, `X-Content-Type-Options`, `security-headers`, `NWebSec`, `middleware`

## Question

> What HTTP security headers should every ASP.NET Core API or web application set? How do you add them via custom middleware or a library like NWebSec?

## Short Answer

Key security headers: **`X-Content-Type-Options: nosniff`** (prevents MIME sniffing), **`X-Frame-Options: DENY`** (prevents clickjacking), **`Content-Security-Policy`** (prevents XSS by allowlisting sources), **`Referrer-Policy`** (controls referrer data leakage), and **`Permissions-Policy`** (restricts browser API access). `HSTS` is covered by `UseHsts()`. Add them via a custom middleware, `app.Use()` callback, or the NWebSec library.

## Detailed Explanation

### Security headers overview

| Header | Protects Against | Recommended Value |
|---|---|---|
| `X-Content-Type-Options` | MIME type sniffing attacks | `nosniff` |
| `X-Frame-Options` | Clickjacking (frame injection) | `DENY` or `SAMEORIGIN` |
| `Content-Security-Policy` | XSS, data injection | (see below) |
| `Referrer-Policy` | Referrer data leakage | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | Excessive browser API access | `camera=(), microphone=(), geolocation=()` |
| `X-XSS-Protection` | Legacy XSS filter (IE) | `0` (disable — CSP replaces this) |
| `Cross-Origin-Embedder-Policy` | Spectre isolation | `require-corp` |
| `Cross-Origin-Opener-Policy` | Cross-origin access | `same-origin` |

### Custom middleware approach

```csharp
app.Use((ctx, next) =>
{
    var headers = ctx.Response.Headers;

    // Prevent MIME sniffing
    headers.XContentTypeOptions = "nosniff";

    // Prevent clickjacking
    headers.XFrameOptions = "DENY";

    // Control referrer information
    headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");

    // Disable legacy XSS filter (CSP is the modern replacement)
    headers.Append("X-XSS-Protection", "0");

    // Restrict browser features
    headers.Append("Permissions-Policy", "camera=(), microphone=(), geolocation=()");

    // Remove server identification
    ctx.Response.Headers.Remove("X-Powered-By");
    ctx.Response.Headers.Remove("Server"); // ASP.NET Core: configure in Kestrel opts

    return next(ctx);
});
```

### Removing `Server` header

```csharp
builder.WebHost.ConfigureKestrel(opts =>
    opts.AddServerHeader = false); // removes "Server: Kestrel" header
```

### Content Security Policy (CSP)

CSP is the most complex and powerful header. It defines which sources browsers trust for scripts, styles, images, etc.:

```csharp
// Strict CSP for API endpoints (no HTML content)
headers.Append("Content-Security-Policy",
    "default-src 'none'; frame-ancestors 'none'");

// CSP for web apps with React/Blazor
headers.Append("Content-Security-Policy",
    "default-src 'self'; " +
    "script-src 'self' 'nonce-{nonce}'; " + // use nonce per request for inline scripts
    "style-src 'self' 'unsafe-inline'; " +   // SPA often requires this
    "img-src 'self' data: https:; " +
    "connect-src 'self' https://api.myapp.com; " +
    "frame-ancestors 'none'; " +
    "upgrade-insecure-requests;");
```

For nonce-based CSP (recommended for inline scripts):

```csharp
app.Use(async (ctx, next) =>
{
    var nonce = Convert.ToBase64String(RandomNumberGenerator.GetBytes(16));
    ctx.Items["csp-nonce"] = nonce;
    ctx.Response.Headers.Append("Content-Security-Policy",
        $"script-src 'nonce-{nonce}' 'strict-dynamic'; object-src 'none'; base-uri 'none'");
    await next(ctx);
});
```

### NWebSec library

```bash
dotnet add package NWebsec.AspNetCore.Middleware
```

```csharp
app.UseXContentTypeOptions();  // X-Content-Type-Options: nosniff
app.UseXfo(opts => opts.Deny()); // X-Frame-Options: DENY
app.UseReferrerPolicy(opts => opts.StrictOriginWhenCrossOrigin());
app.UseXXssProtection(opts => opts.Disabled()); // disable IE XSS filter
app.UseNoCacheHttpHeaders(); // Cache-Control: no-cache, no-store, must-revalidate

// CSP
app.UseCsp(opts => opts
    .DefaultSources(s => s.Self())
    .ScriptSources(s => s.Self().CustomSources("cdn.jsdelivr.net"))
    .StyleSources(s => s.Self().UnsafeInline())
    .ImageSources(s => s.Self().DataScheme())
    .FrameAncestors(s => s.None()));
```

## Code Example

```csharp
// Security headers middleware as an extension method
public static class SecurityHeadersMiddlewareExtensions
{
    public static IApplicationBuilder UseSecurityHeaders(
        this IApplicationBuilder app, bool isApi = false) =>
        app.Use((ctx, next) =>
        {
            var h = ctx.Response.Headers;
            h.XContentTypeOptions = "nosniff";
            h.XFrameOptions = "DENY";
            h.Append("Referrer-Policy", "strict-origin-when-cross-origin");
            h.Append("X-XSS-Protection", "0");
            h.Append("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=()");

            var csp = isApi
                ? "default-src 'none'; frame-ancestors 'none'"
                : "default-src 'self'; frame-ancestors 'none'; upgrade-insecure-requests;";
            h.Append("Content-Security-Policy", csp);

            return next(ctx);
        });
}

// Usage
app.UseSecurityHeaders(isApi: true);
```

## Common Follow-up Questions

- How do you test security headers? (tools: `securityheaders.com`, `nmap --script http-security-headers`)
- How do you implement nonce-based CSP for server-rendered Razor views?
- What is `Cross-Origin-Resource-Policy` and when does it matter?
- How does `X-Frame-Options: DENY` relate to `Content-Security-Policy: frame-ancestors 'none'`?
- How do you add security headers to static files served by `UseStaticFiles()`?

## Common Mistakes / Pitfalls

- **Setting `X-XSS-Protection: 1; mode=block`** — this was a legacy IE header that modern browsers ignore; enabling it in some browsers can actually cause security issues. Set to `0` to disable it explicitly.
- **Not testing CSP before deploying** — a misconfigured CSP breaks your site. Use `Content-Security-Policy-Report-Only` header first to collect violations without blocking.
- **Using `unsafe-inline` for scripts in CSP** — `unsafe-inline` negates most XSS protection. Use nonces or `strict-dynamic` instead.
- **Adding security headers in `UseStaticFiles`** — static files bypass most middleware. Add a custom middleware before `UseStaticFiles` or configure headers directly in `StaticFileOptions`.
- **Not removing `Server` and `X-Powered-By` headers** — these headers reveal technology stack to attackers. Remove them via `Kestrel.AddServerHeader = false` and custom middleware.

## References

- [Microsoft Learn — ASP.NET Core security headers](https://learn.microsoft.com/aspnet/core/security/?view=aspnetcore-8.0) (verify URL)
- [securityheaders.com — Scan tool](https://securityheaders.com/)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [MDN — Content Security Policy](https://developer.mozilla.org/docs/Web/HTTP/CSP)
- [NWebSec GitHub](https://github.com/NWebsec/NWebsec)
