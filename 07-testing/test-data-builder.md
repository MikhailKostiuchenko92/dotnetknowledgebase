# What Is the "Test Data Builder" Pattern and When Is It Useful?

**Category:** Testing / Test Design & Best Practices
**Difficulty:** 🟡 Middle
**Tags:** `test-data-builder`, `builder-pattern`, `test-design`, `DRY`

## Question
> What is the "test data builder" pattern and when is it useful?

## Short Answer
A **Test Data Builder** is a fluent object-construction helper for tests that creates domain entities with sensible defaults while allowing specific properties to be overridden per test. It eliminates repetitive `new Order { ... }` boilerplate, centralises default values, and makes tests resilient to domain model changes — only the builder needs updating when a new required field is added.

## Detailed Explanation

### The Problem Without It
```csharp
// Repeated across 20 test methods — brittle, noisy
var order = new Order
{
    Id = 1,
    CustomerId = 100,
    Status = OrderStatus.Pending,
    Amount = 150m,
    CreatedAt = DateTime.UtcNow,
    ShippingAddress = new Address { City = "Boston", Zip = "02101", Country = "US" },
    Items = new List<OrderItem> { new() { ProductId = 5, Quantity = 2, UnitPrice = 75m } }
};
```
If `Order` gains a required `Currency` field, you must update all 20 test methods.

### The Solution: Builder with Defaults
```csharp
public class OrderBuilder
{
    private int _id = 1;
    private int _customerId = 100;
    private decimal _amount = 100m;
    private OrderStatus _status = OrderStatus.Pending;

    public OrderBuilder WithId(int id) { _id = id; return this; }
    public OrderBuilder WithAmount(decimal amount) { _amount = amount; return this; }
    public OrderBuilder WithStatus(OrderStatus status) { _status = status; return this; }

    public Order Build() => new()
    {
        Id = _id,
        CustomerId = _customerId,
        Amount = _amount,
        Status = _status
    };
}
```

### Usage in Tests
```csharp
// Only specify what the test cares about
var order = new OrderBuilder().WithAmount(200m).WithStatus(OrderStatus.Fulfilled).Build();

// Default values handle everything else
var defaultOrder = new OrderBuilder().Build(); // Id=1, Amount=100, Status=Pending
```

### Test Data Builder vs. Object Mother

| Pattern | Description | When to Use |
|---|---|---|
| **Test Data Builder** | Fluent builder with `WithX()` methods | Complex objects, many tests with variations |
| **Object Mother** | Static factory methods for preset scenarios | Few canonical scenarios (`ValidOrder()`, `CancelledOrder()`) |

They can be combined:
```csharp
// Object Mother delegates to builder
public static class Orders
{
    public static Order Valid() => new OrderBuilder().Build();
    public static Order Cancelled() => new OrderBuilder().WithStatus(OrderStatus.Cancelled).Build();
    public static Order HighValue() => new OrderBuilder().WithAmount(10_000m).Build();
}
```

### Resilience to Model Changes
When `Order` gains a new required `Currency` field:
- **Without builder:** Update every `new Order { ... }` in every test.
- **With builder:** Update `OrderBuilder.Build()` with a default `Currency = "USD"` — all tests keep working.

## Code Example
```csharp
namespace TestDataBuilder.Tests;

public class OrderBuilder
{
    private int _id = 1;
    private decimal _amount = 100m;
    private OrderStatus _status = OrderStatus.Pending;
    private string _currency = "USD";
    private Address? _address;

    public static OrderBuilder Default() => new();

    public OrderBuilder WithId(int id) { _id = id; return this; }
    public OrderBuilder WithAmount(decimal amount) { _amount = amount; return this; }
    public OrderBuilder WithStatus(OrderStatus s) { _status = s; return this; }
    public OrderBuilder WithCurrency(string currency) { _currency = currency; return this; }
    public OrderBuilder WithAddress(Address address) { _address = address; return this; }

    public Order Build() => new()
    {
        Id = _id,
        Amount = _amount,
        Status = _status,
        Currency = _currency,
        ShippingAddress = _address ?? AddressBuilder.Default().Build()
    };
}

public class TaxCalculatorTests
{
    [Fact]
    public void Calculate_USOrder_AppliesCorrectRate()
    {
        var order = OrderBuilder.Default()
            .WithAmount(100m)
            .WithCurrency("USD")
            .Build();

        var tax = TaxCalculator.Compute(order);

        tax.Should().Be(10m); // 10% US rate
    }

    [Fact]
    public void Calculate_FulfilledOrder_IncludesShippingTax()
    {
        var order = OrderBuilder.Default()
            .WithStatus(OrderStatus.Fulfilled)
            .WithAmount(200m)
            .Build();

        var tax = TaxCalculator.Compute(order);

        tax.Should().BeGreaterThan(20m); // includes shipping surcharge
    }
}
```

## Common Follow-up Questions
- What is the difference between a Test Data Builder and the Object Mother pattern?
- How do you handle nested objects in a Test Data Builder?
- When should you use AutoFixture instead of a hand-rolled builder?
- How do you keep Test Data Builders in sync with domain model changes?
- Can Test Data Builders be shared across test projects in a solution?
- How do you build collections with a Test Data Builder?

## Common Mistakes / Pitfalls
- **Using random data in builders** — leads to flaky tests; use fixed defaults unless explicitly randomised with AutoFixture.
- **Not providing sensible defaults** — if `Build()` requires callers to always set every field, it's just a verbose constructor.
- **Creating one mega-builder for all scenarios** — split builders per aggregate root (OrderBuilder, CustomerBuilder, etc.).
- **Putting business logic in the builder** — builders should create valid data structures, not enforce domain rules.
- **Not sharing builders across test projects** — place builders in a `Tests.Common` project to reuse across unit, integration, and E2E tests.

## References
- [Nat Pryce — Test Data Builders](http://www.natpryce.com/articles/000714.html)
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
- [Mark Seemann — Test Data Builders](https://blog.ploeh.dk/2017/08/15/test-data-builders-in-c/) (verify URL)
