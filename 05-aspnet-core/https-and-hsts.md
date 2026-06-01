# HTTPS and HSTS in ASP.NET Core

**Category:** ASP.NET Core / Security Best Practices
**Difficulty:** 🟢 Junior
**Tags:** `HTTPS`, `HSTS`, `UseHttpsRedirection`, `UseHsts`, `X-Forwarded-Proto`, `reverse-proxy`

## Question

> How do you configure HTTPS redirection and HSTS in ASP.NET Core? What special considerations apply when running behind a reverse proxy?

## Short Answer

`UseHttpsRedirection()` redirects HTTP requests to HTTPS (default 307 temporary). `UseHsts()` adds the `Strict-Transport-Security` header telling browsers to only use HTTPS for future requests (for `max-age` seconds, default 30 days). Both should be **disabled in development** (already the default) and **when running behind a TLS-terminating reverse proxy** — the proxy handles TLS, so the app only sees HTTP; use `ForwardedHeaders` middleware to trust the proxy's `X-Forwarded-Proto` header instead.

## Detailed Explanation

### Default setup

```csharp
var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();           // adds HSTS header
}

app.UseHttpsRedirection(); // redirects HTTP → HTTPS
```

### `UseHsts` and HSTS header

```
Strict-Transport-Security: max-age=2592000; includeSubDomains
```

Configuration:

```csharp
builder.Services.AddHsts(opts =>
{
    opts.MaxAge = TimeSpan.FromDays(365); // 1 year (recommended minimum for production)
    opts.IncludeSubDomains = true;
    opts.Preload = true; // required for HSTS preload list submission
});
```

> **Warning:** HSTS preload means browsers cache "HTTPS only" for `max-age` period even if the server changes. Test thoroughly before setting `Preload = true` and long `MaxAge`.

### HTTPS redirection configuration

```csharp
builder.Services.AddHttpsRedirection(opts =>
{
    opts.RedirectStatusCode = StatusCodes.Status301MovedPermanently; // permanent for production
    opts.HttpsPort = 443;
});
```

### Reverse proxy considerations

When running behind nginx, Azure Load Balancer, or Kubernetes ingress, TLS terminates at the proxy:

```
Client → [HTTPS] → nginx proxy → [HTTP] → ASP.NET Core app
```

The app receives HTTP, so `UseHttpsRedirection` would cause an infinite loop. Instead, trust the `X-Forwarded-Proto: https` header from the trusted proxy:

```csharp
builder.Services.Configure<ForwardedHeadersOptions>(opts =>
{
    opts.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    opts.KnownNetworks.Clear();
    opts.KnownProxies.Clear();
    // Or specifically: opts.KnownProxies.Add(IPAddress.Parse("10.0.0.1"));
});

var app = builder.Build();
app.UseForwardedHeaders(); // must come FIRST — before HTTPS redirect
app.UseHttpsRedirection(); // now correctly reads X-Forwarded-Proto
```

In Azure App Service and containers, set `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` environment variable to automatically trust Azure/AKS proxy headers.

### Development certificates

```bash
dotnet dev-certs https --trust  # creates and trusts self-signed cert for localhost
```

### Request scheme after forwarded headers

```csharp
// Verify HTTPS after forwarded headers are applied
app.Use((ctx, next) =>
{
    var scheme = ctx.Request.Scheme; // "https" after UseForwardedHeaders
    Console.WriteLine($"Scheme: {scheme}");
    return next(ctx);
});
```

## Code Example

```csharp
// Production-grade HTTPS + HSTS + reverse proxy setup
builder.Services.AddHsts(opts =>
{
    opts.MaxAge = TimeSpan.FromDays(365);
    opts.IncludeSubDomains = true;
    opts.Preload = false; // set true only after testing
});

builder.Services.AddHttpsRedirection(opts =>
{
    opts.RedirectStatusCode = StatusCodes.Status301MovedPermanently;
    opts.HttpsPort = 443;
});

builder.Services.Configure<ForwardedHeadersOptions>(opts =>
{
    opts.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    // In Kubernetes: trust pod network range
    opts.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 8));
});

var app = builder.Build();

app.UseForwardedHeaders(); // always first

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
    app.UseHttpsRedirection();
}
```

## Common Follow-up Questions

- What is the HSTS preload list and how do you get added to it?
- What happens if `UseHsts` is applied to a development environment with a self-signed certificate?
- How do you disable HTTPS redirection for health check endpoints (`/health`) without disabling it globally?
- What is the difference between 301 (Permanent) and 307 (Temporary) redirects for HTTPS?
- How do you handle `X-Forwarded-For` for IP-based rate limiting behind a proxy?

## Common Mistakes / Pitfalls

- **Using `UseHsts` in development** — development certificates are self-signed; HSTS causes browsers to refuse connections with invalid certs, requiring manual HSTS header reset in the browser.
- **Not calling `UseForwardedHeaders()` before `UseHttpsRedirection()`** — without it, `HttpContext.Request.IsHttps` remains `false` even when the proxy forwarded over HTTPS, causing redirect loops.
- **Trusting all IPs as proxies** — clearing `KnownNetworks` and `KnownProxies` without any restrictions trusts all `X-Forwarded-For` headers, enabling IP spoofing attacks.
- **Setting HSTS `MaxAge` to a very long value before testing** — once HSTS is cached in a browser, you cannot revert to HTTP until the `max-age` expires. Start with a short value and increase.
- **Forgetting HSTS only works after the first HTTPS response** — on the first visit, the browser may still try HTTP. HSTS preload solves this by shipping the domain in the browser's hardcoded list.

## References

- [Microsoft Learn — HTTPS in ASP.NET Core](https://learn.microsoft.com/aspnet/core/security/enforcing-ssl?view=aspnetcore-8.0)
- [Microsoft Learn — ForwardedHeaders middleware](https://learn.microsoft.com/aspnet/core/host-and-deploy/proxy-load-balancer?view=aspnetcore-8.0)
- [HSTS preload list](https://hstspreload.org/)
- [MDN — Strict-Transport-Security](https://developer.mozilla.org/docs/Web/HTTP/Headers/Strict-Transport-Security)
