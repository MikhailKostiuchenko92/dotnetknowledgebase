# Advanced Content Security Policy in ASP.NET Core

**Category:** ASP.NET Core / Security Best Practices
**Difficulty:** 🔴 Senior
**Tags:** `CSP`, `Content-Security-Policy`, `nonce`, `violation-reporting`, `script-src`, `middleware`

## Question

> How do you implement an effective Content Security Policy (CSP) in ASP.NET Core? Explain CSP directives, nonce-based inline script protection, and violation reporting.

## Short Answer

**CSP** is an HTTP response header that instructs browsers to restrict what resources (scripts, styles, images, frames) a page may load. It is the primary browser-enforced defense against XSS after sanitization fails. In ASP.NET Core you emit it via middleware or the `NWebsec.AspNetCore.Middleware` library. **Nonces** allow specific inline `<script>` or `<style>` blocks to run without needing `'unsafe-inline'`, which would defeat XSS protection. **Violation reporting** (`report-uri` / `report-to`) sends policy violations to a logging endpoint so you can tune the policy before enforcing it.

## Detailed Explanation

### Why CSP matters

Even if you escape all output, a XSS payload can arrive through third-party scripts, DOM-based XSS, or browser extension injection. CSP tells the browser: "Only load scripts from these sources." A properly configured CSP is the **last line of defense** in the browser.

### CSP directive cheat sheet

| Directive | Controls |
|---|---|
| `default-src` | Fallback for all fetch directives |
| `script-src` | JavaScript sources |
| `style-src` | CSS sources |
| `img-src` | Image sources |
| `connect-src` | `fetch`, `XHR`, `WebSocket`, `EventSource` |
| `frame-src` | `<iframe>`, `<frame>` sources |
| `font-src` | Font files |
| `object-src 'none'` | Disable Flash/plugins (always set this) |
| `base-uri 'self'` | Restrict `<base href>` |
| `form-action 'self'` | Restrict where forms can POST |
| `upgrade-insecure-requests` | Auto-upgrade HTTP sub-resources to HTTPS |

### Nonce-based inline scripts

Using `'unsafe-inline'` in `script-src` allows any inline script, defeating XSS protection. **Nonces** are the modern alternative:

```html
<!-- Server generates a unique nonce per request -->
<script nonce="r@nd0m_base64_nonce">
  // This script is allowed because it has the matching nonce
  console.log("Trusted inline script");
</script>
```

```
Content-Security-Policy: script-src 'self' 'nonce-r@nd0m_base64_nonce';
```

The browser only executes `<script>` tags whose `nonce` attribute matches the value in the CSP header. XSS-injected scripts don't know the nonce.

### Implementing CSP with nonces in ASP.NET Core middleware

```csharp
// CspMiddleware.cs
public sealed class CspMiddleware(RequestDelegate next, ILogger<CspMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var nonce = Convert.ToBase64String(RandomNumberGenerator.GetBytes(16));

        // Store nonce so Razor can inject it into <script nonce="...">
        context.Items["csp-nonce"] = nonce;

        context.Response.OnStarting(() =>
        {
            var csp = $"default-src 'self'; " +
                      $"script-src 'self' 'nonce-{nonce}'; " +
                      $"style-src 'self' 'nonce-{nonce}'; " +
                      $"img-src 'self' data: https:; " +
                      $"object-src 'none'; " +
                      $"base-uri 'self'; " +
                      $"form-action 'self'; " +
                      $"report-uri /csp-report";

            context.Response.Headers.Append("Content-Security-Policy", csp);
            return Task.CompletedTask;
        });

        await next(context);
    }
}

// Registration
app.UseMiddleware<CspMiddleware>();
```

```csharp
// Helper to access nonce in Razor views
public static class HttpContextExtensions
{
    public static string GetCspNonce(this HttpContext context) =>
        context.Items.TryGetValue("csp-nonce", out var nonce) ? (string)nonce! : "";
}
```

```html
<!-- _Layout.cshtml -->
<script nonce="@Context.GetCspNonce()">
    // Trusted inline script
</script>
```

### Report-Only mode — tune before enforcing

```csharp
// Report violations but don't block — use this first!
context.Response.Headers.Append(
    "Content-Security-Policy-Report-Only",
    "default-src 'self'; script-src 'self' 'nonce-{nonce}'; report-uri /csp-report");
```

### Violation reporting endpoint

```csharp
app.MapPost("/csp-report", async (HttpContext context) =>
{
    var body = await new StreamReader(context.Request.Body).ReadToEndAsync();
    var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
    logger.LogWarning("CSP violation: {Report}", body);
    return Results.NoContent();
});
```

The browser POSTs a JSON body like:

```json
{
  "csp-report": {
    "blocked-uri": "https://evil.com/script.js",
    "violated-directive": "script-src 'self'",
    "document-uri": "https://example.com/page"
  }
}
```

### `report-to` (modern replacement for `report-uri`)

```
Report-To: {"group":"csp","max_age":86400,"endpoints":[{"url":"/csp-report"}]}
Content-Security-Policy: default-src 'self'; report-to csp;
```

### Using NWebsec library

```bash
dotnet add package NWebsec.AspNetCore.Middleware
```

```csharp
app.UseCsp(opts => opts
    .DefaultSources(s => s.Self())
    .ScriptSources(s => s.Self().Nonce())
    .StyleSources(s => s.Self().Nonce())
    .ImageSources(s => s.Self().CustomSources("data:", "https:"))
    .ObjectSources(s => s.None()));
```

## Code Example

```csharp
// Program.cs — complete nonce-based CSP setup
builder.Services.AddSingleton<CspMiddleware>();
// ...
app.UseMiddleware<CspMiddleware>();

// Violation endpoint
app.MapPost("/csp-report", async (HttpContext ctx) =>
{
    var body = await new StreamReader(ctx.Request.Body).ReadToEndAsync();
    ctx.RequestServices.GetRequiredService<ILogger<Program>>()
        .LogWarning("CSP violation: {Body}", body);
    return Results.NoContent();
}).AllowAnonymous();
```

```html
<!-- _Layout.cshtml: inject nonce into all trusted inline scripts/styles -->
@inject IHttpContextAccessor HttpContextAccessor
@{
    var nonce = HttpContextAccessor.HttpContext!.GetCspNonce();
}
<script nonce="@nonce" src="/js/app.js"></script>
<style nonce="@nonce">/* app styles */</style>
```

## Common Follow-up Questions

- What is the difference between `nonce-` and `hash-` based CSP and when would you use a hash instead of a nonce?
- How does `'strict-dynamic'` change how browsers evaluate nonces with dynamically loaded scripts?
- What CSP directives specifically protect against clickjacking vs XSS?
- How do you write CSP tests or automated checks to ensure the header is present and correct?
- What is the `Permissions-Policy` header and how does it relate to CSP?

## Common Mistakes / Pitfalls

- **Using `'unsafe-inline'` in `script-src`** — completely defeats XSS protection; use nonces or hashes instead.
- **Using the same nonce across requests** — nonces must be **cryptographically random per request**; a static nonce is equivalent to `'unsafe-inline'`.
- **Forgetting `object-src 'none'`** — allows Flash/plugin injection; always explicitly set it to `'none'`.
- **Not starting with Report-Only mode** — switching to enforcement on a live site without monitoring will break functionality; always tune with `Content-Security-Policy-Report-Only` first.
- **Including CDN URLs in `script-src` without subresource integrity (SRI)** — a compromised CDN can serve malicious scripts; use `integrity` attributes alongside CSP.

## References

- [MDN — Content-Security-Policy](https://developer.mozilla.org/docs/Web/HTTP/Headers/Content-Security-Policy)
- [CSP Level 3 Specification](https://www.w3.org/TR/CSP3/)
- [OWASP — Content Security Policy Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html)
- [NWebsec library](https://github.com/NWebsec/NWebsec)
- [Scott Helme — CSP Guide](https://scotthelme.co.uk/content-security-policy-an-introduction/)
