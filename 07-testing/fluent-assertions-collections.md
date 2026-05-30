# How Do You Assert on Collections with FluentAssertions?

**Category:** Testing / Assertion Libraries
**Difficulty:** 🟡 Middle
**Tags:** `FluentAssertions`, `collections`, `BeEquivalentTo`, `ContainSingle`, `AllSatisfy`

## Question
> How do you assert on collections with FluentAssertions (e.g., `BeEquivalentTo`, `ContainSingle`)?

## Short Answer
FluentAssertions provides a rich set of collection-specific extension methods: `BeEquivalentTo` for deep structural comparison, `ContainSingle` for asserting exactly one match, `OnlyContain` to validate all elements, `BeInAscendingOrder` for ordering, and many more. These compose cleanly with `.And` for multi-step assertions.

## Detailed Explanation

### Counting / Emptiness
```csharp
list.Should().BeEmpty();
list.Should().NotBeEmpty();
list.Should().HaveCount(3);
list.Should().HaveCountGreaterThan(0);
list.Should().HaveCountLessThanOrEqualTo(10);
```

### Element Existence
```csharp
list.Should().Contain(item);                        // contains specific element
list.Should().Contain(x => x.Id == 42);             // at least one match
list.Should().ContainSingle();                       // exactly 1 element
list.Should().ContainSingle(x => x.IsActive);       // exactly 1 matching element
list.Should().NotContain(x => x.IsDeleted);
```

### All / Any Conditions
```csharp
list.Should().AllSatisfy(x => x.Price.Should().BePositive());
list.Should().AllBeAssignableTo<Order>();
list.Should().OnlyHaveUniqueItems();
list.Should().OnlyContain(x => x.Status == OrderStatus.Active);
```

### Ordering
```csharp
list.Should().BeInAscendingOrder(x => x.Price);
list.Should().BeInDescendingOrder(x => x.CreatedAt);
list.Should().BeInAscendingOrder();           // for IComparable
```

### Structural Equality: `BeEquivalentTo`
Deep compares two collections by property values, regardless of reference or order (by default):
```csharp
actual.Should().BeEquivalentTo(expected);

// Exclude fields:
actual.Should().BeEquivalentTo(expected,
    opts => opts.Excluding(x => x.CreatedAt)
                .Excluding(x => x.UpdatedAt));

// Enforce ordering:
actual.Should().BeEquivalentTo(expected,
    opts => opts.WithStrictOrdering());
```

### Subset / Superset
```csharp
actual.Should().BeSubsetOf(superset);
actual.Should().ContainItemsAssignableTo<IProduct>();
```

### Dictionary Assertions
```csharp
dict.Should().ContainKey("userId");
dict.Should().ContainValue("admin");
dict.Should().Contain("userId", "42");
dict.Should().NotContainKey("password");
```

### Chaining
```csharp
results.Should()
       .NotBeEmpty()
       .And.HaveCount(3)
       .And.ContainSingle(x => x.IsPrimary)
       .And.AllSatisfy(x => x.IsActive.Should().BeTrue());
```

## Code Example
```csharp
namespace Collections.Tests;

public class OrderQueryTests
{
    [Fact]
    public void GetActiveOrders_ReturnsOnlyActiveOrders()
    {
        var repo = new InMemoryOrderRepository(new[]
        {
            new Order { Id = 1, Status = OrderStatus.Active, Amount = 100 },
            new Order { Id = 2, Status = OrderStatus.Cancelled, Amount = 50 },
            new Order { Id = 3, Status = OrderStatus.Active, Amount = 200 }
        });

        var results = repo.GetActive();

        results.Should().HaveCount(2)
               .And.OnlyContain(o => o.Status == OrderStatus.Active)
               .And.BeInAscendingOrder(o => o.Id);
    }

    [Fact]
    public void MapToDto_MapsAllFields_ExceptAuditFields()
    {
        var orders = new[] { new Order { Id = 1, Amount = 99m, CreatedAt = DateTime.UtcNow } };
        var expected = new[] { new OrderDto { Id = 1, Amount = 99m } };

        var actual = orders.Select(OrderMapper.ToDto).ToList();

        actual.Should().BeEquivalentTo(expected,
            opts => opts.Excluding(x => x.CreatedAt));
    }

    [Fact]
    public void GetFeatured_ReturnsExactlyOnePrimary()
    {
        var service = new ProductService();
        var products = service.GetFeatured();

        products.Should().ContainSingle(p => p.IsPrimary,
            "because exactly one product must be designated as primary");
    }

    [Fact]
    public void GetPriceList_AllPricesArePositive()
    {
        var prices = new ProductPriceService().GetAll();

        prices.Should().NotBeEmpty()
              .And.AllSatisfy(p => p.Amount.Should().BeGreaterThan(0));
    }
}
```

## Common Follow-up Questions
- What is the difference between `Contain` and `ContainSingle`?
- How does `BeEquivalentTo` handle nested objects?
- How do you assert ordering with a custom comparer?
- How do you use `AllSatisfy` vs. `OnlyContain`?
- How do you assert on a `Dictionary<TKey, TValue>` with FluentAssertions?
- How do you exclude multiple properties in `BeEquivalentTo`?

## Common Mistakes / Pitfalls
- **Using `Be` instead of `BeEquivalentTo` for collections of objects** — `Be` does reference equality; `BeEquivalentTo` does deep structural comparison.
- **Assuming `BeEquivalentTo` is order-sensitive** — by default it ignores order; add `.WithStrictOrdering()` when sequence matters.
- **Confusing `Contain(item)` with `Contain(predicate)`** — item overload requires `Equals` match; predicate overload does not.
- **Not reading which element failed in `AllSatisfy`** — failure messages show the index, but test code should also name the property being tested.
- **Chaining `AllSatisfy` with lambda that has multiple nested `Should()`** — each nested `Should()` can produce additional assertion failures inside the callback; make sure you want all sub-assertions to execute.

## References
- [FluentAssertions — Collections](https://fluentassertions.com/collections/)
- [FluentAssertions — Dictionaries](https://fluentassertions.com/dictionaries/)
- [FluentAssertions on GitHub](https://github.com/fluentassertions/fluentassertions)
- [NuGet — FluentAssertions](https://www.nuget.org/packages/FluentAssertions/)
