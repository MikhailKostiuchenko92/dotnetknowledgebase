# Tell me about a time you used data or metrics to drive a technical decision.

**Category:** Problem Solving & Technical Decisions
**Difficulty:** 🟡 Middle
**Tags:** `metrics`, `data-driven`, `observability`, `performance`, `decision-making`

## Question
> Tell me about a time you used data or metrics to drive a technical decision.

## Short Answer
When the team proposed replacing our caching layer with Redis, I wanted to validate the assumption that our current in-memory cache was actually the bottleneck. I added request-level telemetry for cache hit rate, latency distribution, and memory pressure, and found that our P99 latency was caused by database query time — not cache misses. We optimised the query instead, saving 3 months of Redis migration work.

## What the Interviewer Is Looking For

This question tests your commitment to **evidence over intuition**. Interviewers want to see:

- You measure before you act, not after.
- You can identify the right metric for the decision at hand.
- You've had experience where data contradicted the intuitive assumption — and you followed the data.
- You understand the difference between correlation and causation in metrics.

> **⚠ Tip:** Stories where the data confirmed what everyone already believed are weaker than stories where the data surprised the team. The best answers show that metrics prevented a wrong decision, not just validated a right one.

### Data-Driven Decision Framework

| Step | Description |
|------|-------------|
| Form hypothesis | What do you believe is true? What decision are you trying to make? |
| Identify signal | What metric would prove or disprove the hypothesis? |
| Collect data | Instrument the system; collect baseline before any change |
| Analyse | Are you seeing correlation or causation? Is the sample size sufficient? |
| Decide | What does the data say? Does it confirm or contradict the hypothesis? |
| Document | Record what you measured, how, and why you decided what you did |

## Example STAR Answer

**Situation:**
Our API had P99 latency around 400 ms for a product search endpoint. Two engineers on the team believed the bottleneck was our in-memory cache: too small, too many misses. The proposed solution was a Redis migration — a significant 6-week project.

**Task:**
I was asked to scope the Redis migration. Before estimating, I wanted to validate the root cause assumption with data, not just intuition.

**Action:**

*Step 1 — Instrument before assuming:*
I added three custom Application Insights metrics to the search endpoint:
- Cache hit/miss rate per request (tagged by query type)
- Time spent in cache lookup (stopwatch before/after)
- Time spent in database query (stopwatch before/after)

I collected 48 hours of production data.

*Step 2 — Analyse:*
Results were surprising:
- Cache hit rate: **87%** — much higher than the team assumed.
- Average cache lookup latency: **2 ms**.
- Average database query latency (on cache miss): **380 ms**.

The cache was working well. The bottleneck was the SQL query executed on cache miss — a complex JOIN with no covering index on the `ProductCategoryId` column, which was the most common filter.

*Step 3 — Present findings and pivot:*
I shared the data in the team's architecture meeting with a clear conclusion: the cache isn't the problem. Adding a covering index on `ProductCategoryId` should resolve the P99 latency — at a fraction of the effort.

I added the index (1 day of work, including migration script and testing). P99 latency dropped from 400 ms to 65 ms.

**Result:**
Zero Redis migration work needed. Saved approximately 5–6 weeks of engineering time. The incident became a team standing principle: profile before you migrate.

## Reflection / What I'd Do Differently
I would build latency breakdowns (database vs. cache vs. external calls) as a default dashboard for all new APIs from day one — not as a reactive investigation. This would have made the root cause immediately visible without the need for a special instrumentation sprint.

## Common Follow-up Questions
- How do you decide which metrics to track for a new service?
- What's your approach when you have conflicting metrics — two data sources telling different stories?
- How do you establish a baseline before making a change so you can measure the impact?
- What's the difference between a leading indicator and a lagging indicator in engineering metrics?
- How do you communicate metrics findings to non-technical stakeholders?
- Have you ever had data that was misleading? How did you identify that?

## Common Mistakes / Pitfalls
- **Collecting data after the decision is made** — post-hoc data collection confirms what you already believe; it doesn't challenge it.
- **Wrong metric for the decision** — measuring "requests per second" when you need "P99 latency" leads to wrong conclusions.
- **Insufficient sample size** — 10 minutes of data during off-peak hours is not a representative baseline.
- **Correlation as causation** — "requests increased when we added Redis" doesn't mean Redis increased requests.
- **Trusting averages** — average latency hides tail latency. Always check P95/P99 for user-facing services.
- **Not presenting alternatives** — when data disproves the assumed solution, you must present a data-backed alternative, not just say "the proposal is wrong."

## References
- [Application Insights Custom Metrics — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-monitor/app/api-custom-events-metrics)
- [Measuring .NET Application Performance — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/)
- [SQL Server Execution Plans and Index Optimization](https://learn.microsoft.com/en-us/sql/relational-databases/performance/execution-plans)
- [USE Method for Performance Analysis — Brendan Gregg](https://www.brendangregg.com/usemethod.html)
- [Accelerate — Forsgren, Humble, Kim](https://itrevolution.com/product/accelerate/) — DORA metrics framework
