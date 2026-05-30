# What Is the Single Assert / Single Concept Principle in Unit Tests?

**Category:** Testing / Test Design & Best Practices
**Difficulty:** 🟡 Middle
**Tags:** `single-assert`, `single-concept`, `test-design`, `cohesion`

## Question
> What is the Single Assert / Single Concept principle in unit tests?

## Short Answer
The **Single Concept** principle says each test should verify exactly one logical behaviour. The stricter **Single Assert** version says each test should contain only one assertion. In practice, the concept version is more pragmatic: a test may have multiple assertions as long as they all verify the same logical outcome. Splitting verification across many tests keeps failures focused and test names descriptive.

## Detailed Explanation

### Why Single Concept?
When a test fails, you need to know *what* failed immediately from the test name alone. A test named `Process_Returns_CorrectOrderAndSendsEmail_AndUpdatesInventory` is testing three things — when it fails you don't know which one broke.

```csharp
// ❌ Multiple concepts in one test — hard to diagnose
[Fact]
public void Process_Order_DoesEverything()
{
    var result = sut.Process(order);

    result.Should().NotBeNull();           // concept 1: returns result
    emailService.Verify(..., Times.Once);   // concept 2: sends email
    inventoryService.Verify(...);           // concept 3: updates inventory
    result.Status.Should().Be(Fulfilled);   // concept 1 again
}
```

```csharp
// ✅ One concept per test
[Fact]
public void Process_ValidOrder_ReturnsFulfilledResult() { ... }

[Fact]
public void Process_ValidOrder_SendsConfirmationEmail() { ... }

[Fact]
public void Process_ValidOrder_DecrementsInventory() { ... }
```

### Single Assert (Strict) vs. Single Concept (Pragmatic)
| Style | Example | When to Use |
|---|---|---|
| Single Assert | One `Should()` call | Ideal for simple value tests |
| Single Concept | Multiple assertions on the same outcome | Testing a DTO mapping, API response structure |

Multiple assertions are acceptable when they are **all required to describe one outcome**:
```csharp
// ✅ Multiple assertions, still single concept: "returns a valid address"
address.Street.Should().Be("123 Main St");
address.City.Should().Be("Boston");
address.Zip.Should().Be("02101");
```

### Benefits
- **Clear failure messages** — test name tells you exactly what broke.
- **Faster diagnosis** — no guessing which assertion out of ten failed.
- **Forces better decomposition** — if splitting is hard, it reveals the SUT is doing too much.
- **Smaller tests** — easier to read, maintain, and review in PRs.

### `AssertionScope` When Multiple Assertions Are Needed
When multiple related assertions genuinely belong together, use `AssertionScope` to run them all and report all failures:
```csharp
using (new AssertionScope())
{
    dto.Id.Should().Be(1);
    dto.Name.Should().Be("Widget");
    dto.Price.Should().BePositive();
}
```

## Code Example
```csharp
namespace SingleConcept.Tests;

// ❌ Before: one test, many concepts
public class OrderProcessorTests_Before
{
    [Fact]
    public void Process_CreatesOrderAndNotifiesAndUpdatesStock()
    {
        var notifier = new Mock<INotifier>();
        var stock = new Mock<IStockService>();
        var sut = new OrderProcessor(notifier.Object, stock.Object);
        var order = new Order { Id = 1, ProductId = 5, Quantity = 2 };

        var result = sut.Process(order);

        result.Should().NotBeNull();
        result.Status.Should().Be(OrderStatus.Confirmed);
        notifier.Verify(n => n.Notify(order.Id), Times.Once);
        stock.Verify(s => s.Decrement(5, 2), Times.Once);
    }
}

// ✅ After: one concept per test
public class OrderProcessorTests_After
{
    private readonly Mock<INotifier> _notifier = new();
    private readonly Mock<IStockService> _stock = new();
    private OrderProcessor Sut => new(_notifier.Object, _stock.Object);

    [Fact]
    public void Process_ValidOrder_ReturnsConfirmedResult()
    {
        var result = Sut.Process(new Order { Id = 1, ProductId = 5, Quantity = 2 });
        result.Status.Should().Be(OrderStatus.Confirmed);
    }

    [Fact]
    public void Process_ValidOrder_SendsNotification()
    {
        Sut.Process(new Order { Id = 1, ProductId = 5, Quantity = 2 });
        _notifier.Verify(n => n.Notify(1), Times.Once);
    }

    [Fact]
    public void Process_ValidOrder_DecrementsStock()
    {
        Sut.Process(new Order { Id = 1, ProductId = 5, Quantity = 2 });
        _stock.Verify(s => s.Decrement(5, 2), Times.Once);
    }
}
```

## Common Follow-up Questions
- Is it ever acceptable to have multiple assertions in one test?
- What is the difference between the Single Assert rule and the Single Concept rule?
- How does `AssertionScope` relate to the Single Concept principle?
- How do you name tests when they each verify one concept?
- What is the relationship between Single Concept tests and the AAA pattern?
- How do you handle tests that need many assertions for one integration scenario?

## Common Mistakes / Pitfalls
- **Dogmatically enforcing one `Assert` per test** — leads to test explosion; pragmatic Single Concept is better.
- **Big test methods with `// section 1` and `// section 2` comments** — this is a sign of multiple concepts; split them.
- **Asserting mock interactions AND return values in the same test** — these are usually two separate concerns.
- **Duplicating Arrange code across many single-concept tests** — extract shared setup to a helper method or constructor.
- **Confusing "single concept" with "single line"** — a DTO mapping test may have 10 assertions and still be single-concept.

## References
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
- [Robert C. Martin — Clean Code, Chapter 9](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [xUnit documentation](https://xunit.net/)
