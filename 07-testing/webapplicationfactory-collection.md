# How Do You Share a Single `WebApplicationFactory` Instance Across an Entire Test Collection?

**Category:** Testing / Integration Testing in ASP.NET Core
**Difficulty:** 🔴 Senior
**Tags:** `WebApplicationFactory`, `ICollectionFixture`, `test-collection`, `xUnit`, `shared-fixture`

## Question
> How do you share a single `WebApplicationFactory` instance across an entire test collection?

## Short Answer
Use xUnit's `ICollectionFixture<T>`. Create a collection definition with `[CollectionDefinition]` and `ICollectionFixture<TFactory>`, then mark each test class with the matching `[Collection("name")]` attribute. This ensures one factory (and its `TestServer`) is created once for all test classes in the collection, significantly reducing test suite startup time.

## Detailed Explanation

### Without Collection Fixture: One Factory Per Class
```csharp
// Each class creates its own factory — expensive!
public class OrderTests : IClassFixture<WebApplicationFactory<Program>> { }
public class ProductTests : IClassFixture<WebApplicationFactory<Program>> { }
// Two factories, two TestServer instances, two DI container builds
```

### With `ICollectionFixture`: One Factory for All
```csharp
// 1. Custom factory with test overrides
public class IntegrationTestFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureTestServices(services =>
        {
            services.RemoveDbContext<AppDbContext>();
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseSqlite("DataSource=:memory:"));
        });
    }
}

// 2. Collection definition — empty marker class
[CollectionDefinition("Integration")]
public class IntegrationCollection : ICollectionFixture<IntegrationTestFactory> { }

// 3. Test classes — all share one factory instance
[Collection("Integration")]
public class OrderTests
{
    private readonly HttpClient _client;
    public OrderTests(IntegrationTestFactory factory)
        => _client = factory.CreateClient();
}

[Collection("Integration")]
public class ProductTests
{
    private readonly HttpClient _client;
    public ProductTests(IntegrationTestFactory factory)
        => _client = factory.CreateClient();
}
```

> ⚠️ All test classes in the same collection run **sequentially**, not in parallel. This is intentional — shared state (one DB) would cause race conditions.

### Accessing the Factory's Services
```csharp
[Collection("Integration")]
public class OrderTests(IntegrationTestFactory factory)
{
    [Fact]
    public async Task GetOrder_AfterSeeding_ReturnsIt()
    {
        // Seed via factory's DI
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        db.Orders.Add(new Order { Id = 77, Amount = 99m });
        await db.SaveChangesAsync();

        var response = await factory.CreateClient().GetAsync("/api/orders/77");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
```

### Managing Shared State Between Tests
Since the DB is shared, one test's data affects the next. Strategies:
1. **Use unique IDs per test** — avoid overlap
2. **Wrap each test in a transaction and roll back** — requires transaction support
3. **Use Respawn** — reset tables between tests (see [seed-and-reset-database.md](seed-and-reset-database.md))
4. **Use separate SQLite in-memory DB per test class** — override `ConnectionString` per class

## Code Example
```csharp
namespace Integration.Tests;

// ── Shared fixture ─────────────────────────────────────────
public class ApiTestFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly SqliteConnection _connection = new("DataSource=:memory:");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureTestServices(services =>
        {
            services.RemoveDbContext<AppDbContext>();
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseSqlite(_connection)); // reuse connection = shared in-memory DB
        });
    }

    public async Task InitializeAsync()
    {
        await _connection.OpenAsync();
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Database.EnsureCreatedAsync();
    }

    public new async Task DisposeAsync()
    {
        await _connection.DisposeAsync();
        await base.DisposeAsync();
    }
}

[CollectionDefinition("Api")]
public class ApiCollection : ICollectionFixture<ApiTestFactory> { }

[Collection("Api")]
public class OrderEndpointTests(ApiTestFactory factory)
{
    [Fact]
    public async Task GetOrders_Returns200() =>
        (await factory.CreateClient().GetAsync("/api/orders")).StatusCode
            .Should().Be(HttpStatusCode.OK);
}

[Collection("Api")]
public class ProductEndpointTests(ApiTestFactory factory)
{
    [Fact]
    public async Task GetProducts_Returns200() =>
        (await factory.CreateClient().GetAsync("/api/products")).StatusCode
            .Should().Be(HttpStatusCode.OK);
}
```

## Common Follow-up Questions
- What is the difference between `IClassFixture<T>` and `ICollectionFixture<T>`?
- Why do all test classes in a collection run sequentially?
- How do you reset the shared database between integration tests?
- Can you have multiple `ICollectionFixture<T>` types in one collection?
- How do you access the factory's `IServiceProvider` from a test?
- What happens if two test collections use the same factory type?

## Common Mistakes / Pitfalls
- **Forgetting the marker class** — `[CollectionDefinition]` must be on a class that also implements `ICollectionFixture<T>`; omitting it means the collection has no fixture.
- **Collection name mismatch** — `[CollectionDefinition("Api")]` and `[Collection("API")]` (different case) don't match; fixtures are not shared.
- **Expecting parallel execution within a collection** — sequential only; if you need parallelism, split into separate collections.
- **Shared in-memory SQLite DB without isolating tests** — test A inserts an order; test B asserts empty DB; test B fails. Use unique IDs or Respawn.
- **Using `new WebApplicationFactory<Program>()` inside test methods** — creates a new factory each time; always inject the shared one.

## References
- [xUnit documentation — Collection fixtures](https://xunit.net/docs/shared-context#collection-fixture)
- [Microsoft Learn — Integration tests in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests)
- [NuGet — Microsoft.AspNetCore.Mvc.Testing](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc.Testing/)
