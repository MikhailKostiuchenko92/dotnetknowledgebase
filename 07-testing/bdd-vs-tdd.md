# What Is BDD and How Does It Differ From TDD?

**Category:** Testing / BDD
**Difficulty:** 🟡 Middle
**Tags:** `BDD`, `TDD`, `Behavior-Driven-Development`, `Given-When-Then`, `acceptance-testing`

## Question
> What is BDD (Behavior-Driven Development) and how does it differ from TDD?

## Short Answer
BDD is an extension of TDD that frames tests as executable specifications written in natural language (Given/When/Then). TDD focuses on internal code correctness from a developer's perspective; BDD focuses on system behaviour from a stakeholder's perspective, bridging developers, testers, and business analysts through shared, readable scenarios.

## Detailed Explanation

### TDD vs. BDD

| Aspect | TDD | BDD |
|---|---|---|
| Perspective | Developer (unit level) | Business / Stakeholder |
| Language | Code-centric (`[Fact]`, `Assert`) | Natural language (Gherkin) |
| Granularity | Unit / class | Feature / scenario |
| Tests written by | Developers | Developers + BA + QA |
| Primary goal | Correct implementation | Correct behaviour |

### BDD Principles
1. **Define behaviour** before writing code — with a business-readable scenario.
2. **Three amigos** — developer, tester, and BA collaborate on scenarios before implementation.
3. **Living documentation** — scenarios remain up to date because they're executable.

### Gherkin Syntax
```gherkin
Feature: Shopping cart checkout

  Scenario: Applying a VIP discount
    Given the customer is a VIP member
    And the cart total is £100.00
    When the customer checks out
    Then the order total should be £80.00
    And a 20% discount should be applied
```

### BDD in .NET
- **SpecFlow** (now **Reqnroll**, MIT fork) — maps `.feature` files to step definitions
- **LightBDD** — code-based BDD without Gherkin files
- **xBehave.net** — xUnit extension for BDD-style tests in code

### When BDD Adds Value
- Teams with non-technical stakeholders who review or write scenarios
- Acceptance tests as a shared language between QA and developers
- Compliance/regulated environments where requirements must be executable

### When BDD Is Overhead
- Internal library development (no non-technical stakeholders)
- Teams without BA involvement
- When Gherkin becomes a wrapper around unit tests nobody reads

## Code Example
```gherkin
# checkout.feature
Feature: Checkout

  Scenario: VIP customer gets 20% discount
    Given a customer with type "VIP"
    And a cart with total 100.00
    When the customer checks out
    Then the order total is 80.00
```

```csharp
// Step definitions (SpecFlow / Reqnroll)
[Binding]
public class CheckoutSteps(ScenarioContext ctx)
{
    [Given(@"a customer with type ""(.*)""")]
    public void GivenCustomerType(string type) =>
        ctx["customer"] = new Customer { Type = type };

    [Given(@"a cart with total (.*)")]
    public void GivenCartTotal(decimal total) =>
        ctx["cart"] = new Cart { Total = total };

    [When(@"the customer checks out")]
    public void WhenCheckout()
    {
        var customer = (Customer)ctx["customer"];
        var cart = (Cart)ctx["cart"];
        ctx["order"] = new CheckoutService().Process(customer, cart);
    }

    [Then(@"the order total is (.*)")]
    public void ThenOrderTotal(decimal expected) =>
        ((Order)ctx["order"]).Total.Should().Be(expected);
}
```

## Common Follow-up Questions
- What is Gherkin and which tools use it?
- What is the "Three Amigos" meeting in BDD?
- How does SpecFlow differ from Reqnroll?
- When does BDD become too costly to maintain?
- Can you do BDD without Gherkin (code-based BDD)?

## Common Mistakes / Pitfalls
- **BDD as developer-only activity** — if non-technical stakeholders don't read/write scenarios, BDD is just extra syntax overhead.
- **Writing scenarios after implementation** — defeats the living documentation purpose; scenarios should drive development.
- **Overly fine-grained scenarios** — BDD scenarios should describe business features, not individual method calls.
- **Ignoring the "Three Amigos"** — skipping collaborative scenario review leads to misunderstood requirements.

## References
- [Reqnroll (SpecFlow successor)](https://reqnroll.net/)
- [Cucumber — BDD with Gherkin](https://cucumber.io/docs/gherkin/)
- [Martin Fowler — GivenWhenThen](https://martinfowler.com/bliki/GivenWhenThen.html)
