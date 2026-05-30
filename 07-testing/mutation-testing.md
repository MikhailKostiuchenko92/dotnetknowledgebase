# What Is Mutation Testing and How Does It Reveal Weaknesses?

**Category:** Testing / Code Coverage
**Difficulty:** 🔴 Senior
**Tags:** `mutation-testing`, `Stryker.NET`, `code-quality`, `test-effectiveness`

## Question
> What is mutation testing and how does it reveal weaknesses that code coverage misses?

## Short Answer
Mutation testing automatically introduces small code changes ("mutants") — like changing `>` to `>=` or `+` to `-` — and checks whether your tests detect them. A mutant that "survives" (tests still pass after the mutation) reveals a gap in your assertions. Mutation score = killed mutants / total mutants. A high mutation score indicates genuinely effective tests.

## Detailed Explanation

### The Core Problem With Code Coverage
```csharp
public bool IsAdult(int age) => age >= 18;

[Fact]
public void IsAdult_Returns_Something()
{
    var result = new AgeService().IsAdult(25); // covered, but no assertion!
}
// Line coverage: 100%
// Mutation score: 0% (all mutations survive)
```

### What Mutants Look Like
A mutation testing tool like Stryker.NET generates variations:

| Mutation type | Original | Mutated |
|---|---|---|
| Boundary change | `age >= 18` | `age > 18` |
| Arithmetic | `price * 0.9m` | `price / 0.9m` |
| Logical operator | `a && b` | `a \|\| b` |
| Boolean literal | `return true` | `return false` |
| Null removal | `x ?? default` | `x` |
| String literal | `"OK"` | `""` |

For each mutant, the test suite runs. If at least one test fails → mutant **killed** ✅. If all tests pass → mutant **survived** ❌ (this is your gap).

### Mutation Score
```
Mutation Score = Killed Mutants / Total Mutants × 100%
```
A score of 70–80% is considered good for most business logic. 100% is possible but expensive.

### Why Mutation Testing > Code Coverage
| Metric | Reveals executed lines | Reveals meaningful assertions |
|---|---|---|
| Code coverage | ✅ | ❌ |
| Mutation score | ❌ | ✅ |

Mutation testing is a **test of your tests**.

### Limitations
- **Slow** — runs the test suite once per mutant; thousands of mutants = many test runs
- **Equivalent mutants** — some mutations produce functionally identical code; false positives
- **Not free** — Stryker.NET is open source; but CI time cost can be high on large projects

### When to Use
- CI for critical business logic libraries
- After adding a new feature, to validate test quality before merge
- When reviewing legacy tests that have coverage but no one trusts

## Code Example
```csharp
// Production code
public class Discount
{
    public decimal Apply(decimal price, CustomerType type) =>
        type == CustomerType.VIP ? price * 0.8m : price;
}

// WEAK test — 100% line coverage, 0% mutation score
[Fact]
public void Apply_CallsMethod()
{
    new Discount().Apply(100m, CustomerType.VIP);
    // no assertion → all boundary mutants survive
}

// STRONG test — kills most mutants
[Theory]
[InlineData(100, CustomerType.VIP,    80)]   // kills price*0.8 mutations
[InlineData(100, CustomerType.Regular,100)]  // kills CustomerType.VIP condition mutations
[InlineData(0,   CustomerType.VIP,    0)]    // kills multiply-by-zero mutations
public void Apply_CorrectDiscount(decimal price, CustomerType type, decimal expected)
{
    new Discount().Apply(price, type).Should().Be(expected);
}
```

## Common Follow-up Questions
- What is Stryker.NET and how do you run it?
- What is an "equivalent mutant" and how do you handle it?
- How do you integrate mutation testing into a CI pipeline without making it too slow?
- What mutation score is considered "good"?
- How do mutation testing tools handle async code?

## Common Mistakes / Pitfalls
- **Running mutation testing on the entire solution at once** — prohibitively slow; scope it to critical modules.
- **Targeting 100% mutation score** — equivalent mutants make this unachievable; aim for 70–80%.
- **Ignoring survived mutants** — each survivor represents a real gap; triage them like bug reports.
- **Substituting coverage for mutation score** — they measure orthogonal dimensions; use both.

## References
- [Stryker Mutator — Official site](https://stryker-mutator.io/)
- [Stryker.NET GitHub](https://github.com/stryker-mutator/stryker-net)
- [Martin Fowler — MutationTesting](https://martinfowler.com/testing/mutationTesting.html)
