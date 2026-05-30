# What Is `[TestCase]` in NUnit and How Does It Relate to xUnit's `[InlineData]`?

**Category:** Testing / NUnit
**Difficulty:** 🟢 Junior
**Tags:** `nunit`, `[TestCase]`, `parameterized-tests`, `[InlineData]`, `data-driven`

## Question
> What is `[TestCase]` in NUnit and how does it relate to xUnit's `[InlineData]`?

## Short Answer
`[TestCase]` is NUnit's attribute for parameterised tests — it is functionally equivalent to xUnit's `[Theory]` + `[InlineData]` combined into one attribute. You add one `[TestCase]` per data row, each containing the argument values; NUnit generates a separate test case for each.

## Detailed Explanation

### Basic Syntax
```csharp
[TestCase(arg1, arg2, ..., ExpectedResult = value)]
[Test] // or omit [Test] — [TestCase] implies test discovery
public ReturnType MethodName(Type1 p1, Type2 p2, ...) { }
```

`[TestCase]` combines the data row *and* the test marking in one attribute. `[Test]` is implied; you can omit it (though including it improves readability in some teams).

### `ExpectedResult` Parameter
`[TestCase]` has a special `ExpectedResult` named parameter. When used, NUnit automatically compares the method's return value to `ExpectedResult` — no `Assert.That` needed:

```csharp
[TestCase(2, 3, ExpectedResult = 5)]
[TestCase(0, 0, ExpectedResult = 0)]
public int Add(int a, int b) => a + b; // return value compared automatically
```

This pattern is convenient for pure functions but removes the Assert from the test body, which some teams find less readable.

### Feature Comparison: `[TestCase]` vs. `[InlineData]`

| Feature | NUnit `[TestCase]` | xUnit `[Theory]`+`[InlineData]` |
|---|---|---|
| Syntax | Single attribute per row | `[Theory]` + one `[InlineData]` per row |
| Auto-expected result | `ExpectedResult = x` | Not built-in; assert in test body |
| Named arguments | `TestName = "..."` | `[Theory]` `DisplayName` not per-row |
| Complex objects | Limited to constants | Same limitation; use `[MemberData]` |
| Skip single row | `Ignore = "reason"` | No native per-row skip |
| Reason string | `Reason = "..."` | No per-row metadata |

### Skipping a Single Row
NUnit supports per-row skipping directly:
```csharp
[TestCase(1, 2, Ignore = "Tracked in #789")]
[TestCase(3, 4)]
public void MyTest(int a, int b) { }
```

This is more flexible than xUnit, which requires a workaround.

### `[TestCaseSource]` for Complex Data
For data that can't be expressed as constants, use `[TestCaseSource]` — the NUnit equivalent of `[MemberData]`. See [nunit-testcasesource.md](nunit-testcasesource.md).

## Code Example
```csharp
namespace Text.Tests;

[TestFixture]
public class StringUtilityTests
{
    // Basic [TestCase] — one row per attribute
    [TestCase("hello", 5)]
    [TestCase("",      0)]
    [TestCase("abc",   3)]
    public void Length_ReturnsCorrectValue(string input, int expected)
    {
        Assert.That(input.Length, Is.EqualTo(expected));
    }

    // ExpectedResult — return value compared automatically, no Assert needed
    [TestCase("hello", "HELLO", ExpectedResult = true)]
    [TestCase("Hello", "hello", ExpectedResult = false)]
    [TestCase("",      "",      ExpectedResult = true)]
    public bool Equals_CaseSensitive_ReturnsExpectedResult(string a, string b)
        => string.Equals(a, b, StringComparison.Ordinal);

    // Per-row ignore
    [TestCase("valid@email.com",  true)]
    [TestCase("not-an-email",     false)]
    [TestCase("broken@@domain",   false, Ignore = "Regex not yet updated for this case")]
    public void IsValidEmail_ReturnsExpectedResult(string email, bool expected)
    {
        var validator = new EmailValidator();
        Assert.That(validator.IsValid(email), Is.EqualTo(expected));
    }

    // Null is a valid argument
    [TestCase(null,  false)]
    [TestCase("",   false)]
    [TestCase("ok", true)]
    public void IsNonEmpty_ReturnsExpectedResult(string? input, bool expected)
    {
        Assert.That(!string.IsNullOrEmpty(input), Is.EqualTo(expected));
    }
}
```

## Common Follow-up Questions
- What is `[TestCaseSource]` and when would you use it instead of `[TestCase]`?
- How do you skip a single `[TestCase]` row in NUnit?
- What is the `ExpectedResult` parameter and when should you use it?
- How does NUnit display the test name for each `[TestCase]` row in test explorers?
- What is the `TestName` parameter on `[TestCase]`?
- How does NUnit's `[TestCase]` compare to MSTest's `[DataRow]`?

## Common Mistakes / Pitfalls
- **Using `[Test]` and `[TestCase]` together** — technically allowed, but `[Test]` adds a zero-argument test case that may not make sense alongside parameterised rows.
- **Forgetting `null` requires special handling** — `[TestCase(null)]` compiles and runs, but the parameter type must be nullable-aware.
- **Overusing `ExpectedResult`** — it only works for the return value; if you need to verify side effects (mock calls, state changes), use normal assertions in the test body.
- **Large numbers of `[TestCase]` attributes cluttering the method** — move to `[TestCaseSource]` for readability when there are 10+ rows.
- **Mismatch between argument types and method signature** — NUnit performs implicit conversion, but edge cases (e.g., `int` → `long`) can cause unexpected behaviour.

## References
- [NUnit documentation — TestCase attribute](https://docs.nunit.org/articles/nunit/writing-tests/attributes/testcase.html)
- [NUnit documentation — Parameterised tests](https://docs.nunit.org/articles/nunit/writing-tests/parameterized-tests.html)
- [Microsoft Learn — Unit testing with NUnit](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-nunit)
- [NUnit GitHub](https://github.com/nunit/nunit)
