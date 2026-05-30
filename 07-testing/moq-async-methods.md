# How Do You Mock Async Methods (Returning `Task`) with Moq?

**Category:** Testing / Mocking
**Difficulty:** 🟡 Middle
**Tags:** `moq`, `async`, `Task`, `ReturnsAsync`, `ValueTask`, `async-mock`

## Question
> How do you mock async methods (returning `Task`) with Moq?

## Short Answer
Use `ReturnsAsync(value)` for methods returning `Task<T>`, and `Returns(Task.CompletedTask)` for void `Task` methods. Moq 4.6+ provides `ReturnsAsync` as a convenience extension that wraps values in `Task.FromResult(...)` internally.

## Detailed Explanation

### `Task<T>` Methods
```csharp
mock.Setup(s => s.GetUserAsync(1))
    .ReturnsAsync(new User { Id = 1, Name = "Alice" });

// Equivalent long-form:
mock.Setup(s => s.GetUserAsync(1))
    .Returns(Task.FromResult(new User { Id = 1 }));
```

### Void `Task` Methods
For methods returning `Task` (no result):
```csharp
mock.Setup(s => s.SendAsync(It.IsAny<Email>()))
    .Returns(Task.CompletedTask);

// Or: let Moq use the default (Loose behavior returns Task.CompletedTask for Task-returning methods)
```

### `ValueTask<T>` Methods
`ReturnsAsync` doesn't work for `ValueTask`; use `Returns`:
```csharp
mock.Setup(s => s.GetCountAsync())
    .Returns(new ValueTask<int>(42));

// Or wrap in ValueTask.FromResult (Moq 4.16+)
mock.Setup(s => s.GetCountAsync())
    .Returns(ValueTask.FromResult(42));
```

### Dynamic / Computed Async Returns
```csharp
// Return different values based on argument
mock.Setup(repo => repo.FindByIdAsync(It.IsAny<int>()))
    .ReturnsAsync((int id) => new Product { Id = id, Name = $"Product {id}" });
```

### Async Exception Throwing
```csharp
mock.Setup(s => s.SendAsync(It.IsAny<Email>()))
    .ThrowsAsync(new SmtpException("connection refused"));
```

Note: `ThrowsAsync` exists as an extension in older Moq versions:
```csharp
// Older Moq (pre-4.16) alternative:
mock.Setup(s => s.SendAsync(It.IsAny<Email>()))
    .Returns(Task.FromException(new SmtpException("connection refused")));
```

### Delayed Task (Simulating Latency)
```csharp
mock.Setup(s => s.FetchDataAsync())
    .Returns(async () =>
    {
        await Task.Delay(50); // simulates network latency
        return new Data();
    });
```

### Verify Async Methods
`Verify` works the same way — it checks that the method was called, not that the task completed:
```csharp
mock.Verify(s => s.SendAsync(It.IsAny<Email>()), Times.Once);
```

> ⚠️ **Warning:** `Verify` only confirms the *call* was made. If you `await` an unconfigured async method on a Loose mock, you get a `null` `Task` which throws `NullReferenceException` when awaited — configure all awaited methods.

### `Loose` Behavior for Async Methods
A Loose mock automatically returns `Task.CompletedTask` for `Task`-returning methods and `Task.FromResult(default(T))` for `Task<T>` methods — no configuration needed.

## Code Example
```csharp
namespace Catalog.Tests;

public class ProductFacadeTests
{
    [Fact]
    public async Task GetProductWithReviews_ReturnsAggregatedData()
    {
        // Setup async methods
        var productRepo = new Mock<IProductRepository>();
        productRepo.Setup(r => r.GetByIdAsync(5))
                   .ReturnsAsync(new Product { Id = 5, Name = "Widget", Price = 29.99m });

        var reviewService = new Mock<IReviewService>();
        reviewService.Setup(s => s.GetAverageAsync(5))
                     .ReturnsAsync(4.2);

        var sut = new ProductFacade(productRepo.Object, reviewService.Object);

        var result = await sut.GetProductWithReviewsAsync(5);

        result.Name.Should().Be("Widget");
        result.AverageRating.Should().Be(4.2);
    }

    [Fact]
    public async Task SaveProduct_WhenRepositoryThrows_PropagatesException()
    {
        var repo = new Mock<IProductRepository>();
        repo.Setup(r => r.SaveAsync(It.IsAny<Product>()))
            .ThrowsAsync(new DbUpdateException("Constraint violation"));

        var sut = new ProductFacade(repo.Object, Mock.Of<IReviewService>());
        var act = async () => await sut.SaveAsync(new Product { Name = "Test" });

        await act.Should().ThrowAsync<DbUpdateException>()
                 .WithMessage("*Constraint violation*");
    }

    [Fact]
    public async Task NotifySubscribers_WhenPriceDrops_SendsAllNotifications()
    {
        var notificationService = new Mock<INotificationService>();
        // void Task setup
        notificationService.Setup(n => n.SendAsync(It.IsAny<Notification>()))
                           .Returns(Task.CompletedTask);

        var sut = new PriceDropNotifier(notificationService.Object);
        await sut.NotifyAsync("SKU-1", oldPrice: 100m, newPrice: 80m);

        notificationService.Verify(
            n => n.SendAsync(It.Is<Notification>(m => m.Subject.Contains("SKU-1"))),
            Times.Once);
    }
}
```

## Common Follow-up Questions
- How do you mock a `ValueTask<T>` method?
- What is the difference between `ThrowsAsync` and `.Returns(Task.FromException(...))`?
- How do you set up an async method to return different values on successive calls?
- How does Moq's Loose behavior handle un-configured `Task`-returning methods?
- How do you verify an async method was awaited (not just called)?
- How do you mock `IAsyncEnumerable<T>` methods?

## Common Mistakes / Pitfalls
- **Using `.Returns(value)` instead of `.ReturnsAsync(value)`** — `.Returns(new User())` returns the object directly (not a task), causing a `InvalidCastException` or test pass when the SUT awaits it and receives `null`.
- **Forgetting `await` in the SUT** — a mock configured with `ReturnsAsync` returns a completed task immediately; if the SUT doesn't await it, the result is lost.
- **`ThrowsAsync` vs `Throws`** — `Throws` on an async method throws *before* the task is created (different exception surface); use `ThrowsAsync` for exceptions that are await-observed.
- **Un-configured `Task<T>` on Strict mock** — throws `MockException`; configure all async methods the SUT calls.
- **`ValueTask` returning `null`** — `ValueTask` is a struct and cannot be null; if the mock returns a default `ValueTask`, the awaited result is `default(T)`.

## References
- [Moq documentation — Async methods](https://github.com/devlooped/moq/wiki/Quickstart#async-methods)
- [Moq GitHub](https://github.com/devlooped/moq)
- [Stephen Cleary — Don't Block on Async Code](https://blog.stephencleary.com/2012/07/dont-block-on-async-code.html)
- [Microsoft Learn — Unit testing async code](https://learn.microsoft.com/en-us/dotnet/core/testing/)
