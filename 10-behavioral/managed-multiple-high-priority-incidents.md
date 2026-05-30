# Tell me about a time you managed multiple high-priority incidents at once.

**Category:** Dealing with Pressure & Tight Deadlines
**Difficulty:** 🔴 Senior
**Tags:** `incident-management`, `multi-tasking`, `leadership`, `triage`, `on-call`

## Question
> Tell me about a time you managed multiple high-priority incidents at once.

## Short Answer
During a Black Friday traffic spike, we had three concurrent incidents: checkout failures, notification delays, and a monitoring alert spike. I didn't try to work all three simultaneously — I applied triage, delegated two to other engineers with clear briefs, and personally owned the highest-impact incident (checkout). Multi-incident management is about parallel delegation with tight feedback loops, not heroic multitasking.

## What the Interviewer Is Looking For

This is a **senior-level question** about incident command, delegation under pressure, and calm leadership in crisis. Interviewers want to see:

- You triage effectively — not everything is equally urgent even when everything is broken.
- You delegate rather than trying to personally manage every issue.
- You maintain communication with stakeholders through the chaos.
- You stay calm and think structurally rather than reactively.

### Multi-Incident Triage: Key Principles

| Principle | Application |
|-----------|-------------|
| Impact first | Which incident affects the most users or most revenue? Own it. |
| Delegate clearly | Assign each incident to an owner; give them the brief and your contact |
| Parallel not serial | Multiple issues need parallel owners, not a serial queue |
| Communication cadence | Stakeholders need updates even if there's no progress — silence is worse |
| Avoid cognitive overload | You can't run 3 incident rooms simultaneously; create structure |

> **⚠ Warning:** "I handled all three incidents myself by working very hard" is not the right answer at the senior level. Delegation and structure are the key signals.

## Example STAR Answer

**Situation:**
On Black Friday (our highest traffic day), at 2pm, three alerts fired within 12 minutes:

1. **P1**: Checkout service error rate at 18% (up from <0.1%) — direct revenue impact.
2. **P1**: Order notification emails delayed by 2+ hours — user experience impact, SLA breach risk.
3. **P2**: Memory alert on 3 of 8 background job instances — potential upcoming issue.

I was the on-call senior engineer.

**Task:**
All three needed attention, but I had 2 other engineers available to support and couldn't manage all three at the same depth simultaneously.

**Action:**

*Triage (5 minutes):*
- Checkout: P1, direct revenue loss, take personally.
- Notifications: P1, SLA risk, delegate to Engineer A.
- Memory alert: P2, not yet impacting users, delegate to Engineer B with note "monitor and update me every 20 minutes; only escalate if it becomes P1."

*Checkout incident (personally managed):*
Error traces pointed to a database timeout on the `inventory_check` query under high concurrency. Temporary fix: increased connection pool size and added an index that had been missed in the previous deploy. Error rate dropped to <1% within 20 minutes.

*Notification incident (delegated, monitored):*
Engineer A identified a message queue backlog caused by a throttled Azure Service Bus connection. Resolution: increased throughput units. Resolved in 35 minutes.

*Memory alert (delegated):*
Engineer B confirmed it was a slow memory leak in a scheduled job that would not become critical within the trading window. Monitored for 2 hours; no escalation needed. Addressed post-peak.

*Stakeholder communication:*
I posted in #incidents every 15 minutes with a simple status table: [Issue | Owner | Status | ETA]. This kept leadership and the PM informed without pulling me into explanation mode during active firefighting.

**Result:**
Checkout restored within 25 minutes. Notifications caught up within 45 minutes. No P2 escalation. Black Friday revenue impact from the checkout incident was approximately 4% of a 25-minute window — significantly less than if resolution had taken 2+ hours.

## Reflection / What I'd Do Differently
I would implement automated runbooks for our most common failure modes (high connection pool pressure, Service Bus throttling). Each of these incidents required someone to trace, diagnose, and then recall the fix from memory. A runbook would have cut resolution time by 30–40%.

## Common Follow-up Questions
- How do you decide the priority order when multiple P1 incidents are happening at once?
- How do you avoid creating additional incidents when rapidly applying fixes under pressure?
- What communication tools and channels do you use for multi-incident coordination?
- How do you ensure delegated incident owners have what they need and aren't blocked?
- What's your post-mortem approach when multiple incidents were caused by the same root event?
- How do you maintain team morale through a multi-hour multi-incident period?

## Common Mistakes / Pitfalls
- **Solo heroism** — personally trying to manage multiple concurrent incidents leads to cognitive overload and slower resolution.
- **Triage by ticket order** — handling whatever was raised first rather than by impact is a common mistake.
- **Communication blackout** — leadership silence during a major incident creates panic that compounds the problem.
- **Ignoring P2s entirely** — P2s during a peak event can escalate; assign a monitor even if not a full responder.
- **No runbooks** — reactive diagnosis under pressure is slower than following a pre-documented procedure.
- **Skipping the post-mortem** — multiple concurrent incidents usually have a common cause; the retrospective is where you find and fix it.

## References
- [Google SRE Book — Managing Incidents](https://sre.google/sre-book/managing-incidents/)
- [PagerDuty Incident Response](https://response.pagerduty.com/)
- [Azure Service Bus Throttling — Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-messaging-exceptions)
- [Runbooks for Engineers — Atlassian](https://www.atlassian.com/incident-management/runbook) (verify exact URL)
- *The Phoenix Project* — Kim, Behr, Spafford (book reference — constraint theory and incident management)
