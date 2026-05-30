# When Is It Appropriate to Use a Fake vs. a Mock?

**Category:** Testing / Test Design & Best Practices
**Difficulty:** 🔴 Senior
**Tags:** `fake`, `mock`, `test-doubles`, `test-design`, `trade-offs`

## Question
> When is it appropriate to use a fake vs. a mock? Discuss with an example.

## Short Answer
Use a **fake** when you need a working lightweight implementation that behaves correctly (e.g., `InMemoryRepository`), and you want tests that focus on outcomes rather than implementation details. Use a **mock** when you need to verify that a specific interaction occurred (e.g., confirm `emailService.Send()` was called exactly once) or when creating a real implementation is impractical. Fakes test *what*, mocks test *how*.

## Detailed Explanation

### Definitions
- **Fake**: A real, simplified implementation that works but takes shortcuts (e.g., stores data in a `Dictionary<int, T>` instead of a database).
- **Mock**: A test double that records interactions and can be configured to return values or throw exceptions on specific calls.

| | Fake | Mock |
|---|---|---|
| Has logic? | ✅ Yes (simplified) | ❌ No (programmed responses) |
| Verifies calls? | ❌ Typically not | ✅ Yes |
| Tests what? | Observable state/output | That specific calls happened |
| Brittle to refactoring? | Low | Higher (verifies internals) |
| Maintenance? | Update when contract changes | Update when call details change |

### Use a Fake When…
- The dependency has stateful behaviour that matters (a repository stores and retrieves data).
- You want tests decoupled from implementation internals.
- The real implementation is slow/external but a simplified version is easy to write.

```csharp
// Fake repository — real logic, no DB
public class InMemoryOrderRepository : IOrderRepository
{
    private readonly Dictionary<int, Order> _store = new();
    public void Save(Order order) => _store[order.Id] = order;
    public Order? GetById(int id) => _store.GetValueOrDefault(id);
}

// Test focuses on outcome — does Save + GetById round-trip work?
[Fact]
public void Process_SavesOrderAndCanRetrieveIt()
{
    var repo = new InMemoryOrderRepository();
    var sut = new OrderService(repo);
    sut.Process(new Order { Id = 1, Amount = 100m });
    repo.GetById(1).Should().NotBeNull();
}
```

### Use a Mock When…
- You need to verify an interaction occurred (notification sent, event published, external API called).
- The dependency is a fire-and-forget service with no observable state.
- The dependency is expensive or impossible to fake (third-party SDK, hardware).

```csharp
// Mock — verify the notification was sent
[Fact]
public void Process_ValidOrder_SendsConfirmationEmail()
{
    var emailMock = new Mock<IEmailService>();
    var sut = new OrderService(new InMemoryOrderRepository(), emailMock.Object);
    sut.Process(new Order { Id = 1, Amount = 100m, CustomerEmail = "a@b.com" });
    emailMock.Verify(e => e.Send("a@b.com", It.IsAny<string>()), Times.Once);
}
```

### Decision Guide
```
Does the test care whether an interaction happened?
  ├─ Yes → Mock (IEmailService, IEventBus, ILogger calls)
  └─ No → Does the dependency have stateful logic that matters?
       ├─ Yes → Fake (IRepository, ICache, IQueue)
       └─ No → Stub (simple return value, no verification needed)
```

### The Danger of Over-Mocking
Mocking a repository and then verifying `SaveAsync` was called tests *implementation*, not *behaviour*. If the team later wraps persistence in a Unit of Work, the mock breaks even though behaviour is identical. A fake repo prevents this.

## Code Example
```csharp
namespace FakeVsMock.Tests;

// ── Fake: repository with stateful logic ─────────────────────
public class InMemoryProductRepository : IProductRepository
{
    private readonly List<Product> _products = [];
    public Task<Product?> GetByIdAsync(int id) =>
        Task.FromResult(_products.FirstOrDefault(p => p.Id == id));
    public Task SaveAsync(Product product)
    {
        _products.RemoveAll(p => p.Id == product.Id);
        _products.Add(product);
        return Task.CompletedTask;
    }
}

// ── Mock: notification (fire-and-forget, no state to check) ──
public class ProductServiceTests
{
    private readonly InMemoryProductRepository _repo = new();
    private readonly Mock<IInventoryNotifier> _notifier = new();
    private ProductService Sut => new(_repo, _notifier.Object);

    [Fact]
    public async Task UpdatePrice_PersistsNewPrice_UsingFakeRepo()
    {
        await _repo.SaveAsync(new Product { Id = 1, Price = 50m });

        await Sut.UpdatePriceAsync(1, 75m);

        var saved = await _repo.GetByIdAsync(1);
        saved!.Price.Should().Be(75m); // state-based assertion on fake
    }

    [Fact]
    public async Task UpdatePrice_NotifiesInventorySystem_UsingMock()
    {
        await _repo.SaveAsync(new Product { Id = 1, Price = 50m });

        await Sut.UpdatePriceAsync(1, 75m);

        // Interaction-based assertion on mock
        _notifier.Verify(n => n.PriceChangedAsync(1, 75m), Times.Once);
    }
}
```

## Common Follow-up Questions
- What is the difference between a stub, a mock, and a fake?
- When should you write a fake instead of using Moq?
- Can a fake evolve into the real implementation?
- How do you decide when to use `InMemoryDatabase` (EF Core) vs. SQLite in-memory?
- What is "mockist TDD" vs. "classicist TDD"?
- How do you share fakes across multiple test projects?

## Common Mistakes / Pitfalls
- **Mocking the repository for state-based tests** — you end up asserting `SaveAsync` was called, not that the data was persisted correctly.
- **Writing fakes that are too naive** — a fake that doesn't enforce domain constraints (e.g., allows duplicate IDs) can hide bugs.
- **Using a mock where a fake would give more confidence** — "if I mock everything, I'm only testing that I call things in a certain order."
- **Sharing fake instances between tests** — fakes accumulate state; create a new fake per test or reset between tests.
- **Not documenting deviations in the fake** — if `InMemoryRepo` doesn't enforce a uniqueness constraint that the real DB does, document it so tests aren't falsely trusted.

## References
- [Martin Fowler — Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Martin Fowler — Test Double](https://martinfowler.com/bliki/TestDouble.html)
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
- [Vladimir Khorikov — Unit Testing Principles, Practices, and Patterns](https://www.manning.com/books/unit-testing)
