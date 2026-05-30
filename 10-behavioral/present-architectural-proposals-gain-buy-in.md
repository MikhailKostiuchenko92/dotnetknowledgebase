# Describe how you present architectural proposals and gain buy-in from stakeholders.

**Category:** Stakeholder Management & Communication
**Difficulty:** 🔴 Senior
**Tags:** `architecture`, `buy-in`, `communication`, `stakeholders`, `influence`, `adr`

## Question
> Describe how you present architectural proposals and gain buy-in from stakeholders.

## Short Answer
My process: write a crisp 1–2 page proposal with context, options, recommendation, and trade-offs; review it asynchronously with key stakeholders before the meeting (no one likes surprises in a formal review); and run the meeting as a conversation, not a presentation. Most buy-in happens in the 1:1 conversations before the meeting, not in the room.

## What the Interviewer Is Looking For

This is a **senior engineering communication and influence** question. Interviewers want to see:

- You have a repeatable process for making architectural proposals, not ad-hoc pitches.
- You understand that buy-in is built through conversation before the meeting, not during it.
- You use written documents effectively (ADR, RFC, design doc) as the basis for discussion.
- You address the different concerns of different stakeholder audiences (technical depth for engineers, business impact for product/leadership).

### Stakeholder-Specific Communication by Audience

| Audience | What They Care About | Emphasis |
|----------|---------------------|----------|
| Engineering team | Technical correctness, complexity, maintainability | Options analysis, implementation detail |
| Engineering director | Delivery risk, team capacity, long-term maintainability | Timeline, risk, team capability |
| Product manager | Feature impact, delivery timeline, business risk | What this enables, when it delivers |
| CTO/VP Engineering | Strategic fit, scalability, cost, vendor risk | Architecture principles, business alignment |

> **⚠ Key insight:** Buy-in is built in 1:1 conversations before the meeting. The formal meeting is the ratification step, not the persuasion step. If you're still trying to persuade in the room, you've already lost.

## Example STAR Answer

**Situation:**
I was proposing a migration from a monolithic deployment to an independently deployable services model for our 3 core product domains. This was a 6-month initiative affecting every engineer on a 12-person team, requiring approval from the engineering director, VP of Product, and CTO.

**Task:**
Produce and present an architectural proposal that was technically sound, clearly communicated, and gained approval from all three decision-makers.

**Action:**

*Step 1 — Write the proposal in document form first:*
I wrote a 2-page RFC (Request for Comments) document:
- **Context**: What problem we're solving (deployment coupling, incident blast radius, team autonomy).
- **Options considered**: Stay-with-monolith (improve deployment scripts), modular monolith, services migration.
- **Recommendation**: Services migration, phased over 6 months.
- **Trade-offs accepted**: Higher operational complexity; learning curve for team; 6 months of parallel maintenance.
- **Success criteria**: Independent deployment of each domain within 6 months; deployment failure rate reduced by 50%.

I shared it in a team Slack channel and gave 5 days for async feedback. 8 engineers commented; I updated the doc to address their concerns.

*Step 2 — 1:1 conversations before the formal review:*
Before the formal review meeting, I had 30-minute conversations with:
- **Engineering director**: Focused on team capacity and risk. Showed the phased plan; confirmed he had concerns about operational overhead (Docker/Kubernetes experience gap). I proposed a 3-day team training week as part of the plan.
- **VP of Product**: Focused on what this enabled (faster per-domain delivery) and the risk to features during migration. I showed that domain 2 and 3 features would be unaffected for the first 3 months.
- **CTO**: Focused on the technical reasoning. He challenged the services model vs. modular monolith. I had data from our post-incident reviews showing that 7 of the last 10 incidents were caused by deployment coupling — this was the key evidence.

*Step 3 — The formal review:*
The formal meeting was 45 minutes. I presented the final version of the RFC (the one already reviewed and updated). Each stakeholder asked 1–2 clarifying questions. All approved.

**Result:**
Migration started within 2 weeks. All 3 domains independently deployable at month 7 (1 month late — one domain had more complexity than expected). Deployment failures dropped from 4/month to 0.5/month.

## Reflection / What I'd Do Differently
I would start the stakeholder 1:1 conversations even earlier — before the first draft is complete, not after. Early involvement in the shaping of the document creates ownership. Stakeholders who feel they contributed to the proposal are more invested in its success.

## Common Follow-up Questions
- How do you handle disagreement from a key stakeholder in the formal review meeting?
- What's the difference between an RFC and an ADR?
- How do you maintain architectural proposals for a team that doesn't have formal review processes?
- What do you do when you're overruled on an architectural decision you believe is important?
- How do you keep architectural decisions visible and accessible for future team members?
- How do you build credibility with a CTO or engineering VP whose technical opinions you have to influence?

## Common Mistakes / Pitfalls
- **Verbal-only proposals** — verbal proposals are forgotten and can't be reviewed asynchronously. Always write it down.
- **Surprising stakeholders in the review meeting** — if a stakeholder encounters your proposal for the first time in the meeting, expect pushback.
- **One document for all audiences** — a deeply technical proposal written for engineers is not useful for a PM. Write for your most important audience; provide technical appendix for others.
- **No options** — "we should do X" without acknowledging alternatives invites the response "what about Y?" Explore the space explicitly.
- **Not updating after feedback** — asking for feedback and not updating the proposal signals that the review was performative.
- **Only presenting the recommendation** — the decision-maker needs to understand what you gave up when you chose the recommendation. Present the trade-offs explicitly.

## References
- [Architecture Decision Records — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [RFC Process — IETF](https://www.ietf.org/standards/rfcs/)
- [Design Docs at Google — Malte Ubl](https://www.industrialempathy.com/posts/design-docs-at-google/)
- [Architecture Review — ThoughtWorks Technology Radar](https://www.thoughtworks.com/radar) (verify exact URL)
- *Staff Engineer* — Will Larson (influence without authority, proposal patterns)
