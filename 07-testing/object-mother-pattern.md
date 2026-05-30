# What Is the Object Mother Pattern and How Does It Differ from a Test Data Builder?

**Category:** Testing / Test Design & Best Practices
**Difficulty:** 🟡 Middle
**Tags:** `object-mother`, `test-data-builder`, `test-design`, `test-fixtures`

## Question
> What is an Object Mother pattern and how does it differ from a Test Data Builder?

## Short Answer
**Object Mother** is a static factory class with named methods that return canonical pre-configured domain objects (`Orders.Valid()`, `Orders.Cancelled()`). It's ideal when you have a small, stable set of representative scenarios. A **Test Data Builder** is a fluent builder that allows incremental customisation of every field. Object Mother is simpler but less flexible; Test Data Builder handles more variation. They are often combined: Object Mother delegates to builders internally.

## Detailed Explanation

### Object Mother
```csharp
public static class OrderMother
{
    public static Order Valid() => new()
    {
        Id = 1, Amount = 100m, Status = OrderStatus.Pending,
        CustomerId = 42, Currency = "USD"
    };

    public static Order Cancelled() => Valid() with { Status = OrderStatus.Cancelled };

    public static Order HighValue() => Valid() with { Amount = 10_000m };

    public static Order Expired() => Valid() with
    {
        CreatedAt = DateTime.UtcNow.AddDays(-90),
        Status = OrderStatus.Expired
    };
}

// Usage:
var order = OrderMother.Cancelled();
```

### Test Data Builder (for comparison)
```csharp
var order = new OrderBuilder()
    .WithAmount(500m)
    .WithStatus(OrderStatus.Shipped)
    .WithCurrency("EUR")
    .Build();
```

### Comparison

| Aspect | Object Mother | Test Data Builder |
|---|---|---|
| Syntax | `OrderMother.Cancelled()` | `new OrderBuilder().WithX().Build()` |
| Flexibility | Fixed named scenarios | Arbitrary property combinations |
| Boilerplate | Low (static methods) | Medium (builder class) |
| Discoverability | Browse static methods | Need to know builder API |
| Handles many variations? | ❌ Scales poorly | ✅ Designed for this |
| Handles few canonical cases? | ✅ Perfect | Verbose overhead |

### When to Use Each
| Situation | Prefer |
|---|---|
| 5–10 stable canonical test objects | Object Mother |
| Many tests with slight variations of the same object | Test Data Builder |
| Domain has strong invariants | Object Mother + Builder internally |
| Prototyping / small projects | Object Mother |
| Large enterprise project | Test Data Builder |

### Combining Both
```csharp
public static class OrderMother
{
    // Object Mother returns pre-set scenarios via Builder
    public static Order Valid() => new OrderBuilder().Build();
    public static Order Cancelled() => new OrderBuilder()
        .WithStatus(OrderStatus.Cancelled).Build();

    // Builder() lets callers customise when needed
    public static OrderBuilder Builder() => new();
}

// Tests can use named scenarios OR customise:
var order = OrderMother.Valid();
var customOrder = OrderMother.Builder().WithAmount(999m).Build();
```

## Code Example
```csharp
namespace ObjectMother.Tests;

// Object Mother for canonical scenarios
public static class CustomerMother
{
    public static Customer New() => new()
    {
        Id = 1, Name = "Alice", Email = "alice@example.com",
        IsVerified = true, CreatedAt = new DateTime(2024, 1, 1)
    };

    public static Customer Unverified() => New() with { IsVerified = false };

    public static Customer Premium() => New() with { Tier = CustomerTier.Premium };

    public static Customer Blocked() => New() with { IsBlocked = true };
}

// Tests using Object Mother — clean and expressive
public class DiscountServiceTests
{
    private readonly DiscountService _sut = new();

    [Fact]
    public void ApplyDiscount_PremiumCustomer_Gets20PercentOff()
    {
        var customer = CustomerMother.Premium();
        var discount = _sut.Calculate(customer, subtotal: 100m);
        discount.Should().Be(20m);
    }

    [Fact]
    public void ApplyDiscount_BlockedCustomer_ThrowsCustomerBlockedException()
    {
        var customer = CustomerMother.Blocked();
        Action act = () => _sut.Calculate(customer, subtotal: 100m);
        act.Should().Throw<CustomerBlockedException>();
    }

    [Fact]
    public void ApplyDiscount_UnverifiedCustomer_ReturnsZeroDiscount()
    {
        var customer = CustomerMother.Unverified();
        var discount = _sut.Calculate(customer, subtotal: 100m);
        discount.Should().Be(0m);
    }
}
```

## Common Follow-up Questions
- Can Object Mother and Test Data Builder be used in the same test suite?
- How do you handle domain object invariants in an Object Mother?
- When does an Object Mother become hard to maintain?
- How does AutoFixture relate to both patterns?
- Should Object Mother instances be mutable or immutable?
- How do you evolve an Object Mother when the domain model changes?

## Common Mistakes / Pitfalls
- **Returning the same instance from Object Mother** — tests mutate the shared object; always return a `new` instance.
- **Object Mother growing beyond ~10 methods** — a sign you need a Test Data Builder instead.
- **Using `with` expression on mutable classes** — C# `with` is for records; mutable classes need careful cloning.
- **Hardcoding IDs that conflict between tests** — use unique IDs or ensure tests don't depend on shared database state.
- **Skipping the builder combination** — the most resilient approach is Object Mother wrapping a builder, but teams often skip the builder step for simplicity.

## References
- [Martin Fowler — Object Mother](https://martinfowler.com/bliki/ObjectMother.html)
- [Nat Pryce — Test Data Builders](http://www.natpryce.com/articles/000714.html)
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
