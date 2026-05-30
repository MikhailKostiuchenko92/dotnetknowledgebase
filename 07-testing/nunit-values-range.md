# How Do You Run Parameterized Tests with `[Values]` and `[Range]` in NUnit?

**Category:** Testing / NUnit
**Difficulty:** 🟡 Middle
**Tags:** `nunit`, `[Values]`, `[Range]`, `[Random]`, `combinatorial`, `parameterized-tests`

## Question
> How do you run parameterized tests with `[Values]` and `[Range]` attributes in NUnit?

## Short Answer
`[Values]` specifies an explicit list of values for a parameter; `[Range]` generates a numeric sequence. NUnit's default is **Combinatorial** — it runs every combination of all parameter values as separate test cases. Use `[Sequential]` to pair values positionally instead.

## Detailed Explanation

### `[Values]` — Inline Enumeration
Applies to a test parameter to supply a discrete list of values:
```csharp
public void Test([Values(1, 2, 3)] int n) { ... }
```
Generates one test case per value: `n=1`, `n=2`, `n=3`.

### `[Range]` — Numeric Sequence
Generates values from `start` to `end` with an optional `step`:
```csharp
// integers from 0 to 4 (step 1): 0, 1, 2, 3, 4
public void Test([Range(0, 4)] int i) { ... }

// decimals from 0.0 to 1.0, step 0.25: 0.0, 0.25, 0.50, 0.75, 1.0
public void Test([Range(0.0, 1.0, 0.25)] double d) { ... }
```

### `[Random]` — Random Values
Generates N random values within a range:
```csharp
public void Test([Random(1, 100, count: 5)] int n) { ... }
// generates 5 random ints between 1 and 100
```

> ⚠️ **Warning:** `[Random]` tests are non-repeatable — each run produces different values. This violates the **Repeatable** property of FIRST. Use sparingly; prefer `[Values]` or `[Range]` for deterministic testing.

### Combinatorial vs. Sequential

#### Combinatorial (default)
Every combination of all parameter values is a test case:
```csharp
[Test]
public void CombinedTest(
    [Values(1, 2)]    int a,
    [Values("x","y")] string b)
```
Generates: `(1,"x")`, `(1,"y")`, `(2,"x")`, `(2,"y")` — **2 × 2 = 4 tests**.

#### Sequential
Values are paired by position (shortest sequence determines count):
```csharp
[Test, Sequential]
public void SequentialTest(
    [Values(1, 2, 3)] int a,
    [Values("x","y")] string b)
```
Generates: `(1,"x")`, `(2,"y")` — **2 tests** (stops at shortest list).

#### Pairwise
Covers all pairings but not all combinations — reduces combinatorial explosion for many parameters:
```csharp
[Test, Pairwise]
public void PairwiseTest(
    [Values(1,2,3)] int a,
    [Values("x","y")] string b,
    [Values(true,false)] bool c)
// instead of 3×2×2 = 12, generates a minimal set covering all pairs
```

### When to Use `[Values]` vs. `[TestCase]`
| | `[Values]` | `[TestCase]` |
|---|---|---|
| Single parameter | ✅ Clean | ✅ Clean |
| Multiple parameters with combinations | ✅ Combinatorial | ❌ Requires N×M rows |
| Paired values | `[Sequential]` | ✅ Natural |
| Custom test names | No | Yes (`[TestCase(x, TestName="…")]`) |

## Code Example
```csharp
namespace Geometry.Tests;

[TestFixture]
public class CircleTests
{
    // [Values] — tests each value of radius independently
    [Test]
    public void Area_IsPositive([Values(1, 5, 10, 100)] double radius)
    {
        double area = Math.PI * radius * radius;
        Assert.That(area, Is.Positive);
    }

    // [Range] — tests a sweep of angles
    [Test]
    public void UnitCircle_PointsAreOnCircumference(
        [Range(0.0, 360.0, 45.0)] double degrees)
    {
        double rad = degrees * Math.PI / 180.0;
        double x = Math.Cos(rad);
        double y = Math.Sin(rad);
        double distance = Math.Sqrt(x * x + y * y);
        Assert.That(distance, Is.EqualTo(1.0).Within(1e-10));
    }

    // Combinatorial (default) — 2 × 3 = 6 test cases
    [Test]
    public void Scale_Combinatorial(
        [Values(1.0, 2.0)] double factor,
        [Values(10, 20, 30)] double radius)
    {
        var circle = new Circle(radius);
        var scaled = circle.Scale(factor);
        Assert.That(scaled.Radius, Is.EqualTo(radius * factor));
    }

    // Sequential — pairs values 1:1 (3 test cases)
    [Test, Sequential]
    public void Scale_Sequential(
        [Values(1.0, 2.0, 0.5)] double factor,
        [Values(10,  20,  40)]   double radius)
    {
        // (1.0, 10), (2.0, 20), (0.5, 40)
        var circle = new Circle(radius);
        Assert.That(circle.Scale(factor).Radius, Is.EqualTo(radius * factor));
    }
}
```

## Common Follow-up Questions
- How does NUnit's `[Values]` differ from `[TestCase]` for single-parameter tests?
- What is the `Pairwise` attribute and when does it reduce test count?
- How do you use `[Values]` with non-primitive types?
- What is the `[Random]` attribute and when is it appropriate?
- How does NUnit count and name generated test cases in test output?
- Can you combine `[Values]` with `[TestCaseSource]` on different parameters?

## Common Mistakes / Pitfalls
- **Combinatorial explosion** — 4 parameters × 5 values each = 625 test cases; use `Pairwise` or refactor to `[TestCase]`.
- **Using `[Random]` for regression tests** — non-repeatable; if a `[Random]` test fails, the failing value is lost. Seed your random generator and log values.
- **`[Sequential]` with mismatched lengths** — the shorter list wins; extra values in the longer list are silently ignored.
- **`[Values(null)]` without nullable parameters** — if the parameter type is non-nullable, NUnit may pass `null` anyway, causing a `NullReferenceException` in the test.
- **Forgetting that combinatorial is the default** — adding a second `[Values]` parameter multiplies test count, potentially slowing the suite unexpectedly.

## References
- [NUnit documentation — Values attribute](https://docs.nunit.org/articles/nunit/writing-tests/attributes/values.html)
- [NUnit documentation — Range attribute](https://docs.nunit.org/articles/nunit/writing-tests/attributes/range.html)
- [NUnit documentation — Combinatorial vs Sequential vs Pairwise](https://docs.nunit.org/articles/nunit/writing-tests/attributes/combinatorial.html)
- [Microsoft Learn — Unit testing with NUnit](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-nunit)
