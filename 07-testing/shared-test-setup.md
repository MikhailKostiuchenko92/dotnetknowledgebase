# How Do You Handle Shared Test Setup Without Creating Hidden Coupling Between Tests?

**Category:** Testing / Test Design & Best Practices
**Difficulty:** 🟡 Middle
**Tags:** `test-setup`, `shared-state`, `IClassFixture`, `constructor`, `test-isolation`

## Question
> How do you handle shared test setup without creating hidden coupling between tests?

## Short Answer
Use the **constructor** for setup that creates fresh state per test (xUnit's default lifecycle), `IClassFixture<T>` for expensive read-only shared objects, and Test Data Builders or helper methods for reusable object creation. Avoid shared *mutable* state between tests — every test should set up exactly what it needs and leave no side effects for others.

## Detailed Explanation

### The Problem: Hidden Coupling
```csharp
// ❌ Shared mutable state — tests can silently affect each other
public class OrderTests
{
    private static readonly List<Order> _orders = new();

    [Fact]
    public void AddOrder_IncreasesCount()
    {
        _orders.Add(new Order());
        _orders.Count.Should().Be(1); // fails if another test ran first!
    }
}
```

### Option 1: Constructor for Per-Test Setup (xUnit)
xUnit creates a new test class instance per test method — constructor is the ideal place for fresh per-test setup:
```csharp
public class OrderServiceTests
{
    private readonly OrderService _sut;
    private readonly Mock<IOrderRepository> _repo;

    public OrderServiceTests() // runs before EACH test
    {
        _repo = new Mock<IOrderRepository>();
        _sut = new OrderService(_repo.Object);
    }
}
```
Each test gets its own `_repo` and `_sut` — no shared mutable state.

### Option 2: `IClassFixture<T>` for Expensive Read-Only Resources
```csharp
public class DatabaseTests : IClassFixture<SqliteFixture>
{
    private readonly SqliteFixture _db;
    public DatabaseTests(SqliteFixture db) => _db = db; // shared, read-only
}
```
The fixture is created once. Tests must NOT mutate it. Good for: database schema, `HttpClient`, `WebApplicationFactory`.

### Option 3: Helper Methods for Reusable Object Creation
```csharp
// Extract object creation to avoid duplication without sharing state
private static Order CreateValidOrder(decimal amount = 100m) =>
    new() { Id = 1, Amount = amount, Status = OrderStatus.Pending };

[Fact]
public void Process_ValidOrder_ReturnsConfirmed()
{
    var order = CreateValidOrder(); // fresh object every time
    // ...
}
```

### Option 4: Test Data Builders
See [test-data-builder.md](test-data-builder.md) for the full pattern.

### Checklist: Avoiding Hidden Coupling

| Practice | Safe? |
|---|---|
| `static readonly` fields for constants (strings, ints) | ✅ |
| `static readonly` fields for mock instances | ❌ (mock state carries over) |
| New object per test via constructor | ✅ |
| `IClassFixture<T>` for read-only shared resource | ✅ |
| `IClassFixture<T>` for a shared DB that tests mutate | ❌ |
| `[SetUp]` in NUnit that resets state before each test | ✅ |
| `[OneTimeSetUp]` for mutable state | ❌ |

## Code Example
```csharp
namespace SharedSetup.Tests;

// ❌ Problem: static mutable field
public class CartService_WithStaticField_Tests
{
    private static readonly Mock<ICartRepository> _repo = new(); // shared between tests!

    [Fact]
    public void AddItem_IncreasesCount()
    {
        _repo.Setup(r => r.GetCart(1)).Returns(new Cart { Items = [] });
        var sut = new CartService(_repo.Object);
        sut.AddItem(cartId: 1, productId: 5);
        _repo.Verify(r => r.Save(It.IsAny<Cart>()), Times.Once);
        // Second test may see stale setups / verifications from this test
    }
}

// ✅ Solution: constructor creates fresh state per test
public class CartService_WithConstructor_Tests
{
    private readonly Mock<ICartRepository> _repo;
    private readonly CartService _sut;

    public CartService_WithConstructor_Tests() // fresh per test
    {
        _repo = new Mock<ICartRepository>(); // new instance each time
        _sut = new CartService(_repo.Object);
    }

    [Fact]
    public void AddItem_CallsRepositorySave()
    {
        _repo.Setup(r => r.GetCart(1)).Returns(new Cart { Items = [] });
        _sut.AddItem(cartId: 1, productId: 5);
        _repo.Verify(r => r.Save(It.IsAny<Cart>()), Times.Once);
    }

    [Fact]
    public void AddItem_DuplicateProduct_DoesNotAddTwice()
    {
        _repo.Setup(r => r.GetCart(1))
             .Returns(new Cart { Items = [new CartItem { ProductId = 5 }] });
        _sut.AddItem(cartId: 1, productId: 5);
        _repo.Verify(r => r.Save(It.Is<Cart>(c => c.Items.Count == 1)), Times.Once);
    }
}
```

## Common Follow-up Questions
- What is the difference between `[SetUp]` in NUnit and xUnit's constructor?
- When is `IClassFixture<T>` the right choice vs. per-test setup?
- How does xUnit's per-test instantiation differ from NUnit and MSTest?
- How do you share setup logic across multiple test classes?
- What makes `static` mock fields dangerous in test classes?
- How do you reset a shared fixture between tests when mutation is unavoidable?

## Common Mistakes / Pitfalls
- **Static mock fields** — mock state (setups, recorded calls) carries over between tests, causing false passes or unexpected failures.
- **`[OneTimeSetUp]` with mutable state** — in NUnit, `[OneTimeSetUp]` is shared across all test methods; if tests mutate the state, later tests see dirty data.
- **Passing the same `Mock<T>` instance to a shared SUT via constructor** — changes in one test affect later tests.
- **Forgetting to reset or recreate objects** — `_repo.Invocations.Clear()` is easy to miss; creating a new mock per test is safer.
- **Extracting setup to a base class** — makes it hard to see what state each test depends on; prefer composition (constructor + helper methods).

## References
- [xUnit documentation — Shared context](https://xunit.net/docs/shared-context)
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
- [NUnit — SetUp / TearDown](https://docs.nunit.org/articles/nunit/writing-tests/setup-teardown/index.html)
