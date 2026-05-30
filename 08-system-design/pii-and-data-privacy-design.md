# PII and Data Privacy Design

**Category:** System Design / Security
**Difficulty:** Middle
**Tags:** `pii`, `gdpr`, `data-privacy`, `pseudonymisation`, `right-to-erasure`, `audit-log`, `data-minimisation`

## Question

> How do you design a system to comply with GDPR and data privacy regulations? What are the key technical mechanisms for data minimisation, pseudonymisation, and the right to erasure? How do you design audit logs that are tamper-evident?

- How do you implement "right to erasure" (right to be forgotten) in a system with event sourcing or immutable logs?
- What is the difference between pseudonymisation and anonymisation?

## Short Answer

Privacy-by-design means collecting only the data you need, protecting it with access controls and encryption, and building deletion and audit mechanisms before they are required. Key techniques are: data minimisation (don't store what you don't need), pseudonymisation (replace identifiers with tokens that can be re-linked via a secure mapping), and hard deletion paths for the right to erasure. The hardest challenge is deletion in append-only systems (event logs, backups) — solved by crypto-erasure (deleting the encryption key rather than the data) or by storing PII in a separate, erasable store referenced by a pseudonymous ID.

## Detailed Explanation

### GDPR Key Obligations (Technical View)

| Obligation | Technical requirement |
|-----------|----------------------|
| **Data minimisation** | Don't collect/store fields not needed for the stated purpose |
| **Purpose limitation** | Don't use data collected for purpose A for purpose B |
| **Storage limitation** | Delete data after retention period expires |
| **Right to access** | Export all PII for a given subject on request |
| **Right to erasure** | Delete all PII for a subject on request |
| **Integrity & confidentiality** | Encrypt PII at rest and in transit; access controls |
| **Accountability** | Audit log of all PII access and processing |

### Data Minimisation

The simplest privacy technique: don't store data you don't need.

```csharp
// ❌ Bad: collecting DOB when you only need age verification
public record UserRegistration(string Email, string Password, DateTime DateOfBirth, string FullAddress);

// ✅ Better: store only what's needed for the purpose
public record UserRegistration(string Email, string Password, bool IsOver18);
// Or: derive IsOver18 at registration, don't persist DOB at all
```

Use separate tables with different retention policies:

```sql
-- Core account (retained while account active)
CREATE TABLE users (id UUID PRIMARY KEY, email_hash TEXT, created_at TIMESTAMPTZ);

-- PII (can be erased independently; FK to users)
CREATE TABLE user_pii (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    deleted_at TIMESTAMPTZ   -- soft delete for audit trail
);

-- Behavioural data (retained for analytics, but pseudonymised)
CREATE TABLE page_views (user_id UUID, page TEXT, viewed_at TIMESTAMPTZ);
-- user_id is a pseudonym — no PII here, user PII stored separately
```

### Pseudonymisation vs Anonymisation

| | Pseudonymisation | Anonymisation |
|--|----------------|--------------|
| Can be re-linked to individual? | Yes, with access to mapping table | No — irreversible |
| GDPR scope | Still personal data (but reduced risk) | Not personal data — outside GDPR |
| Use case | Operational data that needs linking | Analytics, ML training datasets |

**Pseudonymisation in practice:**

```csharp
// Replace PII identifiers with stable, opaque tokens
public sealed class PseudonymService(IDistributedCache cache, IKeyStore keys)
{
    // email → stable pseudonym (HMAC with rotating key)
    public string Pseudonymise(string email, string keyId)
    {
        var key = keys.GetKey(keyId);
        using var hmac = new HMACSHA256(key);
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(email.ToLowerInvariant()));
        return $"{keyId}:{Convert.ToBase64String(hash)}";
    }

    // Store real email only in the PII store; use pseudonym in analytics/events
}
```

### Right to Erasure (GDPR Article 17)

The straightforward case — relational database:

```csharp
public async Task EraseUserDataAsync(Guid userId, CancellationToken ct)
{
    await using var tx = await _db.Database.BeginTransactionAsync(ct);

    // 1. Delete PII from structured store
    await _db.UserPii.Where(p => p.UserId == userId).ExecuteDeleteAsync(ct);
    await _db.UserAddresses.Where(a => a.UserId == userId).ExecuteDeleteAsync(ct);
    await _db.PaymentMethods.Where(p => p.UserId == userId).ExecuteDeleteAsync(ct);

    // 2. Pseudonymise or null out references in analytics tables
    await _db.Orders
        .Where(o => o.UserId == userId)
        .ExecuteUpdateAsync(s => s
            .SetProperty(o => o.CustomerName, "DELETED")
            .SetProperty(o => o.CustomerEmail, null), ct);

    // 3. Record erasure in audit log (keep metadata, not the data)
    _db.ErasureLog.Add(new ErasureRecord
    {
        UserId     = userId,
        ErasedAt   = DateTimeOffset.UtcNow,
        RequestedBy = _currentUser.Id,
    });

    await _db.SaveChangesAsync(ct);
    await tx.CommitAsync(ct);

    // 4. Invalidate caches
    await _cache.RemoveAsync($"user:{userId}:profile", ct);
}
```

### Erasure in Event Sourcing / Immutable Logs

Append-only event stores make deletion challenging. Three strategies:

**Strategy 1: Crypto-erasure (tombstoning)**
Encrypt PII fields in events with a per-user data key. When erasing, delete the key — data becomes unreadable but events are structurally intact:

```csharp
// Store encrypted PII in events
public record UserRegisteredEvent(
    Guid UserId,
    string EncryptedEmail,   // AES-256 encrypted with per-user key
    string KeyId);           // reference to key in Key Vault

// On erasure: delete the key from Key Vault
// await keyVault.DeleteKeyAsync($"user-data-key-{userId}", ct);
// The EncryptedEmail bytes remain in the log but are forever unreadable
```

**Strategy 2: Separate PII store (reference pattern)**
Store PII in a separate erasable store; reference it by pseudonymous ID in events:

```csharp
// Event contains no PII — only an opaque reference
public record OrderPlacedEvent(Guid OrderId, Guid CustomerId, Money Total);

// PII service resolves CustomerId → full name/email at query time
// On erasure: delete from PII store; events remain valid but unresolvable
```

**Strategy 3: Compaction / re-encryption**
Rewrite the event stream without PII after erasure. Expensive but complete. Used when legal or audit requirements prohibit leaving any trace.

### Audit Log Design

A privacy audit log records who accessed what PII and when. It must itself be tamper-evident:

```csharp
// Audit record with hash chain (each record's hash includes the previous hash)
public sealed class AuditEntry
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public Guid SubjectUserId { get; init; }   // whose PII was accessed
    public Guid ActorUserId { get; init; }     // who accessed it
    public string Action { get; init; } = default!;  // "read", "export", "delete"
    public DateTimeOffset Timestamp { get; init; } = DateTimeOffset.UtcNow;
    public string PreviousHash { get; init; } = default!;
    public string Hash { get; private set; } = default!;

    public void ComputeHash()
    {
        var content = $"{Id}|{SubjectUserId}|{ActorUserId}|{Action}|{Timestamp:O}|{PreviousHash}";
        using var sha = SHA256.Create();
        Hash = Convert.ToHexString(sha.ComputeHash(Encoding.UTF8.GetBytes(content)));
    }
}
```

The hash chain means any tampering with a past record invalidates all subsequent hashes — detectable on audit.

For higher assurance, timestamp audit entries with an external trusted timestamping service (RFC 3161).

### Retention Policies

Data that is no longer needed for its stated purpose must be deleted:

```csharp
// Background service: enforce retention
public sealed class RetentionEnforcementJob(IServiceScopeFactory scopeFactory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            await using var scope = scopeFactory.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            // Delete PII for users who haven't logged in for 3 years
            var cutoff = DateTimeOffset.UtcNow.AddYears(-3);
            await db.UserPii
                .Where(p => p.User.LastLoginAt < cutoff && p.DeletedAt == null)
                .ExecuteUpdateAsync(s => s.SetProperty(p => p.DeletedAt, DateTimeOffset.UtcNow), ct);

            await Task.Delay(TimeSpan.FromHours(24), ct);
        }
    }
}
```

> **Warning:** GDPR erasure does not always mean immediate physical deletion — it means making data unreadable/unidentifiable. Legal hold obligations (e.g., financial records for 7 years) override erasure requests for specific data categories. Always involve legal counsel to define which data falls under which retention obligation.

## Common Follow-up Questions

- How do you handle GDPR erasure requests when data is replicated to a data warehouse or analytics platform?
- What is differential privacy and when is it used in analytics systems?
- How do you implement a Subject Access Request (SAR) export that collects data from multiple microservices?
- What is the role of a Data Protection Officer (DPO) and how does system design support their work?
- How do you classify data fields by sensitivity level (PII vs non-PII vs sensitive PII)?

## Common Mistakes / Pitfalls

- **Storing PII in application logs**: logging `userId`, `email`, `IP` in structured logs creates a shadow PII store that is very hard to purge; scrub PII before logging.
- **No retention policy enforcement**: defining a 3-year retention policy in a document but never implementing a deletion job means the policy is legally meaningless.
- **Forgetting backups**: erasing production data but not running the same erasure against DB backups leaves PII in backups; factor backup retention into the erasure process.
- **Conflating pseudonymisation with anonymisation**: GDPR still applies to pseudonymised data if re-linkage is possible; anonymised data has no GDPR obligations but must be truly irreversible.
- **Not testing the erasure path**: data deletion is rarely exercised in development; test the full erasure flow in staging to avoid discovering that cascades are missing or caches are not cleared.

## References

- [GDPR — Article 17 Right to Erasure](https://gdpr-info.eu/art-17-gdpr/)
- [GDPR — Article 5 Principles (data minimisation)](https://gdpr-info.eu/art-5-gdpr/)
- [Pseudonymisation techniques — ENISA guidelines](https://www.enisa.europa.eu/publications/pseudonymisation-techniques-and-best-practices)
- [GDPR in .NET / ASP.NET Core — Microsoft Docs](https://learn.microsoft.com/en-us/aspnet/core/security/gdpr)
- [See: secrets-management-at-scale.md](./secrets-management-at-scale.md)
- [See: authentication-vs-authorization.md](./authentication-vs-authorization.md)
