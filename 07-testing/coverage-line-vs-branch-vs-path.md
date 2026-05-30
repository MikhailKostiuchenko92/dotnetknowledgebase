# What Is the Difference Between Line, Branch, and Path Coverage?

**Category:** Testing / Code Coverage
**Difficulty:** 🟡 Middle
**Tags:** `code-coverage`, `branch-coverage`, `path-coverage`, `line-coverage`, `testing-metrics`

## Question
> What is the difference between line coverage, branch coverage, and path coverage?

## Short Answer
**Line coverage** checks if a line was executed at least once. **Branch coverage** checks if every conditional branch (true/false for each `if`) was taken at least once. **Path coverage** checks if every possible combination of branches through a method was exercised. Branch coverage is the minimum recommended standard; path coverage is often impractical due to combinatorial explosion.

## Detailed Explanation

### Visual Comparison
```csharp
public string Categorize(int age, bool isMember)
{
    if (age >= 18)           // branch 1: true / false
    {
        if (isMember)        // branch 2: true / false
            return "Adult Member";
        return "Adult";
    }
    return "Minor";
}
```

| Coverage type | Tests needed to achieve 100% | Notes |
|---|---|---|
| **Line** | 2 tests | One covering the `if (age >= 18)` true path suffices for the inner `if` line |
| **Branch** | 3 tests | true+true, true+false, false (the false-branch of inner `if` is skipped when outer is false) |
| **Path** | 3 distinct paths (false, true+true, true+false) | Same as branches here; more complex methods grow exponentially |

### Branch Coverage Explained
Each `if`, `switch` case, ternary operator, `&&`, `||`, and null-coalescing operator (`??`) introduces at least two branches. **Branch coverage = (taken branches) / (total branches)**.

Common blind spots:
```csharp
var result = data?.Process(); // two branches: null vs. non-null
var x = a ?? b;               // two branches
throw new X() when (condition); // conditional throw
```

### Path Coverage
Every unique path through a method:
- 2 conditions → 4 potential paths (2²)
- 10 conditions → 1024 potential paths (2¹⁰)

Full path coverage is rarely practical. MC/DC (Modified Condition/Decision Coverage), used in aviation/medical standards, is a pragmatic middle ground.

### Which Coverage to Target?

| Level | Practical target |
|---|---|
| Line | 80–90% — easy to achieve |
| Branch | 70–80% — recommended minimum for business logic |
| Path | Often impractical; focus on critical paths manually |

> ⚠️ 100% branch coverage does not mean zero bugs. It means no branch was *never* executed — assertions may still be absent or incorrect.

### How Coverlet Reports Branches
```shell
dotnet test --collect:"XPlat Code Coverage"
```
`coverage.cobertura.xml` contains both `line-rate` and `branch-rate` per class.

ReportGenerator displays branch coverage visually: green = both branches taken, yellow = one branch taken.

## Code Example
```csharp
// This method has 4 branches: (age >= 18) T/F, (isMember) T/F
public string Classify(int age, bool isMember)
{
    if (age >= 18)
        return isMember ? "Adult Member" : "Adult";
    return "Minor";
}

// Line coverage: 2 tests:
//   Classify(20, true)  → covers all three return lines
//   Classify(10, false) → no — "Adult" line missed
// Correct: need 3 tests:
//   Classify(20, true)  — "Adult Member"
//   Classify(20, false) — "Adult"
//   Classify(10, false) — "Minor"
```

## Common Follow-up Questions
- Why is branch coverage generally more valuable than line coverage?
- What is MC/DC coverage and where is it used?
- How do tools like Coverlet/OpenCover calculate branch coverage?
- Does 100% branch coverage guarantee correct behavior?
- What is condition coverage vs. decision coverage?

## Common Mistakes / Pitfalls
- **Targeting only line coverage** — leaves entire branches untested.
- **Treating 100% branch coverage as the goal** — pathological branches in generated code (EF migrations, designer files) pollute results; exclude them.
- **Not understanding that `&&` and `||` create branches** — `a && b` has 3 cases to cover: (false,_), (true,false), (true,true).
- **Ignoring exception paths** — `try/catch` introduces branches; tests that never trigger the `catch` leave it uncovered.

## References
- [Microsoft Learn — Code coverage](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-code-coverage)
- [Coverlet — branch coverage](https://github.com/coverlet-coverage/coverlet#branch-coverage)
- [ReportGenerator — HTML report with branch markers](https://reportgenerator.io/)
