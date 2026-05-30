# Tell me about a time you had to roll back a release. What was the process?

**Category:** Failure & Mistakes
**Difficulty:** 🔴 Senior
**Tags:** `deployment`, `rollback`, `incident-management`, `release-engineering`, `risk-mitigation`

## Question
> Tell me about a time you had to roll back a release. What was the process?

## Short Answer
I rolled back a release when a database migration's write-path change caused a spike in deadlock errors 5 minutes after deployment. We had a one-command rollback process: redeploy the previous container image. The migration rollback was harder — we had to run a compensating migration — but we had designed for it. The key is having a rollback plan *before* you deploy, not after things break.

## What the Interviewer Is Looking For

This is a **deployment safety and engineering maturity question**. Interviewers — especially at senior level — want to see:

- You have real experience with production rollbacks (not just theoretical knowledge).
- You understand the different dimensions of rollback: application code vs. database migrations vs. data state.
- You have a disciplined pre-deployment process that includes a rollback plan.
- You stayed calm, followed a clear process, and communicated effectively during the incident.

### Rollback Complexity Spectrum

| Change Type | Rollback Complexity |
|-------------|-------------------|
| Stateless code (containers) | Low — redeploy previous image |
| Configuration / feature flags | Low — toggle flag or restore config |
| Additive DB migration (add column) | Medium — column can stay, app code rolled back |
| Destructive DB migration (remove column, change type) | High — requires compensating migration |
| Data transformation | Very High — may need manual data correction |

> **⚠ Key Principle:** The safest releases are **backward-compatible** — old code and new code can both run against the same schema. This makes rollback trivial because you only need to redeploy the previous container.

## Example STAR Answer

**Situation:**
We were deploying a new order processing flow that changed how we wrote order status transitions to the database. The migration added a new `status_history` JSONB column and the application code was updated to write to it. The change had been reviewed, tested in staging, and approved.

**Task:**
I was the on-call engineer and the release owner for this deployment. We deployed at 14:00 on a Tuesday.

**What happened:**
At 14:06, our deadlock error rate spiked from near-zero to 12 errors/minute on the orders table. The new column write introduced a lock acquisition order that conflicted with an existing concurrent update path we hadn't exercised in staging (the staging database had no concurrent writes).

**The rollback process:**

*Step 1 (14:07) — Detect and declare:*
Alert fired; I declared a P1 incident.

*Step 2 (14:08) — Assess rollback feasibility:*
I checked our pre-prepared rollback plan (written before the deployment): the app code rollback was safe because the new column had a default value (nullable JSONB) — old code would simply ignore the column. I confirmed the migration was backward-compatible.

*Step 3 (14:09) — Execute app rollback:*
One command: `kubectl rollout undo deployment/order-service`. Container redeployment completed within 90 seconds.

*Step 4 (14:11) — Verify:*
Error rate returned to baseline. Orders were processing normally. Database column stayed (no data to revert; no rows had been written yet at the point of rollback).

*Step 5 (14:15) — Communicate:*
Posted incident summary to stakeholders: "Release rolled back. Root cause under investigation. No data loss. ETA for re-release: TBD."

*Post-incident:*
Root cause: staging had single-writer assumption; the new column write path acquired table lock in a different order than the concurrent inventory deduction. Fix: rewrite the status history write as a separate transaction with retry logic rather than an in-line write to the same row.

**Result:**
Total user impact: ~6 minutes of degraded order processing (errors retried by clients, no order loss). Re-release shipped 4 days later after staging was enhanced with concurrent write simulation.

## Reflection / What I'd Do Differently
I would require concurrent write simulation in staging for any deployment that touches high-contention tables. The staging environment gap was known but deprioritised — that's a risk register item that should have had an owner and a resolution timeline.

## Common Follow-up Questions
- How do you design releases to make rollback easier?
- What's the difference between a rollback and a hotfix forward — when do you choose each?
- How do you handle database migrations that can't be rolled back?
- What's your pre-deployment checklist for high-risk releases?
- How do you test for rollback safety before deploying?
- What does a blue-green deployment or canary release add to your rollback capability?

## Common Mistakes / Pitfalls
- **No pre-planned rollback** — describing a rollback improvised under pressure signals poor release engineering practice.
- **Skipping the communication story** — who did you notify, when, and what did you say? Stakeholder communication is half the job.
- **Conflating app rollback with DB rollback** — these are different problems with very different complexities.
- **Celebrating the rollback** — a rollback is a recovery from a failure, not a success. Acknowledge what should have prevented the need.
- **No root cause** — saying "we rolled back and it was fine" without identifying why the deployment failed is incomplete.
- **Ignoring the monitoring story** — how did you know there was a problem? User complaints are worse than automated alerts.

## References
- [Blue-Green Deployment — Martin Fowler](https://martinfowler.com/bliki/BlueGreenDeployment.html)
- [Canary Releases — Martin Fowler](https://martinfowler.com/bliki/CanaryRelease.html)
- [Database Migration Strategies — Flyway](https://flywaydb.org/documentation/concepts/migrations) (verify exact URL)
- [SQL Server Deadlock Analysis — Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-deadlocks-guide)
- *Continuous Delivery* — Jez Humble & David Farley (book reference — deployment pipeline patterns)
