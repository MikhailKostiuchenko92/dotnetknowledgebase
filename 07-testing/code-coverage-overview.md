# What Is Code Coverage and What Does Line/Statement Coverage Measure?

**Category:** Testing / Code Coverage
**Difficulty:** 🟢 Junior
**Tags:** `code-coverage`, `line-coverage`, `statement-coverage`, `Coverlet`, `testing`

## Question
> What is code coverage and what does line/statement coverage measure?

## Short Answer
Code coverage is a metric that measures how much of your source code is exercised by your tests. **Line coverage** reports the percentage of executable lines that were hit during a test run. **Statement coverage** is similar but more granular — it counts individual statements, so a single line containing multiple statements (e.g., ternary operators) can be partially covered.

## Detailed Explanation

### Why Coverage Matters
Coverage helps identify untested code paths and acts as a safety net — but it is a necessary, not sufficient, condition for a good test suite. 80% coverage doesn't mean 80% of bugs are caught.

### Types of Coverage

| Type | What it measures | Granularity |
|---|---|---|
| **Line coverage** | Was each line executed at least once? | Medium |
| **Statement coverage** | Was each statement executed? | Higher than line |
| **Branch coverage** | Were both true/false branches of every condition taken? | High |
| **Path coverage** | Were all possible code paths through the method exercised? | Very high (exponential) |
| **Method coverage** | Was each method called at least once? | Coarse |

Line ≈ Statement in most cases; they differ when multiple statements exist on one line:

```csharp
// One line, two statements — line covered but second statement may not be
var msg = isValid ? "OK" : throw new InvalidOperationException();
```

### Collecting Coverage with Coverlet
```shell
dotnet test --collect:"XPlat Code Coverage"
# Outputs coverage.cobertura.xml
```

Or via the `coverlet.collector` NuGet package:
```xml
<PackageReference Include="coverlet.collector" Version="6.*" />
```

### Viewing a Report with ReportGenerator
```shell
dotnet tool install -g dotnet-reportgenerator-globaltool
reportgenerator -reports:"**/coverage.cobertura.xml" -targetdir:"coverage-report" -reporttypes:Html
```

Open `coverage-report/index.html` for a line-by-line HTML report.

### Coverage in CI
```yaml
- name: Test with coverage
  run: dotnet test --collect:"XPlat Code Coverage"
- name: Generate report
  run: reportgenerator -reports:"**/coverage.cobertura.xml" -targetdir:"coverage-report"
- uses: actions/upload-artifact@v4
  with: { name: coverage, path: coverage-report/ }
```

## Code Example
```csharp
namespace Coverage.Demo;

public class DiscountCalculator
{
    // Line 1: Covered if any test calls this
    public decimal Calculate(decimal price, string customerType)
    {
        // Line 2 (branch): covered only if customerType == "VIP"
        if (customerType == "VIP")
            return price * 0.8m;

        // Line 3 (branch): covered only if customerType == "Member"
        if (customerType == "Member")
            return price * 0.9m;

        return price; // Line 4: only if neither VIP nor Member
    }
}

// With only one test [VIP]:
// Line coverage: 3/4 lines = 75%
// Branch coverage: 2/4 branches = 50% (true-VIP, false-VIP→true-Member missed, false-Member missed)
```

## Common Follow-up Questions
- What is the difference between branch coverage and path coverage?
- How do you generate an HTML coverage report in .NET?
- What coverage percentage should a project aim for?
- What is mutation testing and why does it reveal gaps that line coverage misses?
- How does Coverlet differ from the built-in Visual Studio coverage tools?

## Common Mistakes / Pitfalls
- **Equating high coverage with high quality** — tests can cover a line without asserting anything meaningful.
- **Not distinguishing line vs. branch coverage** — 90% line coverage can hide half-covered `if` statements.
- **Auto-generated code skewing metrics** — exclude generated files (EF migrations, designers) with `[ExcludeFromCodeCoverage]`.
- **Only measuring in CI** — running coverage locally speeds up feedback during development.

## References
- [Microsoft Learn — Coverlet overview](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-code-coverage)
- [Coverlet GitHub](https://github.com/coverlet-coverage/coverlet)
- [ReportGenerator GitHub](https://github.com/danielpalme/ReportGenerator)
