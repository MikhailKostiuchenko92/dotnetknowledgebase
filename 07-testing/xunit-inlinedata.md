# How Do You Pass Parameters to a `[Theory]` Using `[InlineData]`?

**Category:** Testing / xUnit
**Difficulty:** 🟢 Junior
**Tags:** `xunit`, `[Theory]`, `[InlineData]`, `parameterized-tests`, `data-driven`

## Question
> How do you pass parameters to a `[Theory]` using `[InlineData]`?

## Short Answer
Apply `[InlineData(...)]` once per data row directly above the `[Theory]` method. Each `[InlineData]` attribute receives a comma-separated list of values that are mapped positionally to the method parameters. xUnit creates one independent test case per attribute.

## Detailed Explanation

### Syntax
```csharp
[Theory]
[InlineData(arg1, arg2, ...)]
public void MethodName(Type1 param1, Type2 param2, ...) { }
```

`[InlineData]` accepts `object[]` arguments (matching CLR attribute limitations), so values must be compile-time constants: literals (`int`, `string`, `bool`, `double`, `char`, `null`), `enum` values, or `typeof(T)`.

### How xUnit Maps Values
Arguments are matched **positionally** to method parameters. The number of values in `[InlineData]` must match the number of parameters in the test method (or a default value is used if the parameter has one).

### Limitations of `[InlineData]`
| Limitation | Workaround |
|---|---|
| Only compile-time constants | Use `[MemberData]` with runtime objects |
| Can't pass `new MyClass()` | Use `[ClassData]` or `[MemberData]` |
| No named arguments | Positional only |
| Large datasets clutter code | Move to `[MemberData]` |

For complex scenarios, see [xunit-memberdata-classdata.md](xunit-memberdata-classdata.md).

### Type Safety with `TheoryData<T>`
In xUnit v3 and newer, `TheoryData<T1, T2>` provides strongly-typed data rows as an alternative to `object[]` in `[MemberData]`. For `[InlineData]` specifically, the values are still `object` under the hood, so type mismatches appear at runtime rather than compile time.

> ⚠️ **Warning:** Passing `1` for a `long` parameter compiles but may cause `InvalidCastException` at runtime. Be explicit: use `1L` for `long`, `1.0` for `double`, `1.0f` for `float`.

### Naming in Test Output
xUnit includes the `[InlineData]` values in the test name shown in test explorers and CI output, making each row self-describing:
```
✓ IsEven_ReturnsExpectedResult(number: 2, expected: True)
✓ IsEven_ReturnsExpectedResult(number: 3, expected: False)
```

## Code Example
```csharp
namespace Numbers.Tests;

public class MathHelpersTests
{
    // Basic primitives: int, bool
    [Theory]
    [InlineData(2,  true)]
    [InlineData(3,  false)]
    [InlineData(0,  true)]
    [InlineData(-4, true)]
    public void IsEven_ReturnsExpectedResult(int number, bool expected)
    {
        MathHelpers.IsEven(number).Should().Be(expected);
    }

    // Strings and null
    [Theory]
    [InlineData("hello", 5)]
    [InlineData("",      0)]
    [InlineData(null,    0)]   // null is a valid [InlineData] value
    public void SafeLength_ReturnsCorrectLength(string? input, int expected)
    {
        MathHelpers.SafeLength(input).Should().Be(expected);
    }

    // Enum values
    [Theory]
    [InlineData(DayOfWeek.Saturday, true)]
    [InlineData(DayOfWeek.Sunday,   true)]
    [InlineData(DayOfWeek.Monday,   false)]
    public void IsWeekend_ReturnsExpectedResult(DayOfWeek day, bool expected)
    {
        MathHelpers.IsWeekend(day).Should().Be(expected);
    }

    // Explicit numeric types to avoid runtime cast issues
    [Theory]
    [InlineData(1L,   2L,   3L)]   // long literals
    [InlineData(-1L,  0L,  -1L)]
    public void Add_LongValues_ReturnsSum(long a, long b, long expected)
    {
        MathHelpers.Add(a, b).Should().Be(expected);
    }
}
```

## Common Follow-up Questions
- What is the difference between `[InlineData]`, `[MemberData]`, and `[ClassData]`?
- How do you pass a complex object (e.g., a custom class instance) to a `[Theory]`?
- How does xUnit name the test cases generated from `[InlineData]`?
- What is `TheoryData<T>` and how does it improve over `object[]`?
- How do you skip a single `[InlineData]` row without skipping the entire theory?
- What happens if the number of values in `[InlineData]` doesn't match the method signature?

## Common Mistakes / Pitfalls
- **Integer literal for `long` parameter** — `[InlineData(1)]` for a `long` param → `InvalidCastException` at runtime. Use `1L`.
- **`float` vs `double` mismatch** — `[InlineData(1.5)]` infers `double`; if the param is `float`, add the `f` suffix.
- **Passing `new` objects in `[InlineData]`** — not allowed (attribute arguments must be constants); use `[MemberData]`.
- **Too many inline rows** — if a theory has 20+ rows, readability drops; move data to a CSV file or `[MemberData]`.
- **Missing the `[Theory]` attribute** — `[InlineData]` without `[Theory]` is silently ignored by xUnit.

## References
- [xUnit documentation — Getting started with parameterised tests](https://xunit.net/docs/getting-started/netcore/cmdline)
- [Andrew Lock — InlineData, ClassData and MemberData in xUnit](https://andrewlock.net/creating-parameterised-tests-in-xunit-with-inlinedata-classdata-and-memberdata/)
- [Microsoft Learn — Unit testing with xUnit](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-dotnet-test)
- [xUnit GitHub — InlineDataAttribute source](https://github.com/xunit/xunit/blob/main/src/xunit.v3.core/InlineDataAttribute.cs)
