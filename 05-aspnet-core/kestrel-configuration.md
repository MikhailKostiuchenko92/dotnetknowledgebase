# Kestrel Configuration in ASP.NET Core

**Category:** ASP.NET Core / Hosting
**Difficulty:** 🔴 Senior
**Tags:** `kestrel`, `https`, `http2`, `http3`, `QUIC`, `IIS`, `in-process`, `limits`

## Question

> How do you configure Kestrel's limits, HTTPS, HTTP/2, and HTTP/3? What are the key differences between Kestrel running standalone vs. behind IIS in-process?

## Short Answer

Kestrel is ASP.NET Core's built-in, cross-platform HTTP server. You configure it via `builder.WebHost.ConfigureKestrel(...)` or the `Kestrel` section in `appsettings.json`, setting per-connection and per-request limits, TLS certificates, and endpoint bindings. HTTP/2 is supported over TLS by default; HTTP/3 (QUIC) requires explicit opt-in. IIS in-process hosting replaces Kestrel with `IISHttpServer` for the HTTP layer but preserves the ASP.NET Core pipeline above it.

## Detailed Explanation

### Kestrel endpoint binding

Endpoints are declared in code or configuration:

```csharp
builder.WebHost.ConfigureKestrel(serverOptions =>
{
    // Bind HTTP on port 5000
    serverOptions.Listen(IPAddress.Any, 5000);

    // Bind HTTPS on port 5001 with inline cert
    serverOptions.Listen(IPAddress.Any, 5001, listenOptions =>
    {
        listenOptions.UseHttps("cert.pfx", "password");
    });
});
```

Or via `appsettings.json`:
```json
{
  "Kestrel": {
    "Endpoints": {
      "Http":  { "Url": "http://0.0.0.0:5000" },
      "Https": { "Url": "https://0.0.0.0:5001" }
    }
  }
}
```

### TLS / HTTPS configuration

| Approach | Use case |
|---|---|
| Dev cert (`dotnet dev-certs`) | Local development |
| `.pfx` / `.pem` file | On-premise deployments |
| `ICertificateLoader` / `ServerCertificateSelector` | SNI — different certs per hostname |
| Certificate store (Windows) | Windows Server deployments |

**Certificate hot-reload (.NET 6+):** Kestrel watches cert files for changes and reloads them without restart if configured with `reloadOnChange: true` in `appsettings.json`.

### HTTP/2

HTTP/2 over TLS (h2) is enabled by default. Requirements:

- TLS 1.2+ with an ALPN-negotiated cipher.
- Connection: TLS on the same port as HTTP/2 traffic.

Unencrypted HTTP/2 (h2c) requires:
```csharp
listenOptions.Protocols = HttpProtocols.Http2;   // no TLS, useful for internal gRPC
```

### HTTP/3 (QUIC) — .NET 8+

```csharp
listenOptions.Protocols = HttpProtocols.Http1AndHttp2AndHttp3;
listenOptions.UseHttps();
```

- Requires `Microsoft.AspNetCore.Server.Kestrel.Transport.Quic` (included in .NET 8 meta-package on supported platforms).
- Requires Windows 11/Server 2022 or Linux with `libmsquic`.
- Browser clients discover HTTP/3 via the `alt-svc: h3=":443"` response header.

### Connection and request limits

```csharp
serverOptions.Limits.MaxConcurrentConnections = 100;
serverOptions.Limits.MaxConcurrentUpgradedConnections = 100; // WebSocket
serverOptions.Limits.MaxRequestBodySize = 30 * 1024 * 1024;  // 30 MB
serverOptions.Limits.RequestHeadersTimeout = TimeSpan.FromSeconds(30);
serverOptions.Limits.KeepAliveTimeout = TimeSpan.FromMinutes(2);

// Per-endpoint overrides
serverOptions.ConfigureEndpointDefaults(listenOptions =>
    listenOptions.Protocols = HttpProtocols.Http1AndHttp2);
```

### IIS in-process vs out-of-process

| | In-Process (`InProcess`) | Out-of-Process (`OutOfProcess`) |
|---|---|---|
| HTTP server | `IISHttpServer` (IIS I/O) | Kestrel (proxied via IIS) |
| Performance | Higher (no loopback proxy) | Lower (extra hop) |
| Shared memory | Yes | No |
| Process model | Runs inside `w3wp.exe` | Separate process |
| Error recovery | IIS restart restarts app | IIS can recycle w3wp without killing app |
| Default since | ASP.NET Core 2.2 | Pre-2.2 only option |

In-process hosting is selected via:
```xml
<AspNetCoreHostingModel>InProcess</AspNetCoreHostingModel>
```

### Unix socket / named pipe (containerized scenarios)

```csharp
serverOptions.ListenUnixSocket("/tmp/app.sock");
```

Useful when NGINX or another reverse proxy communicates over a Unix socket — eliminates TCP overhead.

## Code Example

```csharp
// Program.cs — production-grade Kestrel setup

builder.WebHost.ConfigureKestrel((context, serverOptions) =>
{
    var kestrelConfig = context.Configuration.GetSection("Kestrel");

    // Apply all limits from appsettings.json (Kestrel:Limits section)
    serverOptions.Configure(kestrelConfig);

    // Override: HTTP/1 + HTTP/2 on port 5000 (plain, internal gRPC)
    serverOptions.Listen(IPAddress.Loopback, 5000, listenOptions =>
    {
        listenOptions.Protocols = HttpProtocols.Http2;
    });

    // HTTPS with HTTP/1.1 + HTTP/2 + HTTP/3 on port 5001
    serverOptions.Listen(IPAddress.Any, 5001, listenOptions =>
    {
        listenOptions.Protocols = HttpProtocols.Http1AndHttp2AndHttp3;
        listenOptions.UseHttps(httpsOptions =>
        {
            // SNI: pick cert based on incoming server name
            httpsOptions.ServerCertificateSelector = (_, name) =>
                name is "api.example.com"
                    ? CertificateLoader.LoadFromStoreCert("api.example.com", "My", StoreLocation.CurrentUser, true)
                    : null; // fall back to default cert
        });
    });

    // Limits
    serverOptions.Limits.MaxConcurrentConnections = 1000;
    serverOptions.Limits.MaxRequestBodySize = 10 * 1024 * 1024; // 10 MB
    serverOptions.Limits.Http2.MaxStreamsPerConnection = 100;
    serverOptions.Limits.Http2.HeaderTableSize = 4096;
    serverOptions.Limits.Http2.InitialConnectionWindowSize = 131_072;  // 128 KB
});
```

```json
// appsettings.Production.json — Kestrel limits via config
{
  "Kestrel": {
    "Limits": {
      "MaxConcurrentConnections": 1000,
      "MaxRequestBodySize": 10485760,
      "RequestHeadersTimeout": "00:00:30"
    },
    "Endpoints": {
      "Https": {
        "Url": "https://*:443",
        "Certificate": {
          "Path": "/certs/server.pfx",
          "Password": "${CERT_PASSWORD}"
        }
      }
    }
  }
}
```

## Common Follow-up Questions

- How does Kestrel compare to NGINX as a reverse proxy — when would you put NGINX in front of Kestrel?
- How do you enable HTTP/3 in production on Linux?
- What are the security implications of setting `MaxRequestBodySize = null` (unlimited)?
- How does IIS in-process hosting affect `HttpContext.Connection.RemoteIpAddress`?
- How does Kestrel handle connection draining during graceful shutdown?

## Common Mistakes / Pitfalls

- **Not setting `MaxRequestBodySize`** — without a limit, large payloads can exhaust memory; the default is 30 MB but you should set it explicitly per endpoint for upload routes.
- **Enabling h2c (cleartext HTTP/2) publicly** — HTTP/2 without TLS is appropriate only for internal service-to-service (e.g., gRPC behind a mesh); never expose it on a public endpoint.
- **Forgetting `alt-svc` header for HTTP/3** — browsers will only upgrade to HTTP/3 if the server advertises it; Kestrel adds this header automatically but proxies may strip it.
- **Trusting `X-Forwarded-For` without `UseForwardedHeaders`** — behind a reverse proxy, raw `RemoteIpAddress` is the proxy's IP. Always use `ForwardedHeadersMiddleware` with trusted proxy IPs.
- **Storing cert passwords in `appsettings.json`** — use environment variables, User Secrets, or Azure Key Vault references instead.

## References

- [Microsoft Learn — Configure Kestrel web server](https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel?view=aspnetcore-8.0)
- [Microsoft Learn — HTTP/2 in Kestrel](https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel/http2?view=aspnetcore-8.0)
- [Microsoft Learn — HTTP/3 with Kestrel](https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel/http3?view=aspnetcore-8.0)
- [Microsoft Learn — IIS in-process vs out-of-process hosting](https://learn.microsoft.com/aspnet/core/host-and-deploy/iis/in-process-hosting?view=aspnetcore-8.0)
- [Microsoft Learn — Kestrel connection limits](https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel/options?view=aspnetcore-8.0)
