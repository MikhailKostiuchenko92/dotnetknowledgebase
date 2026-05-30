# What Is `AutoMock` / `AutoFixture` and How Does It Reduce Mock Boilerplate?

**Category:** Testing / Mocking
**Difficulty:** 🔴 Senior
**Tags:** `AutoFixture`, `AutoMock`, `Moq.AutoMock`, `test-data`, `boilerplate`

## Question
> What is `AutoMock` / `AutoFixture` and how does it reduce mock boilerplate?

## Short Answer
**AutoFixture** is a test data generation library that creates anonymous objects with random but valid values, eliminating `new Order { ... }` arrange boilerplate. **AutoMock** (via `Moq.AutoMock` or `AutoFixture.AutoMoq`) extends this to auto-create mock dependencies, so you don't manually declare every `new Mock<IDep>()` — the library resolves the SUT's constructor arguments automatically.

## Detailed Explanation

### The Problem: Constructor Injection Boilerplate
As classes grow, tests accumulate many mock declarations:
```csharp
// ❌ Tedious — every test method needs all dependencies
var logger = new Mock<ILogger<OrderService>>();
var repo = new Mock<IOrderRepository>();
var payments = new Mock<IPaymentGateway>();
var notifications = new Mock<INotificationService>();
var sut = new OrderService(logger.Object, repo.Object, payments.Object, notifications.Object);
```

### AutoFixture for Test Data
```csharp
var fixture = new Fixture();
var order = fixture.Create<Order>(); // random Id, Name, Amount, etc.
var orders = fixture.CreateMany<Order>(3).ToList();
```

Eliminates magic literals in Arrange sections. Test focuses on the specific values that matter; everything else is irrelevant anonymous data.

### `AutoData` Attribute (xUnit integration)
```csharp
[Theory, AutoData]
public void Calculate_Total_ReturnsCorrectSum(Order order, decimal taxRate)
{
    // order and taxRate are auto-generated random values
    var result = TaxCalculator.Apply(order, taxRate);
    result.Total.Should().Be(order.Subtotal * (1 + taxRate));
}
```

### AutoMoq Customization
```csharp
var fixture = new Fixture().Customize(new AutoMoqCustomization());
var sut = fixture.Create<OrderService>(); // all constructor args auto-mocked

var repoMock = fixture.Freeze<Mock<IOrderRepository>>(); // freeze = same instance everywhere
repoMock.Setup(r => r.GetById(1)).Returns(fixture.Create<Order>());
```

`Freeze<T>` ensures the same `Mock<T>` instance is injected everywhere (including into the SUT).

### Moq.AutoMock (Alternative)
```csharp
using var mocker = new AutoMocker();
mocker.GetMock<IOrderRepository>()
      .Setup(r => r.GetById(1)).Returns(new Order { Id = 1 });

var sut = mocker.CreateInstance<OrderService>();
```
`AutoMocker` is simpler if you only need auto-mocking (no test data generation).

### `[AutoMoqData]` Custom Attribute
```csharp
public class AutoMoqDataAttribute : AutoDataAttribute
{
    public AutoMoqDataAttribute()
        : base(() => new Fixture().Customize(new AutoMoqCustomization())) { }
}

[Theory, AutoMoqData]
public void Process_Order_ShouldCallRepository(
    [Frozen] Mock<IOrderRepository> repo,
    OrderService sut,
    Order order)
{
    repo.Setup(r => r.GetById(order.Id)).Returns(order);
    sut.Process(order.Id);
    repo.Verify(r => r.GetById(order.Id), Times.Once);
}
```

### Comparison: Manual vs. AutoFixture+AutoMoq

| Concern | Manual | AutoFixture + AutoMoq |
|---|---|---|
| Mock creation | Explicit per test | Auto from constructor |
| Test data | Hand-crafted values | Random valid objects |
| Adding a dependency | Update every test | Update only tests that care |
| Learning curve | Low | Medium |
| Debuggability | Easy | Harder (anonymous data) |

> ⚠️ AutoFixture generates *random* data — if a test fails intermittently because of a specific random value, use `fixture.Freeze<T>()` or `[Frozen]` to pin the relevant values.

## Code Example
```csharp
namespace AutoFixtureDemo.Tests;

// Custom attribute for convenience
public class AutoMoqDataAttribute : AutoDataAttribute
{
    public AutoMoqDataAttribute()
        : base(() => new Fixture().Customize(new AutoMoqCustomization { ConfigureMembers = true })) { }
}

public class InvoiceServiceTests
{
    // ── Manual (old way) ──────────────────────────────────────────
    [Fact]
    public void Manual_GenerateInvoice_CallsRepository()
    {
        var repo = new Mock<IInvoiceRepository>();
        var taxSvc = new Mock<ITaxService>();
        var logger = new Mock<ILogger<InvoiceService>>();
        var order = new Order { Id = 1, Amount = 100m, CustomerId = 42 };

        repo.Setup(r => r.GetOrder(1)).Returns(order);
        taxSvc.Setup(t => t.GetRate("US")).Returns(0.1m);

        var sut = new InvoiceService(repo.Object, taxSvc.Object, logger.Object);
        sut.Generate(1, "US");

        repo.Verify(r => r.GetOrder(1), Times.Once);
    }

    // ── AutoFixture + AutoMoq (new way) ───────────────────────────
    [Theory, AutoMoqData]
    public void AutoMoq_GenerateInvoice_CallsRepository(
        [Frozen] Mock<IInvoiceRepository> repo,
        [Frozen] Mock<ITaxService> taxSvc,
        Order order,
        InvoiceService sut) // sut auto-created with all mocks injected
    {
        repo.Setup(r => r.GetOrder(order.Id)).Returns(order);
        taxSvc.Setup(t => t.GetRate(Arg.Any<string>())).Returns(0.1m);

        sut.Generate(order.Id, "US");

        repo.Verify(r => r.GetOrder(order.Id), Times.Once);
    }
}
```

## Common Follow-up Questions
- What is the difference between `Freeze<T>` and `Create<T>` in AutoFixture?
- How do you customize AutoFixture to generate domain-specific valid values (e.g., non-negative amounts)?
- What is `ConfigureMembers = true` in `AutoMoqCustomization` and when do you need it?
- How do you use the `[Frozen]` attribute in conjunction with `[AutoData]`?
- How does `AutoMocker` (Moq.AutoMock) differ from the AutoFixture+AutoMoq approach?
- What are the trade-offs of using AutoFixture in a large team codebase?

## Common Mistakes / Pitfalls
- **Forgetting `[Frozen]` for shared mocks** — without `[Frozen]`, AutoFixture creates a *new* `Mock<T>` for the parameter and a *different* one for the SUT constructor; they are not the same instance.
- **Not using `ConfigureMembers = true`** — without it, interface properties are not automatically stubbed, causing `NullReferenceException` when the SUT accesses a property on a mocked dependency.
- **Debugging random failures** — AutoFixture generates random data; a failing test may not reproduce easily. Always pin the specific value with `[Frozen]` or `fixture.Inject<T>(known value)`.
- **Overusing AutoFixture for complex domain objects** — auto-generated objects may violate domain invariants (negative prices, invalid dates). Use custom `ICustomization` or `SpecimenBuilder` to constrain domains.
- **Treating AutoFixture as a replacement for test readability** — hiding all arrange data behind auto-generation can make tests opaque; reserve explicit values for the data that actually drives the test outcome.

## References
- [AutoFixture on GitHub](https://github.com/AutoFixture/AutoFixture)
- [NuGet — AutoFixture.AutoMoq](https://www.nuget.org/packages/AutoFixture.AutoMoq/)
- [NuGet — Moq.AutoMock](https://www.nuget.org/packages/Moq.AutoMock/)
- [AutoFixture documentation — Cheat Sheet](https://github.com/AutoFixture/AutoFixture/wiki/Cheat-Sheet)
- [Mark Seemann — AutoFixture introduction](https://blog.ploeh.dk/2009/03/22/AnnouncingAutoFixture/) (verify URL)
