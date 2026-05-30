# What Is `AssertionScope` in FluentAssertions and Why Is It Useful?

**Category:** Testing / Assertion Libraries
**Difficulty:** 🟡 Middle
**Tags:** `FluentAssertions`, `AssertionScope`, `multiple-failures`, `soft-assertions`

## Question
> What is `AssertionScope` in FluentAssertions and why is it useful?

## Short Answer
`AssertionScope` is FluentAssertions' "soft assertion" mechanism. Normally each failed assertion immediately throws and aborts the test. Wrapping assertions in a `using (new AssertionScope())` block collects all failures within the scope and reports them together at the end. This saves time by showing all problems in a single test run instead of fixing them one at a time.

## Detailed Explanation

### The Problem: Early Bail-Out
```csharp
// Without AssertionScope — stops at the first failure:
result.Id.Should().Be(1);        // ❌ stops here if wrong
result.Name.Should().Be("Alice"); // never reached
result.Age.Should().BeGreaterThan(18);
```
If `Id` is wrong, you fix it, re-run, and only then discover `Name` is also wrong. Three round-trips to fix three problems.

### The Solution: `AssertionScope`
```csharp
using (new AssertionScope())
{
    result.Id.Should().Be(1);
    result.Name.Should().Be("Alice");
    result.Age.Should().BeGreaterThan(18);
}
// All three failures reported in a single message:
// "Expected result.Id to be 1, but found 99.
//  Expected result.Name to be "Alice", but found "Bob".
//  Expected result.Age to be greater than 18, but found 16."
```

### Key Behaviours
- Failures are **accumulated**, not thrown immediately.
- At the end of the `using` block, all failures are combined into a single `AssertionFailedException`.
- The test is still marked failed — `AssertionScope` does not suppress failures.
- Nested scopes are supported; inner scope failures roll up to the outer scope.

### Named Scope for Context
```csharp
using (new AssertionScope("validation of order response"))
{
    response.StatusCode.Should().Be(200);
    response.Content.Should().NotBeEmpty();
}
// Failure: "[validation of order response] Expected response.StatusCode to be 200..."
```

### Async Usage
`AssertionScope` does not automatically carry across `await` boundaries. For async code, collect results first, then assert synchronously:
```csharp
var result = await sut.GetOrderAsync(1);
using (new AssertionScope())
{
    result.Should().NotBeNull();
    result!.Id.Should().Be(1);
    result.Status.Should().Be(OrderStatus.Active);
}
```

### When to Use
| Use `AssertionScope` | Use individual assertions |
|---|---|
| Multiple properties on one object (e.g., DTO mapping) | Single-concern test (one thing can go wrong) |
| Integration test verifying response structure | Unit test validating a single return value |
| Discovering all failures in one run | Test simplicity is more important |

> 💡 For test methods that verify object mappings or response shapes, `AssertionScope` can cut debugging cycles significantly.

## Code Example
```csharp
namespace AssertionScopeDemo.Tests;

public class OrderMappingTests
{
    [Fact]
    public void MapToDto_MapsAllPropertiesCorrectly()
    {
        var order = new Order
        {
            Id = 1,
            CustomerName = "Alice",
            TotalAmount = 149.99m,
            Status = OrderStatus.Shipped,
            CreatedAt = new DateTime(2024, 1, 15)
        };

        var dto = OrderMapper.ToDto(order);

        // All assertions run even if some fail
        using (new AssertionScope("order-to-dto mapping"))
        {
            dto.Id.Should().Be(order.Id);
            dto.CustomerName.Should().Be(order.CustomerName);
            dto.TotalAmount.Should().Be(order.TotalAmount);
            dto.StatusLabel.Should().Be("Shipped");
            dto.CreatedAtFormatted.Should().Be("2024-01-15");
        }
    }

    [Fact]
    public async Task GetSummary_ReturnsCompleteApiResponse()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/orders/1/summary");
        var body = await response.Content.ReadFromJsonAsync<OrderSummaryDto>();

        using (new AssertionScope("GET /orders/1/summary response"))
        {
            response.StatusCode.Should().Be(HttpStatusCode.OK);
            body.Should().NotBeNull();
            body!.OrderId.Should().Be(1);
            body.TotalItems.Should().BeGreaterThan(0);
            body.TotalPrice.Should().BePositive();
        }
    }
}
```

## Common Follow-up Questions
- Does `AssertionScope` suppress test failures or just delay them?
- Can you nest `AssertionScope` instances?
- How do you give an `AssertionScope` a descriptive name?
- Does `AssertionScope` work with async assertions (`ThrowAsync`)?
- How does `AssertionScope` compare to NUnit's `Assert.Multiple`?
- When is it better NOT to use `AssertionScope`?

## Common Mistakes / Pitfalls
- **Thinking `AssertionScope` passes the test** — it still fails; it just collects all failures instead of stopping at the first one.
- **Using `AssertionScope` with `await` inside** — async continuations may execute outside the scope; await the task first, then assert.
- **Over-using in unit tests** — simple unit tests with one concern don't need it; it adds noise. Reserve for mapping/integration scenarios.
- **Not naming the scope** — an unnamed scope gives generic failure messages; add a descriptive name for context in complex tests.
- **Forgetting the `using` block** — without `using`, the scope is never disposed and failures are never reported.

## References
- [FluentAssertions — AssertionScope](https://fluentassertions.com/assertionscopes/)
- [FluentAssertions on GitHub](https://github.com/fluentassertions/fluentassertions)
- [NuGet — FluentAssertions](https://www.nuget.org/packages/FluentAssertions/)
