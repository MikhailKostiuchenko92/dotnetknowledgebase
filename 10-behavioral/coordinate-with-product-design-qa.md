# Describe how you coordinate with product/design/QA to deliver features smoothly.

**Category:** Collaboration & Teamwork
**Difficulty:** 🔴 Senior
**Tags:** `cross-functional`, `delivery`, `process`, `product-management`, `qa`, `design`

## Question
> Describe how you coordinate with product/design/QA to deliver features smoothly.

## Short Answer
Smooth delivery is a process problem before it's an execution problem. I advocate for three things: design involvement in sprint planning (not just before it), a shared definition of done that QA co-authors, and a "desk check" with the PM mid-development — not at the end. These three habits eliminate most late-stage surprises.

## What the Interviewer Is Looking For

This is a **senior-level question** about process design and cross-functional leadership. Interviewers want to see:

- You've thought systematically about the software delivery process, not just your individual lane.
- You know where cross-functional friction typically occurs and have mechanisms to address it.
- You build relationships with product, design, and QA — not just hand things off.
- You can describe a *system* that works repeatedly, not just a single positive story.

### Where Cross-Functional Delivery Usually Breaks Down

| Phase | Common Failure |
|-------|---------------|
| Discovery | Engineering not involved until designs are "final" |
| Sprint planning | QA not involved in acceptance criteria |
| Development | PM gets the feature only at sprint demo, too late for real feedback |
| Testing | QA gets no test environment or API contract upfront |
| Release | No shared agreement on rollout and communication |

> **⚠ Note:** This question asks for a *how* answer — it's about your process and principles, not a single story. You can anchor it in a specific context, but the response should describe a repeatable approach.

## Example STAR Answer

**Context:**
At my previous company, I was the backend tech lead on a 6-person squad: 2 backend engineers, 1 frontend engineer, 1 designer, 1 PM, and 1 QA engineer. We delivered one major feature per sprint (2 weeks).

**The coordination system I helped design and run:**

### Week -1: Design and Refinement (before the sprint)

I scheduled a 90-minute "three amigos" refinement for every story above 5 story points — me (technical), the PM (value), and QA (testability). We each answered: "What could go wrong with this story from my perspective?" This surfaced hidden edge cases before a line of code was written.

I also attended design reviews with the designer — not to approve the design, but to raise technical constraints early: "This animation would require a real-time WebSocket connection we don't have. Can we simplify to a polling model?" Better to have this conversation in Figma than in a PR.

### Week 1: Mid-development check-in

At day 4 of the sprint, I ran a 20-minute "desk check" with the PM: I showed the partial implementation, they checked it against their intent, and I surfaced any assumptions I'd made. This was not a demo — it was a calibration.

For QA: I shared an API contract (Swagger doc) and a test environment URL by day 3. QA began writing and running automated tests in parallel with my development, not after.

### Week 2: Integration and release

I joined QA for their first pass through the feature — not to supervise, but to hear what was confusing or unclear. Their observations often revealed UX or API design issues that were still cheap to fix.

**Result:**
Our squad went from an average of 2.3 sprint-review rework items per sprint to 0.4 over a 6-month period. The PM cited the mid-sprint desk checks as the single highest-value practice change.

## Reflection / What I'd Do Differently
I would involve QA in the technical design of background jobs and async processes earlier — we had several incidents where QA didn't know how to test eventual-consistency flows because they hadn't been part of the design conversation.

## Common Follow-up Questions
- How do you handle it when the PM pushes back on slowing down delivery for design or QA involvement?
- What do you do when QA finds a critical bug two days before release?
- How does this coordination change when working with a remote or distributed team?
- What's the minimum viable coordination you'd keep if sprint timelines were cut to 1 week?
- How do you build a good working relationship with a designer who doesn't understand technical constraints?
- How do you handle a PM who changes requirements mid-sprint?

## Common Mistakes / Pitfalls
- **Waterfall framing** — describing sequential handoffs (design → engineering → QA) rather than parallel, overlapping work.
- **No QA involvement pre-coding** — QA who only receives features for testing is a bottleneck, not a quality partner.
- **No PM visibility during development** — surprises at sprint review are usually caused by lack of mid-sprint calibration.
- **Only describing your lane** — the question is about coordination, not just your individual practices.
- **No measurement** — show that your process improved a measurable outcome (rework rate, sprint velocity, bug escape rate).
- **"We just communicated well"** — specific mechanisms (three amigos, desk check, API contract sharing) are much more convincing than generic claims.

## References
- [Three Amigos — Agile Alliance](https://www.agilealliance.org/glossary/three-amigos/)
- [Definition of Done — Scrum Alliance](https://www.scrumalliance.org/community/articles/2014/may/definition-of-done) (verify exact URL)
- [Shape Up — Basecamp](https://basecamp.com/shapeup) — alternative to sprint model; great on cross-functional collaboration
- [Continuous Delivery — Humble & Farley](https://continuousdelivery.com/) (book reference — collaborative pipeline)
- [DORA Metrics — DevOps Research and Assessment](https://dora.dev/)
