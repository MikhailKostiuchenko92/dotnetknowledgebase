# How Do You Keep BDD Scenarios Readable While Keeping Step Definitions Maintainable?

**Category:** Testing / BDD
**Difficulty:** 🔴 Senior
**Tags:** `BDD`, `Reqnroll`, `step-definitions`, `maintainability`, `declarative`, `imperative`

## Question
> How do you keep BDD scenarios readable for non-technical stakeholders while keeping step definitions maintainable?

## Short Answer
Write scenarios in a **declarative style** (what, not how), limit step definition scope using domain-focused classes, use step argument transformations to avoid complex inline data, share state via `ScenarioContext` or constructor injection, and establish a ubiquitous language dictionary agreed with business stakeholders.

## Detailed Explanation

### 1. Declarative Over Imperative
```gherkin
# ❌ Imperative — tells the browser what to do (fragile, unreadable to BA)
When I navigate to "/cart"
And I click the element with id "add-button"
And I fill "quantity" with "2"

# ✅ Declarative — expresses intent (stable, readable)
When the customer adds 2 units of "Laptop" to the cart
```

Declarative steps expose fewer implementation details and survive UI redesigns.

### 2. Domain-Focused Step Definition Classes
Group step definitions by business capability, not by page or method:

```csharp
// ✅ By domain concept
public class CartSteps { ... }
public class PaymentSteps { ... }
public class LoyaltySteps { ... }

// ❌ By implementation layer
public class DatabaseSteps { ... }
public class HttpSteps { ... }
```

### 3. Step Argument Transformations
Transform complex input so feature files stay clean:

```csharp
// Feature file:
// Given a product priced at £99.99 with SKU "ABC-001"

// Step definition with transformation:
[StepArgumentTransformation(@"£(.*)")]
public decimal ParsePounds(string value) => decimal.Parse(value);

[Given(@"a product priced at (.*) with SKU ""(.*)""")]
public void GivenProduct(decimal price, string sku) => ...
```

### 4. Reusable Step Libraries
Create a shared steps assembly referenced by multiple test projects:

```
MyApp.Tests.StepDefinitions/
  CartSteps.cs
  UserSteps.cs
  PaymentSteps.cs
```

### 5. Agreed Ubiquitous Language
Define a glossary with business stakeholders. All scenarios use the same terms:

| Business term | C# class | Database table |
|---|---|---|
| "Customer" | `Customer` | `users` |
| "Cart" | `ShoppingBasket` | `baskets` |
| "Purchase" | `Order` | `orders` |

Scenarios use "Customer" everywhere — never "User" or "Client."

### 6. Background for Shared Preconditions
```gherkin
Background:
  Given the product catalog contains "Laptop" at £999
  And a logged-in customer "alice"

Scenario: Adding to cart
  When she adds "Laptop" to her cart
  Then her cart contains 1 item
```

### 7. Scenario Outline for Data-Driven Cases
```gherkin
Scenario Outline: Discount tiers
  Given a "<tier>" customer
  When they purchase for <amount>
  Then the discount is <discount>%

  Examples:
    | tier   | amount | discount |
    | VIP    | 100    | 20       |
    | Member | 100    | 10       |
    | Guest  | 100    | 0        |
```

## Code Example
```csharp
// Maintainable step definitions using injection and transformations

[Binding]
public class OrderSteps(ScenarioContext ctx, IOrderService orderService)
{
    // Reusable: works for multiple scenarios with different amounts
    [Given(@"a customer with £(.*) credit")]
    public void GivenCredit(decimal amount) =>
        ctx["credit"] = amount;

    [When(@"they place an order totalling £(.*)")]
    public async Task WhenOrder(decimal total)
    {
        var result = await orderService.PlaceAsync(
            new OrderRequest { Total = total, Credit = (decimal)ctx["credit"] });
        ctx["result"] = result;
    }

    [Then(@"the order (succeeds|fails)")]
    public void ThenResult(string outcome) =>
        ((OrderResult)ctx["result"]).IsSuccess
            .Should().Be(outcome == "succeeds");
}
```

## Common Follow-up Questions
- How do you prevent step definition conflicts between two classes?
- How do you inject dependencies (DbContext, HttpClient) into step definitions?
- What is the difference between `ScenarioContext` and `FeatureContext`?
- How do you organise step definitions in a large project?
- How do you handle state cleanup between scenarios?

## Common Mistakes / Pitfalls
- **Mixing UI automation steps with business logic steps** — creates a fragile "do x then click y" chain.
- **Duplicating step logic** — two step definition methods with similar patterns cause "ambiguous step" errors.
- **Overloading `ScenarioContext`** — treat it like a bag; use typed wrappers or dedicated context classes.
- **Writing steps for developers only** — if a BA cannot read the feature file and understand the scenario, it's not BDD.

## References
- [Reqnroll — Step Definitions](https://docs.reqnroll.net/latest/bindings/step-definitions.html)
- [Cucumber — Gherkin Best Practices](https://cucumber.io/docs/bdd/better-gherkin/)
- [See also: given-when-then.md](given-when-then.md)
