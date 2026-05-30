# What Is `Mock.Of<T>()` and How Does It Differ from `new Mock<T>()`?

**Category:** Testing / Mocking
**Difficulty:** 🔴 Senior
**Tags:** `moq`, `Mock.Of`, `functional-mock`, `LINQ-to-Mocks`

## Question
> What is `Mock.Of<T>()` and how does it differ from `new Mock<T>()`?

## Short Answer
`Mock.Of<T>()` is a LINQ-style factory that returns a pre-configured mock *object* (not the `Mock<T>` wrapper) directly. `new Mock<T>()` gives you the `Mock<T>` wrapper for full control (`.Setup`, `.Verify`, `.Object`). Use `Mock.Of<T>()` for terse, read-only stubs where you don't need to verify interactions; use `new Mock<T>()` when you need behaviour verification.

## Detailed Explanation

### `new Mock<T>()` — The Wrapper
```csharp
var mock = new Mock<IOrderRepository>();
mock.Setup(r => r.GetById(1)).Returns(new Order { Id = 1 });
var obj = mock.Object; // IOrderRepository instance
mock.Verify(r => r.GetById(1), Times.Once);
```

Returns `Mock<T>` — gives access to `.Setup`, `.Verify`, `.Object`, `.Invocations`, `.CallBase`, etc.

### `Mock.Of<T>()` — The Object
```csharp
IOrderRepository repo = Mock.Of<IOrderRepository>(r =>
    r.GetById(1) == new Order { Id = 1 } &&
    r.Count == 5);
```

Returns `T` (the mock object) directly, configured via a predicate. No access to the wrapper unless you retrieve it via `Mock.Get(repo)`.

### Retrieving the Wrapper from a `Mock.Of<T>` Instance
```csharp
var mock = Mock.Get(repo); // returns Mock<IOrderRepository>
mock.Verify(r => r.GetById(1), Times.Once);
```

### Side-by-Side Comparison

| Feature | `new Mock<T>()` | `Mock.Of<T>()` |
|---|---|---|
| Returns | `Mock<T>` wrapper | `T` instance |
| Syntax | Fluent `.Setup().Returns()` | LINQ predicate |
| Verify interactions | ✅ Built-in | ✅ Via `Mock.Get(obj)` |
| Readability for stubs | Verbose | Terse, inline |
| Default behaviour | Loose or Strict | Always Loose |
| Multiple properties | Separate calls | Single expression |

### When to Use `Mock.Of<T>()`
- **Arrange section simplicity** — when you have several read-only stubs passed to a constructor, `Mock.Of<T>()` reduces boilerplate.
- **Test data builders** — creating pre-configured dependency stubs inline.
- **No interaction verification needed** — when the test only checks state, not method calls.

```csharp
// Before — verbose
var logger = new Mock<ILogger<MyService>>().Object;
var config = new Mock<IConfig>();
config.Setup(c => c.Timeout).Returns(30);
var sut = new MyService(logger, config.Object);

// After — terse
var sut = new MyService(
    Mock.Of<ILogger<MyService>>(),
    Mock.Of<IConfig>(c => c.Timeout == 30));
```

> ⚠️ `Mock.Of<T>()` only supports property and method return value setup via `==`. Complex callback behaviour (`.Callback`, conditional throws) requires `new Mock<T>()`.

### Limitations of `Mock.Of<T>()`
- Cannot configure callbacks or sequential returns
- Cannot configure exception throwing inline (no `.Throws` equivalent)
- Does not support `MockBehavior.Strict`
- Setup expression must be a simple equality predicate

## Code Example
```csharp
namespace Billing.Tests;

public class InvoiceServiceTests
{
    // Mock.Of<T>() — clean, no extra variables for simple stubs
    [Fact]
    public void CalculateTotal_WithTax_ReturnsCorrectAmount()
    {
        var taxProvider = Mock.Of<ITaxProvider>(tp => tp.GetRate("US") == 0.1m);
        var discountService = Mock.Of<IDiscountService>(ds =>
            ds.GetDiscount("SUMMER10") == 10m);

        var sut = new InvoiceService(taxProvider, discountService);
        var total = sut.Calculate(region: "US", subtotal: 100m, promoCode: "SUMMER10");

        total.Should().Be(99m); // (100 - 10) * 1.1 = 99
    }

    // new Mock<T>() — needed when verifying interactions
    [Fact]
    public void CalculateTotal_AlwaysQueriesTaxProvider()
    {
        var taxMock = new Mock<ITaxProvider>();
        taxMock.Setup(tp => tp.GetRate(It.IsAny<string>())).Returns(0.0m);
        var discountStub = Mock.Of<IDiscountService>(ds => ds.GetDiscount(It.IsAny<string>()) == 0m);

        var sut = new InvoiceService(taxMock.Object, discountStub);
        sut.Calculate("DE", 200m, "NONE");

        taxMock.Verify(tp => tp.GetRate("DE"), Times.Once);
    }

    // Mock.Get — retrieve wrapper from Mock.Of result to verify
    [Fact]
    public void CalculateTotal_AlwaysQueriesDiscount_VerifiedViaGet()
    {
        var discountService = Mock.Of<IDiscountService>(ds => ds.GetDiscount("VIP") == 50m);
        var taxStub = Mock.Of<ITaxProvider>(tp => tp.GetRate(It.IsAny<string>()) == 0m);

        var sut = new InvoiceService(taxStub, discountService);
        sut.Calculate("US", 100m, "VIP");

        Mock.Get(discountService).Verify(ds => ds.GetDiscount("VIP"), Times.Once);
    }
}
```

## Common Follow-up Questions
- What is LINQ-to-Mocks and which Moq API uses it?
- How do you verify interactions on a `Mock.Of<T>()` object?
- Can `Mock.Of<T>()` be used with `MockBehavior.Strict`?
- When should you prefer `Mock.Of<T>()` over `new Mock<T>()`?
- How does `Mock.Get(obj)` relate to the original `Mock.Of<T>()` call?
- What are the limitations of the predicate syntax in `Mock.Of<T>()`?

## Common Mistakes / Pitfalls
- **Expecting `Verify` to work directly on the object** — call `Mock.Get(obj)` first; the returned object is a plain `T`, not `Mock<T>`.
- **Using `Mock.Of<T>()` when you need callbacks or sequences** — those require `.Setup(...).Callback(...)` which is only available on `Mock<T>`.
- **Nesting complex logic in the predicate** — `Mock.Of<T>(pred)` is meant for simple equality; complex conditions degrade readability.
- **Assuming `Mock.Of<T>()` is strict** — it is always Loose; unexpected calls return defaults without throwing.
- **Forgetting that `Mock.Of<T>()` returns the object, not the wrapper** — trying to call `.Setup(...)` on it will fail at compile time.

## References
- [Moq documentation — LINQ to Mocks](https://github.com/devlooped/moq/wiki/Quickstart#linq-to-mocks)
- [Moq GitHub](https://github.com/devlooped/moq)
- [NuGet — Moq](https://www.nuget.org/packages/Moq/)
