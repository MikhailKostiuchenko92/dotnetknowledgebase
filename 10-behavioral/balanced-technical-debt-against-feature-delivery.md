# Tell me about a time you had to balance technical debt against feature delivery pressure.

**Category:** Leadership & Ownership
**Difficulty:** 🔴 Senior
**Tags:** `technical-debt`, `prioritisation`, `stakeholder-management`, `engineering-culture`, `sustainability`

## Question
> Tell me about a time you had to balance technical debt against feature delivery pressure.

## Short Answer
I negotiated a "20% rule" with the product team — one day per sprint reserved for technical debt and quality work. I made the business case with data: our velocity had dropped 35% over 6 months because of accumulated debt, and continuing to ignore it would cost more than fixing it. The key is making the cost of debt visible to non-engineers, not just asserting it exists.

## What the Interviewer Is Looking For

This is a **senior-level question** about engineering sustainability and stakeholder communication. Interviewers want to see:

- You understand that technical debt is a real cost, not an excuse for perfectionism.
- You can quantify the impact of debt in terms non-engineers understand (velocity, bug rate, feature cost).
- You have practical mechanisms for managing the tension — not just "we need to slow down."
- You are a **partner** to the product team, not an adversary.

### Technical Debt: Quantifying the Invisible

| Debt Symptom | Measurable Signal |
|-------------|------------------|
| Slowing velocity | Story points per sprint declining over time |
| High bug rate | Escaped defects per release |
| Slow onboarding | Time for a new engineer to first PR |
| Fear of changing code | Test coverage, code churn metrics |
| Repeated incidents | Recurring failure modes in post-mortems |

> **⚠ Nuance:** Not all technical debt is bad. The problem is *unmanaged* debt. A senior engineer can distinguish between **deliberate debt** (conscious trade-off with a payback plan) and **accidental debt** (ignorance, decay, or shortcuts without awareness).

## Example STAR Answer

**Situation:**
Our team's velocity had declined from an average of 42 story points per sprint to 27 over a 6-month period. Feature delivery was taking twice as long. The product manager was frustrated and kept adding pressure to "focus on features." At the same time, our legacy authentication module — originally written in 2018 — was causing 1–2 bugs per sprint and blocking integration with a new SSO provider.

**Task:**
I was the tech lead. I needed to make the case for dedicated debt reduction time *without* appearing to be obstructionist, and I needed to do it in terms the PM could act on.

**Action:**

*Step 1 — Quantify the cost:*
I spent a week pulling data from our sprint history: velocity trend, ratio of bug-fix time vs. feature time, and a specific analysis of the auth module showing that ~30% of all sprint delays traced back to it.

*Step 2 — Translate to business language:*
Instead of "we have technical debt," I presented: "The authentication module is costing us approximately 1.5 sprints per quarter in delayed features and incident response. Refactoring it would take approximately 2 sprints and eliminate that cost. Break-even is Sprint Q3+1. After that, we're faster."

*Step 3 — Propose a sustainable mechanism:*
I proposed the "20% rule" — allocating 1 day per sprint (20% of capacity) to debt work. This wasn't a 2-sprint feature stop; it was a long-term budget that the PM could plan around. I also proposed quarterly "debt health reviews" to keep the conversation ongoing.

*Step 4 — Pilot with the auth module:*
I made the auth refactoring the first debt item because it had the clearest business case. We tracked velocity before and after.

**Result:**
After the auth refactoring (completed in 1.5 sprints under the 20% rule), sprint velocity began recovering. 3 months later, velocity was back to 38 story points per sprint. The PM became an advocate for the 20% rule because they could see the business outcome. The SSO integration — previously blocked — shipped the following quarter.

## Reflection / What I'd Do Differently
I would keep a persistent, always-visible "debt register" — not a hidden backlog, but a living document shared with the PM — so that debt conversations are continuous, not episodic firefighting. Quarterly surprises are worse than weekly small conversations.

## Common Follow-up Questions
- How do you decide which technical debt to address first when there's a large backlog?
- What's the difference between technical debt and just "features that aren't done yet"?
- Have you ever advocated for addressing technical debt and been overruled? What happened?
- How do you prevent new technical debt from accumulating while you're paying down old debt?
- How do you communicate technical debt to engineers who are new to the codebase?
- What metrics do you use to measure the health of a codebase?

## Common Mistakes / Pitfalls
- **Pure technical framing** — "the code is messy" is not a business case. Quantify the cost.
- **Binary framing** — "either we fix debt or we ship features" creates an adversarial dynamic. Show both can coexist.
- **Perfectionism** — some debt is deliberate and that's OK. The story should show pragmatic judgment.
- **No mechanism** — "we agreed to focus on quality" is not sustainable without a structural allocation.
- **Debt as excuse** — be careful that your story doesn't read as "I used technical debt framing to slow things down."
- **No outcome measurement** — show what improved after the debt was addressed (velocity, bug rate, cycle time).

## References
- [Technical Debt — Martin Fowler](https://martinfowler.com/bliki/TechnicalDebt.html)
- [Technical Debt Quadrant — Martin Fowler](https://martinfowler.com/bliki/TechnicalDebtQuadrant.html)
- [Accelerate — Forsgren, Humble, Kim](https://itrevolution.com/product/accelerate/) (book reference — data on tech debt and delivery performance)
- [Working Effectively with Legacy Code — Michael Feathers](https://www.amazon.com/Working-Effectively-Legacy-Michael-Feathers/dp/0131177052) (book reference)
- *The DevOps Handbook* — Kim, Humble, Debois, Willis (book reference — flow, feedback, continuous improvement)
