# How Do You Set Up a Method Return Value with `Setup` and `Returns` in Moq?

**Category:** Testing / Mocking
**Difficulty:** 🟡 Middle
**Tags:** `moq`, `Setup`, `Returns`, `ReturnsAsync`, `Callback`, `Returns-lambda`

## Question
> How do you set up a method return value with `Setup` and `Returns` in Moq?

## Short Answer
Use `mock.Setup(x => x.Method(args)).Returns(value)` to configure what a mocked method returns when called with matching arguments. For async methods use `ReturnsAsync(value)`. For computed or dynamic return values, use a `Returns` lambda `Returns(() => ComputeValue())` or `Returns<T1,...>((arg) => ...)`.

## Detailed Explanation

### Basic `Returns`
```csharp
mock.Setup(x => x.GetName()).Returns("Alice");
```
Every call to `GetName()` returns `"Alice"`.

### Matching Specific Arguments
```csharp
mock.Setup(r => r.FindById(42)).Returns(new Product { Id = 42 });
// Only matches calls with argument == 42
// Other argument values return null (Loose) or throw (Strict)
```

### Argument Matchers
To match any value, use `It.IsAny<T>()`:
```csharp
mock.Setup(r => r.FindById(It.IsAny<int>())).Returns(new Product { Id = 0 });
```

For conditional matching, use `It.Is<T>(predicate)`:
```csharp
mock.Setup(r => r.FindById(It.Is<int>(id => id > 0))).Returns(new Product());
```

### Async Methods: `ReturnsAsync`
```csharp
mock.Setup(s => s.GetUserAsync(1)).ReturnsAsync(new User { Id = 1 });
// Equivalent to: .Returns(Task.FromResult(new User { Id = 1 }))
```

For `ValueTask<T>`:
```csharp
mock.Setup(s => s.GetValueAsync()).Returns(new ValueTask<int>(42));
```

### Dynamic / Computed Return Value
Use a lambda to compute the return value at call time:
```csharp
// Stateless lambda
mock.Setup(r => r.GetTimestamp()).Returns(() => DateTime.UtcNow);

// Access call arguments
mock.Setup(r => r.FindById(It.IsAny<int>()))
    .Returns<int>(id => new Product { Id = id, Name = $"Product {id}" });
```

### `Callback` for Side Effects
Run additional logic when the method is called (e.g., log, increment a counter):
```csharp
int callCount = 0;
mock.Setup(s => s.Process(It.IsAny<Order>()))
    .Callback<Order>(order => callCount++)
    .Returns(ProcessResult.Success);
```

### `ReturnsSelf` (Fluent Builders)
For fluent builder interfaces that return `this`:
```csharp
var builder = new Mock<IQueryBuilder>();
builder.Setup(b => b.Where(It.IsAny<string>())).Returns(builder.Object);
builder.Setup(b => b.OrderBy(It.IsAny<string>())).Returns(builder.Object);
```

### Multiple Setups for the Same Method
Later `Setup` calls override earlier ones for the same argument pattern:
```csharp
mock.Setup(r => r.FindById(1)).Returns(productA);
mock.Setup(r => r.FindById(1)).Returns(productB); // overrides the first
```

For successive calls, use `SetupSequence` (see [moq-setup-sequence.md](moq-setup-sequence.md)).

> ⚠️ **Warning:** If you set up the same method call multiple times with `Setup`, only the last setup takes effect. Use `SetupSequence` if you need different return values per call.

## Code Example
```csharp
namespace Catalog.Tests;

public class CatalogServiceTests
{
    [Fact]
    public async Task GetProductDetails_ReturnsCombinedData()
    {
        // Basic return
        var productRepo = new Mock<IProductRepository>();
        productRepo.Setup(r => r.FindById(10))
                   .Returns(new Product { Id = 10, Name = "Laptop", Price = 999m });

        // Async return
        var reviewRepo = new Mock<IReviewRepository>();
        reviewRepo.Setup(r => r.GetAverageRatingAsync(10))
                  .ReturnsAsync(4.5);

        // Dynamic return — computes value per call
        var priceService = new Mock<IPriceService>();
        priceService
            .Setup(p => p.GetFinalPrice(It.IsAny<int>(), It.IsAny<string>()))
            .Returns<int, string>((productId, currency) =>
                currency == "USD" ? 999m : 849m);

        var sut = new CatalogService(productRepo.Object, reviewRepo.Object, priceService.Object);

        var details = await sut.GetProductDetailsAsync(productId: 10, currency: "EUR");

        details.Name.Should().Be("Laptop");
        details.AverageRating.Should().Be(4.5);
        details.Price.Should().Be(849m);
    }

    [Fact]
    public void GetProduct_LogsCallWithCallback()
    {
        var log = new List<int>();
        var repo = new Mock<IProductRepository>();
        repo.Setup(r => r.FindById(It.IsAny<int>()))
            .Callback<int>(id => log.Add(id))  // side effect
            .Returns(new Product());

        var sut = new CatalogService(repo.Object);
        sut.GetProduct(5);
        sut.GetProduct(10);

        log.Should().Equal(5, 10);
    }
}
```

## Common Follow-up Questions
- What is `SetupSequence` and how does it differ from multiple `Setup` calls?
- How do you set up a method to throw an exception with Moq?
- What is `It.IsAny<T>()` vs. `It.Is<T>(predicate)` vs. a specific value?
- How do you use `Callback` to capture arguments for later assertion?
- Can you use `Setup` on properties? How?
- What is `ReturnsLazy` and how does it relate to `Returns(() => ...)`?

## Common Mistakes / Pitfalls
- **Using `Returns(null)` for reference types** — returns a null `object`, not a typed null; use `Returns((MyType?)null)`.
- **Forgetting `ReturnsAsync` for async methods** — `.Returns(Task.FromResult(x))` works but is verbose; prefer `.ReturnsAsync(x)`.
- **Overriding setups unintentionally** — multiple `.Setup(...)` calls for the same signature replace each other; use `SetupSequence` for successive-call scenarios.
- **Lambda in `Returns` with captured mutable state** — `Returns(() => list.Count)` is evaluated lazily; ensure the captured state is what you intend at call time.
- **Mismatched argument matchers** — mixing exact values and `It.IsAny<T>()` on overloaded methods may match the wrong overload.

## References
- [Moq documentation — Quickstart: Returning values](https://github.com/devlooped/moq/wiki/Quickstart#returns)
- [Moq documentation — Argument matching](https://github.com/devlooped/moq/wiki/Quickstart#matching-arguments)
- [NuGet — Moq](https://www.nuget.org/packages/Moq/)
- [Microsoft Learn — Unit testing with Moq](https://learn.microsoft.com/en-us/dotnet/core/testing/)
