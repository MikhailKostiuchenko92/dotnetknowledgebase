# Infrastructure Layer Design

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🟡 Middle
**Tags:** `infrastructure-layer`, `clean-architecture`, `EF-Core`, `adapters`, `dependency-inversion`, `repositories`

## Question

> What is the Infrastructure layer's role in Clean Architecture? What types of code belong there, and how do you implement application-layer interfaces without coupling domain logic to persistence or external services?

## Short Answer

The Infrastructure layer implements the technical contracts (interfaces) defined in the Application layer using concrete technologies: EF Core for persistence, `HttpClient` for external APIs, messaging libraries for queues. It depends inward on Application and Domain — never the reverse. Its code is all "detail": how data is stored, how emails are sent, how external systems are called. The only place these details connect to business logic is via the interfaces — the Infrastructure layer writes the implementation; the Application layer only sees the interface.

## Detailed Explanation

### What Belongs in Infrastructure

| Concern | Concrete type | Implements |
|---------|---------------|------------|
| Relational persistence | `EfOrderRepository` | `IOrderRepository` |
| EF Core DbContext | `AppDbContext` | — |
| EF Core entity config | `OrderConfiguration : IEntityTypeConfiguration<Order>` | — |
| External HTTP APIs | `StripePaymentGateway` | `IPaymentGateway` |
| Email sending | `SendGridEmailSender` | `IEmailSender` |
| Message publishing | `RabbitMqEventPublisher` | `IEventPublisher` |
| File/blob storage | `AzureBlobFileStorage` | `IFileStorage` |
| Current user context | `HttpContextCurrentUser` | `ICurrentUser` |
| Time abstraction | `SystemClock` | `ISystemClock` |
| Background jobs | `HangfireJobScheduler` | `IJobScheduler` |

### EF Core DbContext in Infrastructure

The `AppDbContext` lives in Infrastructure and is invisible to Application and Domain:

```csharp
// Infrastructure/Persistence/AppDbContext.cs
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<Customer> Customers => Set<Customer>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
        => modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
}

// Infrastructure/Persistence/Configurations/OrderConfiguration.cs
public class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.HasKey(o => o.Id);
        builder.Property(o => o.Status).HasConversion<string>().IsRequired();
        builder.OwnsOne(o => o.Total, m =>
        {
            m.Property(x => x.Amount).HasColumnName("TotalAmount");
            m.Property(x => x.Currency).HasColumnName("TotalCurrency");
        });
        builder.HasMany(o => o.Lines).WithOne().OnDelete(DeleteBehavior.Cascade);
        // Map private backing field for Lines collection
        builder.Navigation(o => o.Lines).UsePropertyAccessMode(PropertyAccessMode.Field);
    }
}
```

### Implementing Driven Ports

Every driven port (interface from Application layer) gets an Infrastructure implementation:

```csharp
// IEmailSender is defined in Application.Contracts
public class SendGridEmailSender(IOptions<SendGridOptions> options, ILogger<SendGridEmailSender> log)
    : IEmailSender
{
    public async Task SendOrderConfirmationAsync(int customerId, int orderId, CancellationToken ct)
    {
        var client = new SendGridClient(options.Value.ApiKey);
        var msg = MailHelper.CreateSingleEmail(
            new EmailAddress(options.Value.FromAddress),
            new EmailAddress($"customer{customerId}@example.com"),
            $"Order #{orderId} Confirmed",
            $"Your order {orderId} has been placed.",
            null);
        var response = await client.SendEmailAsync(msg, ct);
        if (!response.IsSuccessStatusCode)
            log.LogWarning("SendGrid returned {StatusCode} for order {OrderId}", response.StatusCode, orderId);
    }
}
```

### Resilient HTTP Client

Infrastructure is the right place for `HttpClient` policies:

```csharp
// Infrastructure/DependencyInjection.cs
services
    .AddHttpClient<IInventoryClient, HttpInventoryClient>(client =>
    {
        client.BaseAddress = new Uri(config["InventoryService:BaseUrl"]!);
        client.Timeout = TimeSpan.FromSeconds(10);
    })
    .AddResilienceHandler("inventory-pipeline", builder =>
    {
        builder.AddRetry(new HttpRetryStrategyOptions
        {
            MaxRetryAttempts = 3,
            Delay = TimeSpan.FromMilliseconds(200),
            BackoffType = DelayBackoffType.Exponential
        });
        builder.AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
        {
            FailureRatio = 0.5,
            MinimumThroughput = 10,
            BreakDuration = TimeSpan.FromSeconds(30)
        });
    });
```

### DI Registration Pattern

```csharp
// Infrastructure/DependencyInjection.cs
public static IServiceCollection AddInfrastructure(
    this IServiceCollection services,
    IConfiguration config)
{
    services.AddDbContext<AppDbContext>(o =>
        o.UseSqlServer(config.GetConnectionString("Default"),
            sql => sql.EnableRetryOnFailure(3)));

    services.AddScoped<IOrderRepository, EfOrderRepository>();
    services.AddScoped<ICustomerRepository, EfCustomerRepository>();
    services.AddScoped<IEmailSender, SendGridEmailSender>();
    services.AddSingleton<ISystemClock, SystemClock>();
    services.Configure<SendGridOptions>(config.GetSection("SendGrid"));
    return services;
}
```

## Code Example

```csharp
// Full repository implementation showing private backing field access
public class EfOrderRepository(AppDbContext db) : IOrderRepository
{
    public async Task AddAsync(Order order, CancellationToken ct)
    {
        await db.Orders.AddAsync(order, ct);
        await db.SaveChangesAsync(ct);
    }

    public Task<Order?> GetByIdAsync(int id, CancellationToken ct)
        => db.Orders
            .Include(o => o.Lines)  // eager-load collection
            .FirstOrDefaultAsync(o => o.Id == id, ct);

    public async Task<IReadOnlyList<Order>> GetByCustomerAsync(int customerId, CancellationToken ct)
        => await db.Orders
            .Where(o => o.CustomerId == customerId)
            .OrderByDescending(o => o.Id)
            .ToListAsync(ct);

    // Unit of work: Application layer calls SaveChanges via IUnitOfWork
    // or Repository includes SaveChanges — pick one approach consistently
}

// Current-user adapter: bridges ASP.NET Core IHttpContextAccessor to ICurrentUser
public class HttpContextCurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    private ClaimsPrincipal User => accessor.HttpContext!.User;
    public int UserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    public bool IsAdmin => User.IsInRole("Admin");
}
```

## Common Follow-up Questions

- Should `SaveChangesAsync` be called inside the repository or by the application layer?
- How do you share an EF Core transaction between two repositories in a single use case?
- How do you write unit tests for application handlers without hitting the real infrastructure?
- How do you handle database migrations — does the Infrastructure layer trigger them?
- What is the IDbContextFactory pattern, and when would you use it in Infrastructure?

## Common Mistakes / Pitfalls

- **Putting EF Core query logic in the Application layer**: calling `db.Orders.Where(...).ToListAsync()` from a handler means swapping EF Core requires changing application code.
- **Making repository methods too granular or too generic**: one method per use case creates a bloated interface; a fully generic `IRepository<T>` leaks `IQueryable` to callers.
- **Injecting `AppDbContext` directly into Application handlers**: bypasses the repository abstraction, couples the handler to EF Core, and makes unit testing without a database impossible.
- **Placing config (e.g., connection strings) in the Domain layer**: connection strings, API keys, and URLs are infrastructure details — they belong in `appsettings.json` read by the Infrastructure DI registration.

## References

- [Infrastructure concerns in DDD — Microsoft Architecture Guides](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-implemetation-entity-framework-core)
- [See: clean-architecture-in-dotnet.md](./clean-architecture-in-dotnet.md)
- [See: application-layer-responsibilities.md](./application-layer-responsibilities.md)
- [See: domain-layer-design.md](./domain-layer-design.md)
- [See: repository-pattern.md](./repository-pattern.md)
