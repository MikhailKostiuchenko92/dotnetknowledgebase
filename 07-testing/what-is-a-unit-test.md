# What Is a Unit Test and How Does It Differ from an Integration Test?

**Category:** Testing / Fundamentals
**Difficulty:** 🟢 Junior
**Tags:** `unit-test`, `integration-test`, `testing-fundamentals`

## Question
> What is a unit test and how does it differ from an integration test?

## Short Answer
A unit test verifies the behaviour of a single, isolated unit of code — typically one class or method — with all external dependencies replaced by test doubles. An integration test verifies that two or more real components work correctly together (e.g., a service talking to a real database).

## Detailed Explanation

### What Is a "Unit"?
A *unit* is the smallest testable piece of behaviour in your codebase. In practice it maps to a single public method or a small cohesive class. The defining constraint is **isolation**: a unit test must not cross process, network, or file-system boundaries.

### Key Differences

| Property | Unit Test | Integration Test |
|---|---|---|
| Speed | Milliseconds | Seconds to minutes |
| Dependencies | All replaced with fakes/mocks | Real (or near-real) |
| Isolation | Full | Partial |
| Failure message | Pinpoints the exact unit | May require investigation |
| Setup complexity | Low | Medium–high |
| Feedback cycle | Immediate (runs on every save) | Slower (runs on CI or manually) |

### When to Use Each
- **Unit tests** form the bulk of your test suite. Use them for business logic, edge cases, and error-handling paths.
- **Integration tests** verify that components wire together correctly — EF Core mappings, serialization round-trips, HTTP client headers, message broker flow.

> ⚠️ **Common confusion:** Many developers call any test that avoids a network call a "unit test." The real boundary is whether *external infrastructure* (DB, disk, clock, random) is involved. If it is, the test is at least a narrow integration test — even if it runs quickly.

### Sociable vs. Solitary Unit Tests
Martin Fowler distinguishes two styles:
- **Solitary** — the class under test is the only real object; every collaborator is a mock/stub.
- **Sociable** — the test exercises a small cluster of real objects (e.g., a service + its domain model), only replacing I/O boundaries.

Neither is categorically better. Use solitary tests for complex algorithms; sociable tests can reduce over-mocking and catch real wiring bugs inside a module.

## Code Example
```csharp
// ── Unit test: zero real infrastructure ──────────────────────────────────────
namespace ShopApp.Tests.Unit;

public class OrderServiceTests
{
    [Fact]
    public void PlaceOrder_WhenPaymentSucceeds_ReturnsConfirmedOrder()
    {
        // Arrange
        var paymentGateway = new Mock<IPaymentGateway>();
        paymentGateway.Setup(g => g.Charge(It.IsAny<decimal>())).Returns(true);

        var sut = new OrderService(paymentGateway.Object);

        // Act
        var result = sut.PlaceOrder(new Cart { Total = 99.99m });

        // Assert
        result.Status.Should().Be(OrderStatus.Confirmed);
    }
}

// ── Integration test: real DbContext (SQLite in-memory) ──────────────────────
public class OrderRepositoryIntegrationTests : IClassFixture<DatabaseFixture>
{
    private readonly AppDbContext _db;

    public OrderRepositoryIntegrationTests(DatabaseFixture fixture)
        => _db = fixture.CreateContext();

    [Fact]
    public async Task SaveOrder_PersistsToDatabase()
    {
        var order = new Order { Total = 50m };
        _db.Orders.Add(order);
        await _db.SaveChangesAsync();

        var loaded = await _db.Orders.FindAsync(order.Id);
        loaded.Should().NotBeNull();
    }
}
```

## Common Follow-up Questions
- What is the testing pyramid and where do unit and integration tests sit within it?
- Can a test be both fast *and* use a real database (e.g., SQLite in-memory)?
- How do you handle dependencies that are hard to mock — static classes, `DateTime.Now`?
- What is the difference between a sociable and a solitary unit test?
- When does a unit test become too slow, and what do you do about it?
- How do you decide which layer of the pyramid to target for a given scenario?

## Common Mistakes / Pitfalls
- **Calling DB-hitting tests "unit tests"** — they are slower and flaky under concurrent CI runs.
- **Over-mocking** — mocking value objects or simple pure helpers adds noise without benefit.
- **Testing implementation details** — asserting on the number of repository calls (not outcomes) couples tests to internals and makes refactoring painful.
- **Shared mutable state between tests** — causes order-dependent failures that are hard to reproduce.
- **Ignoring integration tests entirely** — unit tests cannot catch misconfigured DI, SQL constraint violations, or serialization mismatches.

## References
- [Microsoft Learn — Unit testing in .NET](https://learn.microsoft.com/en-us/dotnet/core/testing/)
- [Martin Fowler — UnitTest](https://martinfowler.com/bliki/UnitTest.html)
- [Martin Fowler — IntegrationTest](https://martinfowler.com/bliki/IntegrationTest.html)
- [Vladimir Khorikov — Unit Testing Principles, Practices, and Patterns (Manning)](https://www.manning.com/books/unit-testing)
- [Andrew Lock — Integration testing in ASP.NET Core (series)](https://andrewlock.net/converting-integration-tests-to-use-webapplicationfactory/)
