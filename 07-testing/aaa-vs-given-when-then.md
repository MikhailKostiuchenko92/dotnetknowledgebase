# What Is the Arrange-Act-Assert vs. Given-When-Then Naming Convention?

**Category:** Testing / Test Design & Best Practices
**Difficulty:** 🟡 Middle
**Tags:** `AAA`, `given-when-then`, `test-structure`, `BDD`, `naming`

## Question
> What is the Arrange-Act-Assert vs. Given-When-Then naming convention?

## Short Answer
**Arrange-Act-Assert (AAA)** is the structural pattern for the *inside* of a test method: set up → execute → verify. **Given-When-Then (GWT)** is a *naming* convention inspired by BDD that maps to the same three phases with different vocabulary. AAA is code structure; GWT is test description. They are complementary — a test can be structured with AAA sections internally and named with Given-When-Then externally.

## Detailed Explanation

### Arrange-Act-Assert (AAA) — Code Structure
```csharp
[Fact]
public void ProcessOrder_ValidOrder_ReturnsConfirmedStatus()
{
    // Arrange — set up the SUT and its dependencies
    var repo = Mock.Of<IOrderRepository>(r => r.Exists(1) == true);
    var sut = new OrderProcessor(repo);
    var order = new Order { Id = 1, Amount = 100m };

    // Act — invoke the behaviour under test
    var result = sut.Process(order);

    // Assert — verify the outcome
    result.Status.Should().Be(OrderStatus.Confirmed);
}
```

| Phase | Keyword | What Happens |
|---|---|---|
| Arrange | Given | Create objects, configure mocks, seed data |
| Act | When | Call the method or trigger the event under test |
| Assert | Then | Verify return value, state change, or mock interactions |

### Given-When-Then (GWT) — Naming Style
```csharp
// Same test, GWT naming
[Fact]
public void GivenValidOrder_WhenProcessed_ThenStatusIsConfirmed() { }
```

GWT vocabulary comes from BDD (Behaviour-Driven Development) and is the language of Gherkin feature files in SpecFlow / Reqnroll.

### Comparing the Two

| Aspect | AAA | Given-When-Then |
|---|---|---|
| Role | Internal structure | Test method name / documentation |
| Origin | xUnit.net community, Roy Osherove | BDD, Dan North, SpecFlow |
| Audience | Developer reading the test code | Developer + stakeholder reading reports |
| Usage | Comments in body (`// Arrange`) | Prefix in name (`GivenX_WhenY_ThenZ`) |

> 💡 They are not mutually exclusive. The most expressive tests use **GWT naming** (the method name describes behaviour in stakeholder terms) and **AAA sections** (the body is cleanly divided with comments).

### When to Use Each

| Use AAA structure | Use GWT naming |
|---|---|
| All unit tests — always | BDD-adjacent projects |
| Clear method body organisation | When non-developers read test reports |
| Teams familiar with .NET conventions | SpecFlow / Reqnroll projects |

### Combined Best Practice
```csharp
[Fact]
public void GivenCustomer_WhenPlacingFirstOrder_ThenDiscountIsApplied()
{
    // Arrange / Given
    var customer = new CustomerBuilder().FirstTime().Build();
    var priceCalculator = new PriceCalculator();

    // Act / When
    var total = priceCalculator.Calculate(customer, subtotal: 100m);

    // Assert / Then
    total.Should().Be(90m, "because first-time customers get 10% off");
}
```

## Code Example
```csharp
namespace AAA_vs_GWT.Tests;

// Structure: AAA | Naming: Method_Scenario_Expected
public class PaymentService_AAANaming_Tests
{
    [Fact]
    public void ProcessPayment_InsufficientFunds_ThrowsPaymentDeclinedException()
    {
        // Arrange
        var gateway = new Mock<IPaymentGateway>();
        gateway.Setup(g => g.Charge(It.IsAny<decimal>()))
               .Returns(ChargeResult.InsufficientFunds);
        var sut = new PaymentService(gateway.Object);

        // Act
        Action act = () => sut.ProcessPayment(100m);

        // Assert
        act.Should().Throw<PaymentDeclinedException>()
           .WithMessage("*insufficient funds*");
    }
}

// Structure: AAA | Naming: Given_When_Then
public class PaymentService_GWTNaming_Tests
{
    [Fact]
    public void GivenInsufficientFunds_WhenProcessingPayment_ThenPaymentDeclinedExceptionIsThrown()
    {
        // Given
        var gateway = new Mock<IPaymentGateway>();
        gateway.Setup(g => g.Charge(It.IsAny<decimal>()))
               .Returns(ChargeResult.InsufficientFunds);
        var sut = new PaymentService(gateway.Object);

        // When
        Action act = () => sut.ProcessPayment(100m);

        // Then
        act.Should().Throw<PaymentDeclinedException>();
    }
}
```

## Common Follow-up Questions
- Can you use both AAA structure and GWT naming in the same test?
- How does Given-When-Then relate to SpecFlow Gherkin scenarios?
- What are the section comments `// Arrange`, `// Act`, `// Assert` — are they required?
- How do you handle tests with multiple Acts or Asserts?
- What is the relationship between AAA and the Single Concept principle?
- Is GWT naming appropriate for non-BDD .NET projects?

## Common Mistakes / Pitfalls
- **Omitting `// Arrange` / `// Act` / `// Assert` comments in complex tests** — without them, long tests are hard to scan.
- **Multiple Act sections in one test** — indicates multiple concepts; split into separate tests.
- **Arrange bloat** — very long Arrange sections signal the SUT has too many dependencies; use Test Data Builders or AutoFixture.
- **Assert before Act** — a subtle copy-paste bug; always double-check the order.
- **GWT method names that describe implementation** (`GivenRepo_WhenCalledWithId_ThenRepositoryGetByIdIsCalled`) — describe user-visible behaviour, not internal calls.

## References
- [Microsoft Learn — Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices)
- [Dan North — Introducing BDD](https://dannorth.net/introducing-bdd/) (verify URL)
- [SpecFlow documentation — Gherkin](https://docs.specflow.org/projects/specflow/en/latest/Gherkin/Gherkin-Reference.html)
- [Roy Osherove — The Art of Unit Testing](https://www.artofunittesting.com/)
