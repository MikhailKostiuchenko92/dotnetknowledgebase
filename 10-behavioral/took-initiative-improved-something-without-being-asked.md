# Describe a situation where you took initiative and improved something without being asked.

**Category:** Leadership & Ownership
**Difficulty:** 🟡 Middle
**Tags:** `initiative`, `ownership`, `proactivity`, `improvement`, `developer-experience`

## Question
> Describe a situation where you took initiative and improved something without being asked.

## Short Answer
I noticed our CI pipeline was failing on flaky integration tests three or four times a week, causing 30-minute wasted cycles. Without being asked, I investigated the root causes over two evenings, found three specific tests with race conditions, fixed them, and added a retry strategy for network-dependent tests. Pipeline stability improved from ~70% to 98% pass rate within a week.

## What the Interviewer Is Looking For

This question probes **ownership mindset**, **proactivity**, and **engineering professionalism**. Interviewers want to see:

- You notice problems beyond your assigned work scope.
- You act on them without waiting for permission or a ticket.
- You deliver a real, measurable improvement.
- You don't need external motivation to do quality work.

### "Bias for Action" — What It Looks Like

| Action | Bias for Action |
|--------|----------------|
| See a flaky test | Fix it when you have a spare hour, not "add it to the backlog" |
| Notice a missing README | Write one before someone else wastes time onboarding |
| Spot a security misconfiguration | Flag it immediately and propose a fix |
| See a slow query in logs | Investigate root cause and open a PR |

> **⚠ Warning:** The story must be about something you did *unprompted* — not a task you completed enthusiastically once assigned. The "without being asked" element is central.

## Example STAR Answer

**Situation:**
Our team's CI pipeline had been intermittently failing for months. The failure rate was roughly 3–4 times per week, always in the integration test suite. The team had accepted it as "normal" — the running joke was "just re-run the pipeline." No one had been formally asked to fix it because it didn't block any specific feature.

**Task:**
I hadn't been assigned to fix this. But I calculated the cost: 3 failures/week × ~30 minutes of wasted developer time per failure × 5 developers = 7.5 developer-hours wasted per week. That was real.

**Action:**
I spent two evenings (about 4 hours total) investigating. I pulled CI failure logs for the past 30 days and categorised failures by test file. Three patterns emerged:

1. `OrderProcessorTests.ShouldProcessConcurrentOrders` — had a `Thread.Sleep(500)` that was timing-sensitive on slow CI runners.
2. `EmailNotificationTests.ShouldDeliverWithinSLA` — made a real HTTP call to a third-party test sandbox that was occasionally unavailable.
3. Five tests in `DatabaseRepositoryTests` — were not resetting shared state between runs and could fail depending on execution order.

Fixes:
1. Replaced the `Thread.Sleep` with `await Task.Delay` + polling with `AsyncRetryPolicy` (Polly).
2. Replaced the live HTTP call with a Wiremock stub.
3. Added `[Collection("database")]` xUnit collection fixture to serialize the database tests and reset state between each.

I opened a single PR titled "Fix: eliminate flaky CI tests (3 root causes)" with a short description of each root cause and fix.

**Result:**
Pipeline pass rate measured over the next 30 days: 98.1% (was ~72%). The PR was merged with minimal review — the team was visibly appreciative. The fix was mentioned in our next team retrospective as a high-value contribution. The 7.5 developer-hours per week reclaimed amounted to roughly 30 days per year.

## Reflection / What I'd Do Differently
I would add a flaky test tracking dashboard from the start of new projects — before the problem accumulates. Flaky tests are cheap to fix when there are 3; they're a week-long project when there are 40. Prevention is better than a retroactive fix.

## Common Follow-up Questions
- How do you prioritise self-initiated improvements against your assigned work?
- How do you communicate self-initiated work to your manager so it's visible and valued?
- Have you ever taken initiative on something that turned out to be a mistake or wasn't welcome?
- How do you decide when to raise a problem to the team vs. just fixing it yourself?
- What do you do when you notice a problem but don't have the skill to fix it yourself?
- How do you encourage this kind of initiative in your teammates?

## Common Mistakes / Pitfalls
- **Choosing a story that was actually assigned work** — the "without being asked" qualifier is fundamental.
- **No measurable improvement** — quantify what changed (build time, failure rate, onboarding hours, etc.).
- **Too small a scope** — "I added a comment to a confusing function" is not a compelling story.
- **Not mentioning the recognition or reception** — how did the team or manager respond? This adds texture.
- **Ignoring the cost of the original problem** — establish why the problem mattered before describing the fix.
- **No process implication** — at the senior level, show that you also considered how to prevent the problem from returning.

## References
- [Polly — Resilience and Transient Fault Handling for .NET](https://github.com/App-vNext/Polly)
- [xUnit Collection Fixtures — xUnit Docs](https://xunit.net/docs/shared-context#collection-fixture)
- [Testcontainers for .NET — Eliminating External Test Dependencies](https://dotnet.testcontainers.org/)
- [Flaky Tests — Google Testing Blog](https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html) (verify exact URL)
- [Developer Experience (DevEx) Framework — GitHub](https://github.blog/2023-06-08-developer-experience-what-is-it-and-why-should-you-care/) (verify exact URL)
