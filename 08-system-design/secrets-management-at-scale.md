# Secrets Management at Scale

**Category:** System Design / Security
**Difficulty:** Senior
**Tags:** `secrets`, `azure-key-vault`, `hashicorp-vault`, `kubernetes-secrets`, `secret-rotation`, `dotnet-configuration`

## Question

> How do you manage secrets (connection strings, API keys, certificates) at scale in a distributed .NET system? What strategies ensure secrets are never committed to source control, can be rotated without downtime, and are auditable? What tools and patterns do you use in Azure and Kubernetes environments?

- What is the difference between storing secrets in environment variables vs a secret manager?
- How do you rotate a database password without a service restart?

## Short Answer

Secrets management at scale requires a dedicated secret store (Azure Key Vault, HashiCorp Vault, AWS Secrets Manager) rather than environment variables or config files. Secrets are injected at runtime via the .NET configuration system, never baked into container images or committed to source. Zero-downtime rotation is achieved by supporting two valid credentials simultaneously (old + new) during a rotation window, draining existing connections, then removing the old credential. Audit logs from the vault track every secret read, providing the accountability required by compliance frameworks.

## Detailed Explanation

### Why Environment Variables Are Not Enough

Environment variables are a step up from hardcoded config files, but they have serious limitations at scale:

| Problem | Detail |
|---------|--------|
| **No versioning** | Cannot roll back to a previous secret value |
| **No audit log** | No record of who read the secret when |
| **No rotation support** | Changing a value requires redeploying all pods |
| **No lifecycle management** | Expiry, auto-rotation, lease management missing |
| **Kubernetes `Secret` is base64-encoded** | Not encrypted at rest by default; requires etcd encryption |

A centralised secret manager solves all of these.

### Azure Key Vault + .NET Configuration

The `Azure.Extensions.AspNetCore.Configuration.Secrets` package integrates Key Vault directly into the .NET `IConfiguration` pipeline:

```csharp
// Program.cs
using Azure.Identity;
using Azure.Extensions.AspNetCore.Configuration.Secrets;

var builder = WebApplication.CreateBuilder(args);

// Add Key Vault as a configuration source
// Managed Identity — no credentials in code at all
builder.Configuration.AddAzureKeyVault(
    new Uri($"https://{builder.Configuration["KeyVaultName"]}.vault.azure.net/"),
    new DefaultAzureCredential(),   // uses Managed Identity in Azure, developer credential locally
    new AzureKeyVaultConfigurationOptions
    {
        ReloadInterval = TimeSpan.FromMinutes(5), // poll for rotated secrets
    });

// Access secrets the same way as any IConfiguration value
var connStr = builder.Configuration["database-connection-string"];
// Key Vault secret named "database-connection-string" is mapped automatically
```

Key Vault secrets map to `IConfiguration` keys: hyphens are the preferred separator in Key Vault names (maps to `database:connectionString` via `--` → `:`).

### Managed Identity: No Credentials for Credentials

The authentication paradox: "How do I authenticate to the secret store without a secret?" is solved by **Managed Identity** in Azure / **Workload Identity** in Kubernetes:

- The cloud platform assigns an identity to the pod/VM.
- The identity is granted RBAC access to Key Vault.
- The SDK (`DefaultAzureCredential`) obtains a short-lived token from the instance metadata endpoint.
- No passwords, no API keys, no secrets in config.

```bash
# Azure: Assign Key Vault Secret User role to the app's Managed Identity
az role assignment create \
  --assignee <managed-identity-client-id> \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault>
```

### Kubernetes: CSI Secret Store Driver

For Kubernetes environments, the **Secrets Store CSI Driver** mounts secrets from Key Vault directly as files in the pod filesystem (no Kubernetes Secrets object involved):

```yaml
# SecretProviderClass — references Key Vault
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: orders-secrets
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "<client-id>"
    keyvaultName: "orders-keyvault"
    objects: |
      array:
        - |
          objectName: database-password
          objectType: secret
          objectVersion: ""   # "" = latest version
        - |
          objectName: redis-password
          objectType: secret
---
# Pod spec
volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "orders-secrets"
containers:
  - name: orders-api
    volumeMounts:
      - name: secrets-store
        mountPath: "/mnt/secrets"
        readOnly: true
```

Secrets are mounted as files; the app reads them at startup or polls for changes.

### Zero-Downtime Secret Rotation

The critical challenge: rotating a database password without taking the service offline.

**Pattern: Double-key rotation**

```
Phase 1: Add new password to DB (both old + new are valid)
Phase 2: Update secret in vault → new version deployed
Phase 3: Service instances gradually restart (rolling update), pick up new secret
Phase 4: Remove old password from DB — all instances now use new secret
```

```csharp
// Support reading a "secondary" connection string during rotation
// Only needed during the rotation window (minutes)
public sealed class RotationAwareDbConnectionFactory(IConfiguration config)
{
    public NpgsqlConnection Create()
    {
        // Primary secret — updated first
        var primary = config["db:connection-string"];
        try
        {
            var conn = new NpgsqlConnection(primary);
            conn.Open();
            return conn;
        }
        catch (PostgresException)
        {
            // Fallback to secondary during rotation window
            var secondary = config["db:connection-string-secondary"];
            if (secondary is null) throw;
            return new NpgsqlConnection(secondary);
        }
    }
}
```

**EF Core connection resilience** handles transient failures automatically (Polly-based retry), so brief rotation hiccups are handled without explicit dual-credential logic in most cases.

### HashiCorp Vault: Dynamic Secrets

HashiCorp Vault goes further — it can generate **dynamic credentials** on demand:

```
Service requests DB credentials → Vault creates a temporary DB user
Vault returns: { username: "v-orders-svc-xKk3", password: "...", lease: 1h }
After 1 hour, Vault automatically revokes the user from the DB
```

This means:
- No static passwords to rotate.
- Each service instance has unique, time-limited credentials.
- Breach of one credential is automatically time-bounded.

```csharp
// Vault.NET client for dynamic secrets
using VaultSharp;
using VaultSharp.V1.AuthMethods.Kubernetes;

var vaultClient = new VaultClient(new VaultClientSettings(
    "https://vault.internal",
    new KubernetesAuthMethodInfo(roleName: "orders-svc",
        jwt: File.ReadAllText("/var/run/secrets/kubernetes.io/serviceaccount/token"))));

// Request a dynamic PostgreSQL credential (valid for 1 hour)
var secret = await vaultClient.V1.Secrets.Database.GetCredentialsAsync("orders-db-role");
var connStr = $"Host=db; Username={secret.Data.Username}; Password={secret.Data.Password}; Database=orders";
```

### Audit and Compliance

Every vault read operation is logged:

```
2024-01-15T10:23:45Z  READ  secret/database-password  principal=orders-svc  ip=10.0.1.5
2024-01-15T10:23:46Z  READ  secret/redis-password      principal=orders-svc  ip=10.0.1.5
```

For compliance (PCI DSS, SOC 2, HIPAA): audit logs show who accessed what secret when, and alert on anomalous access patterns.

> **Warning:** Never log secret values — only log that a secret was accessed. Structured logging middleware should scrub known secret key patterns before writing to log sinks.

### Local Development

`DefaultAzureCredential` automatically uses VS/CLI developer credentials locally:

```csharp
// Works in both local dev (Visual Studio / az CLI login) and production (Managed Identity)
new DefaultAzureCredential(new DefaultAzureCredentialOptions
{
    ExcludeEnvironmentCredential     = false, // CI/CD: service principal via env vars
    ExcludeManagedIdentityCredential = false, // Production: AKS Workload Identity
    ExcludeVisualStudioCredential    = false, // Local dev: VS login
    ExcludeAzureCliCredential        = false, // Local dev: az login
})
```

For local development without vault access, use `dotnet user-secrets`:

```bash
dotnet user-secrets set "database-connection-string" "Host=localhost;Database=orders;Username=dev;Password=dev"
```

## Common Follow-up Questions

- How does Key Vault's soft-delete and purge protection help against accidental secret deletion?
- What is the difference between a Key Vault secret, key, and certificate?
- How do you handle secret expiry alerts — notify the team before a secret expires?
- What is SOPS (Secrets OPerationS) and how does it allow encrypting secrets in Git?
- How do you grant least-privilege access to secrets — different services read different secrets?

## Common Mistakes / Pitfalls

- **Committing secrets to Git**: even in private repositories. Use `git-secrets` or `gitleaks` as pre-commit hooks to prevent this.
- **Kubernetes Secrets without etcd encryption**: Kubernetes Secrets are only base64-encoded by default; enable etcd encryption-at-rest or use the CSI driver.
- **Shared service principal for all services**: each service should have a unique identity with access only to its own secrets (least privilege). A shared principal means compromising one service exposes all secrets.
- **Caching secrets indefinitely**: if a secret rotates but the application caches the old value forever, it breaks. Use `ReloadInterval` or refresh on failure.
- **Logging secret values**: structured logging that serialises objects may accidentally log secret strings. Implement `ILogValueMasker` or mark sensitive properties with a `[Sensitive]` attribute and custom serializer.
- **No rotation plan**: creating secrets without defining a rotation schedule means secrets become stale and are never rotated in practice.

## References

- [Azure Key Vault — Microsoft Docs](https://learn.microsoft.com/en-us/azure/key-vault/general/overview)
- [Add Key Vault to ASP.NET Core configuration](https://learn.microsoft.com/en-us/aspnet/core/security/key-vault-configuration)
- [DefaultAzureCredential — Azure Identity](https://learn.microsoft.com/en-us/dotnet/api/azure.identity.defaultazurecredential)
- [Secrets Store CSI Driver for Kubernetes](https://secrets-store-csi-driver.sigs.k8s.io/)
- [HashiCorp Vault dynamic secrets](https://developer.hashicorp.com/vault/docs/secrets/databases)
- [See: zero-trust-architecture.md](./zero-trust-architecture.md)
- [See: authentication-vs-authorization.md](./authentication-vs-authorization.md)
