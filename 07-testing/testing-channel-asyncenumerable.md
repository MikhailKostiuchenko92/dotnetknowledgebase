# How Do You Test Code That Uses `Channel<T>` or `IAsyncEnumerable<T>`?

**Category:** Testing / Async Code
**Difficulty:** 🔴 Senior
**Tags:** `Channel`, `IAsyncEnumerable`, `async-stream`, `testing`, `producer-consumer`

## Question
> How do you test code that uses `Channel<T>` or `IAsyncEnumerable<T>`?

## Short Answer
For `Channel<T>`, write directly to the channel in the test and assert on what is consumed; or conversely, have the SUT write to the channel and read the output from the test. For `IAsyncEnumerable<T>`, iterate with `await foreach` or collect with `.ToListAsync()`. Use in-memory implementations — no mocking is needed for these core types.

## Detailed Explanation

### Testing a Consumer of `Channel<T>`
If the SUT reads from a channel, write items in the test and complete the writer:
```csharp
var channel = Channel.CreateUnbounded<int>();
var sut = new Processor(channel.Reader);

channel.Writer.TryWrite(1);
channel.Writer.TryWrite(2);
channel.Writer.Complete();

var result = await sut.ProcessAllAsync();
result.Should().Be(3); // sum of [1, 2]
```

### Testing a Producer of `Channel<T>`
If the SUT writes to a channel, observe the channel reader in the test:
```csharp
var channel = Channel.CreateUnbounded<string>();
var sut = new LogProcessor(channel.Writer);

await sut.EmitLogsAsync(new[] { "a", "b" });
channel.Writer.Complete();

var items = new List<string>();
await foreach (var item in channel.Reader.ReadAllAsync())
    items.Add(item);

items.Should().BeEquivalentTo(new[] { "a", "b" });
```

### Testing `IAsyncEnumerable<T>` Methods
Collect all items with `.ToListAsync()`:
```csharp
var result = await sut.GetProductsAsync().ToListAsync();
result.Should().HaveCount(3);
```

Or use `await foreach` for assertions on large sequences:
```csharp
var count = 0;
await foreach (var item in sut.StreamOrdersAsync())
{
    item.Should().NotBeNull();
    count++;
}
count.Should().BeGreaterThan(0);
```

### Providing a Fake `IAsyncEnumerable<T>` to a Dependency
```csharp
private static async IAsyncEnumerable<Order> FakeOrders()
{
    yield return new Order { Id = 1 };
    yield return new Order { Id = 2 };
    await Task.Yield(); // ensures async behavior
}

_repo.Setup(r => r.StreamAsync(It.IsAny<CancellationToken>()))
     .Returns(FakeOrders());
```

### Bounded vs. Unbounded Channel in Tests
Use `Channel.CreateUnbounded<T>()` in tests to avoid backpressure issues. If you want to test backpressure specifically, use `Channel.CreateBounded<T>(capacity: 1)`.

### Testing Cancellation
```csharp
[Fact]
public async Task StreamAsync_CancelledToken_StopsEarly()
{
    using var cts = new CancellationTokenSource();
    var channel = Channel.CreateUnbounded<int>();
    var sut = new StreamingService(channel.Reader);

    var task = sut.ConsumeAsync(cts.Token);
    channel.Writer.TryWrite(1);
    cts.Cancel();

    await act.Should().ThrowAsync<OperationCanceledException>();
}
```

## Code Example
```csharp
namespace Channels.Tests;

public class EventStreamProcessorTests
{
    [Fact]
    public async Task ProcessAsync_AllItemsConsumed()
    {
        // Arrange
        var channel = Channel.CreateUnbounded<DomainEvent>();
        var processed = new List<DomainEvent>();
        var sut = new EventStreamProcessor(channel.Reader,
            async (ev, _) => { processed.Add(ev); });

        var events = Enumerable.Range(1, 5)
            .Select(i => new DomainEvent { Id = i })
            .ToList();

        foreach (var ev in events) channel.Writer.TryWrite(ev);
        channel.Writer.Complete();

        // Act
        await sut.ProcessAsync(CancellationToken.None);

        // Assert
        processed.Should().HaveCount(5);
        processed.Select(e => e.Id).Should().BeEquivalentTo(new[] { 1, 2, 3, 4, 5 });
    }

    [Fact]
    public async Task StreamProductsAsync_YieldsAllItems()
    {
        // Arrange
        var fakeRepo = Mock.Of<IProductRepository>(
            r => r.StreamAsync(CancellationToken.None) == FakeProducts());
        var sut = new ProductQueryService(fakeRepo);

        // Act
        var result = await sut.StreamProductsAsync(CancellationToken.None).ToListAsync();

        // Assert
        result.Should().HaveCount(3);
    }

    private static async IAsyncEnumerable<Product> FakeProducts()
    {
        yield return new Product { Id = 1, Name = "A" };
        yield return new Product { Id = 2, Name = "B" };
        yield return new Product { Id = 3, Name = "C" };
        await Task.CompletedTask; // suppress compiler warning
    }
}
```

## Common Follow-up Questions
- What is the difference between `Channel<T>` and `IAsyncEnumerable<T>`?
- How do you mock `IAsyncEnumerable<T>` with Moq?
- How do you test a producer-consumer with backpressure (bounded channel)?
- What is `ChannelClosedException` and when does it occur?
- How do you use `ConfigureAwait(false)` with `await foreach`?

## Common Mistakes / Pitfalls
- **Forgetting to call `channel.Writer.Complete()`** — the reader hangs indefinitely waiting for more items.
- **Not awaiting `ReadAllAsync` fully** — partial reads leave items in the channel and tests may time out.
- **Using `channel.Reader.ReadAsync()` in a test loop without proper completion handling** — throws `ChannelClosedException`.
- **Mocking `IAsyncEnumerable` incorrectly** — returning a `List<T>` as an async enumerable without `await` breaks async contract; use a real `async IAsyncEnumerable` helper method.

## References
- [Microsoft Learn — Channel<T>](https://learn.microsoft.com/en-us/dotnet/core/extensions/channels)
- [Microsoft Learn — IAsyncEnumerable<T>](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.iasyncenumerable-1)
- [Stephen Toub — An Introduction to System.Threading.Channels](https://devblogs.microsoft.com/dotnet/an-introduction-to-system-threading-channels/)
