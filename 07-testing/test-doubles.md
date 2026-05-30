# What Is a Test Double and What Are the Different Types?

**Category:** Testing / Mocking
**Difficulty:** 🟢 Junior
**Tags:** `test-doubles`, `dummy`, `stub`, `spy`, `mock`, `fake`, `mocking`

## Question
> What is a test double and what are the different types (dummy, stub, spy, mock, fake)?

## Short Answer
A test double is any object that stands in for a real dependency in a test. Gerard Meszaros defined five types: **Dummy** (placeholder not used), **Stub** (returns canned values), **Spy** (records interactions for later assertion), **Mock** (pre-programmed with expectations), and **Fake** (real but simplified implementation). Understanding the distinctions helps you choose the right tool for each test.

## Detailed Explanation

### The Five Types (Meszaros Taxonomy)

#### 1. Dummy
An object passed to fill a parameter but never actually used in the test. It satisfies a method signature requirement.

```csharp
// We need an ILogger, but this test doesn't exercise logging
var logger = Mock.Of<ILogger<OrderService>>(); // dummy — never called
```

#### 2. Stub
Returns predetermined, "canned" data to drive the system under test into a specific state. The test does **not** assert on the stub itself.

```csharp
// Stub: returns a fixed customer so the SUT has data to work with
var customerRepo = new Mock<ICustomerRepository>();
customerRepo.Setup(r => r.GetById(1)).Returns(new Customer { Name = "Alice" });
```

#### 3. Spy
A real or partial implementation that records how it was called. You check the spy **after** the SUT runs to verify interactions.

```csharp
// Spy: records sent emails for later assertion
public class SpyEmailSender : IEmailSender
{
    public List<Email> SentEmails { get; } = new();
    public Task SendAsync(Email email) { SentEmails.Add(email); return Task.CompletedTask; }
}
```

#### 4. Mock
A pre-programmed double with **expectations set up before the call**. The mock itself verifies that the expected interactions happened. Moq's `Verify` turns a mock into a mock in this strict sense.

```csharp
// Mock: verifies the SUT called Send with the right argument
var emailSender = new Mock<IEmailSender>();
sut.ConfirmOrder(order);
emailSender.Verify(e => e.Send(It.Is<Email>(m => m.To == "user@test.com")), Times.Once);
```

#### 5. Fake
A working implementation that takes shortcuts not suitable for production (e.g., in-memory database, fake file system, in-process message broker).

```csharp
// Fake: fully functional but in-memory, not a real DB
public class FakeOrderRepository : IOrderRepository
{
    private readonly Dictionary<int, Order> _store = new();
    public void Save(Order o) => _store[o.Id] = o;
    public Order? FindById(int id) => _store.GetValueOrDefault(id);
}
```

### Type Comparison

| Type | Has logic? | Assertions on it? | Production alternative |
|---|---|---|---|
| Dummy | No | No | Real object (unused) |
| Stub | No | No | Repository, service |
| Spy | No (records) | Yes (after-the-fact) | Event recorder |
| Mock | No (expectations) | Yes (pre-set) | Same as stub |
| Fake | Yes (simplified) | Possibly | Full implementation |

> 💡 In practice, "mock" has become colloquial shorthand for *any* test double. Moq's objects can serve as dummies, stubs, mocks, or spies depending on how you use them.

### Martin Fowler vs. Meszaros
Martin Fowler simplifies to **stub** (indirect inputs) and **mock** (verifiable interactions). Neither is wrong — the Meszaros taxonomy is more precise; Fowler's is more practical for daily communication.

## Code Example
```csharp
namespace Ordering.Tests;

public class OrderProcessorTests
{
    [Fact]
    public void ProcessOrder_WithValidOrder_SendsConfirmationEmail()
    {
        // ── Dummy ──────────────────────────────────────────────────────
        var logger = Mock.Of<ILogger<OrderProcessor>>();

        // ── Stub ───────────────────────────────────────────────────────
        var pricingService = new Mock<IPricingService>();
        pricingService.Setup(p => p.GetPrice("SKU-1")).Returns(99m);

        // ── Spy ────────────────────────────────────────────────────────
        var emailSpy = new SpyEmailSender();

        // ── Fake ───────────────────────────────────────────────────────
        var orderRepo = new FakeOrderRepository();

        var sut = new OrderProcessor(pricingService.Object, emailSpy, orderRepo, logger);
        sut.Process(new Order { Id = 1, Sku = "SKU-1", Qty = 2 });

        // Assert via spy
        emailSpy.SentEmails.Should().ContainSingle(e => e.Subject.Contains("Confirmation"));
        // Assert via fake
        orderRepo.FindById(1).Should().NotBeNull();
    }
}

public class SpyEmailSender : IEmailSender
{
    public List<Email> SentEmails { get; } = new();
    public Task SendAsync(Email email) { SentEmails.Add(email); return Task.CompletedTask; }
}

public class FakeOrderRepository : IOrderRepository
{
    private readonly Dictionary<int, Order> _data = new();
    public void Save(Order o) => _data[o.Id] = o;
    public Order? FindById(int id) => _data.GetValueOrDefault(id);
}
```

## Common Follow-up Questions
- What is the difference between a stub and a mock?
- When should you use a fake instead of a mock?
- What is a "partial mock" and when is it useful?
- How does Moq support multiple test double patterns in one framework?
- What are the drawbacks of using mocks extensively?
- When is a hand-rolled fake better than a mock library?

## Common Mistakes / Pitfalls
- **Using "mock" to mean any test double** — imprecise language in team discussions; try to use the correct type name.
- **Using a mock where a fake is better** — a fake with real logic (in-memory repo) is often more readable and less brittle than a mock with complex `Setup` chains.
- **Using a spy where state-based assertion suffices** — if you can check the return value, prefer state-based; spies add complexity.
- **Forgetting to set up required stubs** — a Loose mock returns default values silently, which may cause the SUT to behave differently than expected.
- **Over-using dummies** — if a parameter is truly unused, refactor the API to not require it.

## References
- [Gerard Meszaros — xUnit Test Patterns: Test Doubles chapter](http://xunitpatterns.com/Test%20Double.html)
- [Martin Fowler — Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Moq documentation](https://github.com/devlooped/moq/wiki/Quickstart)
- [Vladimir Khorikov — Unit Testing Principles, Practices, and Patterns (Manning)](https://www.manning.com/books/unit-testing)
