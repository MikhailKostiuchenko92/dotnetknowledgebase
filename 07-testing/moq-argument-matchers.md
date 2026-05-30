# What Is `It.IsAny<T>()` and When Would You Use Argument Matchers in Moq?

**Category:** Testing / Mocking
**Difficulty:** 🟡 Middle
**Tags:** `moq`, `It.IsAny`, `It.Is`, `argument-matchers`, `Setup`, `Verify`

## Question
> What is `It.IsAny<T>()` and when would you use argument matchers?

## Short Answer
Argument matchers are special expressions used inside `Setup` and `Verify` lambdas to match method call arguments flexibly. `It.IsAny<T>()` matches any value of type `T`. Use matchers when you don't care about the exact argument value, or when you want to match a subset of arguments based on a predicate.

## Detailed Explanation

### Why Argument Matchers?
Without matchers, a `Setup` or `Verify` only triggers for an exact argument value. Matchers make your setups and verifications flexible without losing control.

### Core Matchers

| Matcher | Matches | Example |
|---|---|---|
| `It.IsAny<T>()` | Any value of type `T` | `It.IsAny<int>()` |
| `It.Is<T>(predicate)` | Values matching the predicate | `It.Is<int>(n => n > 0)` |
| `It.IsIn<T>(values)` | Any of the listed values | `It.IsIn("a", "b", "c")` |
| `It.IsNotIn<T>(values)` | Not any of the listed values | `It.IsNotIn(0, -1)` |
| `It.IsInRange<T>(lo, hi, range)` | Within a numeric range | `It.IsInRange(1, 10, Range.Inclusive)` |
| `It.IsRegex(pattern)` | Strings matching a regex | `It.IsRegex(@"^\d{4}$")` |
| `It.IsNotNull<T>()` | Any non-null value | `It.IsNotNull<string>()` |
| `It.Ref<T>.IsAny` | `ref` or `out` parameter matching | `ref It.Ref<int>.IsAny` |

### When to Use `It.IsAny<T>()`
- The SUT's behaviour doesn't depend on the specific argument value.
- You want a catch-all fallback setup for any call to a method.
- The argument is constructed inside the SUT and you can't predict it exactly (e.g., a generated GUID).

```csharp
// Don't care about the specific order — just that Save is called
repo.Setup(r => r.Save(It.IsAny<Order>())).Returns(true);
```

### When to Use `It.Is<T>(predicate)`
- You care about a property of the argument but not its exact value.
- You're verifying that the SUT constructed an object correctly.

```csharp
// Verify the email was sent to the right recipient with the right subject
emailSender.Verify(
    e => e.Send(It.Is<Email>(m =>
        m.To == "user@example.com" &&
        m.Subject.StartsWith("Order #"))),
    Times.Once);
```

### Mixing Matchers and Exact Values
You can't mix matchers and exact values in the same `Setup` or `Verify` call — use matchers for all arguments, or exact values for all:
```csharp
// ❌ Invalid — cannot mix
repo.Setup(r => r.GetPage(It.IsAny<int>(), 10)); // page=any, size=10 — FAILS

// ✅ Valid — use matchers for all
repo.Setup(r => r.GetPage(It.IsAny<int>(), It.Is<int>(n => n == 10)));

// ✅ Valid — exact values for all
repo.Setup(r => r.GetPage(1, 10));
```

> ⚠️ **Moq 4.20+ Note:** Starting with Moq 4.20, `It.IsAny<T>()` can be mixed with exact values in some scenarios due to internal refactoring. However, for clarity, prefer consistent use of matchers.

### Capturing Arguments for Custom Assertions
Use `Capture.In<T>` (Moq 4.20+) or `Callback` to save the argument:
```csharp
var capturedOrder = new List<Order>();
repo.Setup(r => r.Save(It.IsAny<Order>()))
    .Callback<Order>(o => capturedOrder.Add(o));

sut.PlaceOrder(new Cart { Items = 3 });

capturedOrder.Single().ItemCount.Should().Be(3);
```

## Code Example
```csharp
namespace Warehouse.Tests;

public class InventoryServiceTests
{
    [Fact]
    public void Reserve_UpdatesStockForAnyValidSku()
    {
        var stockRepo = new Mock<IStockRepository>();
        // IsAny — we don't care which specific SKU is passed
        stockRepo.Setup(r => r.GetStock(It.IsAny<string>()))
                 .Returns(100);

        var sut = new InventoryService(stockRepo.Object);
        sut.Reserve("SKU-9999", quantity: 5);

        // Verify the update happened for any string SKU
        stockRepo.Verify(r => r.UpdateStock(It.IsAny<string>(), It.Is<int>(n => n == 95)),
                         Times.Once);
    }

    [Fact]
    public void Reserve_WhenQuantityNegative_ThrowsArgumentException()
    {
        var stockRepo = new Mock<IStockRepository>();
        stockRepo.Setup(r => r.GetStock(It.IsAny<string>())).Returns(50);

        var sut = new InventoryService(stockRepo.Object);
        var act = () => sut.Reserve("SKU-1", quantity: -3);

        act.Should().Throw<ArgumentOutOfRangeException>()
            .WithParameterName("quantity");
    }

    [Fact]
    public void Fulfil_SendsPickingListWithCorrectItems()
    {
        var warehouse = new Mock<IWarehouseSystem>();
        var sut = new InventoryService(new Mock<IStockRepository>().Object, warehouse.Object);

        var order = new Order { Lines = [new("SKU-A", 2), new("SKU-B", 1)] };
        sut.Fulfil(order);

        // Is<T> predicate — verify the picking list has 2 lines
        warehouse.Verify(
            w => w.SubmitPickingList(It.Is<PickingList>(pl =>
                pl.Lines.Count == 2 &&
                pl.Lines.Any(l => l.Sku == "SKU-A" && l.Qty == 2))),
            Times.Once);
    }
}
```

## Common Follow-up Questions
- How do you capture the argument passed to a mocked method for detailed assertions?
- What is `It.Ref<T>.IsAny` and when do you need it?
- Can you use argument matchers in `Returns` lambdas?
- How do you match nullable types with argument matchers?
- What is the difference between `It.IsAny<string>()` and `It.IsNotNull<string>()`?
- How do `It.IsIn` and `It.IsNotIn` work for collection arguments?

## Common Mistakes / Pitfalls
- **Mixing exact values and matchers** — causes a `NotSupportedException`; use matchers consistently.
- **Using `It.IsAny<T>()` when you should be specific** — an overly loose setup passes when the SUT sends wrong data; prefer `It.Is<T>(predicate)` for important arguments.
- **Forgetting that matchers only work inside `Setup`/`Verify` lambdas** — you can't store `It.IsAny<T>()` in a variable and reuse it.
- **Complex predicate in `It.Is`** — overly complex predicates that themselves have bugs; keep the logic simple and test the predicate separately if needed.
- **`It.Is` predicate that throws** — if the predicate itself throws (e.g., NullReferenceException), Moq reports it as a match failure, which is confusing.

## References
- [Moq documentation — Argument matching](https://github.com/devlooped/moq/wiki/Quickstart#matching-arguments)
- [Moq GitHub — It class source](https://github.com/devlooped/moq/blob/main/src/Moq/It.cs)
- [NuGet — Moq](https://www.nuget.org/packages/Moq/)
- [Microsoft Learn — Mocking with Moq in .NET](https://learn.microsoft.com/en-us/dotnet/core/testing/)
