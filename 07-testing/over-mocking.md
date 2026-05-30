# What Are the Dangers of Over-Mocking?

**Category:** Testing / Test Design & Best Practices
**Difficulty:** 🔴 Senior
**Tags:** `over-mocking`, `test-design`, `brittle-tests`, `test-doubles`, `mock-smell`

## Question
> What are the dangers of over-mocking and how do you know when you've mocked too much?

## Short Answer
Over-mocking produces tests that pass even when the system is broken, break on internal refactors, and test implementation rather than behaviour. Signs include: mocking domain logic, asserting method call counts instead of outcomes, mocking `HttpClient` when `WebApplicationFactory` would be better, and tests where the mock setup is longer than the code under test. The fix is using fakes, in-memory implementations, or integration tests where appropriate.

## Detailed Explanation

### What Is Over-Mocking?
Over-mocking occurs when you mock dependencies that:
- Contain business logic you also need to test
- Are pure/deterministic and have no I/O side effects
- Are your own domain classes (not external boundaries)

### Danger 1: Mocking Domain Logic
```csharp
// ❌ Don't mock domain services that contain business rules
var taxCalc = new Mock<ITaxCalculator>();
taxCalc.Setup(t => t.Compute(100m)).Returns(10m);

// If TaxCalculator.Compute has a bug, this test will never catch it.
// The mock returns 10m regardless of what the real code does.
```

**Fix:** Use the real `TaxCalculator` (or a lightweight in-memory fake).

### Danger 2: Tests That Verify How, Not What
```csharp
// ❌ Verifying call order / arguments — tests implementation details
repoMock.Verify(r => r.BeginTransaction(), Times.Once);
repoMock.Verify(r => r.Insert(order), Times.Once);
repoMock.Verify(r => r.CommitTransaction(), Times.Once);
```
If the implementation switches from manual transactions to EF Core's `SaveChanges`, all three verifications fail — even though the behaviour (order saved) is identical.

**Fix:** Verify the observable outcome: `repo.GetById(1).Should().NotBeNull()`.

### Danger 3: Tests Longer Than Production Code
If your `Arrange` section with 10 `Setup` calls is longer than the 5-line method being tested, the test has too much mock setup. This signals:
- The SUT has too many dependencies (design smell)
- Or you're mocking things you shouldn't

### Danger 4: Green Tests Hide Real Bugs
```csharp
// ❌ Mocking HttpClient entirely bypasses real HTTP behaviour
// Tests pass but the integration is broken
mockHttp.Setup(c => c.GetAsync("...")).ReturnsAsync(ok); // mocked at the wrong level
```

The service may not serialize JSON correctly, send wrong headers, or fail on real redirects — the mock can't catch this.

### Signals You've Mocked Too Much

| Signal | What It Means |
|---|---|
| Mock setup > code being tested | SUT has too many dependencies |
| Mocking `IClock`, `IIdGenerator` but also `IOrderService` | Mixing infrastructure and domain mocks |
| Tests break on every internal refactor | Testing implementation, not behaviour |
| 100% unit test coverage, but integration tests fail | Mocks too disconnected from reality |
| `Mock<IList<T>>` or `Mock<List<T>>` | Mocking concrete collections — always wrong |

### The Rule of Thumb: Mock Only External Boundaries
Mock: databases, HTTP clients, email/SMS services, file systems, message queues, clocks.  
Don't mock: domain services, value objects, pure functions, collections, your own repositories if a fake is easy.

## Code Example
```csharp
namespace OverMocking.Tests;

// ❌ Over-mocked — mocks domain logic, verifies internals
public class PricingService_OverMocked_Tests
{
    [Fact]
    public void CalculateTotal_AppliesDiscount()
    {
        var discountCalc = new Mock<IDiscountCalculator>(); // ❌ domain logic mocked
        discountCalc.Setup(d => d.GetDiscount(It.IsAny<Customer>())).Returns(10m);
        var taxCalc = new Mock<ITaxCalculator>(); // ❌ domain logic mocked
        taxCalc.Setup(t => t.Compute(It.IsAny<decimal>())).Returns(9m);
        var repo = new Mock<IOrderRepository>();

        var sut = new PricingService(discountCalc.Object, taxCalc.Object, repo.Object);
        var total = sut.CalculateTotal(new Customer { IsVip = true }, subtotal: 100m);

        // ❌ Verifies call, not correctness
        discountCalc.Verify(d => d.GetDiscount(It.IsAny<Customer>()), Times.Once);
        taxCalc.Verify(t => t.Compute(It.IsAny<decimal>()), Times.Once);
        total.Should().Be(99m);
    }
}

// ✅ Only mock I/O boundary; use real domain logic
public class PricingService_CorrectlyMocked_Tests
{
    [Fact]
    public void CalculateTotal_VipCustomer_AppliesDiscountAndTax()
    {
        // Real domain logic — catches bugs in discount/tax calculation
        var discountCalc = new DiscountCalculator();
        var taxCalc = new TaxCalculator();
        var repo = new Mock<IOrderRepository>(); // ✅ only the I/O boundary is mocked

        var sut = new PricingService(discountCalc, taxCalc, repo.Object);
        var total = sut.CalculateTotal(new Customer { IsVip = true }, subtotal: 100m);

        // ✅ Assert the actual business outcome
        total.Should().Be(99m); // (100 - 10%) * 1.1
    }
}
```

## Common Follow-up Questions
- What is the "classical" vs. "mockist" school of TDD and how do they differ on mocking?
- How do you decide what to mock vs. what to use a fake for?
- What is the "fragile test" problem and how does over-mocking cause it?
- How does over-mocking relate to the Single Responsibility Principle?
- What is a "sociable unit test" and is it better than a "solitary unit test"?
- How do you refactor a test suite that has too many mocks?

## Common Mistakes / Pitfalls
- **Mocking everything "for purity"** — leads to tests that verify nothing meaningful.
- **Verify instead of Assert** — `Verify(repo.Save(...), Times.Once)` tests implementation; `repo.GetById(1).ShouldNotBeNull()` tests behaviour.
- **Mocking concrete classes** — Moq can't mock non-virtual methods; this usually indicates the design needs an interface.
- **Chained mocks (`mock.Setup(x => x.GetService().DoThing())`)** — signs of Law of Demeter violation in production code.
- **Assuming that passing tests with mocks = working system** — always pair unit tests with integration tests for the boundaries you mocked.

## References
- [Martin Fowler — Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Vladimir Khorikov — The Mockist vs. Classical debate](https://enterprisecraftsmanship.com/posts/when-to-mock/) (verify URL)
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
- [Vladimir Khorikov — Unit Testing Principles, Practices, and Patterns](https://www.manning.com/books/unit-testing)
