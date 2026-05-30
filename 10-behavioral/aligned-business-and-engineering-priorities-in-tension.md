# Describe a situation where you aligned business and engineering priorities that were in tension.

**Category:** Stakeholder Management & Communication
**Difficulty:** 🔴 Senior
**Tags:** `alignment`, `prioritisation`, `business-engineering`, `stakeholders`, `trade-offs`

## Question
> Describe a situation where you aligned business and engineering priorities that were in tension.

## Short Answer
Product wanted to ship 3 new features in Q3. Engineering had a critical infrastructure upgrade (containerisation) that competed for the same 2 senior engineers. I facilitated a prioritisation session that reframed both as business investments — not "feature vs. tech debt" — and we sequenced them: containerisation first (enabling faster feature delivery in Q4), then features 2 and 3 (feature 1 was deprioritised because it had the lowest business impact). Both sides got what actually mattered most.

## What the Interviewer Is Looking For

This is a **senior leadership question** about bridging the business-engineering divide. Interviewers want to see:

- You understand that "engineering priorities vs. business priorities" is often a framing problem, not an actual conflict.
- You facilitate alignment rather than escalating to someone else to decide.
- You translate engineering investments into business value (speed, reliability, cost).
- You can advocate for engineering needs without being adversarial about it.

> **⚠ Key insight:** Framing infrastructure work as "tech debt" immediately loses the argument with product. Reframe it as "enabling investment" — "this work reduces our per-feature delivery time by 30%" is a business case. "We need to pay off tech debt" is not.

### Reframing Technical Priorities for Business Alignment

| Technical Framing | Business-aligned Framing |
|-------------------|--------------------------|
| "Pay off tech debt" | "Reduce per-feature delivery cost by X%" |
| "Refactor the service" | "Enable new features in this area to ship 2x faster" |
| "Upgrade our infrastructure" | "Reduce deployment failures from N/month to near-zero" |
| "Add tests" | "Reduce regression rate, which costs N hours/month in fixes" |
| "Address security vulnerabilities" | "Reduce compliance risk and prevent a data breach" |

## Example STAR Answer

**Situation:**
Entering Q3 planning, product had 3 high-priority features that required 2 senior engineers. Engineering had a critical containerisation project (migrating 12 services to Kubernetes) that also required the same 2 engineers. Both initiatives had genuine business value — features drove new revenue; containerisation reduced 4x/month deployment failures that were blocking customer deliveries.

**Task:**
Facilitate a prioritisation conversation between the VP of Product and the engineering director that resulted in a shared Q3 plan — not a "who wins" decision.

**Action:**

*Step 1 — Reframe both as business investments before the meeting:*
I prepared a business case for each initiative, in consistent format:
- **Feature 1**: Expected revenue impact, customer value, delivery estimate.
- **Feature 2**: Expected revenue impact, customer value, delivery estimate.
- **Feature 3**: Expected revenue impact, customer value, delivery estimate.
- **Containerisation**: Reduction in deployment failures per month (4 → ~0 expected), engineering hours saved per month (estimated 30 hours/month), enabling faster feature delivery in Q4 (35% capacity increase due to automated deployments).

I explicitly did NOT use "tech debt" language. Containerisation was "deployment reliability investment."

*Step 2 — Facilitate the session:*
I ran a 90-minute session with the VP of Product and engineering director. I presented all four initiatives on equal footing and facilitated a discussion on three questions:
1. What is the cost of NOT doing each one in Q3?
2. What does each one enable or unblock?
3. Are there sequencing dependencies?

The containerisation work, once framed correctly, was compelling: 30 engineering hours/month saved was equivalent to ~1 engineer's capacity per quarter. And it was a prerequisite for features 2 and 3 (they required new deployment infrastructure).

*Step 3 — Sequence, not compete:*
The outcome: containerise in months 1–2, then feature 2 and 3 in month 3. Feature 1 was deferred to Q4 because its revenue impact was the lowest and it had no sequencing dependency.

**Result:**
Containerisation shipped in 7 weeks. Deployment failures dropped from 4/month to 0.5/month. Feature 2 shipped in week 11 (originally estimated 8 weeks post-containerisation — delivered in 5, thanks to the new deployment pipeline). The VP of Product told the board that the engineering team had "found a way to deliver more with the same people."

## Reflection / What I'd Do Differently
I would introduce a quarterly "engineering-business alignment" planning format permanently — not just use it when there's tension. Most tension arises because engineering and business priorities are only visible to each other when there's a conflict.

## Common Follow-up Questions
- How do you decide which engineering investments deserve a business case and which can just be done?
- What do you do when product refuses to give up time for engineering investments no matter how you frame it?
- How do you build a long-term relationship with product leadership that makes these conversations easier?
- What's your framework for deciding between engineering work and feature work?
- How do you measure the business return on engineering infrastructure investments?
- How do you handle it when an engineering investment you championed doesn't deliver the expected return?

## Common Mistakes / Pitfalls
- **"Tech debt vs. features" framing** — this frame is adversarial and engineering almost always loses it.
- **Presenting engineering priorities only in technical terms** — no PM cares about container orchestration; they care about delivery failures and developer capacity.
- **Not involving both sides** — a unilateral decision (from either side) creates resentment. Facilitated alignment creates ownership.
- **No quantification** — "this will make things better" is not a business case. "This saves 30 engineering hours per month" is.
- **Not addressing sequencing** — often the real conflict is order, not priority. "We can do both — containerise first, then features" resolves many apparent zero-sum conflicts.
- **Over-promising** — be conservative with return estimates on engineering investments; over-promising destroys credibility.

## References
- [Accelerate — Forsgren, Humble, Kim](https://itrevolution.com/product/accelerate/) (deployment frequency, lead time as business metrics)
- [An Elegant Puzzle — Will Larson](https://lethain.com/elegant-puzzle/) (tech debt framing, engineering strategy)
- [Shape Up — Basecamp](https://basecamp.com/shapeup) (appetite-based prioritisation)
- [Kubernetes Documentation — kubernetes.io](https://kubernetes.io/docs/home/)
- *Good Strategy Bad Strategy* — Richard Rumelt (framing and prioritisation)
