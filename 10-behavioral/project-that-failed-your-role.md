# Describe a project that failed. What was your role and what would you do differently?

**Category:** Failure & Mistakes
**Difficulty:** 🔴 Senior
**Tags:** `failure`, `project-management`, `leadership`, `retrospective`, `accountability`

## Question
> Describe a project that failed. What was your role and what would you do differently?

## Short Answer
A microservices migration I led was cancelled after six months because we had underestimated the operational overhead and the team lacked the SRE capability to run a distributed system. My role was tech lead. The failure taught me that architecture decisions must be grounded in the team's current operational maturity, not just technical correctness.

## What the Interviewer Is Looking For

This is a **senior-level question** about large-scale failure, leadership accountability, and learning at depth. Interviewers want to see:

- You can describe a genuinely significant failure — not a minor setback reframed as a "learning opportunity."
- You take ownership of your specific contribution to the failure.
- Your post-mortem is honest and specific — not "we should have communicated better" (generic) but "I failed to validate X assumption with Y person by Z date" (specific).
- The lesson you drew is structural and has changed how you work.

### Common Failure Modes to Draw From

| Category | Example |
|----------|---------|
| Technical overreach | Chose too-complex architecture for team maturity |
| Assumptions not validated | Built for requirements that turned out to be wrong |
| People/process | Team misalignment, unclear ownership, no decision authority |
| Estimation catastrophe | Severely underestimated scope or dependencies |
| External forces | Budget cut, business pivot, acquisition |

> **⚠ Warning:** Avoid blaming business decisions, management, or external forces entirely. Even if the project was cancelled due to a company pivot, your role may have included not flagging risks early enough.

> **⚠ Note on Format:** This question benefits from covering: what the project was, your specific role, what went wrong, what *you specifically* did/didn't do, and — crucially — what you would do differently now.

## Example STAR Answer

**Situation:**
I led the technical design for a greenfield microservices rewrite of a monolithic e-commerce platform. The decision to move to microservices came from senior leadership after reading about Netflix and Amazon's success with the pattern. I was made tech lead for the 8-person development team.

**Task:**
My role was to design the service boundaries, lead the implementation, and coordinate with DevOps for the Kubernetes infrastructure. The project was given a 9-month runway and was considered a top-priority initiative.

**What went wrong:**
After 6 months, the project was cancelled. We had 4 of 12 planned services running in production. The services that were live required 3x the operational attention of the equivalent monolith code.

My post-mortem identified four specific failures I owned:

1. **I validated the architecture with the wrong audience.** I reviewed the design with two senior architects from other teams who were excited about microservices. I didn't validate it with the two DevOps engineers who would operate the system — who later told me they had significant reservations from the beginning.

2. **I accepted ambiguous service boundaries.** I let the initial domain model slide with vague ownership rules. Three months in, we had 4 services that couldn't be deployed independently because of synchronous inter-service dependencies — defeating the main benefit.

3. **I didn't quantify the operational overhead early.** I knew microservices were more complex to operate but didn't model what "more complex" meant for *this team* with *our current tooling*. A realistic operational cost model would have flagged the gap.

4. **I didn't establish failure criteria.** There was no written agreement on "if X, we revisit the architecture decision." Without it, sunk-cost pressure kept the project going past the rational stopping point.

**Result:**
Project cancelled. The monolith was maintained for another 18 months and eventually replaced by a pragmatic modular monolith (not microservices) that the team could operate effectively.

## Reflection / What I'd Do Differently
Before committing to a major architectural direction: (1) validate with the people who will operate it, not just the people who will design it; (2) write down the assumptions and create explicit checkpoints to validate them; (3) define failure criteria upfront so you can make a rational decision to pivot early rather than a political one later.

## Common Follow-up Questions
- How do you decide when a failing project should be cancelled vs. saved?
- What's the difference between a project failure and a learning experience? Can a cancelled project still be a success?
- How do you maintain team morale when a project they've invested in is cancelled?
- What's your approach to avoiding the sunk cost fallacy in long-running projects?
- How do you communicate a project failure to senior leadership?
- What have you changed about how you initiate new projects as a result of this experience?

## Common Mistakes / Pitfalls
- **Picking a minor setback** — a "failed" story must have real impact: project cancelled, product pulled, significant financial loss.
- **External blame only** — "leadership cancelled it for business reasons" is evasive if you didn't flag the technical risks early enough.
- **Vague lessons** — "we should have communicated better" is not a lesson. Be specific about what you should have communicated, to whom, when.
- **Too much narrative, not enough reflection** — the reflection/what-you'd-do-differently section is what interviewers care about most.
- **No ownership of your specific actions** — large team failures have many contributors; zoom in on your specific decisions and omissions.
- **Victim framing** — if your story sounds like "things were done to me," the interviewer will question your agency and leadership capacity.

## References
- [The Anatomy of a Failed Software Project — CHAOS Report, Standish Group](https://www.standishgroup.com/) (verify exact URL)
- [Microservices — When Not to Use Them — Martin Fowler](https://martinfowler.com/articles/dont-start-with-microservices.html) (verify exact URL)
- *The Mythical Man-Month* — Fred Brooks (book reference — classic on project failure)
- [How to Conduct a Blameless Post-Mortem — Google SRE Book](https://sre.google/sre-book/postmortem-culture/)
- *Thinking in Systems* — Donella Meadows (book reference — understanding systemic failure)
