# How Do You Override Services in `WebApplicationFactory`?

**Category:** Testing / Integration Testing in ASP.NET Core
**Difficulty:** 🟡 Middle
**Tags:** `WebApplicationFactory`, `WithWebHostBuilder`, `ConfigureTestServices`, `service-override`

## Question
> How do you override services (e.g., replace a real DB with an in-memory one) in `WebApplicationFactory`?

## Short Answer
Call `.WithWebHostBuilder(builder => builder.ConfigureTestServices(services => ...))` to replace or remove registrations after the production `Program.cs` has run. `ConfigureTestServices` runs after the app's `ConfigureServices`, so your test registrations win over production ones. This is the standard way to swap a real database for an in-memory provider, replace an external service with a stub, or inject test-only behaviour.

## Detailed Explanation

### Basic Override Pattern
```csharp
var factory = new WebApplicationFactory<Program>()
    .WithWebHostBuilder(builder =>
    {
        builder.ConfigureTestServices(services =>
        {
            // Remove real DbContext
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor != null) services.Remove(descriptor);

            // Add in-memory DbContext
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseInMemoryDatabase("TestDb"));
        });
    });
```

### Why `ConfigureTestServices` Not `ConfigureServices`
`ConfigureTestServices` is called AFTER the app's own registrations, so it can override them. `ConfigureServices` (on `IWebHostBuilder`) is called before and may be overridden by the app's own startup.

### Custom Factory Class (Recommended for Multiple Tests)
```csharp
public class TestWebAppFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureTestServices(services =>
        {
            // Replace real DB
            services.RemoveDbContext<AppDbContext>();
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseSqlite("DataSource=:memory:"));

            // Replace email service with a stub
            services.AddSingleton<IEmailService, FakeEmailService>();
        });
    }
}

public class OrdersApiTests : IClassFixture<TestWebAppFactory>
{
    private readonly HttpClient _client;
    public OrdersApiTests(TestWebAppFactory factory)
        => _client = factory.CreateClient();
}
```

### Seeding the Database
```csharp
protected override void ConfigureWebHost(IWebHostBuilder builder)
{
    builder.ConfigureTestServices(services =>
    {
        services.RemoveDbContext<AppDbContext>();
        services.AddDbContext<AppDbContext>(opts =>
            opts.UseSqlite("DataSource=:memory:"));

        // Seed after build
        var sp = services.BuildServiceProvider();
        using var scope = sp.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Database.EnsureCreated();
        db.Products.AddRange(SeedData.Products);
        db.SaveChanges();
    });
}
```

### Extension Helper
```csharp
public static class ServiceCollectionExtensions
{
    public static void RemoveDbContext<T>(this IServiceCollection services)
        where T : DbContext
    {
        var descriptor = services.SingleOrDefault(d =>
            d.ServiceType == typeof(DbContextOptions<T>));
        if (descriptor != null) services.Remove(descriptor);
    }
}
```

## Code Example
```csharp
namespace Integration.Tests;

public class TestWebAppFactory : WebApplicationFactory<Program>
{
    public FakeEmailService EmailService { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureTestServices(services =>
        {
            services.RemoveDbContext<AppDbContext>();
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseSqlite("DataSource=:memory:"));

            services.AddSingleton<IEmailService>(EmailService);
        });
    }
}

public class RegistrationApiTests : IClassFixture<TestWebAppFactory>
{
    private readonly HttpClient _client;
    private readonly FakeEmailService _emailService;

    public RegistrationApiTests(TestWebAppFactory factory)
    {
        _client = factory.CreateClient();
        _emailService = factory.EmailService;
    }

    [Fact]
    public async Task Register_ValidUser_ReturnsCreated_AndSendsWelcomeEmail()
    {
        var request = new { Email = "bob@example.com", Password = "P@ssw0rd!" };
        var response = await _client.PostAsJsonAsync("/api/users", request);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        _emailService.SentEmails.Should().ContainSingle(e =>
            e.To == "bob@example.com" && e.Subject.Contains("Welcome"));
    }
}

public class FakeEmailService : IEmailService
{
    public List<(string To, string Subject)> SentEmails { get; } = [];
    public Task SendAsync(string to, string subject, string body)
    {
        SentEmails.Add((to, subject));
        return Task.CompletedTask;
    }
}
```

## Common Follow-up Questions
- What is the difference between `ConfigureTestServices` and `ConfigureServices` in `WebApplicationFactory`?
- How do you seed test data into the in-memory database?
- How do you access custom services (e.g., `FakeEmailService`) from the test?
- How do you reset database state between tests in a shared factory?
- What is `services.RemoveAll<T>()` and when do you use it over `Remove(descriptor)`?
- How do you configure test-specific `appsettings` (e.g., `appsettings.Testing.json`)?

## Common Mistakes / Pitfalls
- **Using `ConfigureServices` instead of `ConfigureTestServices`** — app's own registrations run after and override yours; `ConfigureTestServices` is the correct hook.
- **Not removing the original `DbContextOptions`** — adding a second registration causes ambiguity; always remove the original before adding the test one.
- **Seeding in `ConfigureTestServices` but DB is per-test** — if each test creates a new scope/DB, seed must happen per test, not just during factory setup.
- **Sharing mutable fake services across tests** — `FakeEmailService.SentEmails` accumulates across tests in `IClassFixture`; clear it in test constructor or use `IAsyncLifetime`.
- **Forgetting `builder.UseEnvironment("Testing")`** — production environment-specific services (e.g., real Azure Storage) may still be registered.

## References
- [Microsoft Learn — Integration tests — `ConfigureTestServices`](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests#customize-webapplicationfactory)
- [NuGet — Microsoft.AspNetCore.Mvc.Testing](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc.Testing/)
- [Andrew Lock — Replacing services in WebApplicationFactory](https://andrewlock.net/converting-integration-tests-to-net-core-3/) (verify URL)
