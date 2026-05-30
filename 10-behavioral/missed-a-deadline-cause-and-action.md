# Tell me about a time you missed a deadline. What caused it and what did you do?

**Category:** Failure & Mistakes
**Difficulty:** 🟡 Middle
**Tags:** `deadline`, `estimation`, `accountability`, `communication`, `recovery`

## Question
> Tell me about a time you missed a deadline. What caused it and what did you do?

## Short Answer
I missed a sprint deadline because my estimate didn't account for the discovery work involved in understanding an undocumented legacy module. I flagged it as soon as I could see the miss coming — not on the deadline day — explained the specific gap in my original assessment, and renegotiated scope with the product manager so the critical path wasn't blocked.

## What the Interviewer Is Looking For

This question tests **accountability**, **early communication**, and **learning from planning failures**. Interviewers want to see:

- You own the miss — not blame "scope creep" or the legacy codebase.
- You flagged early rather than hoping things would magically work out.
- You have a concrete lesson about how you estimate better now.
- You recovered professionally and protected the team's trust.

### Dimensions Being Assessed

| Dimension | What a Strong Answer Shows |
|-----------|---------------------------|
| Accountability | "I missed it because I underestimated X" — no excuses |
| Early escalation | You flagged the risk before the deadline, not after |
| Problem-solving | You offered a revised plan, not just a confession |
| Process improvement | Your estimation or communication approach changed afterward |

> **⚠ Warning:** "I missed the deadline because I had too much on my plate" sounds like a capacity complaint rather than a personal learning. Own the specific mistake in your estimation or planning approach.

## Example STAR Answer

**Situation:**
I committed to delivering a new user permission system in two weeks. The feature required integrating with our existing role management module, which I had never worked in before but assumed was straightforward.

**Task:**
I was responsible for the estimate and the delivery. My commitment was used to plan a product launch date.

**Action (what happened):**
On day 5 of 10, I discovered the role management module had no unit tests, was tightly coupled to the UI layer through reflection-based attribute discovery, and hadn't been touched in two years. What I had estimated as a 2-hour integration turned into a 3-day refactoring requirement before I could even add the new permission logic.

On day 6 — not day 10 — I scheduled an immediate meeting with my PM. I explained: "I underestimated the complexity of the role module. I should have spiked it before committing. Here's what I know now and here are two options." Option A: extend by 3 days, full feature. Option B: deliver the core permission enforcement on time, defer the admin UI to the following sprint.

The PM chose option B. I documented the role module's hidden complexity in our technical debt backlog so no one else would be blindsided.

**Result:**
Core permissions shipped on the original date. The admin UI shipped in the following sprint with no launch impact. The product manager appreciated the early heads-up — it came with enough lead time to adjust communication to stakeholders.

## Reflection / What I'd Do Differently
I would always include a discovery spike for any unfamiliar module before committing to an estimate. A 2-hour spike on day 1 would have revealed the complexity and I would have given a realistic estimate from the start.

## Common Follow-up Questions
- How do you decide at what point a potential deadline miss needs to be escalated?
- How do you estimate tasks that involve unknown or legacy code?
- What's the difference between a deadline miss caused by underestimation vs. scope creep vs. external blockers?
- How do you handle the emotional pressure of admitting a miss to a manager who is counting on you?
- Have you ever missed a deadline that had real financial or business consequences? What happened?
- What estimation techniques have worked best for you?

## Common Mistakes / Pitfalls
- **Waiting until the deadline to raise the issue** — the longer you wait, the fewer options stakeholders have.
- **Blaming external factors exclusively** — "the requirements kept changing" is often partially true but rarely the whole story.
- **No recovery plan** — confession without a revised path forward leaves stakeholders with nothing actionable.
- **Picking a trivial story** — "I missed a self-imposed internal deadline by a day" is not what the interviewer is looking for.
- **No lesson** — "I'll work harder next time" is not a structural improvement. What specific process changed?
- **Failing to quantify the impact** — show that you understood the business cost of the miss.

## References
- [Planning Fallacy — Wikipedia](https://en.wikipedia.org/wiki/Planning_fallacy)
- [Software Estimation — Steve McConnell](https://www.stevemcconnell.com/books/) (book reference: *Software Estimation: Demystifying the Black Art*)
- [Three-Point Estimation — PMI](https://www.pmi.org/learning/library/three-point-estimating-techniques-9902) (verify exact URL)
- [STAR Interview Method — Indeed Career Advice](https://www.indeed.com/career-advice/interviewing/star-interview-questions)
- *Agile Estimating and Planning* — Mike Cohn (book reference)
