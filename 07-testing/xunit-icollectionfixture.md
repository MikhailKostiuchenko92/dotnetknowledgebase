# What Is `ICollectionFixture<T>` and How Does It Differ from `IClassFixture<T>`?

**Category:** Testing / xUnit
**Difficulty:** 🟡 Middle
**Tags:** `xunit`, `ICollectionFixture`, `IClassFixture`, `test-fixture`, `shared-state`

## Question
> What is `ICollectionFixture<T>` and how does it differ from `IClassFixture<T>`?

## Short Answer
`IClassFixture<T>` shares one fixture instance across all tests *within a single test class*. `ICollectionFixture<T>` shares one fixture instance across *multiple test classes* that belong to the same named collection. Use `ICollectionFixture<T>` when an expensive resource (database, container, web server) must be shared across several test classes while still being created only once per test run.

## Detailed Explanation

### `IClassFixture<T>` — Per-Class Shared State
```csharp
public class MyTests : IClassFixture<DatabaseFixture>
{
    private readonly DatabaseFixture _db;
    public MyTests(DatabaseFixture db) => _db = db;
}
```
- One `DatabaseFixture` instance for all tests in `MyTests`.
- Another, separate `DatabaseFixture` instance for tests in `OtherTests` (if it also implements `IClassFixture<DatabaseFixture>`).

### `ICollectionFixture<T>` — Cross-Class Shared State
1. **Define the fixture** (same as before — just a POCO with optional `IAsyncLifetime`):
```csharp
public class SqlServerFixture : IAsyncLifetime
{
    public string ConnectionString { get; private set; } = default!;

    public async Task InitializeAsync()
        => ConnectionString = await StartSqlServerContainerAsync();

    public Task DisposeAsync() => StopContainerAsync();
}
```

2. **Define the collection** (marker class + attribute):
```csharp
[CollectionDefinition("SQL Server")]
public class SqlServerCollection : ICollectionFixture<SqlServerFixture> { }
```

3. **Apply to test classes**:
```csharp
[Collection("SQL Server")]
public class OrderRepositoryTests
{
    private readonly SqlServerFixture _db;
    public OrderRepositoryTests(SqlServerFixture db) => _db = db;
}

[Collection("SQL Server")]
public class CustomerRepositoryTests
{
    private readonly SqlServerFixture _db;
    public CustomerRepositoryTests(SqlServerFixture db) => _db = db;
}
```

`SqlServerFixture` is instantiated **once** and shared across both test classes. Its `Dispose` / `DisposeAsync` runs after all tests in both classes finish.

### Side-by-Side Comparison

| Feature | `IClassFixture<T>` | `ICollectionFixture<T>` |
|---|---|---|
| Scope | One test class | All classes in a named collection |
| Setup | Implement `IClassFixture<T>` on the class | `[CollectionDefinition]` + `[Collection]` attributes |
| Boilerplate | Minimal | Requires extra marker class |
| Parallelism | Each class can run in parallel | All classes in collection run **sequentially** |
| Best for | Per-class expensive resource | Shared DB, container, web server |

### Parallelism Warning
> ⚠️ All test classes in the same `[Collection]` run **sequentially** — xUnit prevents two classes in the same collection from running in parallel to avoid shared state corruption. This is intentional but can slow CI if overused.

### When to Use Each

| Use `IClassFixture<T>` | Use `ICollectionFixture<T>` |
|---|---|
| Each test class needs its own isolated instance | Multiple classes must share the same expensive object |
| Setup/teardown is fast (< 1s) | Setup is slow (container, DB, web server) |
| No state shared between classes needed | Multiple repositories, services, or endpoints tested against the same DB |

## Code Example
```csharp
namespace IntegrationTests;

// ── Shared fixture ────────────────────────────────────────────
public class WebAppFixture : IAsyncLifetime
{
    private WebApplicationFactory<Program>? _factory;
    public HttpClient Client { get; private set; } = default!;

    public async Task InitializeAsync()
    {
        _factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
                builder.ConfigureServices(services =>
                    services.AddSingleton<IWeatherService, FakeWeatherService>()));

        Client = _factory.CreateClient();
        await Task.CompletedTask;
    }

    public async Task DisposeAsync()
    {
        Client.Dispose();
        if (_factory is not null) await _factory.DisposeAsync();
    }
}

// ── Collection definition ─────────────────────────────────────
[CollectionDefinition("WebApp")]
public class WebAppCollection : ICollectionFixture<WebAppFixture> { }

// ── Test classes sharing the fixture ─────────────────────────
[Collection("WebApp")]
public class WeatherEndpointTests(WebAppFixture fixture)
{
    [Fact]
    public async Task GetWeather_Returns200()
    {
        var response = await fixture.Client.GetAsync("/weather");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}

[Collection("WebApp")]
public class HealthCheckTests(WebAppFixture fixture)
{
    [Fact]
    public async Task HealthCheck_ReturnsHealthy()
    {
        var response = await fixture.Client.GetAsync("/health");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }
}
```

## Common Follow-up Questions
- What happens to parallel execution when classes belong to the same collection?
- Can a test class belong to multiple collections?
- How do you share both class-level and collection-level fixtures simultaneously?
- How does `ICollectionFixture<T>` interact with `IAsyncLifetime`?
- What is the `[CollectionDefinition]` attribute and where should it be placed?
- Can you have multiple `ICollectionFixture<T>` types in one collection?

## Common Mistakes / Pitfalls
- **Missing `[CollectionDefinition]` marker class** — without the marker class, the `[Collection("name")]` attribute on the test class has no effect; each test class creates its own fixture.
- **Expecting parallel execution within a collection** — all classes in the same collection run sequentially; if you need parallelism, split into separate collections.
- **Mutating shared state in tests** — since the fixture is shared, tests that modify data leave it dirty for subsequent tests. Use database transactions, Respawn, or unique test data per test.
- **Mismatching collection names** — the string in `[CollectionDefinition("X")]` must exactly match `[Collection("X")]`; typos silently produce independent fixtures.
- **Overusing `ICollectionFixture`** — sharing too much state couples tests and creates order dependencies. Prefer isolated setups unless the resource cost is genuinely high.

## References
- [xUnit documentation — Shared context](https://xunit.net/docs/shared-context)
- [xUnit — ICollectionFixture](https://xunit.net/docs/shared-context#collection-fixture)
- [NuGet — xunit](https://www.nuget.org/packages/xunit/)
- [Andrew Lock — xUnit fixtures](https://andrewlock.net/making-your-db-tests-resilient-to-schema-changes-got-a-lot-easier-with-respawn-v6/) (verify URL)
