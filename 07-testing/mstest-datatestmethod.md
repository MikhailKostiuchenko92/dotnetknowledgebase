# How Do You Use `[DataTestMethod]` with `[DataRow]` in MSTest v2?

**Category:** Testing / MSTest
**Difficulty:** 🟡 Middle
**Tags:** `mstest`, `[DataTestMethod]`, `[DataRow]`, `[DynamicData]`, `parameterized-tests`

## Question
> How do you use `[DataTestMethod]` with `[DataRow]` in MSTest v2?

## Short Answer
Replace `[TestMethod]` with `[DataTestMethod]` and add one `[DataRow(...)]` attribute per test case. Each row's arguments are passed positionally to the method parameters. For complex or runtime-computed data, use `[DynamicData]` pointing to a static property or method.

## Detailed Explanation

### Basic Pattern
```csharp
[DataTestMethod]
[DataRow(arg1, arg2, ...)]
public void TestName(Type1 param1, Type2 param2, ...) { }
```

Each `[DataRow]` creates an independent test case with its own pass/fail status. The number and types of arguments must match the method signature (implicit conversion is applied; mismatches throw at runtime).

### `DisplayName` Parameter
```csharp
[DataRow(100, 21, DisplayName = "Standard VAT on 100")]
```
Overrides the auto-generated test name in test output. Without it, MSTest generates names like `TestName (100, 21)`.

### Comparison with xUnit and NUnit

| | MSTest | xUnit | NUnit |
|---|---|---|---|
| Method attribute | `[DataTestMethod]` | `[Theory]` | (implied by `[TestCase]`) |
| Row attribute | `[DataRow]` | `[InlineData]` | `[TestCase]` |
| Custom row name | `DisplayName` param | Not per-row | `TestName` param |
| Complex objects | ❌ Constants only | ❌ Constants only | ❌ Constants only |
| Skip single row | No | No | `Ignore` param |

For complex objects, all three frameworks require a separate data source mechanism:

| Framework | Complex data attribute |
|---|---|
| MSTest | `[DynamicData(nameof(Prop), DynamicDataSourceType.Property)]` |
| xUnit | `[MemberData(nameof(Prop))]` |
| NUnit | `[TestCaseSource(nameof(Prop))]` |

### `[DynamicData]` for Complex Test Data
```csharp
[DataTestMethod]
[DynamicData(nameof(InvalidOrderCases), DynamicDataSourceType.Property)]
public void Validate_InvalidOrder_ReturnsError(Order order, string expectedError)
{
    var result = new OrderValidator().Validate(order);
    StringAssert.Contains(result.Error, expectedError);
}

public static IEnumerable<object[]> InvalidOrderCases =>
[
    [new Order { CustomerId = 0 }, "Customer ID required"],
    [new Order { CustomerId = 1, Total = -1m }, "Total must be positive"],
];
```

`DynamicDataSourceType.Method` is also available when pointing to a method rather than a property.

## Code Example
```csharp
namespace Math.Tests;

[TestClass]
public class CalculatorTests
{
    private readonly Calculator _sut = new();

    // Basic [DataRow] — values mapped positionally
    [DataTestMethod]
    [DataRow(6,  2, 3)]
    [DataRow(10, 5, 2)]
    [DataRow(0,  1, 0)]
    [DataRow(-8, 2, -4, DisplayName = "Negative dividend")]
    public void Divide_ValidInputs_ReturnsExpectedQuotient(
        int dividend, int divisor, int expected)
    {
        Assert.AreEqual(expected, _sut.Divide(dividend, divisor));
    }

    // [DataRow] with null (allowed — parameter must be nullable)
    [DataTestMethod]
    [DataRow(null,  false)]
    [DataRow("",    false)]
    [DataRow("abc", true)]
    public void IsNonEmpty_ReturnsExpectedResult(string? input, bool expected)
    {
        Assert.AreEqual(expected, !string.IsNullOrEmpty(input));
    }

    // [DynamicData] for complex objects
    [DataTestMethod]
    [DynamicData(nameof(BoundaryValueCases), DynamicDataSourceType.Property)]
    public void Add_BoundaryValues_DoesNotOverflow(long a, long b, long expected)
    {
        Assert.AreEqual(expected, _sut.AddLong(a, b));
    }

    public static IEnumerable<object[]> BoundaryValueCases =>
    [
        [long.MaxValue - 1, 1L,            long.MaxValue],
        [long.MinValue + 1, -1L,           long.MinValue],
        [0L,                0L,            0L],
    ];
}
```

## Common Follow-up Questions
- What is the difference between `[DataTestMethod]` and `[TestMethod]`?
- How does `[DynamicData]` compare to `[MemberData]` in xUnit?
- How do you add a custom display name to each `[DataRow]`?
- What happens if the number of `[DataRow]` arguments doesn't match the method parameters?
- Can you use `null` values in `[DataRow]`?
- How do you skip a specific `[DataRow]` in MSTest?

## Common Mistakes / Pitfalls
- **Using `[TestMethod]` instead of `[DataTestMethod]`** — the data rows are silently ignored.
- **Type mismatch in `[DataRow]`** — `[DataRow(1.0)]` for an `int` parameter causes `InvalidCastException` at runtime.
- **No `[DataRow]`** — `[DataTestMethod]` with no rows produces one failing test that reports "No data found for method".
- **Expecting per-row `Ignore`** — MSTest doesn't support skipping individual rows; you must remove the row or split into a separate `[TestMethod]`.
- **Forgetting `DynamicDataSourceType` is required** — `[DynamicData(nameof(Prop))]` defaults to `Property`; if pointing to a method, add `DynamicDataSourceType.Method`.

## References
- [Microsoft Learn — DataTestMethod and DataRow](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-mstest)
- [Microsoft Learn — DynamicData attribute](https://learn.microsoft.com/en-us/visualstudio/test/how-to-create-a-data-driven-unit-test)
- [MSTest GitHub — DataRowAttribute source](https://github.com/microsoft/testfx/blob/main/src/TestFramework/TestFramework/Attributes/DataSource/DataRowAttribute.cs)
