# What Is the Humble Object Pattern?

**Category:** Testing / Advanced Topics
**Difficulty:** 🔴 Senior
**Tags:** `Humble Object`, `design-pattern`, `testability`, `UI`, `legacy-code`

## Question
> What is the Humble Object pattern and how does it make untestable code testable?

## Short Answer
The Humble Object pattern splits a class into two parts: a **humble object** that is hard to test and contains only the minimum logic needed to interact with the environment (UI, threading, file system), and a **testable object** that contains all the real business logic with no environmental coupling. The testable object is tested normally; the humble object stays so thin that testing it manually is trivial.

## Detailed Explanation

### The Problem
Some code is inherently hard to test:
- UI event handlers (tightly coupled to framework objects)
- Worker thread logic (non-deterministic scheduling)
- `HttpContext`-dependent code
- Timer callbacks
- Entrypoint methods that combine setup + logic

### The Solution
Extract all non-trivial logic into a collaborator class (the testable object) and leave the hard-to-test shell (the humble object) as a thin delegator.

```
┌─────────────────────────────┐
│  Humble Object              │
│  (UI/Thread/Timer callback) │
│  • Has no logic             │
│  • Calls Testable Object    │
└────────────┬────────────────┘
             │ delegates to
┌────────────▼────────────────┐
│  Testable Object (Logic)    │
│  • Contains all business    │
│    rules                    │
│  • No framework deps        │
│  • Fully unit-testable      │
└─────────────────────────────┘
```

### Before: Untestable Event Handler
```csharp
private void btnCheckout_Click(object sender, EventArgs e) // WinForms
{
    var total = decimal.Parse(txtTotal.Text);
    var discount = total > 100 ? total * 0.1m : 0;
    var finalPrice = total - discount;
    lblResult.Text = $"Total: {finalPrice:C}";
}
```

### After: Humble Object Pattern Applied
```csharp
// Humble Object — only framework interaction
private void btnCheckout_Click(object sender, EventArgs e)
{
    var total = decimal.Parse(txtTotal.Text);
    var result = _checkoutPresenter.CalculateFinal(total); // delegates to testable
    lblResult.Text = result.Display;
}

// Testable Object — all logic here, no UI dependency
public class CheckoutPresenter
{
    public CheckoutResult CalculateFinal(decimal total)
    {
        var discount = total > 100 ? total * 0.1m : 0;
        var finalPrice = total - discount;
        return new CheckoutResult { Total = finalPrice, Display = $"Total: {finalPrice:C}" };
    }
}

// Unit test — no UI, no framework
[Fact]
public void CalculateFinal_Over100_Applies10PercentDiscount()
{
    var presenter = new CheckoutPresenter();
    var result = presenter.CalculateFinal(200m);
    result.Total.Should().Be(180m);
}
```

### Related Patterns
| Pattern | Relationship |
|---|---|
| Presenter (MVP) | View is the Humble Object; Presenter is testable |
| ViewModel (MVVM) | Binding framework is humble; ViewModel is testable |
| Controller thin | Controller is humble; Service/Handler is testable |
| Timer callback | Callback is humble; scheduled logic is testable |

### In .NET Contexts
- **ASP.NET Core Controller** — controller stays thin (parse HTTP, delegate to service)
- **Blazor component** — component delegates to injectable ViewModel/service
- **BackgroundService** — `ExecuteAsync` loop is humble; real logic lives in a service

## Code Example
```csharp
// HUMBLE: ASP.NET Core controller — no logic, just HTTP plumbing
[ApiController]
[Route("api/checkout")]
public class CheckoutController(ICheckoutService checkout) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Post(CheckoutRequest req)
    {
        var result = await checkout.ProcessAsync(req); // all logic here
        return result.IsSuccess ? Ok(result) : BadRequest(result.Error);
    }
}

// TESTABLE: service — all logic, no HTTP deps
public class CheckoutService(IOrderRepository repo, IDiscountEngine discounts)
    : ICheckoutService
{
    public async Task<CheckoutResult> ProcessAsync(CheckoutRequest req)
    {
        var discount = await discounts.CalculateAsync(req.Total, req.CustomerType);
        var order = await repo.CreateAsync(req with { Total = req.Total - discount });
        return new CheckoutResult { IsSuccess = true, OrderId = order.Id };
    }
}

// Test — no ASP.NET Core, pure logic
[Fact]
public async Task ProcessAsync_VipCustomer_AppliesDiscount()
{
    var discounts = Mock.Of<IDiscountEngine>(d =>
        d.CalculateAsync(100m, "VIP") == Task.FromResult(20m));
    var repo = new Mock<IOrderRepository>();
    repo.Setup(r => r.CreateAsync(It.IsAny<CheckoutRequest>()))
        .ReturnsAsync(new Order { Id = 99 });

    var sut = new CheckoutService(repo.Object, discounts);
    var result = await sut.ProcessAsync(new CheckoutRequest { Total = 100m, CustomerType = "VIP" });

    result.IsSuccess.Should().BeTrue();
    repo.Verify(r => r.CreateAsync(It.Is<CheckoutRequest>(x => x.Total == 80m)), Times.Once);
}
```

## Common Follow-up Questions
- How does the Humble Object relate to the MVP (Model-View-Presenter) pattern?
- What is the Thin Controller pattern in ASP.NET Core?
- How do you apply the Humble Object pattern to background worker threads?
- How does the Humble Object differ from the Facade pattern?
- How do you test the Humble Object itself (UI, timer)?

## Common Mistakes / Pitfalls
- **Business logic leaking into the Humble Object** — if the event handler/controller has conditionals, it's no longer humble.
- **Making the Testable Object depend on the framework** — the testable object must be free of `HttpContext`, `IFormFile`, etc.
- **Not applying the pattern to timers** — timer callbacks are frequently stuffed with logic; extract to a scheduler service.

## References
- [Gerard Meszaros — xUnit Test Patterns (Humble Object)](http://xunitpatterns.com/Humble%20Object.html)
- [Martin Fowler — Presentation Model](https://martinfowler.com/eaaDev/PresentationModel.html)
- [See also: tdd-legacy-codebase.md](tdd-legacy-codebase.md)
