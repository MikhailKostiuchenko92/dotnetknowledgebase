# Tell me about a time you had to deliver under extreme time pressure. What trade-offs did you make?

**Category:** Dealing with Pressure & Tight Deadlines
**Difficulty:** 🟡 Middle
**Tags:** `time-pressure`, `trade-offs`, `prioritisation`, `delivery`, `quality`

## Question
> Tell me about a time you had to deliver under extreme time pressure. What trade-offs did you make?

## Short Answer
We had a 48-hour window to deliver a GDPR data deletion capability before a regulatory audit. I made three explicit trade-offs: manual deletions for low-volume data instead of automation, no UI (just an admin API endpoint), and reduced test coverage focused only on the critical deletion paths. All trade-offs were documented and tracked as follow-up items. I never hide shortcuts — I make them visible and time-bounded.

## What the Interviewer Is Looking For

This question assesses your **judgment under pressure**, **ability to identify and communicate trade-offs**, and **professional discipline** (documenting shortcuts, not hiding them). Interviewers want to see:

- You stayed calm and made rational decisions, not panicked choices.
- You made the trade-offs **explicit** — you didn't just cut corners without awareness.
- You communicated the trade-offs to stakeholders.
- You tracked the shortcuts as follow-up work, not permanent debt.

### Trade-off Framework Under Pressure

When time is severely constrained, you can only have some of:

| Dimension | Can be reduced | Cannot be reduced |
|-----------|---------------|------------------|
| Scope | ✅ Cut to MVP | — |
| Polish / UX | ✅ Admin-only, no UI | — |
| Test breadth | ✅ Focus on critical paths | Core correctness |
| Performance | ✅ Unoptimised is OK initially | Correctness |
| Documentation | ✅ Minimal for now | Follow-up ticket required |

> **⚠ Warning:** "I just worked harder" is not a trade-off story. The question specifically asks what *trade-offs* you made — decisions to leave something out or do it at lower quality.

## Example STAR Answer

**Situation:**
A GDPR Right to Erasure request came in from a corporate client on a Tuesday. Legal confirmed we had to complete the full data deletion by Thursday 5pm or face a regulatory penalty. I had 48 hours.

**Task:**
I was responsible for implementing the deletion logic. Our data was spread across 5 database tables, 2 blob storage containers, and a third-party analytics platform. A full automated deletion pipeline with testing would take a week minimum.

**Action:**

*Step 1 — Assess and scope:*
I mapped all data locations. The analytics platform had an API for deletion — that was already covered. Three of the five database tables stored user-generated content. Two stored system audit logs.

*Step 2 — Explicit trade-offs:*

Trade-off 1 — Manual over automated: For the blob storage (low volume: 23 files), I ran a manual deletion script rather than building automation. Documented as "automate in sprint 45."

Trade-off 2 — No UI: I built a single admin API endpoint (`DELETE /admin/users/{id}/data`) rather than an admin console. Documented as "add admin UI in sprint 45."

Trade-off 3 — Targeted tests only: I wrote integration tests for the critical deletion paths (user table, content table) but skipped tests for the audit log deletion (lower risk, manual verification). Documented as "add test coverage in sprint 45."

I shared this trade-off list with the PM and legal before starting implementation, got explicit sign-off, and added all three items to the backlog with sprint 45 target.

*Implementation:*
Built the endpoint in 12 hours. Tested critical paths in 4 hours. QA and legal verified manually on Thursday morning.

**Result:**
Deletion completed by Thursday 2pm — 3 hours before the deadline. The follow-up items were completed in sprint 45 as committed. Zero regulatory penalty.

## Reflection / What I'd Do Differently
I would have a GDPR deletion capability designed in from the start of any product that handles personal data. Building it reactively under regulatory pressure is expensive — building it proactively as part of the data model design is straightforward.

## Common Follow-up Questions
- How do you decide which trade-offs are acceptable and which are not?
- What do you do if a trade-off you make under pressure turns out to cause a bug later?
- How do you ensure shortcuts made under pressure get paid back?
- How do you communicate trade-offs to non-technical stakeholders without alarming them?
- Have you ever refused a deadline because the trade-offs required were unacceptable?
- How does your quality bar change under pressure, and where does it not change?

## Common Mistakes / Pitfalls
- **"I just worked harder"** — the question asks about trade-offs, not effort.
- **Hidden shortcuts** — making quality trade-offs without documenting or communicating them is professional malpractice.
- **No follow-up commitment** — shortcuts without a tracked remediation plan become permanent debt.
- **Trading correctness for speed** — cutting test coverage on critical paths is dangerous. Show you kept the right things.
- **Moral ambiguity** — if you made a trade-off that felt wrong, say so and explain what you'd do differently.
- **No communication story** — stakeholders need to know about trade-offs to give informed sign-off.

## References
- [GDPR Right to Erasure — ICO](https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/individual-rights/right-to-erasure/)
- [Technical Debt — Martin Fowler](https://martinfowler.com/bliki/TechnicalDebt.html)
- [Minimum Viable Product — Eric Ries](http://theleanstartup.com/principles) (verify exact URL)
- [STAR Interview Method — Indeed Career Advice](https://www.indeed.com/career-advice/interviewing/star-interview-questions)
- [Release It! — Michael Nygard](https://pragprog.com/titles/mnee2/release-it-second-edition/) (book reference — pragmatic design under constraints)
