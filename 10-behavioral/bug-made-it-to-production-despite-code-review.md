# Tell me about a bug that made it to production despite your code review. What did you learn?

**Category:** Failure & Mistakes
**Difficulty:** 🟡 Middle
**Tags:** `code-review`, `quality`, `testing`, `accountability`, `learning`

## Question
> Tell me about a bug that made it to production despite your code review. What did you learn?

## Short Answer
I approved a PR that had a race condition in a background job scheduler — something that doesn't manifest under normal test conditions. The bug caused duplicate email notifications for 48 hours before detection. My lesson: code review can't be the last safety net. I started advocating for integration tests and load tests to cover concurrency paths that human review misses structurally.

## What the Interviewer Is Looking For

This question probes **quality culture ownership**, **honesty about review limitations**, and **systemic thinking**. Interviewers want to see:

- You acknowledge that code review has limits — it's a human process applied to a complex system.
- You own your part without over-blaming yourself (you weren't negligent; you hit a blind spot).
- The lesson is about improving the *system*, not just "I'll review more carefully."
- You understand what categories of bugs are reviewable and which are not.

### What Code Review Can and Cannot Catch

| Can Often Catch | Hard to Catch in Review |
|-----------------|------------------------|
| Logic errors in happy path | Race conditions |
| Missing null checks | Memory leaks under load |
| Wrong API usage | Order-dependent state issues |
| Obvious security holes | Performance degradation at scale |
| Missing error handling | Environment-specific failures |

> **⚠ Note:** Code review is a knowledge-transfer and quality *improvement* tool, not a guarantee of correctness. A sophisticated answer acknowledges this distinction.

## Example STAR Answer

**Situation:**
A teammate submitted a PR for a background job that deduplicates outgoing email notifications. The logic was: check if an email has been sent in the last 24 hours, and if not, send it and record the fact. I reviewed the PR, found the logic readable and correct-looking, and approved it.

**Task:**
I was the senior reviewer and my approval was the gate before merge. I was also the most experienced person on the team with our email infrastructure.

**What happened:**
Under normal load — a few hundred events per minute — the deduplication worked correctly. During a flash sale event, however, notification volume spiked to ~4,000 events per minute. Because the "check-then-send" logic was not atomic (it used a SELECT followed by an INSERT, not a distributed lock or conditional upsert), multiple instances of the background job would simultaneously read "not sent" and each trigger the email — classic TOCTOU (Time of Check to Time of Use) race condition.

Over 48 hours, approximately 12,000 duplicate emails were sent to 3,800 users.

**Action:**
I was not on-call but took ownership once the pattern was identified. I wrote the hotfix: replacing the SELECT+INSERT pattern with a conditional upsert using `INSERT ... WHERE NOT EXISTS` wrapped in an application-level distributed lock (Redis `SET NX`). I also wrote a root cause memo.

**Lesson and change:**
The root cause was that I reviewed the logic under an implicit assumption of single-instance execution. Our service had 4 replicas. I started requiring that PRs touching background jobs include a concurrency note in the PR description ("this is/isn't safe under multiple concurrent instances because..."). I also added a high-concurrency integration test template for scheduled jobs.

**Result:**
The hotfix resolved the duplicates within 2 hours of deployment. We sent a user apology communication. The concurrency note requirement was adopted as a team standard. Zero recurrence in 14 months.

## Reflection / What I'd Do Differently
I should have asked "what happens if two instances run this simultaneously?" as a standard review question for any job that reads-then-writes. I now have a mental checklist for concurrency-sensitive code paths that I apply before approving any background processing PR.

## Common Follow-up Questions
- How do you decide when a code review is "good enough" vs. when to request more information?
- What types of bugs are code review fundamentally unable to catch, and how do you compensate?
- How do you handle the political fallout when a bug you approved causes a production incident?
- Have you ever pushed back on a PR you felt wasn't safe, only to be overruled? What happened?
- How do you review code in a domain you're not an expert in?
- What's your review strategy for PRs that are very large (500+ lines)?

## Common Mistakes / Pitfalls
- **Excessive self-blame** — "I should have caught this" for every category of bug implies code review can and should be a perfect process. It isn't.
- **Blaming the author** — the question is about your code review; own your part of it.
- **No systemic lesson** — "I'll review more carefully" is not a structural improvement.
- **Choosing a trivial bug** — the bug should have had real user or business impact.
- **Not understanding the bug** — if you can't explain the root cause technically, the story loses credibility.
- **Forgetting the relationship** — how did the interaction with the PR author go after the incident? Show maturity.

## References
- [Code Review Effectiveness — SmartBear State of Code Review](https://smartbear.com/resources/ebooks/the-state-of-code-review/) (verify exact URL)
- [TOCTOU Race Conditions — OWASP](https://owasp.org/www-community/vulnerabilities/Time_of_check_to_time_of_use)
- [Redis SET NX — Distributed Locks](https://redis.io/docs/manual/patterns/distributed-locks/)
- [Google Engineering Practices — Code Review](https://google.github.io/eng-practices/review/)
- [Testing Concurrency in .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/testing/) (verify exact URL for concurrency testing)
