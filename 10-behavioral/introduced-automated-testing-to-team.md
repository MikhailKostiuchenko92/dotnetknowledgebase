# Tell me about a time you introduced automated testing to a team that didn't have it.

**Category:** Process Improvement & Engineering Culture
**Difficulty:** 🟡 Middle
**Tags:** `testing`, `automated-testing`, `culture`, `tdd`, `quality`, `ci`

## Question
> Tell me about a time you introduced automated testing to a team that didn't have it.

## Short Answer
I joined a 6-person team delivering a .NET API with zero automated tests. Rather than proposing a testing overhaul, I introduced testing incrementally: new code got tests first (not the legacy code), I added a CI coverage gate at 0% rising to 40% over 3 months, and I offered pair-testing sessions for engineers unfamiliar with xUnit. Within 4 months, the team was writing tests as a default and had caught 3 regression bugs in CI before they reached staging.

## What the Interviewer Is Looking For

Introducing testing to a team without it is both a **technical** and **cultural change management** challenge. Interviewers want to see:

- You know how to introduce testing incrementally, not as a big-bang overhaul.
- You understand that "write tests" as a mandate without support fails — people need patterns and examples.
- You can make the value of testing visible quickly, to build team buy-in.
- You know how to avoid the "we're behind on coverage" trap of trying to test legacy code first.

> **⚠ Key insight:** The biggest mistake when introducing testing to a team that doesn't have it is starting with the legacy code. Test legacy code last (with characterisation tests). New code gets tests first. This delivers quick wins, builds team confidence, and avoids the worst of the technical difficulty.

### Testing Introduction Strategy

| Phase | Action | Why |
|-------|--------|-----|
| 1 — New code gets tests | Test all new code; leave legacy for now | Immediate value; no legacy complexity |
| 2 — Characterisation tests | Add characterisation tests to areas you're about to change | Safety net before touching legacy code |
| 3 — Rising coverage gate | Add CI gate; start at current coverage (maybe 0%); increment by 5–10% per sprint | Creates discipline without blocking delivery |
| 4 — Team enablement | Pair-test with team members; code review encourages test quality | Builds skill and confidence |
| 5 — Legacy coverage | Address remaining legacy code methodically | Last, not first |

## Example STAR Answer

**Situation:**
I joined a team building a .NET 6 REST API with 6 engineers, 0% test coverage, and no CI pipeline. The codebase had been in production for 2 years and had grown to ~25,000 lines. Bugs discovered in production were the primary quality signal — there was no earlier detection.

**Task:**
Introduce automated testing in a way that would stick — not a one-time exercise but a permanent team practice.

**Action:**

*Week 1 — Don't touch legacy; prove value first:*
I added an xUnit test project to the solution and wrote tests for the next feature I was building (a new endpoint for user notification preferences). I wrote 12 unit tests and 3 integration tests. I demoed them in standup: "These took 45 minutes to write. If this endpoint has a regression in future, they'll catch it in 3 seconds."

*Week 2 — Add the CI gate:*
I added a GitHub Actions CI workflow with `dotnet test`. Current coverage was effectively 0% (I had 15 tests out of thousands of code paths). I set the gate at 0% — just "tests must not fail." No blocking on coverage yet.

*Month 1 — Build patterns and examples:*
I wrote a "testing patterns" guide for the team: how to test ASP.NET Core controllers with `WebApplicationFactory`, how to test services with mocked dependencies using Moq, and how to test EF Core repositories with a test database.

I ran 3 pair-testing sessions (30 minutes each, voluntary) with 3 engineers. All 3 started writing tests on their next features.

*Month 2 — Rising coverage gate:*
I incremented the CI coverage gate: month 1 at 5%, month 2 at 15%, month 3 at 30%, month 4 at 40%. I set the expectation that new code should be at >70% coverage; the rising overall gate just reflects new code's contribution.

**Result:**
- Coverage: 0% → 42% over 4 months.
- CI gate: tests run on every PR; 3 regressions caught in CI before reaching staging.
- All 6 engineers are writing tests as a default on new features.
- One engineer who had never written a unit test before told me: "I didn't understand why tests were useful until one of mine caught a bug. Now I can't imagine not writing them."

## Reflection / What I'd Do Differently
I would introduce contract/snapshot tests for the API's HTTP response shapes from day one — these are the simplest tests to write and catch the most damaging regressions (breaking API clients). I focused on unit tests first; contract tests should have been parallel track 1.

## Common Follow-up Questions
- What's the difference between unit tests, integration tests, and end-to-end tests? When do you use each?
- How do you decide what to test first when there's no test coverage?
- What do you do when an engineer insists tests slow them down?
- What is a code coverage gate and what's a reasonable target?
- How do you test ASP.NET Core middleware or request pipelines?
- What testing frameworks do you prefer for .NET and why?

## Common Mistakes / Pitfalls
- **Starting with legacy code** — trying to add 100% coverage to a 25,000-line legacy codebase first is demoralising and technically difficult. New code first.
- **Mandating without enabling** — "everyone write tests now" without patterns, examples, and support fails.
- **Coverage as the goal** — coverage percentage is a proxy. The goal is catching real bugs. A 40% suite that catches regressions reliably is more valuable than an 80% suite of trivial pass-through tests.
- **Slow tests** — a test suite that takes 15 minutes to run will be disabled. Keep the PR feedback loop under 5 minutes.
- **Not celebrating early wins** — when a test catches a real bug in CI, make it visible. This builds team belief in the practice.
- **All unit, no integration** — a suite of unit tests with heavily mocked dependencies may pass while the real system fails. Integration tests against a real database are essential for persistence layers.

## References
- [xUnit Testing in .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-with-dotnet-test)
- [WebApplicationFactory — Integration Testing in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests)
- [Moq — GitHub](https://github.com/devlooped/moq)
- [Characterisation Testing — Michael Feathers, Working Effectively with Legacy Code](https://www.goodreads.com/book/show/44919.Working_Effectively_with_Legacy_Code)
- [Code Coverage in .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-code-coverage)

[See also: Worked With Legacy Codebase](worked-with-legacy-codebase.md)
