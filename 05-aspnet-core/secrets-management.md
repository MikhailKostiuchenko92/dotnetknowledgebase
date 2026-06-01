# Secrets Management in ASP.NET Core

**Category:** ASP.NET Core / Security Best Practices
**Difficulty:** 🟢 Junior
**Tags:** `user-secrets`, `environment-variables`, `Azure-Key-Vault`, `IConfiguration`, `secrets`, `vault`

## Question

> How should you manage secrets (connection strings, API keys, certificates) in ASP.NET Core across development and production environments?

## Short Answer

Never store secrets in source code or `appsettings.json`. In **development**, use **User Secrets** (`dotnet user-secrets`) — stored in the OS user profile, not in the project directory. In **production**, use **environment variables** (simple, works everywhere) or a **secrets vault** like Azure Key Vault, HashiCorp Vault, or AWS Secrets Manager. All of these integrate seamlessly with `IConfiguration` and are transparent to application code.

## Detailed Explanation

### User Secrets (development only)

```bash
dotnet user-secrets init           # adds UserSecretsId to .csproj
dotnet user-secrets set "Jwt:Secret" "my-super-secret-key-dev-only"
dotnet user-secrets set "ConnectionStrings:Default" "Server=localhost;..."
dotnet user-secrets list
```

Secrets are stored in:
- Windows: `%APPDATA%\Microsoft\UserSecrets\<UserSecretsId>\secrets.json`
- Linux/macOS: `~/.microsoft/usersecrets/<UserSecretsId>/secrets.json`

They are added to `IConfiguration` automatically in development:

```csharp
// Automatically added by WebApplication.CreateBuilder in Development
// builder.Configuration.AddUserSecrets<Program>();
```

### Environment variables (production)

The default configuration provider chain includes environment variables:

```bash
# Set in shell / container / deployment pipeline
export ConnectionStrings__Default="Server=prod-db;..."
export Jwt__Secret="your-production-secret"
```

Environment variable naming convention: `:` separator in config key → `__` (double underscore) in env var name.

```csharp
// Reads automatically — no code change needed
var connStr = builder.Configuration.GetConnectionString("Default");
var jwtSecret = builder.Configuration["Jwt:Secret"];
```

### Azure Key Vault integration

```bash
dotnet add package Azure.Extensions.AspNetCore.Configuration.Secrets
```

```csharp
if (!builder.Environment.IsDevelopment())
{
    var vaultUri = new Uri($"https://{builder.Configuration["KeyVaultName"]}.vault.azure.net/");
    builder.Configuration.AddAzureKeyVault(vaultUri, new DefaultAzureCredential());
}
```

Azure Key Vault secret naming: colons (`:`) must be replaced with double dashes (`--`) in secret names:
- Config key `ConnectionStrings:Default` → Key Vault secret name `ConnectionStrings--Default`

### `DefaultAzureCredential` chain

`DefaultAzureCredential` tries these in order:
1. `AZURE_*` environment variables
2. Workload Identity (AKS)
3. Managed Identity (Azure VM/App Service)
4. Visual Studio / VS Code credential
5. Azure CLI

This means no hardcoded credentials anywhere — the identity context provides access.

### `IConfiguration` provider order (last wins)

```
appsettings.json
  ↓
appsettings.{Environment}.json
  ↓
User Secrets (Development only)
  ↓
Environment Variables
  ↓
Azure Key Vault (if added)     ← highest priority in this example
```

### Accessing strongly-typed secrets

```csharp
public sealed record JwtOptions(
    [Required] string Secret,
    [Required] string Issuer,
    TimeSpan TokenLifetime = default);

builder.Services.AddOptions<JwtOptions>()
    .Bind(builder.Configuration.GetSection("Jwt"))
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

## Code Example

```csharp
// Program.cs — production secrets wiring
var builder = WebApplication.CreateBuilder(args);

// In production: add Key Vault
if (!builder.Environment.IsDevelopment())
{
    var kvName = builder.Configuration["KeyVaultName"]
        ?? throw new InvalidOperationException("KeyVaultName not configured");
    builder.Configuration.AddAzureKeyVault(
        new Uri($"https://{kvName}.vault.azure.net/"),
        new DefaultAzureCredential(new DefaultAzureCredentialOptions
        {
            ExcludeVisualStudioCodeCredential = true, // production-only: skip dev tools
            ExcludeAzureCliCredential = true
        }));
}

// Options pattern — secrets available anywhere via IOptions<T>
builder.Services.AddOptions<DatabaseOptions>()
    .Bind(builder.Configuration.GetSection("Database"))
    .ValidateDataAnnotations()
    .ValidateOnStart();

// Never log the raw connection string
builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
```

```bash
# Kubernetes secret → env var → IConfiguration
kubectl create secret generic app-secrets \
  --from-literal=ConnectionStrings__Default="Server=prod-db;Password=s3cret"

# In deployment.yaml:
env:
  - name: ConnectionStrings__Default
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: ConnectionStrings__Default
```

## Common Follow-up Questions

- How do you rotate secrets in production without application downtime?
- What is `DefaultAzureCredential` and how does it avoid hardcoded credentials?
- How do you access secrets from a background worker that runs outside an HTTP request?
- How do you use HashiCorp Vault instead of Azure Key Vault with `IConfiguration`?
- What are the security implications of passing secrets via environment variables vs files?

## Common Mistakes / Pitfalls

- **Committing `appsettings.Development.json` with real secrets** — development overrides often end up in git. Use User Secrets for local development secrets; add `appsettings.Development.json` to `.gitignore` if it ever contains non-trivial config.
- **Hardcoding secrets in `Dockerfile` or CI/CD YAML** — use platform-level secrets injection (GitHub Actions secrets, Azure DevOps variables groups, K8s secrets).
- **Not validating secrets at startup** — use `ValidateOnStart()` with `IOptions<T>` to catch missing/malformed secrets immediately, not at the first request that needs them.
- **Using `IConfiguration` directly in long-lived services** — `IConfiguration` reads values once; for reloading secrets (Key Vault rotations), use `IOptionsMonitor<T>` which reloads on change.
- **Logging secrets accidentally** — `ILogger` structured logging with `{@Options}` on an options object that contains secrets will log the secret value. Implement `IFormattable` or `[DataMember(IsRequired = true)]` with redacted `ToString()`.

## References

- [Microsoft Learn — Safe storage of app secrets in development](https://learn.microsoft.com/aspnet/core/security/app-secrets?view=aspnetcore-8.0)
- [Microsoft Learn — Azure Key Vault configuration provider](https://learn.microsoft.com/aspnet/core/security/key-vault-configuration?view=aspnetcore-8.0)
- [Microsoft Learn — DefaultAzureCredential](https://learn.microsoft.com/dotnet/api/azure.identity.defaultazurecredential)
- [OWASP — Secrets management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
