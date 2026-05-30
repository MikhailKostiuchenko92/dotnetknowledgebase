# Tell me about your experience working with a legacy codebase. How did you approach it?

**Category:** Adaptability & Change
**Difficulty:** 🟡 Middle
**Tags:** `legacy-code`, `refactoring`, `technical-debt`, `testing`, `strangler-fig`

## Question
> Tell me about your experience working with a legacy codebase. How did you approach it?

## Short Answer
I inherited a 10-year-old WCF service with no tests and tight coupling throughout. My approach was characterisation testing first, isolate-then-refactor second, and never rewrite more than I could test in a single PR. Over 6 months, I improved code coverage from 0% to 62% while delivering new features into the same codebase every sprint.

## What the Interviewer Is Looking For

Legacy codebase experience is nearly universal for .NET developers — this question tests your **maturity, patience, and systematic approach** to working in difficult codebases. Interviewers want to see:

- You understand the risk landscape of legacy code (hidden dependencies, undefined behaviour, no safety net).
- You use characterisation testing to establish a safety net before changing behaviour.
- You refactor incrementally (strangler fig, not big rewrite).
- You deliver value throughout the process, not just after a multi-month refactor completes.

> **⚠ Warning:** "We decided to rewrite it from scratch" is a red flag answer unless you can explain exactly why the rewrite was justified and how it was managed as a migration rather than a replacement. Most legacy rewrites fail.

### Approaches to Legacy Code Work

| Approach | When to Use | Risk |
|----------|------------|------|
| Characterisation tests first | Always — before any change to legacy code | Low risk — only captures current behaviour |
| Strangler Fig pattern | Replacing subsystems while keeping the legacy system running | Medium — requires routing layer |
| Seam extraction | Introducing testability without changing observable behaviour | Low — surgical, limited scope changes |
| Big bang rewrite | Rarely — only when the system is completely irredeemable | High — high probability of failure or missed behaviour |
| Side-by-side migration | Running old and new simultaneously with shadow traffic | Medium — expensive but safe |

## Example STAR Answer

**Situation:**
I was assigned to maintain and extend a 10-year-old billing service built on WCF (.NET Framework 4.5). The service processed invoices for approximately 12,000 accounts. It had no unit tests, no integration tests, minimal logging, and the most experienced person who knew the system had left 2 years earlier. The business wanted 3 new billing rules added within the next quarter.

**Task:**
Deliver the 3 new billing rules on schedule, while improving the maintainability of the service enough that future changes wouldn't carry the same risk.

**Action:**

*Step 1 — Don't change anything. Understand first:*
My first week was pure reading: I traced the main billing calculation flow end-to-end in a document. I found 11 places where the calculation could branch based on account type — none of them documented.

*Step 2 — Characterisation testing:*
Before writing a single line of new code, I wrote characterisation tests (Michael Feathers' technique): tests that capture what the system currently does, not what it should do. These tests would fail if I accidentally changed existing behaviour.

I focused characterisation tests on the critical calculation paths — the ones that, if broken, would generate wrong invoices.

*Step 3 — Seam extraction for the new features:*
For each of the 3 new billing rules, I introduced a seam: an `IBillingRuleEvaluator` interface extracted from the monolithic billing method. I added the new rules behind the interface and tested them in complete isolation.

*Step 4 — Incremental improvement alongside delivery:*
Each PR I submitted included: the feature change (always), a refactoring of the surrounding code (opportunistic, in-scope only), and new tests for the changed area. I never refactored outside the scope of the current change.

**Result:**
Delivered all 3 billing rules on schedule. Code coverage rose from 0% to 62% over 6 months. The next developer to work on the service completed a change in 2 days that would previously have taken a week, citing the tests as enabling their confidence.

## Reflection / What I'd Do Differently
I would advocate for a dedicated "stabilisation sprint" at the start — 1–2 weeks to do nothing but write characterisation tests and documentation — before committing to any feature delivery timeline. I delivered the characterisation tests alongside features, which meant the early-sprint features were delivered with less safety net than I was comfortable with.

## Common Follow-up Questions
- How do you decide when legacy code should be refactored vs. rewritten vs. left alone?
- How do you handle legacy code that you cannot run locally?
- What's your strategy when adding tests to legacy code is impractical due to tight coupling?
- How do you manage the technical debt conversation with product stakeholders who only care about feature velocity?
- Have you ever advocated for a full rewrite? How did you make the case?
- How do you migrate a legacy .NET Framework app to .NET 8?

## Common Mistakes / Pitfalls
- **Changing behaviour before establishing a safety net** — making "obvious" improvements without characterisation tests frequently breaks subtle (intentional) edge cases in legacy code.
- **Scope creep** — "clean up everything I touch" spirals into a 3-month refactor with no deliverables.
- **The big rewrite trap** — estimating a rewrite as cheaper than incremental improvement. It rarely is.
- **Ignoring the human dimension** — legacy code is someone's work. Approach it with curiosity, not contempt.
- **Not involving the team** — refactoring decisions in legacy code should be visible and reviewed, never done in isolation.
- **Gold-plating the characterisation tests** — characterisation tests should be fast to write and capture current behaviour, not be design documents for the future architecture.

## References
- [Working Effectively with Legacy Code — Michael Feathers](https://www.goodreads.com/book/show/44919.Working_Effectively_with_Legacy_Code) (book — characterisation testing, seam extraction)
- [Strangler Fig Application — Martin Fowler](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Migrating from .NET Framework to .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/porting/)
- [WCF to gRPC Migration — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/grpc/wcf)
- [Technical Debt — Ward Cunningham / Martin Fowler](https://martinfowler.com/bliki/TechnicalDebt.html)

[See also: Balanced Technical Debt Against Feature Delivery](balanced-technical-debt-against-feature-delivery.md)
