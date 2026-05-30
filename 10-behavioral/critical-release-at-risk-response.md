# Tell me about a time a critical release was at risk. How did you respond?

**Category:** Dealing with Pressure & Tight Deadlines
**Difficulty:** 🔴 Senior
**Tags:** `release-management`, `risk`, `leadership`, `incident`, `delivery`

## Question
> Tell me about a time a critical release was at risk. How did you respond?

## Short Answer
Our product launch was 36 hours out when we discovered a data migration flaw that would corrupt 8% of user records. I immediately pulled the team into an incident mode response — not a "let's see what happens" response. We worked through the night, implemented and tested a fix, and launched on time with zero user impact. The principle: treat a pre-release risk discovery like a live incident. Respond with the same urgency.

## What the Interviewer Is Looking For

This is a **senior-level question** about crisis leadership, technical problem-solving under pressure, and stakeholder communication. Interviewers want to see:

- You assessed the risk correctly and quickly — you didn't minimise or over-escalate.
- You mobilised the right people without unnecessary chaos.
- You made a clear recommendation to leadership (launch, delay, or scope-reduce), backed by data.
- You kept the situation under control through focused, calm execution.

### Response Framework for At-Risk Releases

```
1. Assess   → What exactly is wrong? Severity? User impact? Reversible?
2. Decide   → Launch, delay, or scope-reduce? Who makes this decision?
3. Mobilise → Pull in the right people; assign clear roles
4. Execute  → Focus on the critical path; cut non-essential work
5. Communicate → Regular updates to stakeholders; no surprises
6. Recover  → After launch, review what caused the risk in the first place
```

## Example STAR Answer

**Situation:**
Our new subscription management platform was launching on a Monday. On Saturday morning (36 hours before go-live), QA discovered that our data migration script incorrectly mapped subscription tier IDs between legacy and new systems — 8% of migrated users would have their subscription plan downgraded silently.

**Task:**
I was the tech lead and release owner. I had to assess the risk, form a remediation plan, and make a recommendation to the product VP about whether to proceed, delay, or change scope.

**Action:**

*0–30 minutes — Assess:*
I reproduced the bug, confirmed the scope (8% of users, approximately 14,000 accounts), verified the data was not yet committed to production, and classified it as a P0 blocker for the planned launch.

*30 minutes — Decision meeting:*
I called a 20-minute Zoom with the VP, PM, and data team lead. I presented: the bug, the scope, two options — (A) delay launch by 48 hours and fix properly, or (B) fix the migration script tonight and re-run. I recommended option B, conditional on a 3-hour test window, because the migration data was still in staging and the fix appeared bounded.

The VP chose option B.

*Hour 1–8 — Execution:*
I personally led the migration fix. Two engineers from the data team joined. I set clear roles: one engineer fixed the script, one ran parallel validation tests, I reviewed changes and coordinated with QA for verification criteria.

By 2am, the corrected migration had been tested against a full production dataset backup. Zero affected records.

*Ongoing — Communication:*
I sent hourly status updates in Slack (#release-critical channel) even when there was nothing new to report — because silence creates anxiety. Updates were factual: "Fixing — no new blockers. ETA still 2am."

**Result:**
Launch proceeded Monday as scheduled. Zero user impact from the migration issue. The detection-to-resolution timeline (14 hours) was used as a case study for our "pre-launch readiness" process, which now includes a migration dry-run against production-scale anonymised data 72 hours before any major data migration.

## Reflection / What I'd Do Differently
I would mandate a production-scale dry run for all data migrations as part of the launch checklist. The migration had only been tested against a 1,000-record sample; a 100,000-record test would have caught this 3 days earlier, when fixing it would have been routine rather than a crisis.

## Common Follow-up Questions
- How do you decide whether to delay a launch vs. pushing through with a known risk?
- How do you communicate a last-minute launch risk to the CEO or a major customer?
- What's your process for minimising the risk of data migrations on production systems?
- How do you keep your team calm and focused during a late-night release crisis?
- What post-launch review practices have you introduced as a result of near-misses?
- Have you ever made the wrong call on a "launch or delay" decision? What happened?

## Common Mistakes / Pitfalls
- **No risk assessment before acting** — diving into a fix without understanding the scope can waste hours.
- **Silent escalation** — the product VP needs to know about a P0 risk immediately, not on Monday morning.
- **Panic mode** — unstructured "all hands on deck" responses create chaos; clear roles and focus are more effective.
- **The wrong decision framing** — presenting "we have a problem" without options and a recommendation is not leadership.
- **No launch checklist outcome** — at the senior level, a near-miss should improve the process for next time.
- **Missing the human story** — working through the night with a team requires keeping morale up; mention how you managed that.

## References
- [Release Management — Google SRE Book](https://sre.google/sre-book/release-engineering/)
- [Data Migration Best Practices — Microsoft Learn](https://learn.microsoft.com/en-us/azure/architecture/data-guide/relational-data/data-migration)
- [Blue-Green Deployment — Martin Fowler](https://martinfowler.com/bliki/BlueGreenDeployment.html)
- [Incident Command for Engineers — PagerDuty](https://response.pagerduty.com/)
- *Accelerate* — Forsgren, Humble, Kim (book reference — change failure rate as a DORA metric)
