# Audit Logging Architecture

**Category:** Architecture / Cross-Cutting Concerns
**Difficulty:** 🟡 Middle
**Tags:** `audit-logging`, `EF-Core-interceptors`, `domain-events`, `structured-logging`, `compliance`, `change-tracking`

## Question

> How do you implement an audit trail in a .NET application? Compare EF Core interceptors for DB-level auditing vs domain events as the audit log source, and explain structured logging best practices for compliance.

## Short Answer

Two main approaches: (1) **EF Core `SaveChangesInterceptor`** — captures all entity changes (added, modified, deleted) automatically, including field-level before/after values. Great for database-level audit trails, requires no domain model changes. (2) **Domain events as audit log** — explicit business intents captured in domain language (`OrderCancelledEvent`, `CustomerDeactivatedEvent`) — richer semantic context but requires manual event raising. For compliance (GDPR, SOX, HIPAA): use structured logging with `ILogger` + Serilog/Seq for searchable, tamper-evident audit logs.

## Detailed Explanation

### EF Core SaveChanges Interceptor

```csharp
// Captures ALL entity changes automatically — no domain model changes needed
public class AuditInterceptor(ICurrentUser currentUser) : SaveChangesInterceptor
{
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData ev, InterceptionResult<int> result, CancellationToken ct)
    {
        var changes = ev.Context?.ChangeTracker.Entries()
            .Where(e => e.State is EntityState.Added or EntityState.Modified or EntityState.Deleted)
            .Select(e => new AuditEntry
            {
                UserId       = currentUser.UserId,
                Timestamp    = DateTimeOffset.UtcNow,
                EntityType   = e.Entity.GetType().Name,
                EntityId     = e.Property("Id").CurrentValue?.ToString() ?? "unknown",
                Action       = e.State.ToString(),
                OldValues    = e.State == EntityState.Added ? null :
                               JsonSerializer.Serialize(e.OriginalValues.Properties
                                   .ToDictionary(p => p.Name, p => e.OriginalValues[p])),
                NewValues    = e.State == EntityState.Deleted ? null :
                               JsonSerializer.Serialize(e.CurrentValues.Properties
                                   .ToDictionary(p => p.Name, p => e.CurrentValues[p]))
            }).ToList();

        // Add audit entries to a separate AuditLog table in the same transaction
        foreach (var entry in changes ?? [])
            ev.Context!.Set<AuditEntry>().Add(entry);

        return base.SavingChangesAsync(ev, result, ct);
    }
}

// Register interceptor
services.AddDbContext<AppDbContext>((sp, opts) =>
{
    opts.UseNpgsql(connectionString);
    opts.AddInterceptors(sp.GetRequiredService<AuditInterceptor>());
});
```

### Domain Events as Audit Log

```csharp
// Richer semantic context — "WHY" not just "WHAT"
// EF Core: "Order.Status changed from Submitted to Cancelled"
// Domain event: "OrderCancelled because customer requested refund for damaged item"

public class OrderCancelledEvent(int orderId, int customerId, string reason, DateTimeOffset cancelledAt)
    : IDomainEvent
{
    public int OrderId       { get; } = orderId;
    public int CustomerId    { get; } = customerId;
    public string Reason     { get; } = reason;
    public DateTimeOffset At { get; } = cancelledAt;
}

// Handler: persist to audit log with full business context
public class AuditOrderCancelledHandler : INotificationHandler<OrderCancelledEvent>
{
    public Task Handle(OrderCancelledEvent ev, CancellationToken ct)
    {
        _logger.LogInformation(
            "AUDIT: Order {OrderId} cancelled by customer {CustomerId}. Reason: {Reason}. At: {At}",
            ev.OrderId, ev.CustomerId, ev.Reason, ev.At);

        return _auditRepo.LogAsync(new AuditRecord(
            action:      "OrderCancelled",
            entityType:  "Order",
            entityId:    ev.OrderId.ToString(),
            userId:      ev.CustomerId.ToString(),
            details:     new { ev.Reason, ev.At },
            timestamp:   ev.At), ct);
    }
}
```

### Structured Logging for Audit (Serilog)

```csharp
// Serilog structured logging: each audit event is a structured log record
// Queryable in Seq, Elasticsearch, Application Insights

Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.Seq("http://seq:5341")                    // ← searchable audit store
    .Enrich.WithProperty("ApplicationName", "OrdersApi")
    .Enrich.FromLogContext()                            // ← adds correlation ID, user ID
    .CreateLogger();

// Audit log: use a dedicated channel or sink for tamper evidence
Log.Logger = new LoggerConfiguration()
    .WriteTo.Logger(lc => lc
        .Filter.ByIncludingOnly(e => e.Properties.ContainsKey("AuditEvent"))
        .WriteTo.File("audit/audit.log",
            rollingInterval: RollingInterval.Day,
            retainedFileCountLimit: 365,
            outputTemplate: "{Timestamp:o} {AuditEvent} {Message:lj}{NewLine}")
    )
    .CreateLogger();

// Emit structured audit event
_logger.LogInformation(
    "{@AuditEvent}",          // ← @ destructures the object as structured data
    new { Event = "OrderCancelled", OrderId = 42, UserId = 7, Reason = "refund", At = DateTimeOffset.UtcNow });
```

### Sensitive Data Handling (GDPR)

```csharp
// Never log PII in audit logs unless legally required
// Use pseudonymization: log user ID, not user email/name

// BAD: logs personal data
_logger.LogInformation("User {Email} placed order {OrderId}", user.Email, orderId);

// GOOD: logs pseudonymized identifier
_logger.LogInformation("User {UserId} placed order {OrderId}", user.Id, orderId);

// GDPR right to erasure: pseudonymization allows "erasing" by deleting the user ID mapping
// The audit log entries remain (for legal compliance) but can no longer be linked to an individual
```

## Code Example

```csharp
// Hybrid: EF Core interceptor for low-level DB audit + domain events for business audit
// Register:
services.AddScoped<AuditInterceptor>();
services.AddDbContext<AppDbContext>((sp, opts) =>
    opts.AddInterceptors(sp.GetRequiredService<AuditInterceptor>()));

// Use EF interceptor for: Who changed what field, when, at DB level
// Use domain events for: Business reasons, compliance-level events (GDPR consent, account closure)
```

## Common Follow-up Questions

- How do you protect audit logs from being tampered with by application code?
- How do you handle audit logging for soft-deleted records?
- How do you query audit history for a specific entity in EF Core?
- How do you log before/after values while excluding sensitive fields (password hashes, tokens)?
- What is the difference between an audit log and an application log?

## Common Mistakes / Pitfalls

- **Logging PII in audit events**: audit logs that contain email addresses, phone numbers, or health data create GDPR compliance issues. Use pseudonymized IDs and log only non-personal identifiers.
- **Separate transaction for audit log**: if the audit `INSERT` is in a different transaction than the entity `UPDATE`, a failure between them leaves the DB changed but with no audit record. Write both in the same `SaveChanges` transaction.
- **Using EF Core interceptor for all tables blindly**: intercepting all entity changes creates massive audit log volume. Filter to auditable entities via marker interface (`IAuditable`) or explicit opt-in configuration.
- **Structured logging with `string.Format` style instead of message templates**: `_logger.LogInformation($"User {email} did X")` loses structured property capture. Use `_logger.LogInformation("User {Email} did X", email)` — Serilog stores `Email` as a queryable property.

## References

- [EF Core SaveChanges interceptors — Microsoft Docs](https://learn.microsoft.com/en-us/ef/core/logging-events-diagnostics/interceptors)
- [Serilog structured logging](https://serilog.net/)
- [GDPR and audit logs — best practices](https://ico.org.uk/for-organisations/guide-to-data-protection/) (verify URL)
- [See: domain-events.md](./domain-events.md)
