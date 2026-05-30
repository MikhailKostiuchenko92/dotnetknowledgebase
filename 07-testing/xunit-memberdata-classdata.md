# How Do You Use `[MemberData]` and `[ClassData]` for Complex Theory Data?

**Category:** Testing / xUnit
**Difficulty:** 🟡 Middle
**Tags:** `xunit`, `[MemberData]`, `[ClassData]`, `[Theory]`, `TheoryData`, `parameterized-tests`

## Question
> How do you use `[MemberData]` and `[ClassData]` for complex theory data?

## Short Answer
When `[InlineData]` is insufficient — because you need runtime objects, complex initialization, or reusable data sets — use `[MemberData]` to source data from a static property or method on any class, or `[ClassData]` to delegate data supply to a dedicated class implementing `IEnumerable<object[]>`. Both produce one test case per yielded row.

## Detailed Explanation

### When `[InlineData]` Falls Short
`[InlineData]` only accepts compile-time constants. You cannot pass:
- `new MyClass(...)` instances
- Computed values (e.g., `new DateTime(2025, 1, 1)`)
- Data read from a file or database

`[MemberData]` and `[ClassData]` lift all these restrictions.

---

### `[MemberData]` — Data from a Static Member
Points to a `static` property, field, or method that returns `IEnumerable<object[]>` (or `TheoryData<T...>` for type safety).

```csharp
[Theory]
[MemberData(nameof(MyTestData))]
public void Test(InputType input, bool expected) { ... }

public static IEnumerable<object[]> MyTestData =>
[
    [new InputType("a"), true],
    [new InputType("b"), false],
];
```

**`MemberType` parameter** — points to a member on a *different* class:
```csharp
[MemberData(nameof(SharedData.Cases), MemberType = typeof(SharedData))]
```

This is useful for sharing data sets across multiple test classes.

---

### `[ClassData]` — Data from a Dedicated Class
Points to a class implementing `IEnumerable<object[]>`. This encapsulates complex data generation logic and can be reused across assemblies.

```csharp
[Theory]
[ClassData(typeof(InvalidOrderDataSet))]
public void ValidateOrder_WithInvalidInput_ThrowsException(Order order, string expectedError) { ... }
```

---

### Type-Safe Alternative: `TheoryData<T1, T2>`
`object[]` rows lose type information and produce runtime cast errors. `TheoryData<T>` is strongly typed and works with both `[MemberData]` and `[ClassData]`.

```csharp
public static TheoryData<string, int> SampleData => new()
{
    { "hello", 5 },
    { "",      0 },
};
```

### Comparison Table

| | `[InlineData]` | `[MemberData]` | `[ClassData]` |
|---|---|---|---|
| Data location | Attribute arguments | Static member | Separate class |
| Complex objects | ❌ No | ✅ Yes | ✅ Yes |
| Type safety | ❌ object[] | ✅ with TheoryData | ✅ with TheoryData |
| Reuse across classes | ❌ No | ✅ via `MemberType` | ✅ Yes |
| Data from file/DB | ❌ No | ✅ Yes | ✅ Yes |
| Readability for small data | ✅ Best | 🟡 OK | 🟡 OK |

## Code Example
```csharp
namespace Pricing.Tests;

// ── [MemberData] example ──────────────────────────────────────────────────────
public class DiscountCalculatorTests
{
    [Theory]
    [MemberData(nameof(ValidDiscountCases))]
    public void ApplyDiscount_ReturnsExpectedPrice(
        decimal originalPrice, decimal discountPct, decimal expectedPrice)
    {
        var sut = new DiscountCalculator();
        sut.Apply(originalPrice, discountPct).Should().Be(expectedPrice);
    }

    // TheoryData<T1,T2,T3> — strongly typed, no object[] casts
    public static TheoryData<decimal, decimal, decimal> ValidDiscountCases => new()
    {
        { 100m, 10m, 90m  },
        { 200m, 25m, 150m },
        { 50m,  0m,  50m  },   // zero discount
        { 50m,  100m, 0m  },   // full discount
    };
}

// ── [ClassData] example ───────────────────────────────────────────────────────
public class InvalidOrderDataSet : TheoryData<Order, string>
{
    public InvalidOrderDataSet()
    {
        Add(new Order { CustomerId = 0 },               "Customer ID is required");
        Add(new Order { CustomerId = 1, Items = [] },   "Order must contain at least one item");
        Add(new Order { CustomerId = 1, Items = null! }, "Items cannot be null");
    }
}

public class OrderValidatorTests
{
    [Theory]
    [ClassData(typeof(InvalidOrderDataSet))]
    public void Validate_WithInvalidOrder_ReturnsExpectedError(
        Order order, string expectedError)
    {
        var sut = new OrderValidator();
        var result = sut.Validate(order);
        result.Errors.Should().Contain(expectedError);
    }
}

// ── [MemberData] from a different class (shared across test projects) ─────────
public static class SharedPricingData
{
    public static TheoryData<decimal, string> EdgeCases => new()
    {
        { 0m,     "zero price"    },
        { -1m,    "negative price" },
        { 999999m, "maximum price" },
    };
}

public class AnotherPricingTests
{
    [Theory]
    [MemberData(nameof(SharedPricingData.EdgeCases), MemberType = typeof(SharedPricingData))]
    public void EdgeCase_HandledGracefully(decimal price, string scenario)
    {
        // ...
    }
}
```

## Common Follow-up Questions
- What is `TheoryData<T>` and how does it improve type safety over `object[]`?
- When would you choose `[ClassData]` over `[MemberData]`?
- How do you load theory data from a JSON or CSV file?
- Can `[MemberData]` reference a non-static member?
- How does xUnit display the test names for `[MemberData]` rows?
- What is the `IXunitSerializable` interface and when do you need it for `[MemberData]`?

## Common Mistakes / Pitfalls
- **`[MemberData]` pointing to a non-static member** — causes a runtime exception; the member must be `static`.
- **Returning `IEnumerable<object[]>` with mismatched types** — `object[]{1, "x"}` for `(string, int)` parameters causes `InvalidCastException` at runtime.
- **Evaluating expensive data at class-load time** — `static` properties are evaluated when the test assembly loads; heavy I/O here slows all test starts.
- **Using `[ClassData]` when `[InlineData]` suffices** — adds unnecessary complexity.
- **Forgetting `nameof`** — hardcoding the member name as a string breaks silently on rename; always use `nameof(...)`.

## References
- [Andrew Lock — InlineData, ClassData and MemberData in xUnit](https://andrewlock.net/creating-parameterised-tests-in-xunit-with-inlinedata-classdata-and-memberdata/)
- [xUnit documentation — Data-driven tests](https://xunit.net/docs/getting-started/netcore/cmdline)
- [xUnit GitHub — TheoryData source](https://github.com/xunit/xunit/blob/main/src/xunit.v3.core/TheoryData.cs)
- [Microsoft Learn — Unit testing with xUnit](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-dotnet-test)
