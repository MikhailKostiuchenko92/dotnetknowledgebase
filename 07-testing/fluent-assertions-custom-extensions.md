# How Do You Write Custom FluentAssertions Extensions?

**Category:** Testing / Assertion Libraries
**Difficulty:** 🔴 Senior
**Tags:** `FluentAssertions`, `custom-extensions`, `ReferenceTypeAssertions`, `extension-methods`

## Question
> How do you write custom FluentAssertions extensions?

## Short Answer
Create an extension method on `ObjectAssertions` or a custom `ReferenceTypeAssertions<TSubject, TAssertions>` subclass. Use `Execute.Assertion` with `ForCondition`, `FailWith`, and `BecauseOf` to produce formatted failure messages. Register the extension by convention (method on the subject type's `AssertionExtensions`-style class). This lets you add domain-specific assertions that read naturally and produce descriptive failure messages.

## Detailed Explanation

### Simplest Approach: Extension on the Type Directly
For simple, one-off assertions:
```csharp
public static class OrderAssertionExtensions
{
    public static AndConstraint<ObjectAssertions> BeFulfilled(
        this ObjectAssertions assertions,
        string because = "", params object[] becauseArgs)
    {
        var order = assertions.Subject as Order;

        Execute.Assertion
            .BecauseOf(because, becauseArgs)
            .ForCondition(order?.Status == OrderStatus.Fulfilled)
            .FailWith("Expected {context:order} to be Fulfilled{reason}, but its status was {0}.",
                      order?.Status);

        return new AndConstraint<ObjectAssertions>(assertions);
    }
}

// Usage:
order.Should().BeFulfilled("because payment succeeded");
```

### Proper Approach: Typed Assertions Class
For a richer API with domain-specific helpers:
```csharp
// 1. Create a typed assertions class
public class OrderAssertions : ReferenceTypeAssertions<Order, OrderAssertions>
{
    public OrderAssertions(Order subject) : base(subject) { }

    protected override string Identifier => "order";

    public AndConstraint<OrderAssertions> BeFulfilled(
        string because = "", params object[] becauseArgs)
    {
        Execute.Assertion
            .BecauseOf(because, becauseArgs)
            .ForCondition(Subject.Status == OrderStatus.Fulfilled)
            .FailWith("Expected {context:order} to be Fulfilled{reason}, but status was {0}.",
                      Subject.Status);
        return new AndConstraint<OrderAssertions>(this);
    }

    public AndConstraint<OrderAssertions> HaveAmount(decimal expected,
        string because = "", params object[] becauseArgs)
    {
        Execute.Assertion
            .BecauseOf(because, becauseArgs)
            .ForCondition(Subject.Amount == expected)
            .FailWith("Expected {context:order} amount to be {0}{reason}, but found {1}.",
                      expected, Subject.Amount);
        return new AndConstraint<OrderAssertions>(this);
    }
}

// 2. Hook into the fluent API via extension method
public static class OrderAssertionExtensions
{
    public static OrderAssertions Should(this Order order) => new(order);
}

// 3. Usage:
order.Should().BeFulfilled().And.HaveAmount(149.99m);
```

### `BecauseOf` and Failure Message Tokens
- `{reason}` — inserts the `because` text (e.g., ", because payment succeeded")
- `{context:order}` — uses the configured context label (falls back to "order")
- `{0}`, `{1}` — positional arguments
- `{context}` — caller expression name if not set explicitly

### When to Write Custom Assertions
- Domain objects with complex validity rules
- HTTP response objects with status + body checks
- Collections of domain objects with invariant checks
- Any assertion repeated 3+ times across tests (extract to extension)

## Code Example
```csharp
namespace CustomAssertions.Tests;

// ── Domain: Order ──────────────────────────────────────────────────────────
public record Order(int Id, decimal Amount, OrderStatus Status, DateTime CreatedAt);
public enum OrderStatus { Pending, Fulfilled, Cancelled }

// ── Custom assertions ──────────────────────────────────────────────────────
public class OrderAssertions(Order subject)
    : ReferenceTypeAssertions<Order, OrderAssertions>(subject)
{
    protected override string Identifier => "order";

    public AndConstraint<OrderAssertions> BeFulfilled(
        string because = "", params object[] becauseArgs)
    {
        Execute.Assertion
            .BecauseOf(because, becauseArgs)
            .ForCondition(Subject.Status == OrderStatus.Fulfilled)
            .FailWith("Expected order {0} to be Fulfilled{reason}, but was {1}.",
                      Subject.Id, Subject.Status);
        return new AndConstraint<OrderAssertions>(this);
    }

    public AndConstraint<OrderAssertions> HaveAmountGreaterThan(decimal threshold,
        string because = "", params object[] becauseArgs)
    {
        Execute.Assertion
            .BecauseOf(because, becauseArgs)
            .ForCondition(Subject.Amount > threshold)
            .FailWith("Expected order amount to be > {0}{reason}, but found {1}.",
                      threshold, Subject.Amount);
        return new AndConstraint<OrderAssertions>(this);
    }
}

public static class OrderFluentExtensions
{
    public static OrderAssertions Should(this Order order) => new(order);
}

// ── Tests using the custom assertions ─────────────────────────────────────
public class OrderCustomAssertionTests
{
    [Fact]
    public void FulfillOrder_MarksFulfilled_AndPreservesAmount()
    {
        var service = new OrderFulfillmentService();
        var order = new Order(1, 200m, OrderStatus.Pending, DateTime.UtcNow);

        var result = service.Fulfill(order);

        result.Should().BeFulfilled("because payment was accepted")
              .And.HaveAmountGreaterThan(0m);
    }
}
```

## Common Follow-up Questions
- What is `ReferenceTypeAssertions<TSubject, TAssertions>` and when do you use it?
- How do you chain multiple custom assertions using `AndConstraint`?
- How does `Execute.Assertion` format failure messages?
- What is `{context}` in a FluentAssertions failure message?
- Can you override `Should()` for built-in .NET types (e.g., `string`, `int`)?
- How do you test that your custom assertion itself throws on failure?

## Common Mistakes / Pitfalls
- **Not returning `AndConstraint<T>`** — the `.And` fluent continuation breaks if the method returns `void`.
- **Hardcoding the subject name instead of using `{context}`** — `{context:order}` adapts to `because` and caller expression; hardcoded strings degrade messages.
- **Forgetting `BecauseOf`** — skipping `BecauseOf(because, becauseArgs)` means the `{reason}` token is blank; the custom assertion loses the `because` feature.
- **Testing only the happy path of the assertion** — write a failing-case test for the custom assertion itself to verify the error message is accurate.
- **Overloading `Should()` on types that already have FA assertions** — can cause ambiguity errors; prefer creating a wrapper type or different method name.

## References
- [FluentAssertions — Custom assertions](https://fluentassertions.com/extensibility/)
- [FluentAssertions — `Execute.Assertion`](https://fluentassertions.com/extensibility/#execute-assertion)
- [FluentAssertions on GitHub](https://github.com/fluentassertions/fluentassertions)
- [NuGet — FluentAssertions](https://www.nuget.org/packages/FluentAssertions/)
