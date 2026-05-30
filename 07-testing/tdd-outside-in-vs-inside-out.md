# Outside-In (London School) TDD vs. Inside-Out (Chicago School) TDD

**Category:** Testing / TDD
**Difficulty:** 🟡 Middle
**Tags:** `TDD`, `Outside-In`, `Inside-Out`, `London-School`, `Chicago-School`, `mockist`, `classicist`

## Question
> What is the "Outside-In" (London School) TDD style vs. "Inside-Out" (Chicago School)?

## Short Answer
**Outside-In (London/Mockist)** starts from the user-facing boundary (API, UI) and works inward using mocks for unimplemented collaborators; you drive design top-down. **Inside-Out (Chicago/Classicist)** starts from core domain objects and builds outward; few mocks, real implementations, bottom-up design. Neither is universally superior — choose based on context.

## Detailed Explanation

### London School (Outside-In, Mockist)
- Start with an acceptance test (or an entry-point test for a controller/use case).
- Use mock objects for any collaborators that don't yet exist.
- Drive the design of inner layers by how the outer layer calls them.
- Heavy on mocking; interfaces emerge naturally.

**Strengths:**
- Forces a clean API contract before implementation
- Good for top-down feature development with well-defined acceptance criteria
- Reveals coupling issues early

**Weaknesses:**
- Tests are coupled to internal implementation (collaborator interactions)
- Over-specified tests break during refactoring even when behaviour is unchanged
- "Mock hell" if overdone

### Chicago School (Inside-Out, Classicist)
- Start with the innermost domain object.
- Use real implementations as much as possible.
- Build outward once inner layers are solid.
- Mocks used only for external boundaries (DB, HTTP, etc.).

**Strengths:**
- Tests are stable across refactoring (test behaviour, not implementation)
- Natural alignment with domain-driven design
- Less test brittleness

**Weaknesses:**
- May not reveal design issues until later in development
- Building inner layers first requires upfront decisions about structure

### Comparison Table

| Aspect | Outside-In (London) | Inside-Out (Chicago) |
|---|---|---|
| Starting point | Acceptance/system boundary | Core domain object |
| Use of mocks | Heavy (all collaborators) | Minimal (only external) |
| Design direction | Top-down | Bottom-up |
| Test stability | Lower (brittle to refactoring) | Higher |
| Good for | Feature-driven, API-first | Domain-driven, library code |
| Risk | Over-mocking | Building wrong abstractions early |

### Hybrid Approach
Most experienced practitioners use both:
- Outside-In for new features (acceptance test first)
- Chicago-style for domain logic (pure unit tests, no mocks)

## Code Example
```csharp
// --- LONDON (Outside-In) ---
// Starts with the handler, mocks the repository before it exists

[Fact]
public async Task CreateOrder_ValidRequest_ReturnsOrderId()
{
    var repo = new Mock<IOrderRepository>();
    repo.Setup(r => r.SaveAsync(It.IsAny<Order>(), default))
        .ReturnsAsync(Guid.NewGuid());

    var handler = new CreateOrderHandler(repo.Object);
    var result = await handler.HandleAsync(new CreateOrderCommand("Item A", 2));

    result.OrderId.Should().NotBeEmpty();
}

// --- CHICAGO (Inside-Out) ---
// Starts with Order domain object, no mocks needed

[Fact]
public void Order_WithZeroQuantity_ThrowsDomainException()
{
    var act = () => new Order("Item A", quantity: 0);
    act.Should().Throw<DomainException>()
       .WithMessage("*quantity*");
}

[Fact]
public void Order_ApplyDiscount_ReducesTotal()
{
    var order = new Order("Item A", quantity: 2, unitPrice: 50m);
    order.ApplyDiscount(0.1m);
    order.Total.Should().Be(90m);
}
```

## Common Follow-up Questions
- When would you choose Outside-In over Inside-Out in a real project?
- How does Outside-In TDD relate to Acceptance-Test-Driven Development (ATDD)?
- What is the difference between a "mockist" and a "classicist" test double philosophy?
- How do you avoid over-mocking when using London-style TDD?
- Can you use both styles in the same project?

## Common Mistakes / Pitfalls
- **London-style: testing implementation, not behaviour** — each mock.Verify assertion couples the test to how the method was called, not what it achieved.
- **Chicago-style: building the wrong domain model** — without a driving acceptance test, you may invest in domain objects that don't serve the actual use case.
- **Conflating styles mid-test** — a single test that combines real domain objects with heavily mocked collaborators is hard to read and maintain.

## References
- [Martin Fowler — Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Growing Object-Oriented Software, Guided by Tests (Freeman & Pryce)](https://www.growing-object-oriented-software.com/) — the canonical London-school book
- [Kent Beck — Test-Driven Development: By Example](https://www.oreilly.com/library/view/test-driven-development/0321146530/) — Chicago-style
