# How Do You Test Code That Uses `DateTime.Now` or `Guid.NewGuid()`?

**Category:** Testing / Test Design & Best Practices
**Difficulty:** 🔴 Senior
**Tags:** `DateTime`, `Guid`, `non-deterministic`, `ISystemClock`, `TimeProvider`, `dependency-injection`

## Question
> How do you test code that uses `DateTime.Now` or `Guid.NewGuid()` (non-deterministic dependencies)?

## Short Answer
Inject the source of non-determinism as an abstraction that can be replaced in tests. For time, use `TimeProvider` (.NET 8+) or a custom `ISystemClock`/`IClock` interface. For GUIDs, inject an `IIdGenerator` or `Func<Guid>`. In tests, substitute the real implementation with a controllable fake that returns fixed, predictable values.

## Detailed Explanation

### The Problem: Static Non-Determinism
```csharp
public class OrderService
{
    public Order CreateOrder()
    {
        return new Order
        {
            Id = Guid.NewGuid(), // untestable
            CreatedAt = DateTime.UtcNow // untestable
        };
    }
}
```
You can't assert on random GUIDs or control timestamps in tests.

### Solution 1: `TimeProvider` (.NET 8+) — Official Approach
```csharp
public class OrderService(TimeProvider time)
{
    public Order CreateOrder() => new()
    {
        Id = Guid.NewGuid(),
        CreatedAt = time.GetUtcNow().UtcDateTime
    };
}

// Production registration:
services.AddSingleton(TimeProvider.System);

// In tests:
var fakeTime = new FakeTimeProvider(new DateTimeOffset(2024, 6, 1, 12, 0, 0, TimeSpan.Zero));
var sut = new OrderService(fakeTime);
var order = sut.CreateOrder();
order.CreatedAt.Should().Be(new DateTime(2024, 6, 1, 12, 0, 0));
```

`FakeTimeProvider` is available in `Microsoft.Extensions.TimeProvider.Testing`.

### Solution 2: Custom `ISystemClock` Interface
```csharp
public interface ISystemClock
{
    DateTime UtcNow { get; }
}

public class SystemClock : ISystemClock
{
    public DateTime UtcNow => DateTime.UtcNow;
}

public class FakeClock(DateTime utcNow) : ISystemClock
{
    public DateTime UtcNow => utcNow;
}

// In tests:
var clock = new FakeClock(new DateTime(2024, 6, 1));
var sut = new OrderService(clock);
```

### Solution 3: `Func<DateTime>` Delegate (Lightweight)
```csharp
public class OrderService(Func<DateTime> getNow)
{
    public Order CreateOrder() => new() { CreatedAt = getNow() };
}

// Production: new OrderService(() => DateTime.UtcNow)
// Test: new OrderService(() => new DateTime(2024, 6, 1))
```

### Solution 4: Injecting `IIdGenerator` for GUIDs
```csharp
public interface IIdGenerator
{
    Guid NewId();
}

public class GuidIdGenerator : IIdGenerator
{
    public Guid NewId() => Guid.NewGuid();
}

public class SequentialIdGenerator : IIdGenerator
{
    private int _counter;
    public Guid NewId() => new($"00000000-0000-0000-0000-{++_counter:D12}");
}
```

### Summary of Options

| Dependency | Production | Test Replacement |
|---|---|---|
| `DateTime.UtcNow` | `TimeProvider.System` (.NET 8+) | `FakeTimeProvider` |
| `DateTime.UtcNow` | `ISystemClock` | `FakeClock(fixedDate)` |
| `Guid.NewGuid()` | `IIdGenerator` | `FakeIdGenerator(knownId)` |
| `Random.Next()` | `IRandom` | `FakeRandom(fixedSeed)` |

## Code Example
```csharp
namespace NonDeterminism.Tests;

// ── .NET 8 TimeProvider approach ──────────────────────────
public class InvoiceServiceTests
{
    [Fact]
    public void CreateInvoice_SetsCreatedAtToCurrentTime()
    {
        var fixedTime = new DateTimeOffset(2024, 3, 15, 9, 0, 0, TimeSpan.Zero);
        var fakeTime = new FakeTimeProvider(fixedTime);
        var sut = new InvoiceService(fakeTime);

        var invoice = sut.Create(orderId: 1, amount: 250m);

        invoice.CreatedAt.Should().Be(fixedTime.UtcDateTime);
    }

    [Fact]
    public void CreateInvoice_DueIn30Days()
    {
        var fixedTime = new DateTimeOffset(2024, 3, 15, 0, 0, 0, TimeSpan.Zero);
        var fakeTime = new FakeTimeProvider(fixedTime);
        var sut = new InvoiceService(fakeTime);

        var invoice = sut.Create(orderId: 1, amount: 250m);

        invoice.DueDate.Should().Be(fixedTime.UtcDateTime.AddDays(30));
    }
}

// ── GUID injection ────────────────────────────────────────
public class FakeIdGenerator : IIdGenerator
{
    private readonly Queue<Guid> _ids;
    public FakeIdGenerator(params Guid[] ids) => _ids = new Queue<Guid>(ids);
    public Guid NewId() => _ids.Dequeue();
}

public class OrderCreationTests
{
    [Fact]
    public void CreateOrder_AssignsKnownId()
    {
        var knownId = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
        var sut = new OrderService(new FakeIdGenerator(knownId));

        var order = sut.Create();

        order.Id.Should().Be(knownId);
    }
}
```

## Common Follow-up Questions
- What is `TimeProvider` in .NET 8 and how does `FakeTimeProvider` work?
- Why should you prefer `TimeProvider` over a custom `ISystemClock`?
- How do you advance time in `FakeTimeProvider` for deadline/expiry tests?
- How do you test code that uses `DateTimeOffset` vs `DateTime`?
- Should you inject `IIdGenerator` for every service or only when ID predictability matters?
- What is the `IClock` interface in ASP.NET Core and how does it relate to `TimeProvider`?

## Common Mistakes / Pitfalls
- **Testing with real `DateTime.UtcNow`** — tests may fail on midnight boundary, DST transitions, or leap seconds.
- **Mocking `DateTime` with Moq** — `DateTime` is a struct; Moq cannot mock it; you must use an abstraction.
- **Not registering `TimeProvider.System` in DI** — forgetting to add the production implementation causes `NullReferenceException` at runtime.
- **Using a single shared `FakeTimeProvider` instance in parallel tests** — advancing time on a shared provider affects other tests; create a new instance per test.
- **Forgetting `Guid.NewGuid()` in constructors** — IDs generated in constructors rather than factory methods are harder to control; centralise creation in a service.

## References
- [Microsoft Learn — TimeProvider](https://learn.microsoft.com/en-us/dotnet/api/system.timeprovider)
- [Microsoft.Extensions.TimeProvider.Testing on NuGet](https://www.nuget.org/packages/Microsoft.Extensions.TimeProvider.Testing/)
- [Andrew Lock — FakeTimeProvider](https://andrewlock.net/exploring-the-dotnet-8-preview-fake-time-provider/) (verify URL)
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
