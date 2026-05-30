# Describe a production incident you were responsible for. How did you handle it?

**Category:** Failure & Mistakes
**Difficulty:** 🔴 Senior
**Tags:** `incident-management`, `production`, `accountability`, `debugging`, `on-call`, `post-mortem`

## Question
> Describe a production incident you were responsible for. How did you handle it?

## Short Answer
I was responsible for a deployment that caused a 40-minute outage on our payment confirmation service. I declared the incident immediately, rolled back within 10 minutes, communicated status every 15 minutes to stakeholders, and led the post-mortem that identified three systemic gaps in our deployment safety net. The goal in the moment is restoring service, not assigning blame — including to yourself.

## What the Interviewer Is Looking For

At the senior level, this question assesses your **incident command skills**, **ownership mindset**, and **ability to learn at scale**. Interviewers want to see:

- You didn't minimise or delay acknowledging the incident.
- You prioritised **restoration over diagnosis** — you rolled back first, investigated second.
- You communicated proactively and clearly under pressure.
- You led a structured post-mortem and drove systemic improvement, not just a hotfix.

### Incident Response Framework

A strong answer follows this structure:

```
1. Detect    → How was it found? (alert vs. user report — alerts are better)
2. Declare   → Did you escalate early and involve the right people?
3. Contain   → What was the fastest way to stop the bleeding (rollback, feature flag)?
4. Diagnose  → What was the root cause?
5. Resolve   → What was the permanent fix?
6. Learn     → What systematic change did you make?
```

### Dimensions Being Assessed

| Dimension | What a Strong Answer Shows |
|-----------|---------------------------|
| Ownership | "I was responsible" — no hedging |
| Incident command | You knew the playbook: contain first, diagnose second |
| Communication | Regular, honest, clear status updates during the incident |
| Systems thinking | The post-mortem led to process changes, not just a one-off fix |
| Emotional regulation | You were calm and methodical under pressure |

> **⚠ Warning:** Never describe an incident where you don't own any part of it. The question specifically says "you were responsible for." If you deflect, the interviewer will probe until you accept responsibility for something.

## Example STAR Answer

**Situation:**
I deployed a database migration that added a non-nullable column to our `Orders` table — a table receiving ~5,000 writes per minute during peak hours. I had tested it on staging, but staging used a 10,000-row dataset. Production had 80 million rows.

**Task:**
The migration took a full-table lock in SQL Server that I hadn't anticipated because I used `ALTER TABLE ADD COLUMN NOT NULL` without a default value — a locking operation I had mistakenly believed was non-blocking in our version of SQL Server.

**Action:**

*First 5 minutes (Detect & Declare):*
Our error rate alert fired within 45 seconds of deployment — orders were timing out with lock contention errors. I immediately declared a P1 incident in our Slack incident channel, paging the on-call DBA and my tech lead.

*Minutes 5–12 (Contain):*
Rather than investigate the cause first, I made the fastest path to service restoration: rolled back the application deployment. This didn't fix the migration — the column was still there — but it stopped new writes from failing and reduced the lock contention enough that existing connections could complete.

*Minutes 12–40 (Diagnose & Resolve):*
With the DBA, I diagnosed the lock issue. We ran the column addition as an online operation using a two-step migration: first adding the column as nullable (non-blocking), then backfilling with a batched UPDATE, then adding the NOT NULL constraint once all rows had values.

*Post-incident:*
I wrote a post-mortem within 24 hours. Root causes: (1) our migration guide didn't document locking behaviours for ALTER TABLE operations on large tables, (2) staging data was too small to simulate production lock contention, (3) we had no pre-deployment checklist that included "estimated lock duration."

Actions: migration guide updated with locking annotations, staging refreshed monthly with production-scale anonymised data, a pre-deploy checklist created for schema changes.

**Result:**
40-minute total incident duration. Approximately 1,200 failed order attempts, all retried successfully by the client. No data loss. Post-mortem actions fully implemented within two sprints.

## Reflection / What I'd Do Differently
I would have consulted the DBA during the migration design phase, not the incident. Schema changes on hot tables are a category where I now proactively involve a DBA regardless of how simple the migration looks.

## Common Follow-up Questions
- How do you decide whether to roll back vs. hotfix forward during an incident?
- How do you keep stakeholders informed during an incident without getting pulled away from resolution work?
- What does a good post-mortem look like, and how do you prevent them from becoming blame sessions?
- How do you handle it when you caused an incident but weren't on-call?
- How do you build resilience so incidents like this don't recur?
- What's the difference between root cause and contributing cause in a post-mortem?

## Common Mistakes / Pitfalls
- **Diagnosing before containing** — the #1 mistake in incident response is trying to understand the cause while the system is still failing. Stop the bleeding first.
- **Minimising responsibility** — "it was a team failure" may be true but is not the answer to this question.
- **No post-mortem or learning** — a senior engineer who just fixes and moves on is missing a growth opportunity.
- **Only technical detail, no communication story** — how you kept stakeholders informed is as important as how you fixed the problem.
- **Blaming the tools or environment** — "SQL Server should have handled this better" is a deflection.
- **Picking an incident that wasn't actually serious** — choose one with real business impact to show you've worked in high-stakes environments.

## References
- [Google SRE Book — Chapter: Being On Call](https://sre.google/sre-book/being-on-call/)
- [Blameless Post-Mortems and a Just Culture — John Allspaw](https://www.etsy.com/codeascraft/blameless-postmortems/) (verify exact URL)
- [SQL Server Online Index Operations — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/guidelines-for-online-index-operations)
- [Incident Management — PagerDuty](https://response.pagerduty.com/)
- *The Site Reliability Workbook* — Beyer et al. (book reference)
