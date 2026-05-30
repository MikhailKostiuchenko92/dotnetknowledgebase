# What Is `IClassFixture<T>` and When Would You Use It?

**Category:** Testing / xUnit
**Difficulty:** 🟡 Middle
**Tags:** `xunit`, `IClassFixture`, `shared-context`, `test-fixture`, `setup`

## Question
> What is `IClassFixture<T>` and when would you use it?

## Short Answer
`IClassFixture<T>` is xUnit's mechanism for creating a single shared instance of `T` for all tests in a test class. The fixture is created once before the first test, injected via the constructor, and disposed after the last test. Use it for expensive, read-only resources like database schemas, HTTP servers, or external connections.

## Detailed Explanation

### The Problem It Solves
xUnit's default model creates a new test class instance per test (see [xunit-test-class-instantiation.md](xunit-test-class-instantiation.md)). This is perfect for cheap, in-memory setup. But for expensive setup — spinning up a `WebApplicationFactory`, creating a database schema, or starting a Testcontainer — recreating it for every test wastes significant time.

`IClassFixture<T>` creates `T` **once per test class** and injects it into every test constructor.

### Lifecycle

```
[TestClass begins]
  new T() (fixture created, InitializeAsync called if IAsyncLifetime)
    new TestClass(T fixture) → Run Test1 → Dispose
    new TestClass(T fixture) → Run Test2 → Dispose
    new TestClass(T fixture) → Run Test3 → Dispose
  T.Dispose() / DisposeAsync() called
[TestClass ends]
```

### Usage Pattern
1. Create a fixture class (can implement `IDisposable` or `IAsyncLifetime`).
2. Implement `IClassFixture<MyFixture>` on the test class.
3. Receive the fixture as a constructor parameter.

> ⚠️ **Warning:** Tests that *mutate* the shared fixture state can interfere with each other. Only share **read-only** or **reset-between-tests** state via `IClassFixture`. For cross-class sharing, use `ICollectionFixture<T>` (see [xunit-icollectionfixture.md](xunit-icollectionfixture.md)).

### When to Use It
| Use case | Appropriate? |
|---|---|
| Start a `WebApplicationFactory<Program>` once | ✅ Yes |
| Create a SQLite in-memory schema once | ✅ Yes |
| Start a Testcontainer (PostgreSQL) | ✅ Yes |
| Share a mock across tests | ❌ No — mocks have per-test setup; use fresh mocks |
| Share a `DbContext` that tests write to | ⚠️ Risky — data from one test persists into the next |

## Code Example
```csharp
namespace Api.Tests;

// 1. Define the fixture — expensive resource created once
public class ApiFixture : IAsyncLifetime
{
    private WebApplicationFactory<Program> _factory = null!;
    public HttpClient Client { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        _factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(b =>
                b.ConfigureServices(services =>
                    services.AddSingleton<IEmailSender, FakeEmailSender>()));

        Client = _factory.CreateClient();
        // Optionally seed data here
    }

    public async Task DisposeAsync()
    {
        Client.Dispose();
        await _factory.DisposeAsync();
    }
}

// 2. Consume the fixture — created once, injected per test instance
public class ProductsApiTests : IClassFixture<ApiFixture>
{
    private readonly HttpClient _client;

    public ProductsApiTests(ApiFixture fixture)
        => _client = fixture.Client; // reuse the same server instance

    [Fact]
    public async Task GetProducts_ReturnsOk()
    {
        var response = await _client.GetAsync("/products");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task GetProduct_WhenNotFound_Returns404()
    {
        var response = await _client.GetAsync("/products/99999");
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }
}
```

## Common Follow-up Questions
- What is the difference between `IClassFixture<T>` and `ICollectionFixture<T>`?
- How do you share a fixture across multiple test classes?
- How does xUnit know to inject the fixture into the constructor?
- What happens if the fixture's `InitializeAsync` throws?
- Can you use `IClassFixture<T>` and `IDisposable` on the same test class?
- How do you reset mutable state in a shared fixture between tests?

## Common Mistakes / Pitfalls
- **Mutating shared state in the fixture** — tests that write to the shared DB leave data that affects subsequent tests; always reset state or use a per-test transaction rollback.
- **Putting mock setup in the fixture** — mocks need per-test `Setup()` calls; shared mocks will have stale or bleeding configuration.
- **Creating a fixture for cheap resources** — if setup takes <10 ms, use the constructor; `IClassFixture` adds complexity.
- **Forgetting `IAsyncLifetime`** — if setup is async (e.g., `EnsureCreatedAsync`), not implementing `IAsyncLifetime` means setup happens in a fire-and-forget `Task` that may not complete before tests run.
- **Sharing a mutable `DbContext`** — `DbContext` is not thread-safe; sharing it across parallel tests causes exceptions.

## References
- [xUnit documentation — Shared context between tests (IClassFixture)](https://xunit.net/docs/shared-context#class-fixture)
- [Microsoft Learn — Integration tests in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests)
- [Andrew Lock — Integration testing in ASP.NET Core with WebApplicationFactory](https://andrewlock.net/converting-integration-tests-to-use-webapplicationfactory/)
- [xUnit GitHub — IClassFixture source](https://github.com/xunit/xunit/blob/main/src/xunit.v3.core/IClassFixture.cs)
