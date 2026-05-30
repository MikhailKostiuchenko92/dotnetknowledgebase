# Unit of Work Pattern

**Category:** Data Access / Repository & Unit of Work Patterns
**Difficulty:** 🟡 Middle
**Tags:** `unit-of-work`, `transaction`, `DbContext`, `DDD`, `repository-pattern`, `SaveChanges`

## Question

> What is the Unit of Work pattern? How does it relate to the Repository pattern, and how does EF Core's `DbContext` already implement it? When do you need an explicit `IUnitOfWork` abstraction?

## Short Answer

The Unit of Work (UoW) pattern tracks all changes made during a business operation and flushes them to the database in a single transaction. It coordinates multiple repositories so that either all changes succeed together or none do. EF Core's `DbContext` **is** an implementation of Unit of Work — it tracks entity state changes and commits them atomically via `SaveChangesAsync`. An explicit `IUnitOfWork` interface is needed only when: (1) the domain layer must call "commit" without depending on `DbContext` directly, or (2) you want to compose multiple repositories under one explicit transaction boundary.

## Detailed Explanation

### EF Core as Unit of Work

`DbContext` satisfies the UoW contract out of the box:

```csharp
// DbContext internally does what Unit of Work describes:
var order = new Order(customerId: 1, total: 99.99m);
db.Orders.Add(order);  // registers: Added

var inventory = await db.InventoryItems.FindAsync(order.ProductId);
inventory.Reserve(order.Quantity);  // registers: Modified

// Single transaction — both changes committed atomically
await db.SaveChangesAsync(ct);
```

### When You Need IUnitOfWork

If the application layer (use-cases / commands) is not allowed to depend on `AppDbContext` directly (Clean Architecture constraint), you introduce an interface:

```csharp
// Application layer interface — no EF Core reference
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}

// Infrastructure implementation — DbContext already implements this contract
// Just implement the interface on your DbContext
public sealed class AppDbContext : DbContext, IUnitOfWork
{
    // DbContext.SaveChangesAsync already satisfies IUnitOfWork.SaveChangesAsync
}

// Or via adapter if you don't want DbContext to implement the interface
public sealed class EfUnitOfWork(AppDbContext db) : IUnitOfWork
{
    public Task<int> SaveChangesAsync(CancellationToken ct = default)
        => db.SaveChangesAsync(ct);
}
```

### Coordinating Multiple Repositories

```csharp
// Application layer — orchestrates two repositories + commit
public class PlaceOrderHandler(
    IOrderRepository orders,
    IInventoryRepository inventory,
    IUnitOfWork uow)
{
    public async Task HandleAsync(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var order = Order.Create(cmd.CustomerId, cmd.Lines);

        // Both work against the same DbContext internally
        await orders.AddAsync(order, ct);           // db.Orders.Add — staged
        await inventory.ReserveAsync(cmd.Lines, ct); // db.InventoryItems — staged

        // Single commit — both changes in one transaction
        await uow.SaveChangesAsync(ct);
    }
}
```

This works because both `OrderRepository` and `InventoryRepository` receive the **same `AppDbContext` instance** via scoped DI:

```csharp
// All three receive the same scoped AppDbContext
builder.Services.AddScoped<AppDbContext>();
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
builder.Services.AddScoped<IInventoryRepository, InventoryRepository>();
builder.Services.AddScoped<IUnitOfWork>(sp => sp.GetRequiredService<AppDbContext>());
```

### Unit of Work with Explicit Transaction

When you need to span the UoW across multiple `SaveChanges` calls (rare):

```csharp
public sealed class EfUnitOfWork(AppDbContext db) : IUnitOfWork, IAsyncDisposable
{
    private IDbContextTransaction? _tx;

    public async Task BeginAsync(CancellationToken ct = default)
        => _tx = await db.Database.BeginTransactionAsync(ct);

    public async Task<int> SaveChangesAsync(CancellationToken ct = default)
        => await db.SaveChangesAsync(ct);

    public async Task CommitAsync(CancellationToken ct = default)
    {
        await db.SaveChangesAsync(ct);
        if (_tx is not null) await _tx.CommitAsync(ct);
    }

    public async ValueTask DisposeAsync()
    {
        if (_tx is not null) await _tx.DisposeAsync();
    }
}
```

### UoW Scope = Request Scope

In ASP.NET Core, the DI scope = HTTP request. Each request gets its own `DbContext` (scoped), meaning:
- All changes in one request are tracked in one UoW.
- `SaveChangesAsync` commits all of them atomically.
- The DbContext is disposed at the end of the request.

This aligns naturally: one HTTP request = one unit of work.

## Code Example

```csharp
// Complete minimal setup — application layer does not reference EF Core
// Domain/Application projects
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}

public class TransferMoneyHandler(
    IAccountRepository accounts,
    ITransactionLogRepository txLog,
    IUnitOfWork uow)
{
    public async Task HandleAsync(TransferMoneyCommand cmd, CancellationToken ct)
    {
        var source = await accounts.GetByIdAsync(cmd.SourceAccountId, ct)
            ?? throw new NotFoundException("Source account not found");
        var target = await accounts.GetByIdAsync(cmd.TargetAccountId, ct)
            ?? throw new NotFoundException("Target account not found");

        source.Debit(cmd.Amount);   // domain logic
        target.Credit(cmd.Amount);  // domain logic

        await txLog.RecordAsync(
            new MoneyTransferEvent(cmd.SourceAccountId, cmd.TargetAccountId, cmd.Amount), ct);

        // One SaveChanges = one transaction = atomic
        await uow.SaveChangesAsync(ct);
    }
}

// Infrastructure project (separate project, references EF Core)
public class AppDbContext : DbContext, IUnitOfWork
{
    // IUnitOfWork.SaveChangesAsync is satisfied by DbContext.SaveChangesAsync
}
```

## Common Follow-up Questions

- Should repositories call `SaveChangesAsync`, or should only the Unit of Work call it?
- How do you handle domain events that should be dispatched after `SaveChanges` within the same transaction?
- Can you use EF Core's `ISaveChangesInterceptor` to dispatch domain events as part of the UoW commit?
- When would you NOT use the Unit of Work pattern?
- How does Dapper fit into a Unit of Work — how do you share a transaction between Dapper and EF Core?

## Common Mistakes / Pitfalls

- **Calling `SaveChangesAsync` inside repository methods**: each save is a separate transaction. If `OrderRepository.AddAsync` saves, and then `InventoryRepository.ReserveAsync` saves, the two operations are not atomic. An exception after the first save leaves the system in an inconsistent state.
- **Creating a new DbContext per repository**: if each repository gets its own `DbContext`, they have separate change trackers and cannot be committed in one transaction. All repositories must share the same scoped `DbContext` instance.
- **Overly complex UoW with `Begin/Commit/Rollback`**: in ASP.NET Core, the scoped `DbContext` pattern already handles transactional scope per request. Explicit `Begin/Commit/Rollback` in the UoW is only needed for multi-step operations that span multiple `SaveChanges` calls — which is rare.
- **Forgetting to dispose the transaction on exception**: if you use an explicit `IDbContextTransaction`, always `await tx.RollbackAsync()` or `await tx.DisposeAsync()` in a `finally` or `catch` block — or use `await using`.

## References

- [Unit of Work — Fowler PoEAA](https://martinfowler.com/eaaCatalog/unitOfWork.html) (verify URL)
- [DbContext as UoW and Repository — Microsoft Learn](https://learn.microsoft.com/en-us/ef/core/dbcontext-configuration/)
- [DDD microservices — infrastructure persistence layer — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design)
- [See: repository-pattern-basics.md](./repository-pattern-basics.md)
- [See: manual-transactions-ef-core.md](./manual-transactions-ef-core.md)
