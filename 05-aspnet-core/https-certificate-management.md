# HTTPS Certificate Management in ASP.NET Core

**Category:** ASP.NET Core / Security Best Practices
**Difficulty:** 🟡 Middle
**Tags:** `dev-certs`, `Let's-Encrypt`, `Kestrel`, `cert-hot-reload`, `X509Certificate2`, `pfx`

## Question

> How do you manage HTTPS certificates in ASP.NET Core? Walk through development certs, Let's Encrypt automation, and Kestrel certificate hot-reload.

## Short Answer

In **development**, `dotnet dev-certs https --trust` creates a self-signed localhost certificate and trusts it in the OS/browser store. In **production**, use a certificate from a public CA (Let's Encrypt via `certbot` or `Certes`, or a commercial CA). Kestrel loads the certificate at startup; for zero-downtime rotation without restart, ASP.NET Core 5+ supports **hot-reload** of TLS certificates by storing the path/thumbprint in configuration rather than loading it directly.

## Detailed Explanation

### Development certificates

```bash
# Create and trust a self-signed localhost cert
dotnet dev-certs https --trust

# Inspect
dotnet dev-certs https --check --trust

# Clean and re-create (if expired or corrupt)
dotnet dev-certs https --clean
dotnet dev-certs https --trust
```

The cert is stored:
- **Windows:** Windows Certificate Store (Personal → Trusted Root CA)
- **macOS:** Keychain
- **Linux:** No trust store — configure each browser manually

On Linux, use `mkcert` as an alternative.

### Kestrel HTTPS configuration (production)

#### From a `.pfx` file

```csharp
builder.WebHost.ConfigureKestrel(opts =>
{
    opts.ListenAnyIP(443, listenOpts =>
    {
        listenOpts.UseHttps("path/to/certificate.pfx", "pfx-password");
    });
});
```

#### From configuration (`appsettings.json`) — recommended for hot-reload

```json
// appsettings.Production.json
{
  "Kestrel": {
    "Certificates": {
      "Default": {
        "Path": "/certs/mycert.pfx",
        "Password": "${KESTREL_CERT_PASSWORD}" // loaded from env/vault
      }
    }
  }
}
```

```csharp
builder.WebHost.ConfigureKestrel(opts =>
    opts.Configure(builder.Configuration.GetSection("Kestrel")));
```

#### From Windows Certificate Store

```csharp
builder.WebHost.ConfigureKestrel(opts =>
{
    opts.ListenAnyIP(443, listenOpts =>
    {
        listenOpts.UseHttps(httpsOpts =>
        {
            var store = new X509Store(StoreName.My, StoreLocation.CurrentUser);
            store.Open(OpenFlags.ReadOnly);
            var cert = store.Certificates
                .Find(X509FindType.FindByThumbprint, "CERT_THUMBPRINT", validOnly: true)
                .OfType<X509Certificate2>()
                .FirstOrDefault()
                ?? throw new InvalidOperationException("Certificate not found");
            httpsOpts.ServerCertificate = cert;
        });
    });
});
```

### Certificate hot-reload (.NET 6+)

When using the `appsettings.json` Kestrel configuration, Kestrel monitors the config for changes. Update the cert file and path, and new connections pick up the new cert without a restart:

```csharp
builder.WebHost.ConfigureKestrel(opts =>
{
    opts.Configure(builder.Configuration.GetSection("Kestrel"), reloadOnChange: true);
    // reloadOnChange: true enables hot-reload of cert config
});
```

> **Note:** Existing TLS connections are not disrupted; only new connections use the updated certificate.

### Let's Encrypt with `Certes` (programmatic)

```bash
dotnet add package Certes
```

```csharp
// Simplified — production use requires challenge handler (HTTP-01 or DNS-01)
var acme = new AcmeContext(WellKnownServers.LetsEncryptV2);
var account = await acme.NewAccount("admin@example.com", termsOfServiceAgreed: true);
var order = await acme.NewOrder(new[] { "example.com" });
// ... complete HTTP-01 challenge, then:
var privateKey = KeyFactory.NewKey(KeyAlgorithm.RS256);
var cert = await order.Generate(new CsrInfo { CommonName = "example.com" }, privateKey);
var pfxBuilder = cert.ToPfx(privateKey);
var pfx = pfxBuilder.Build("example.com", "");
await File.WriteAllBytesAsync("/certs/example.pfx", pfx);
```

For production, `nreco/le-acme-core` or Docker with `Certbot` + volume mount are more common.

### SNI (Server Name Indication) — multiple certs per port

```csharp
builder.WebHost.ConfigureKestrel(opts =>
{
    opts.ListenAnyIP(443, listenOpts =>
    {
        listenOpts.UseHttps(httpsOpts =>
        {
            httpsOpts.ServerCertificateSelector = (connectionContext, hostName) => hostName switch
            {
                "api.example.com" => LoadCert("api"),
                "app.example.com" => LoadCert("app"),
                _ => LoadCert("default")
            };
        });
    });
});
```

## Code Example

```csharp
// Production Kestrel config with hot-reload and SNI
builder.WebHost.ConfigureKestrel(opts =>
{
    opts.Configure(builder.Configuration.GetSection("Kestrel"), reloadOnChange: true);
    opts.ConfigureHttpsDefaults(https =>
    {
        https.SslProtocols = SslProtocols.Tls12 | SslProtocols.Tls13;
        https.ClientCertificateMode = ClientCertificateMode.NoCertificate;
    });
});
```

```json
// appsettings.Production.json
{
  "Kestrel": {
    "Endpoints": {
      "Https": {
        "Url": "https://*:443",
        "Certificate": {
          "Path": "/certs/current.pfx",
          "KeyPath": null,
          "Password": null
        }
      }
    }
  }
}
```

## Common Follow-up Questions

- How do you rotate a certificate in Kubernetes without restarting the ASP.NET Core pod?
- What is the `dotnet dev-certs` trust mechanism on Linux and why doesn't it update browser trust?
- How does Kestrel's `ServerCertificateSelector` enable SNI for multi-tenant deployments?
- What is the minimum TLS version you should configure, and how do you disable TLS 1.0/1.1?
- How do you use a PEM certificate (not PFX) with Kestrel?

## Common Mistakes / Pitfalls

- **Not running `dotnet dev-certs https --trust`** — the certificate is created but not trusted by the browser; HTTPS connections fail with `NET::ERR_CERT_AUTHORITY_INVALID`.
- **Hardcoding PFX passwords in `appsettings.json`** — always load PFX passwords from environment variables or a vault, not from committed config files.
- **Not enabling `reloadOnChange: true`** — without it, Kestrel does not pick up new certificates; a restart is required for cert renewal.
- **Using `SslProtocols.Default`** — this may include TLS 1.0/1.1 on older OS versions. Explicitly set `SslProtocols.Tls12 | SslProtocols.Tls13`.
- **Forgetting that dev certs expire after 1 year** — run `dotnet dev-certs https --check` periodically; expired dev certs cause subtle HTTPS failures that resemble network errors.

## References

- [Microsoft Learn — HTTPS in ASP.NET Core](https://learn.microsoft.com/aspnet/core/security/enforcing-ssl?view=aspnetcore-8.0)
- [Microsoft Learn — Kestrel certificate configuration](https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel/cert-configuration?view=aspnetcore-8.0)
- [Let's Encrypt — Getting Started](https://letsencrypt.org/getting-started/)
- [Certes ACME client](https://github.com/fszlin/certes)
