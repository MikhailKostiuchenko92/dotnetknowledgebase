# SaveChanges Interceptors in EF Core

**Category:** Data Access / EF Core
**Difficulty:** 🔴 Senior
**Tags:** `ef-core`, `ISaveChangesInterceptor`, `interceptors`, `audit-trail`, `soft-delete`, `domain-events`, `AuditableEntity`

## Question

> What is `ISaveChangesInterceptor` in EF Core? How do you implement an audit trail and a soft-delete mechanism using interceptors, and what are the limitations and performance considerations?

## Short Answer

`ISaveChangesInterceptor` is an EF Core hook that fires before and after every `SaveChanges`/`SaveChangesAsync` call. It gives you access to the change tracker entries before SQL is generated, allowing you to inspect and modify entity state — perfect for audit trails (auto-setting `CreatedAt`, `UpdatedAt`, `CreatedBy`), soft deletes (redirecting `Deleted` → `Modified` with `IsDeleted = true`), and publishing domain events after a successful commit. Interceptors are registered once in DI and apply to every save, removing this cross-cutting concern from individual repositories or services.

## Detailed Explanation

### ISaveChangesInterceptor Overview

The interface has four methods (sync and async variants for each phase):

| Method | When called | Use for |
|--------|------------|---------|
| `SavingChanges` | Before SQL generation | Modify entities/state before persist |
| `SavingChangesAsync` | Before SQL generation (async) | Same, async-capable |
| `SavedChanges` | After successful commit | Post-commit side effects (events) |
| `SavedChangesAsync` | After successful commit (async) | Same, async-capable |
| `SaveChangesFailed` | On exception | Error logging, compensation |

### Implementing an Audit Trail

```csharp
public interface IAuditable
{
    DateTimeOffset CreatedAt { get; set; }
    DateTimeOffset UpdatedAt { get; set; }
    string? CreatedBy { get; set; }
    string? UpdatedBy { get; set; }
}

public sealed class AuditInterceptor(ICurrentUserService currentUser) : SaveChangesInterceptor
{
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData data,
        InterceptionResult<int> result,
        CancellationToken ct = default)
    {
        if (data.Context is null) return new(result);

        var now = DateTimeOffset.UtcNow;
        var user = currentUser.UserId;

        foreach (var entry in data.Context.ChangeTracker.Entries<IAuditable>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedAt = now;
                    entry.Entity.CreatedBy = user;
                    entry.Entity.UpdatedAt = now;
                    entry.Entity.UpdatedBy = user;
                    break;

                case EntityState.Modified:
                    entry.Entity.UpdatedAt = now;
                    entry.Entity.UpdatedBy = user;
                    // Prevent tampering with CreatedAt/CreatedBy
                    entry.Property(e => e.CreatedAt).IsModified = false;
                    entry.Property(e => e.CreatedBy).IsModified = false;
                    break;
            }
        }

        return new(result);
    }
}
```

### Implementing Soft Delete

Instead of deleting rows, mark them with `IsDeleted = true`:

```csharp
public interface ISoftDeletable
{
    bool IsDeleted { get; set; }
    DateTimeOffset? DeletedAt { get; set; }
    string? DeletedBy { get; set; }
}

public sealed class SoftDeleteInterceptor(ICurrentUserService currentUser) : SaveChangesInterceptor
{
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData data,
        InterceptionResult<int> result,
        CancellationToken ct = default)
    {
        if (data.Context is null) return new(result);

        foreach (var entry in data.Context.ChangeTracker.Entries<ISoftDeletable>())
        {
            if (entry.State != EntityState.Deleted) continue;

            entry.State = EntityState.Modified;    // redirect: DELETE → UPDATE
            entry.Entity.IsDeleted = true;
            entry.Entity.DeletedAt = DateTimeOffset.UtcNow;
            entry.Entity.DeletedBy = currentUser.UserId;
        }

        return new(result);
    }
}
```

Combine with a global query filter to automatically exclude soft-deleted records:

```csharp
// In DbContext.OnModelCreating:
modelBuilder.Entity<Order>().HasQueryFilter(o => !o.IsDeleted);
```

[See: global-query-filters.md](./global-query-filters.md)

### Dispatching Domain Events After Commit

```csharp
public sealed class DomainEventInterceptor(IEventDispatcher dispatcher) : SaveChangesInterceptor
{
    private readonly List<IDomainEvent> _events = [];

    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData data,
        InterceptionResult<int> result,
        CancellationToken ct = default)
    {
        if (data.Context is null) return new(result);

        // Collect all domain events from entities before save
        _events.AddRange(
            data.Context.ChangeTracker
                .Entries<IHasDomainEvents>()
                .SelectMany(e => e.Entity.DomainEvents));

        // Clear events from entities to prevent double-dispatch on retry
        foreach (var entry in data.Context.ChangeTracker.Entries<IHasDomainEvents>())
            entry.Entity.ClearDomainEvents();

        return new(result);
    }

    public override async ValueTask<int> SavedChangesAsync(
        SaveChangesCompletedEventData data,
        int result,
        CancellationToken ct = default)
    {
        // Dispatch only after successful commit
        foreach (var ev in _events)
            await dispatcher.DispatchAsync(ev, ct);

        _events.Clear();
        return result;
    }
}
```

> **Important:** Dispatch events in `SavedChanges` (post-commit), not `SavingChanges` (pre-commit). If the DB transaction rolls back, events dispatched pre-commit would be orphaned.

### Registration

```csharp
services.AddScoped<AuditInterceptor>();
services.AddScoped<SoftDeleteInterceptor>();
services.AddScoped<DomainEventInterceptor>();

services.AddDbContext<AppDb>((sp, opt) =>
{
    opt.UseSqlServer(connStr)
       .AddInterceptors(
           sp.GetRequiredService<AuditInterceptor>(),
           sp.GetRequiredService<SoftDeleteInterceptor>(),
           sp.GetRequiredService<DomainEventInterceptor>());
});
```

### Limitations

- **Cannot make async DB calls from `SavingChanges`**: The interceptor shares the same DbContext and transaction. Don't call `db.X.FindAsync` inside `SavingChanges` — it re-enters the context mid-save.
- **Order matters**: Multiple interceptors are called in registration order. Ensure audit runs after soft-delete so that `DeletedAt` is picked up by the audit interceptor.
- **Scoped services require resolving via factory**: The DbContext options builder runs at registration time — you must resolve scoped interceptors from the service provider at request time (using `(sp, opt) =>` overload).

## Code Example

```csharp
// Combined audit + soft delete — complete registration example
builder.Services.AddDbContext<AppDb>((sp, opt) =>
{
    opt.UseSqlServer(builder.Configuration.GetConnectionString("Default"));

    // Register interceptors that depend on scoped services
    opt.AddInterceptors(
        sp.GetRequiredService<AuditInterceptor>(),       // sets CreatedAt/UpdatedAt
        sp.GetRequiredService<SoftDeleteInterceptor>(),  // redirects Delete → Update
        sp.GetRequiredService<DomainEventInterceptor>()); // dispatches events post-commit
});

// Entity
public class Order : IAuditable, ISoftDeletable, IHasDomainEvents
{
    public int Id { get; set; }
    public string Status { get; set; } = "";

    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? UpdatedBy { get; set; }

    public bool IsDeleted { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
    public string? DeletedBy { get; set; }

    private readonly List<IDomainEvent> _domainEvents = [];
    public IReadOnlyList<IDomainEvent> DomainEvents => _domainEvents.AsReadOnly();
    public void ClearDomainEvents() => _domainEvents.Clear();
    public void RaiseEvent(IDomainEvent e) => _domainEvents.Add(e);
}
```

## Common Follow-up Questions

- How does a `SaveChangesInterceptor` differ from overriding `SaveChanges` in the `DbContext` subclass?
- Can interceptors make additional database calls within the same transaction?
- How do you test `SaveChangesInterceptor` implementations in unit tests?
- What is the execution order when multiple interceptors are registered?
- How do you handle interceptors in multi-tenancy scenarios where the tenant context must be resolved?

## Common Mistakes / Pitfalls

- **Dispatching domain events in `SavingChanges` instead of `SavedChanges`**: Events dispatched before commit are published even if the transaction rolls back — causing ghost events for operations that never committed.
- **Accessing `ICurrentUserService` as a transient in a pooled DbContext**: If DbContext pooling is used, scoped services injected into the interceptor via the factory pattern (see registration) are correctly scoped. Directly injecting into a pooled context constructor will fail.
- **Mutating entities after `SavingChanges` without calling `DetectChanges`**: The interceptor sets properties on entities — these changes are already in `CurrentValues` and don't require a separate `DetectChanges` call because EF Core re-reads `CurrentValues` after the interceptor returns.
- **Infinite recursion from `SavingChanges` calling `db.SaveChanges`**: Any `SaveChanges` call from inside `SavingChanges` re-triggers all registered interceptors — infinite recursion and a stack overflow.
- **Forgetting to exclude `CreatedAt` from modification**: Without `entry.Property(e => e.CreatedAt).IsModified = false`, an `UPDATE` query will overwrite `CreatedAt` with the current timestamp, erasing the original creation time.

## References

- [Interceptors — EF Core — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/logging-events-diagnostics/interceptors)
- [DbCommandInterceptor / ISaveChangesInterceptor — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/logging-events-diagnostics/interceptors#savechanges-interception)
- [See: global-query-filters.md](./global-query-filters.md)
- [See: ef-core-logging-and-diagnostics.md](./ef-core-logging-and-diagnostics.md)
- [See: shadow-properties.md](./shadow-properties.md)
