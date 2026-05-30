# What Is Stryker.NET and How Do You Interpret Its Mutation Score?

**Category:** Testing / Code Coverage
**Difficulty:** 🔴 Senior
**Tags:** `Stryker.NET`, `mutation-testing`, `mutation-score`, `.NET`, `testing`

## Question
> What is Stryker.NET and how do you interpret its mutation score?

## Short Answer
Stryker.NET is the .NET port of the Stryker mutation testing framework. It generates code mutants, runs your test suite against each, and reports a **mutation score** (percentage of mutants killed by your tests). A score above 70% is generally considered good; surviving mutants indicate specific assertions your tests are missing.

## Detailed Explanation

### Installing and Running Stryker.NET
```shell
# Install as a global tool
dotnet tool install -g dotnet-stryker

# Run against a test project
dotnet stryker --project "MyLib.csproj"

# With scope limiting
dotnet stryker --mutate "src/MyLib/Services/**/*.cs"
```

### Output Summary
```
Mutation score: 76%  (152/200 mutants killed)

  Killed: 152  ← tests caught the mutation
Survived: 35   ← tests passed with broken code (gap!)
 Timeout: 8    ← mutant caused infinite loop (counts as killed)
  No coverage: 5 ← no test covered these lines
```

### Interpreting the Score

| Score | Interpretation |
|---|---|
| < 50% | Tests are too weak; major refactoring risk |
| 50–70% | Acceptable for non-critical code |
| 70–85% | Good; typical production target |
| > 85% | Excellent; worth targeting for domain logic |
| 100% | Likely impractical (equivalent mutants) |

### Stryker Report — HTML Dashboard
```shell
dotnet stryker --reporter html
# Opens mutation-report/mutation-report.html
```
The report shows each file with colour-coded lines:
- 🟢 **Killed** — tests detected the mutation
- 🔴 **Survived** — tests missed the mutation
- 🟡 **No coverage** — no test executed this line

### Handling Survived Mutants
For each survivor, ask: "Would production code work with this mutation?" If yes — equivalent mutant (ignore). If no — add an assertion.

```csharp
// Survived mutant: price >= 100 → price > 100
public bool IsEligible(decimal price) => price >= 100m;

// Kill it by testing the boundary:
[Theory]
[InlineData(99.99, false)]
[InlineData(100,   true)]   // kills the >= vs > mutant
[InlineData(100.01,true)]
public void IsEligible_BoundaryValues(decimal price, bool expected)
    => sut.IsEligible(price).Should().Be(expected);
```

### Scoping to Avoid Slow Runs
```json
// stryker-config.json
{
  "stryker-config": {
    "project": "MyLib.csproj",
    "mutate": ["src/MyLib/Domain/**/*.cs"],
    "reporters": ["html", "progress"],
    "threshold-high": 80,
    "threshold-low": 60,
    "break-at": 50
  }
}
```

### CI Integration
```yaml
- name: Run Stryker mutation testing
  run: dotnet stryker --break-at 60
  continue-on-error: true  # don't fail build for low score initially

- uses: actions/upload-artifact@v4
  with:
    name: mutation-report
    path: StrykerOutput/**/mutation-report.html
```

## Code Example
```shell
# Full run on a bounded context
dotnet stryker \
  --project "Ordering.Domain.csproj" \
  --mutate "src/Ordering/Domain/**/*.cs" \
  --reporter html \
  --threshold-high 80 \
  --threshold-low 60 \
  --break-at 50

# Typical output:
# All files:   83% (166/200)
# Domain/Order.cs: 91%
# Domain/Discount.cs: 72% ← investigate survivors here
```

## Common Follow-up Questions
- How does Stryker.NET decide which mutations to apply?
- What is an "equivalent mutant" and how do you mark it as ignored?
- How do you prevent Stryker from timing out on long-running tests?
- How do you configure Stryker to only mutate changed files in a PR?
- How does Stryker.NET compare to PIT (for Java) or Cosmic Ray (for Python)?

## Common Mistakes / Pitfalls
- **Running Stryker on the entire monorepo** — runtime is proportional to (mutant count × test suite time); scope it carefully.
- **Treating all survived mutants as bugs** — equivalent mutants are benign; triage before adding tests.
- **Setting `break-at` to 80% from day one on a legacy codebase** — start with 50% and raise the bar incrementally.
- **Not specifying `--mutate` scope** — Stryker will mutate test helpers, DTOs, and trivial auto-properties that aren't worth mutating.

## References
- [Stryker.NET documentation](https://stryker-mutator.io/docs/stryker-net/introduction/)
- [Stryker.NET GitHub](https://github.com/stryker-mutator/stryker-net)
- [Stryker dashboard & badge integration](https://dashboard.stryker-mutator.io/)
- [See also: mutation-testing.md](mutation-testing.md)
