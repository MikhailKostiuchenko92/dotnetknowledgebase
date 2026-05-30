# DDD Anti-Patterns

**Category:** Architecture / Domain-Driven Design
**Difficulty:** 🔴 Senior
**Tags:** `DDD`, `anti-patterns`, `anemic-model`, `persistence-bleeding`, `entity-service`, `database-driven-design`

## Question

> What are the most common DDD anti-patterns? Describe the Entity-Service naming trap, database-driven design, and persistence bleeding into the domain. How do you recognize and fix them?

## Short Answer

The three most damaging DDD anti-patterns are: **Entity-Service naming trap** (naming application services after entities — `UserService`, `OrderService` — producing anemic models with scattered rules), **database-driven design** (designing the domain model from the DB schema rather than from business concepts, producing a model that reflects table structure instead of domain language), and **persistence bleeding** (EF Core attributes, `IQueryable`, DbContext, or navigation properties appearing in the domain layer, coupling business logic to infrastructure). All three symptoms share the same root cause: letting infrastructure or technical concerns dictate domain model design.

## Detailed Explanation

### Anti-Pattern 1: Entity-Service Naming Trap

Every entity gets a `XxxService` that does CRUD operations — the service has all the logic, the entity has none:

```csharp
// ❌ ENTITY-SERVICE TRAP
// OrderService with methods for every possible operation
public class OrderService
{
    public Order GetOrder(int id) => _repo.GetById(id);
    public void CreateOrder(OrderDto dto) { ... }
    public void UpdateOrder(int id, OrderDto dto) { ... }
    public void DeleteOrder(int id) { ... }
    public void SubmitOrder(int id) { if (order.Status != "P") ... order.Status = "S"; }
    public void CancelOrder(int id) { ... }
    public void AddLineToOrder(int id, OrderLineDto dto) { ... }
    // 20 more methods, each checking status, each duplicating validation
}

// Entity is empty
public class Order { public int Id; public string Status; public List<OrderLine> Lines; }

// Problem: every method must independently validate state transitions
// Problem: nothing prevents calling _repo.Save(badOrder) directly
// Problem: "cancel logic" is in OrderService, not in Order — it can be bypassed
```

**Fix**: push behavior onto the entity; keep the service as a thin use-case orchestrator:

```csharp
// ✅ Entity owns behavior and invariants
public class Order
{
    public void Submit() { /* enforces: must be pending, must have lines */ }
    public void Cancel(string reason) { /* enforces: only pending/submitted */ }
    public void AddLine(ProductId id, int qty, Money price) { /* enforces: draft only, positive qty */ }
}

// Application handler: thin orchestration only
public class SubmitOrderHandler(IOrderRepository orders) : IRequestHandler<SubmitOrderCommand>
{
    public async Task Handle(SubmitOrderCommand cmd, CancellationToken ct)
    {
        var order = await orders.GetByIdAsync(cmd.OrderId, ct);
        order.Submit(); // ← domain enforces the rule
        await orders.SaveAsync(order, ct);
    }
}
```

### Anti-Pattern 2: Database-Driven Design

Designing domain classes that mirror the database schema:

```csharp
// ❌ DATABASE-DRIVEN DESIGN
// Table: tbl_ord with columns OrdId, CustId, Stat, TotAmt, TotCur
public class tbl_ord  // ← named after table
{
    public int OrdId { get; set; }    // ← column name in code
    public int CustId { get; set; }
    public int Stat { get; set; }     // ← integer status code, not enum
    public decimal TotAmt { get; set; }
    public string TotCur { get; set; } = "";
    // ← no behavior, no invariants, no ubiquitous language
}
```

Signals:
- Class names match table names (`tbl_order`, `user_account`)
- Property names match column names (`Stat`, `CustId`, `TotAmt`)
- All properties are primitive types — no value objects
- No meaningful methods on the class

**Fix**: design from business concepts; let the EF Core configuration handle the mapping:

```csharp
// ✅ Domain-first design
public class Order : AggregateRoot        // ← domain concept
{
    public OrderId Id { get; private set; }
    public CustomerId CustomerId { get; private set; }
    public OrderStatus Status { get; private set; }  // ← meaningful enum
    public Money Total { get; private set; }          // ← value object
    // ...behavior...
}

// EF Core maps this to whatever the DB schema requires
```

### Anti-Pattern 3: Persistence Bleeding into the Domain

Infrastructure concerns appearing in the domain layer:

```csharp
// ❌ PERSISTENCE BLEEDING
using Microsoft.EntityFrameworkCore;  // ← EF Core in Domain project!

[Table("Orders")]                     // ← EF Core attribute
public class Order
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int Id { get; set; }

    [Required]
    [MaxLength(50)]
    public string Status { get; set; } = "";

    public virtual ICollection<OrderLine> Lines { get; set; } = [];  // ← virtual = lazy loading proxy

    // Domain method that calls the context directly
    public void Submit(AppDbContext db)  // ← DbContext in domain method!
    {
        Status = "Submitted";
        db.SaveChanges();
    }
}
```

**Fix**: use EF Core Fluent API in Infrastructure to map the clean domain class:

```csharp
// ✅ Domain layer: zero EF Core references
namespace YourApp.Domain.Entities;

public class Order : AggregateRoot
{
    public OrderId Id { get; private set; }
    public OrderStatus Status { get; private set; }
    private readonly List<OrderLine> _lines = [];

    public void Submit()
    {
        Status = OrderStatus.Submitted;
        Raise(new OrderSubmittedEvent(Id));
    }
}

// Infrastructure layer: EF Core Fluent API maps the domain class
public class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.ToTable("Orders");
        builder.HasKey(o => o.Id);
        builder.Property(o => o.Status).HasConversion<string>().IsRequired().HasMaxLength(50);
        builder.Navigation(o => o.Lines).UsePropertyAccessMode(PropertyAccessMode.Field);
    }
}
```

### Anti-Pattern 4: "CRUD-over-DDD" — Applying DDD to Simple Domains

Over-engineering CRUD-heavy domains with aggregates, domain events, and value objects:

```csharp
// ❌ DDD for a settings page — overkill
public class UserSettings : AggregateRoot
{
    public void ChangeTheme(Theme theme)
    {
        _theme = theme;
        Raise(new UserThemeChangedEvent(UserId, theme));
    }
}
```

**Fix**: apply DDD only to the **core domain** — where the business rules are complex and worth protecting. Use simple CRUD for supporting/generic subdomains.

## Code Example

```csharp
// NetArchTest: enforce no EF Core in Domain project
[Fact]
public void Domain_Must_Have_No_EFCore_References()
{
    var result = Types.InAssembly(typeof(Order).Assembly)
        .ShouldNot()
        .HaveDependencyOnAny(
            "Microsoft.EntityFrameworkCore",
            "System.Data",
            "Dapper")
        .GetResult();

    Assert.True(result.IsSuccessful,
        $"Persistence bleeding violations: {string.Join(", ", result.FailingTypeNames ?? [])}");
}

// NetArchTest: no public setters on domain entities (catches anemic model drift)
[Fact]
public void Domain_Entities_Should_Use_Private_Setters()
{
    // Custom check using reflection
    var entityTypes = typeof(Order).Assembly.GetTypes()
        .Where(t => t.IsSubclassOf(typeof(AggregateRoot)) || t.IsSubclassOf(typeof(Entity)));

    var violations = entityTypes
        .SelectMany(t => t.GetProperties())
        .Where(p => p.SetMethod?.IsPublic == true)
        .Select(p => $"{p.DeclaringType!.Name}.{p.Name}")
        .ToList();

    Assert.Empty(violations);
}
```

## Common Follow-up Questions

- How do you incrementally refactor an anemic model to a rich model without breaking existing code?
- What is the "Aggregate-Service-Repository" trinity trap, and how do you escape it?
- How do you identify which parts of a codebase have DDD applied correctly vs incorrectly?
- What is the cost of applying DDD to the wrong subdomain (supporting vs core)?
- How does the Result/Option pattern help avoid exception-driven domain logic?

## Common Mistakes / Pitfalls

- **Mistaking complexity for DDD value**: applying tactical DDD patterns (aggregates, VOs, domain events) to a user settings screen or a product catalog adds complexity with no domain invariant benefit.
- **Creating domain services for every operation**: a `OrderDomainService.Submit()` that just calls `order.Status = "Submitted"` is the Entity-Service trap in disguise — with an extra wrapper.
- **Virtual properties for lazy loading**: `virtual ICollection<OrderLine> Lines` enables EF Core lazy loading, which can trigger N+1 queries silently and makes the domain model dependent on EF Core proxies.
- **DbContext in application code via service locator**: calling `ServiceLocator.Get<AppDbContext>()` from inside an aggregate or domain service bypasses the entire dependency inversion model.

## References

- [Anemic Domain Model — Martin Fowler](https://martinfowler.com/bliki/AnemicDomainModel.html) (verify URL)
- [DDD common pitfalls — Vladimir Khorikov](https://enterprisecraftsmanship.com/posts/domain-driven-design-vs-plain-old-objects/) (verify URL)
- [See: anemic-vs-rich-domain-model.md](./anemic-vs-rich-domain-model.md)
- [See: domain-layer-design.md](./domain-layer-design.md)
- [See: fitness-functions.md](./fitness-functions.md)
