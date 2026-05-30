# Describe a time you had to make a high-stakes technical decision with incomplete information.

**Category:** Leadership & Ownership
**Difficulty:** 🔴 Senior
**Tags:** `decision-making`, `uncertainty`, `technical-leadership`, `risk-management`, `incident-response`

## Question
> Describe a time you had to make a high-stakes technical decision with incomplete information.

## Short Answer
During a production incident, I had to decide within 5 minutes whether to roll back a deployment or hotfix forward — without knowing whether the bug was in the new code or a data migration. I chose rollback, explained my reasoning to the team, and logged the decision. The principle: under time pressure, prefer reversible over irreversible. The decision was right, but the reasoning mattered more than the outcome.

## What the Interviewer Is Looking For

This is a **senior/lead question** about decision quality under uncertainty. Interviewers want to see:

- You have a **framework** for making decisions under uncertainty — not just intuition.
- You distinguish between **reversible** and **irreversible** decisions, and treat them differently.
- You **own the decision** — you don't stall waiting for consensus when time is critical.
- You **communicate the decision and reasoning** so the team can execute confidently.
- You **review the decision afterward** — did you make a good decision, and did it happen to be correct?

### Decision-Making Under Uncertainty: Frameworks

| Framework | When Useful |
|-----------|-------------|
| Prefer reversible over irreversible | Time-pressured binary choices |
| Two-way door vs. one-way door (Bezos) | Architectural/strategic decisions |
| Assume worst-case scope | Incident scope estimation |
| Seek minimum viable information | What's the cheapest data that would change my decision? |
| Document assumptions | So the team can correct you if you're wrong |

> **⚠ Warning:** The interviewer is evaluating your *decision process*, not whether the outcome was correct. A lucky right answer from poor reasoning is worse than a thoughtful wrong answer from sound reasoning — because luck doesn't scale.

## Example STAR Answer

**Situation:**
At 11 PM on a release night, our order confirmation service started failing with `NullReferenceException` in production. Error rate reached 30% of requests within 3 minutes. We had deployed a new version 20 minutes earlier that included both application code changes and a database schema migration.

**Task:**
As the on-call senior engineer, I had to make an immediate decision: roll back the deployment (reverting code but not the schema) or attempt a hotfix forward. I had 5 minutes before the business impact exceeded our SLA threshold.

**The incomplete information:**
I didn't know whether the NullReferenceException was caused by the new code or by data written in an unexpected format by the migration. Rollback would fix a code bug; it wouldn't fix corrupted data written during the migration window.

**My decision process:**

1. **Prefer reversible:** Code rollback is fast and reversible. Forward hotfix is slower and could introduce new bugs under time pressure.

2. **Assess the migration risk:** The migration only *added* a nullable column with no backfill. Even if there was a data issue, rolling back would not make it worse — null data would stay null.

3. **Make the call:** I announced: "Rolling back the container image. Reason: fastest path to service restoration; migration is additive so rollback is safe. If the error persists after rollback, we know the issue is in the data, not the code."

4. **Log the reasoning:** I posted the decision and its rationale in the incident Slack channel before executing, so the team knew what I was doing and why.

**Result:**
Rollback resolved the error within 90 seconds. Post-mortem confirmed the bug was in the new code (a null guard omitted in an edge case for users with no shipping address). The migration column was harmless. Decision was correct — and had been made with sound reasoning even before confirmation.

## Reflection / What I'd Do Differently
I would establish a written **decision log** template as standard practice for all incidents: timestamp, decision made, information known at the time, assumptions, and next review point. Currently this lives in Slack messages and is hard to audit later. A structured decision log is a force-multiplier for post-mortem learning.

## Common Follow-up Questions
- How do you build confidence in a decision when you know you're missing important information?
- What's the difference between deciding quickly and deciding rashly?
- Have you ever made a high-stakes decision that turned out to be wrong? How did you handle the fallout?
- How do you communicate an uncertain decision to your team so they can still execute with confidence?
- What's your approach to "two-way door" vs. "one-way door" decisions?
- How does your decision-making approach change when lives or significant financial impact are involved?

## Common Mistakes / Pitfalls
- **No decision framework** — "I just went with my gut" is not an answer for a senior role.
- **Waiting for perfect information** — by definition, high-stakes incomplete-information decisions require acting before all data is in.
- **Paralysis by committee** — showing you stalled for consensus during a time-critical situation is a red flag.
- **Outcome bias** — a good story evaluates the decision quality, not just whether it worked out.
- **No communication during decision** — tell the team what you're deciding and why, even briefly.
- **Missing the reflection** — what did you learn about your decision-making process, not just the technical outcome?

## References
- [One-Way Door vs. Two-Way Door Decisions — Jeff Bezos](https://www.aboutamazon.com/news/company-news/2015-letter-to-shareholders) (verify exact URL)
- [Thinking in Bets — Annie Duke](https://www.annieduke.com/books/) (book reference — decision quality vs. outcome quality)
- [Incident Command System — FEMA](https://www.fema.gov/emergency-managers/nims/incident-command-system) (verify exact URL — ICS framework applicable to engineering incidents)
- [Google SRE Book — Chapter: Being On Call](https://sre.google/sre-book/being-on-call/)
- *Thinking, Fast and Slow* — Daniel Kahneman (book reference — decision-making under uncertainty)
