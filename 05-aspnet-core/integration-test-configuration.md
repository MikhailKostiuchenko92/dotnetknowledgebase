# Integration Test Configuration in ASP.NET Core

**Category:** ASP.NET Core / Testing
**Difficulty:** 🟡 Middle
**Tags:** `integration-testing`, `appsettings`, `environment`, `IConfiguration`, `ConfigureServices`

## Question

> How do you configure an ASP.NET Core integration test environment — overriding `appsettings.json`, replacing services, and isolating tests from production dependencies?

## Short Answer

`WebApplicationFactory.WithWebHostBuilder()` (or subclassing) lets you call `ConfigureServices` to remove and replace registrations, and `ConfigureAppConfiguration` to inject test-specific `appsettings.Testing.json` values or in-memory key-value pairs. Combined with `UseEnvironment("Testing")`, this gives each test run a fully isolated configuration with real DI and real middleware but stub/in-memory infrastructure.

## Detailed Explanation

### Environment-specific settings

ASP.NET Core loads `appsettings.{Environment}.json` automatically. Create `appsettings.Testing.json` in the test project (or API project) and set `CopyToOutputDirectory = Always`:

```json
// appsettings.Testing.json
{
  "ConnectionStrings": {
    "DefaultConnection": "DataSource=:memory:"
  },
  "FeatureFlags": {
    "EnableBetaFeatures": false
  }
}
```

```csharp
protected override void ConfigureWebHost(IWebHostBuilder builder)
{
    builder.UseEnvironment("Testing");
    // Automatically picks up appsettings.Testing.json
}
```

### Injecting in-memory configuration values

```csharp
protected override void ConfigureWebHost(IWebHostBuilder builder)
{
    builder.ConfigureAppConfiguration((ctx, config) =>
    {
        config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:DefaultConnection"] = "DataSource=:memory:",
            ["Jwt:Issuer"] = "test-issuer",
            ["Jwt:Audience"] = "test-audience",
            ["ExternalApi:BaseUrl"] = "http://localhost:9999", // WireMock or stub
        });
    });
}
```

### Replacing services

```csharp
protected override void ConfigureWebHost(IWebHostBuilder builder)
{
    builder.ConfigureServices(services =>
    {
        // Remove real DbContext registration
        var descriptor = services.SingleOrDefault(d =>
            d.ServiceType == typeof(DbContextOptions<AppDbContext>));

        if (descriptor is not null)
            services.Remove(descriptor);

        // Add in-memory replacement
        services.AddDbContext<AppDbContext>(opts =>
            opts.UseInMemoryDatabase($"TestDb_{Guid.NewGuid()}"));

        // Replace an external HTTP dependency
        services.RemoveAll<IEmailService>();
        services.AddSingleton<IEmailService, FakeEmailService>();
    });
}
```

### Database seeding per test

```csharp
// CustomFactory.cs
public sealed class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder) =>
        builder.ConfigureServices(services =>
        {
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseInMemoryDatabase("IntegrationTestDb"));
        });

    public void SeedDatabase(Action<AppDbContext> seeder)
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Database.EnsureCreated();
        seeder(db);
        db.SaveChanges();
    }
}

// Usage in test
public class OrderTests : IClassFixture<CustomWebApplicationFactory>
{
    public OrderTests(CustomWebApplicationFactory factory)
    {
        factory.SeedDatabase(db =>
        {
            db.Users.Add(new User { Id = "user1", Email = "test@example.com" });
            db.Products.Add(new Product { Id = 1, Name = "Widget", Price = 9.99m });
        });
        _client = factory.CreateClient();
    }
}
```

### Scoped vs Singleton gotcha

`IClassFixture` shares one factory instance across all tests in the class. If you seed once in the constructor, all tests share that seed. For test isolation, reset the DB between tests:

```csharp
public async Task InitializeAsync()
{
    using var scope = _factory.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.EnsureDeletedAsync();
    await db.Database.EnsureCreatedAsync();
}
```

## Code Example

```csharp
// Factory with full configuration override
public sealed class IntegrationTestFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder
            .UseEnvironment("Testing")
            .ConfigureAppConfiguration((_, config) =>
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["ConnectionStrings:DefaultConnection"] = "DataSource=:memory:",
                }))
            .ConfigureServices(services =>
            {
                services.RemoveAll<DbContextOptions<AppDbContext>>();
                services.AddDbContext<AppDbContext>(o =>
                    o.UseSqlite("DataSource=:memory:"));

                services.RemoveAll<IEmailService>();
                services.AddSingleton<IEmailService>(_ => Substitute.For<IEmailService>());
            });
    }

    public async Task InitializeAsync()
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Database.EnsureCreatedAsync();
    }

    public new Task DisposeAsync() => Task.CompletedTask;
}
```

## Common Follow-up Questions

- How do you configure tests to use a real SQL Server (Testcontainers) instead of in-memory?
- How do you share a factory between multiple test classes without recreating it?
- Why is `UseInMemoryDatabase` sometimes insufficient as a test database?
- How do you override only a subset of configuration values without replacing the full `appsettings.json`?
- What is the order of configuration sources in `ConfigureAppConfiguration` and why does order matter?

## Common Mistakes / Pitfalls

- **Assuming shared `IClassFixture` database is isolated per test** — multiple tests modifying shared in-memory state cause flaky tests; always reset between tests or use unique DB names per test.
- **Not removing the original service before adding a replacement** — `ConfigureServices` *adds* to the existing collection; without removing first, you get two registrations (and the wrong one wins depending on ordering).
- **Using in-memory EF provider for tests that rely on SQL-specific behavior** — `UseInMemoryDatabase` does not enforce FK constraints, unique indexes, or SQL-specific query translation; use SQLite or Testcontainers for accurate tests.
- **Forgetting to set `ASPNETCORE_ENVIRONMENT=Testing`** — the test may load `appsettings.Production.json` accidentally, connecting to real databases.

## References

- [Microsoft Learn — Integration tests in ASP.NET Core](https://learn.microsoft.com/aspnet/core/test/integration-tests?view=aspnetcore-8.0)
- [Andrew Lock — Using IConfiguration in integration tests](https://andrewlock.net/how-to-override-configuration-in-aspnet-core-integration-tests/) (verify URL)
- [Testcontainers for .NET](https://dotnet.testcontainers.org)
