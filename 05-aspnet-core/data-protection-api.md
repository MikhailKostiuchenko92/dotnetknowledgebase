# Data Protection API in ASP.NET Core

**Category:** ASP.NET Core / Authentication & Authorization
**Difficulty:** 🔴 Senior
**Tags:** `IDataProtector`, `data-protection`, `IDataProtectionProvider`, `key-ring`, `purpose-strings`, `key-rotation`

## Question

> What is the ASP.NET Core Data Protection API? How do purpose strings work, and how do you manage key ring storage in a multi-node deployment?

## Short Answer

The **Data Protection API** provides cryptographic protection (encrypt + authenticate) for arbitrary byte payloads using a managed key ring. `IDataProtectionProvider.CreateProtector(purpose)` creates an `IDataProtector` scoped to a purpose string — protectors with different purposes produce ciphertext that cannot be decrypted by each other, even with the same underlying key. The built-in keys are rotated automatically every 90 days. In multi-node deployments, all nodes must share the same key ring (persisted to a shared location) and the same key encryption mechanism.

## Detailed Explanation

### Core abstractions

| Interface | Responsibility |
|---|---|
| `IDataProtectionProvider` | Root factory — creates purpose-scoped protectors |
| `IDataProtector` | Protects (encrypt+sign) and Unprotects (verify+decrypt) payloads |
| `IDataProtectionBuilder` | Configuration fluent API |

### Basic usage

```csharp
// Setup (automatic in ASP.NET Core — already registered by default)
builder.Services.AddDataProtection();

// Usage in a service
public sealed class TokenService(IDataProtectionProvider provider)
{
    private readonly IDataProtector _protector = provider.CreateProtector("TokenService.v1");

    public string GenerateToken(string userId)
    {
        var payload = $"{userId}:{DateTimeOffset.UtcNow:O}";
        return _protector.Protect(payload); // encrypt + sign
    }

    public string? ValidateToken(string token)
    {
        try
        {
            return _protector.Unprotect(token); // verify + decrypt
        }
        catch (CryptographicException)
        {
            return null; // tampered or expired
        }
    }
}
```

### Purpose string isolation

Purpose strings create a **namespace isolation** — ciphertext produced by `protector1` cannot be decrypted by `protector2`, even on the same machine:

```csharp
var protector1 = provider.CreateProtector("UserService.PasswordReset");
var protector2 = provider.CreateProtector("UserService.EmailConfirmation");

var token = protector1.Protect("user123");
protector2.Unprotect(token); // CryptographicException — different purpose
```

This prevents a password-reset token from being used as an email-confirmation token (a common attack vector).

### Hierarchical purposes

```csharp
var protector = provider.CreateProtector("UserService", "PasswordReset", "v2");
// Equivalent to: "UserService.PasswordReset.v2"
// IDataProtector.CreateProtector(subPurpose) chains purposes:
var subProtector = userServiceProtector.CreateProtector("PasswordReset");
```

### Time-limited tokens with `ITimeLimitedDataProtector`

```csharp
var tlProtector = provider.CreateProtector("EmailConfirmation")
    .ToTimeLimitedDataProtector();

// Protect with expiry
var token = tlProtector.Protect("user123", TimeSpan.FromHours(24));

// Unprotect — throws if expired
try
{
    var payload = tlProtector.Unprotect(token);
}
catch (CryptographicException ex) when (ex.Message.Contains("expired"))
{
    // Token expired
}
```

### Key ring management

Keys are stored in `%LOCALAPPDATA%\ASP.NET\DataProtection-Keys` by default (not suitable for production).

Configure a shared location:

```csharp
builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo(@"\\server\share\dp-keys"))
    .ProtectKeysWithCertificate("thumbprint")  // encrypt keys at rest
    .SetApplicationName("MyApp")               // must match across all nodes
    .SetDefaultKeyLifetime(TimeSpan.FromDays(14));
```

```csharp
// Azure Blob + Key Vault (production-grade)
builder.Services.AddDataProtection()
    .PersistKeysToAzureBlobStorage(new Uri("https://storage.blob.core.windows.net/keys/keys.xml"),
        new DefaultAzureCredential())
    .ProtectKeysWithAzureKeyVault(new Uri("https://vault.azure.net/keys/dp-key"),
        new DefaultAzureCredential())
    .SetApplicationName("MyApp");
```

```csharp
// Redis (popular choice)
builder.Services.AddDataProtection()
    .PersistKeysToStackExchangeRedis(ConnectionMultiplexer.Connect(redisConnectionString), "DataProtection-Keys")
    .SetApplicationName("MyApp");
```

### Key rotation

- Default key lifetime: 90 days
- A new key is generated **14 days before** the current key expires (overlap period)
- Old keys are retained indefinitely to decrypt old ciphertext
- `RevokeAllKeys()` or `RevokeKey(keyId)` can invalidate keys (e.g., security incident)

### What ASP.NET Core uses Data Protection for

- Cookie authentication tickets
- Anti-forgery tokens
- TempData
- Session ID (for `ISessionFeature`)
- `[ViewState]` in Razor Pages

## Code Example

```csharp
// Unsubscribe link generator using ITimeLimitedDataProtector
public sealed class UnsubscribeLinkService(
    IDataProtectionProvider provider,
    IOptions<AppOptions> options)
{
    private readonly ITimeLimitedDataProtector _protector =
        provider.CreateProtector("UnsubscribeService.v1").ToTimeLimitedDataProtector();

    public string GenerateLink(string email)
    {
        var token = _protector.Protect(email, TimeSpan.FromDays(7));
        return $"{options.Value.BaseUrl}/unsubscribe?token={Uri.EscapeDataString(token)}";
    }

    public string? ValidateToken(string token)
    {
        try
        {
            return _protector.Unprotect(token, out var expiry);
        }
        catch (CryptographicException)
        {
            return null; // invalid or expired
        }
    }
}
```

## Common Follow-up Questions

- What happens to existing cookies when Data Protection keys are rotated or revoked?
- How does `SetApplicationName()` affect key isolation between applications on the same server?
- What is the difference between `PersistKeysToFileSystem` and `PersistKeysToAzureBlobStorage`?
- How do you share Data Protection keys between a web app and a background worker service?
- What is the `EphemeralDataProtectionProvider` and when would you use it?

## Common Mistakes / Pitfalls

- **Not setting `SetApplicationName()` in multi-app deployments** — by default, the app discriminator is derived from the content root path. If two apps have the same name but different content roots, they can't share keys; explicitly setting the name ensures consistency.
- **Using the default in-memory key ring in a load-balanced environment** — each node generates its own keys; cookies encrypted by one node can't be decrypted by another → random logouts.
- **Not protecting keys at rest in production** — keys stored unencrypted in a file share or blob can be exfiltrated. Always wrap with `ProtectKeysWithCertificate` or Azure Key Vault.
- **Trusting purpose strings as the sole security boundary** — purpose strings prevent cross-purpose decryption, but the underlying encryption is only as strong as the key ring. Leaked keys compromise all purposes.
- **Using `Protect`/`Unprotect` for long-lived tokens without `ITimeLimitedDataProtector`** — standard protectors don't expire; use `ToTimeLimitedDataProtector()` for tokens that should become invalid after a period.

## References

- [Microsoft Learn — Data Protection API overview](https://learn.microsoft.com/aspnet/core/security/data-protection/introduction?view=aspnetcore-8.0)
- [Microsoft Learn — Configure Data Protection](https://learn.microsoft.com/aspnet/core/security/data-protection/configuration/overview?view=aspnetcore-8.0)
- [Microsoft Learn — Time-limited data protection](https://learn.microsoft.com/aspnet/core/security/data-protection/consumer-apis/limited-lifetime-payloads?view=aspnetcore-8.0)
- [Andrew Lock — ASP.NET Core Data Protection](https://andrewlock.net/tag/data-protection/) (verify URL)
