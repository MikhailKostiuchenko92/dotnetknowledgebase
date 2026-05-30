# How Does NUnit's `Assert.That` Constraint Model Work Compared to Classic `Assert.*`?

**Category:** Testing / NUnit
**Difficulty:** 🟡 Middle
**Tags:** `nunit`, `Assert.That`, `constraints`, `fluent-assertions`, `assertion-model`

## Question
> How does NUnit's `Assert.That` constraint model work compared to classic `Assert.*`?

## Short Answer
NUnit's constraint model (`Assert.That(actual, Is.EqualTo(expected))`) uses composable constraint objects to describe the expected relationship. The classic model (`Assert.AreEqual(expected, actual)`) uses individual static methods with fixed parameter order. The constraint model is more readable, composable, and produces clearer failure messages.

## Detailed Explanation

### Classic Model (`Assert.AreEqual`, `Assert.IsTrue`, etc.)
These are individual static methods inherited from NUnit 1.x/2.x:

```csharp
Assert.AreEqual(5, result);       // expected, actual — easy to mix up
Assert.IsTrue(result.IsValid);
Assert.IsNotNull(customer);
Assert.AreNotEqual("", name);
```

**Problems:**
- Parameter order (`expected, actual`) is easy to mix up, producing misleading failure messages.
- No composability — cannot chain conditions.
- Still supported, but considered legacy style.

### Constraint Model (`Assert.That`)
All assertions go through `Assert.That(actual, constraint)`:
```csharp
Assert.That(result,    Is.EqualTo(5));
Assert.That(result.IsValid, Is.True);
Assert.That(customer,  Is.Not.Null);
Assert.That(name,      Is.Not.Empty);
```

**Advantages:**
- **Readable** — reads like English.
- **Composable** — constraints combine with `&` / `|` / `.And` / `.Or`.
- **Better failure messages** — "Expected: 5 but was: 3" is generated automatically.
- **Extensible** — implement `IConstraint` for custom constraints.

### The `Is`, `Has`, `Does`, `Throws`, `Contains` Helper Classes
NUnit provides several static "grammatical" classes to build constraints:

| Class | Usage examples |
|---|---|
| `Is` | `Is.EqualTo(x)`, `Is.Null`, `Is.True`, `Is.GreaterThan(0)`, `Is.TypeOf<T>()` |
| `Is.Not` | `Is.Not.Null`, `Is.Not.Empty`, `Is.Not.EqualTo(x)` |
| `Has` | `Has.Count.EqualTo(3)`, `Has.Property("Name").EqualTo("x")` |
| `Does` | `Does.Contain("substr")`, `Does.StartWith("A")`, `Does.Match(regex)` |
| `Throws` | `Assert.Throws<T>(action)` (note: separate method, not `Assert.That`) |
| `Contains` | `Contains.Item(x)` on collections |

### Composing Constraints
```csharp
// Value is between 1 and 100 (inclusive)
Assert.That(value, Is.GreaterThanOrEqualTo(1).And.LessThanOrEqualTo(100));

// Collection has 2–5 elements, all positive
Assert.That(numbers, Has.Count.InRange(2, 5).And.All.GreaterThan(0));

// String matches one of two values
Assert.That(status, Is.EqualTo("Active").Or.EqualTo("Pending"));
```

### Failure Message Customisation
Add a failure message as the third parameter:
```csharp
Assert.That(invoice.Total, Is.EqualTo(150m),
    $"Expected total 150 for order {invoice.Id}, but got {invoice.Total}");
```

> 💡 **vs. FluentAssertions:** NUnit's constraint model is good; FluentAssertions (a third-party library) goes further with a chainable API (`result.Should().Be(5)`) and richer collection/exception assertions. Many teams use FluentAssertions *on top of* any test framework. See [fluent-assertions-overview.md](../07-testing/fluent-assertions-overview.md).

## Code Example
```csharp
namespace Orders.Tests;

[TestFixture]
public class OrderConstraintTests
{
    [Test]
    public void Classic_vs_ConstraintModel()
    {
        var order = new Order { Id = 1, Total = 150m, Items = [new(), new()] };

        // ── Classic model (legacy) ─────────────────────────────────────────
        Assert.AreEqual(150m, order.Total);      // easy to swap expected/actual
        Assert.IsNotNull(order);
        Assert.IsTrue(order.Items.Count > 0);

        // ── Constraint model (preferred) ──────────────────────────────────
        Assert.That(order.Total,      Is.EqualTo(150m));
        Assert.That(order,            Is.Not.Null);
        Assert.That(order.Items,      Is.Not.Empty);
        Assert.That(order.Items.Count, Is.EqualTo(2));
        Assert.That(order.Id,         Is.Positive);
    }

    [Test]
    public void ComposedConstraints_ValidateRangeAndContent()
    {
        var prices = new[] { 10m, 25m, 99m };

        Assert.That(prices, Has.Length.EqualTo(3));
        Assert.That(prices, Has.All.GreaterThan(0m));
        Assert.That(prices, Does.Contain(25m));
        Assert.That(prices, Is.Ordered.Ascending); // passes if sorted
    }

    [Test]
    public void StringConstraints_CheckContent()
    {
        const string message = "Order processed successfully.";

        Assert.That(message, Does.Contain("processed"));
        Assert.That(message, Does.StartWith("Order"));
        Assert.That(message, Does.EndWith("."));
        Assert.That(message, Is.Not.Empty);
    }

    [Test]
    public void Exception_Constraint()
    {
        var sut = new DiscountCalculator();

        // Assert.Throws returns the exception for further inspection
        var ex = Assert.Throws<ArgumentOutOfRangeException>(
            () => sut.Apply(100m, discountPct: -5m));

        Assert.That(ex!.ParamName, Is.EqualTo("discountPct"));
    }
}
```

## Common Follow-up Questions
- What is FluentAssertions and how does it compare to NUnit's constraint model?
- How do you write a custom NUnit constraint?
- What are `Has`, `Does`, and `Contains` constraint namespaces used for?
- How do you assert on collection contents with constraints?
- What is the difference between `Is.EqualTo` and `Is.SameAs`?
- How do you test exceptions with `Assert.That` / `Assert.Throws`?

## Common Mistakes / Pitfalls
- **Mixing classic and constraint styles in the same test class** — inconsistent style hurts readability; pick one and stick to it.
- **Swapping `expected` and `actual` in classic `Assert.AreEqual`** — the failure message says "Expected X but was Y" where X and Y are wrong-way-round.
- **Using `Assert.IsTrue(a == b)` instead of `Assert.That(a, Is.EqualTo(b))`** — the `IsTrue` version just says "Expected True but was False" with no context.
- **Missing `Assert.ThrowsAsync<T>` for async methods** — use the async variant; sync `Assert.Throws` with an async lambda won't await.
- **Over-composing constraints** — deeply nested `.And.Or.And` chains become hard to read; split into multiple `Assert.That` calls.

## References
- [NUnit documentation — Constraints model](https://docs.nunit.org/articles/nunit/writing-tests/constraints/index.html)
- [NUnit documentation — Assert.That](https://docs.nunit.org/articles/nunit/writing-tests/assertions/classic-vs-constraint-model.html)
- [Microsoft Learn — Unit testing with NUnit](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-nunit)
- [FluentAssertions documentation](https://fluentassertions.com/introduction)
