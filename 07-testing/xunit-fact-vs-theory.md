# What Is the Difference Between `[Fact]` and `[Theory]` in xUnit?

**Category:** Testing / xUnit
**Difficulty:** 🟢 Junior
**Tags:** `xunit`, `[Fact]`, `[Theory]`, `parameterized-tests`, `InlineData`

## Question
> What is the difference between `[Fact]` and `[Theory]` in xUnit?

## Short Answer
`[Fact]` marks a test that runs exactly once with no external input — it represents one specific, unconditional truth. `[Theory]` marks a test that accepts parameters and runs once per data row; it represents a rule that holds across multiple inputs, each of which becomes an independent test case.

## Detailed Explanation

### `[Fact]` — One Test, One Truth
A `[Fact]` test expresses something that is *always* true, with no variation. Because there are no parameters, every run of the test is identical. The test either passes or fails.

Use `[Fact]` when:
- The behaviour is unconditional and has no meaningful variation.
- You are testing exception throwing, event firing, or a single specific scenario.
- There is only one meaningful input combination to consider.

### `[Theory]` — One Behaviour, Many Inputs
A `[Theory]` expresses a behaviour that should hold for a *family* of inputs. xUnit generates one independent test case per data row. Each row appears separately in the test output and can fail independently.

Use `[Theory]` when:
- You have multiple inputs that should produce the same type of result.
- You want to eliminate copy-paste of near-identical `[Fact]` methods.
- You want to document edge cases explicitly (zero, negative, boundary values) as separate entries.

### What Happens Under the Hood
xUnit's test discovery mechanism inspects types for these attributes. For each `[InlineData]` row on a `[Theory]`, it creates a separate `TestCase` in the runner. Each `TestCase` gets its own pass/fail status, which means one bad row doesn't mask failures in other rows.

```
[Theory]
[InlineData(1)]   → TestCase #1
[InlineData(2)]   → TestCase #2
[InlineData(-1)]  → TestCase #3
```

### Key Differences

| Dimension | `[Fact]` | `[Theory]` |
|---|---|---|
| Parameters | None | Required (via data attribute) |
| Test cases generated | 1 | 1 per data row |
| Data source | N/A | `[InlineData]`, `[MemberData]`, `[ClassData]` |
| Use case | Single, specific scenario | Parameterised, data-driven scenarios |
| Failure isolation | Always one failure | Per data row |

> ⚠️ **Warning:** A `[Theory]` with no data attribute compiles but throws `TheoryWithoutDataException` at runtime. Always pair `[Theory]` with at least one data attribute.

## Code Example
```csharp
namespace Validation.Tests;

public class EmailValidatorTests
{
    private readonly EmailValidator _sut = new();

    // [Fact] — a single, specific scenario
    [Fact]
    public void IsValid_WhenInputIsNull_ReturnsFalse()
    {
        _sut.IsValid(null).Should().BeFalse();
    }

    // [Theory] — same behaviour across many inputs
    [Theory]
    [InlineData("user@example.com",    true)]
    [InlineData("user+tag@domain.co",  true)]
    [InlineData("not-an-email",        false)]
    [InlineData("missing@",            false)]
    [InlineData("@nodomain.com",       false)]
    [InlineData("",                    false)]
    public void IsValid_ReturnsExpectedResult(string email, bool expected)
    {
        _sut.IsValid(email).Should().Be(expected);
    }
}
```

### Running the Tests
```bash
dotnet test --filter "FullyQualifiedName~EmailValidatorTests"
```

Output (each InlineData row is a separate test case):
```
✓ IsValid_WhenInputIsNull_ReturnsFalse
✓ IsValid_ReturnsExpectedResult(email: "user@example.com", expected: True)
✓ IsValid_ReturnsExpectedResult(email: "not-an-email", expected: False)
✗ IsValid_ReturnsExpectedResult(email: "missing@", expected: False)  ← independent failure
```

## Common Follow-up Questions
- How do you pass complex objects (not just primitives) to a `[Theory]`?
- What is `[MemberData]` and how does it differ from `[InlineData]`?
- How do you skip a single data row in a `[Theory]`?
- What happens if one `[InlineData]` row throws — do the other rows still run?
- What is `TheoryData<T1, T2>` and how does it improve type safety over `object[]`?
- How does xUnit display theory test names in test explorers?

## Common Mistakes / Pitfalls
- **Using `[Fact]` for multiple near-identical cases** — copy-paste of test methods that differ only in data; use `[Theory]`.
- **Putting every case in `[Theory]` even when a single case is meaningful** — over-engineering; if there's only one case, `[Fact]` is clearer.
- **`[Theory]` without a data source** — compiles, throws at runtime.
- **Large `[InlineData]` sets obscuring test intent** — if data grows beyond ~10 rows, move to `[MemberData]` or `[ClassData]`.
- **Type mismatch in `[InlineData]`** — e.g., passing `1` when the parameter is `long`; causes subtle test failures or implicit conversions.

## References
- [xUnit documentation — Parameterised tests](https://xunit.net/docs/getting-started/netcore/cmdline)
- [Andrew Lock — Creating parameterised tests in xUnit with InlineData, ClassData and MemberData](https://andrewlock.net/creating-parameterised-tests-in-xunit-with-inlinedata-classdata-and-memberdata/)
- [Microsoft Learn — Unit testing with xUnit in .NET](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-dotnet-test)
- [xUnit source — TheoryAttribute](https://github.com/xunit/xunit/blob/main/src/xunit.v3.core/TheoryAttribute.cs)
