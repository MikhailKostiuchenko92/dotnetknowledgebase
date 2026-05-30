# What Is the Given-When-Then Structure in BDD Scenarios?

**Category:** Testing / BDD
**Difficulty:** 🟡 Middle
**Tags:** `BDD`, `Given-When-Then`, `Gherkin`, `AAA`, `scenario-writing`

## Question
> What is the Given-When-Then structure in BDD scenarios?

## Short Answer
**Given** sets up preconditions (the initial context). **When** describes the action or event that occurs. **Then** asserts the expected outcome. It is BDD's equivalent of Arrange-Act-Assert but written in business-readable language to serve both technical and non-technical stakeholders.

## Detailed Explanation

### Structure Breakdown

| Keyword | Role | Equivalent |
|---|---|---|
| **Given** | Preconditions / context / state | Arrange |
| **When** | Action / trigger / event | Act |
| **Then** | Expected outcome / assertion | Assert |
| **And** | Continuation of any step | — |
| **But** | Negative continuation | — |

### Example
```gherkin
Feature: Account transfer

  Scenario: Successful transfer between accounts
    Given Alice has a balance of £500
    And Bob has a balance of £100
    When Alice transfers £200 to Bob
    Then Alice's balance should be £300
    And Bob's balance should be £300
```

### Dos and Don'ts for Writing Scenarios

✅ **Do:**
- Write from a business/user perspective, not technical
- Each scenario should be independent (no shared state between scenarios)
- Use `Background` for shared preconditions
- One `When` per scenario (single action)

❌ **Don't:**
- Mix UI details into business scenarios: "When I click the button with id='btnTransfer'"
- Chain multiple actions in a single `When`: "When Alice transfers £200 and Bob withdraws £50"
- Write scenarios as unit tests: "Given OrderService is instantiated with MockRepo..."

### Good vs. Bad Scenarios
```gherkin
# ❌ Technical, brittle
Scenario: Transfer via HTTP
  Given I POST to /api/accounts/1/transfer with {"amount": 200}
  When the response status is 200
  Then the JSON body contains "newBalance": 300

# ✅ Business-readable, stable
Scenario: Successful transfer
  Given Alice has £500 in her account
  When she transfers £200 to Bob
  Then her balance is £300
```

### Relationship to AAA
```csharp
// AAA in unit test
// Arrange: Alice = 500, Bob = 100
// Act: Transfer(200)
// Assert: Alice == 300, Bob == 300

// Given-When-Then expresses the same intent in English:
// Given Alice has £500...
// When she transfers £200...
// Then her balance is £300...
```

### Declarative vs. Imperative Style
```gherkin
# Imperative (brittle — reveals UI internals)
When I navigate to /login
And I fill in "username" with "alice"
And I fill in "password" with "secret"
And I click the "Login" button

# Declarative (preferred — expresses intent)
When Alice logs in with valid credentials
```

## Code Example
```gherkin
Feature: Shopping cart

  Background:
    Given the product catalog is loaded

  Scenario: Adding an item to an empty cart
    Given the cart is empty
    When the customer adds "Laptop" to the cart
    Then the cart contains 1 item
    And the cart total is £999.00

  Scenario: Removing an item reduces the total
    Given the cart contains "Laptop" priced at £999.00
    And the cart contains "Mouse" priced at £29.00
    When the customer removes "Mouse"
    Then the cart total is £999.00
```

## Common Follow-up Questions
- What is the difference between `And` and `But` in Gherkin?
- How do you handle shared preconditions across multiple scenarios?
- What is `Scenario Outline` and when should you use it?
- How do you write scenarios for error/failure cases?
- What is the difference between declarative and imperative BDD scenarios?

## Common Mistakes / Pitfalls
- **Multiple When steps** — each scenario should have a single action; multiple Whens indicate a scenario is doing too much.
- **Then steps that verify implementation details** — "Then `SaveAsync` was called once" — BDD Then steps should verify observable outcomes, not internal calls.
- **Verbose Given sections** — if setup requires 10 steps, extract to a Background or use `Scenario Outline` with default state tables.
- **Copy-pasting the same Given steps** — use `Background:` for common setup.

## References
- [Martin Fowler — GivenWhenThen](https://martinfowler.com/bliki/GivenWhenThen.html)
- [Gherkin reference](https://cucumber.io/docs/gherkin/reference/)
- [See also: bdd-vs-tdd.md](bdd-vs-tdd.md)
