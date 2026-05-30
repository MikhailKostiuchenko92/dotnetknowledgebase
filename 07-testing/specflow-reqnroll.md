# What Is SpecFlow and How Does It Map Gherkin Feature Files to .NET Test Code?

**Category:** Testing / BDD
**Difficulty:** 🟡 Middle
**Tags:** `SpecFlow`, `Reqnroll`, `Gherkin`, `BDD`, `.NET`, `step-definitions`

## Question
> What is SpecFlow and how does it map Gherkin feature files to .NET test code?

## Short Answer
SpecFlow (now continued as **Reqnroll**, an MIT-licensed fork) is a .NET BDD framework that parses `.feature` files written in Gherkin and generates test runner bindings that map each `Given/When/Then` step to a C# method decorated with matching regular expression attributes. The generated tests run through xUnit, NUnit, or MSTest.

## Detailed Explanation

### Project Setup (Reqnroll, the modern choice)
```shell
dotnet add package Reqnroll.xUnit     # or .NUnit / .MsTest
dotnet add package Reqnroll
```

### How the Mapping Works

```
Feature File (.feature)                Step Definitions (.cs)
─────────────────────────────────      ──────────────────────────────────
Given the user is logged in        ──► [Given(@"the user is logged in")]
When they click "Checkout"         ──► [When(@"they click ""(.*)""")]
Then the order is confirmed        ──► [Then(@"the order is confirmed")]
```

The framework uses regex matching. Captured groups become method parameters.

### Feature File Structure
```gherkin
Feature: User login

  Background:
    Given the application is running

  Scenario: Successful login
    Given a user "alice" with password "P@ss"
    When she logs in with correct credentials
    Then she sees the dashboard

  Scenario Outline: Invalid login
    Given a user "<user>" with password "<pass>"
    When she tries to login
    Then she sees error "<error>"

  Examples:
    | user  | pass      | error            |
    | alice | wrong     | Invalid password |
    | bob   | P@ss      | User not found   |
```

### Step Definitions
```csharp
[Binding]
public class LoginSteps(ScenarioContext context, IWebDriver driver)
{
    [Given(@"a user ""(.*)"" with password ""(.*)""")]
    public void GivenUser(string username, string password)
    {
        context["username"] = username;
        context["password"] = password;
    }

    [When(@"she logs in with correct credentials")]
    public async Task WhenLogin()
    {
        var result = await new AuthService().LoginAsync(
            (string)context["username"],
            (string)context["password"]);
        context["result"] = result;
    }

    [Then(@"she sees the dashboard")]
    public void ThenDashboard() =>
        ((LoginResult)context["result"]).RedirectUrl
            .Should().Be("/dashboard");
}
```

### Hooks (`[BeforeScenario]`, `[AfterScenario]`)
```csharp
[Binding]
public class DbHooks(DatabaseFixture db)
{
    [BeforeScenario]
    public async Task ResetDatabase() => await db.ResetAsync();
}
```

### Step Argument Transformations
```csharp
[StepArgumentTransformation]
public Order TransformOrder(string json) =>
    JsonSerializer.Deserialize<Order>(json)!;
```

### Reqnroll vs. SpecFlow
| | SpecFlow | Reqnroll |
|---|---|---|
| License | Commercial (v4+) | MIT |
| Maintainer | TechTalk | Community fork |
| .NET 8/9 support | Partial | Full |
| Recommended | Legacy | ✅ New projects |

## Code Example
```gherkin
# Features/Discount.feature
Feature: Discount calculation

  Scenario: VIP discount
    Given a product priced at 100.00
    When a VIP customer adds it to the cart
    Then the cart total should be 80.00
```

```csharp
// Steps/DiscountSteps.cs
[Binding]
public class DiscountSteps(ScenarioContext ctx)
{
    [Given(@"a product priced at (.*)")]
    public void GivenProduct(decimal price) =>
        ctx["price"] = price;

    [When(@"a VIP customer adds it to the cart")]
    public void WhenVipAdds()
    {
        var calculator = new DiscountCalculator();
        ctx["total"] = calculator.Calculate((decimal)ctx["price"], "VIP");
    }

    [Then(@"the cart total should be (.*)")]
    public void ThenTotal(decimal expected) =>
        ((decimal)ctx["total"]).Should().Be(expected);
}
```

## Common Follow-up Questions
- What is the difference between SpecFlow and Reqnroll?
- How do you share state between step definition classes?
- How do you inject services into step definitions?
- What is `Scenario Outline` and how does it compare to `[Theory]` in xUnit?
- How do you organise large numbers of step definitions across multiple files?

## Common Mistakes / Pitfalls
- **Using SpecFlow 4+ on new projects** — requires a commercial license; use Reqnroll instead.
- **Putting all steps in one class** — step definitions should be grouped by feature/domain concept.
- **Over-capturing with broad regex** — `(.*)` captures everything; be specific to avoid ambiguous step matches.
- **Skipping Background** — shared setup goes in `Background` to avoid duplication.

## References
- [Reqnroll documentation](https://docs.reqnroll.net/)
- [Gherkin reference](https://cucumber.io/docs/gherkin/reference/)
- [Reqnroll GitHub](https://github.com/reqnroll/Reqnroll)
