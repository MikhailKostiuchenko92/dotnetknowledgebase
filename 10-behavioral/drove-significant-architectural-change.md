# Tell me about a time you drove a significant architectural change in your team.

**Category:** Leadership & Ownership
**Difficulty:** 🔴 Senior
**Tags:** `architecture`, `technical-leadership`, `change-management`, `influence`, `migration`

## Question
> Tell me about a time you drove a significant architectural change in your team.

## Short Answer
I led the migration from a single-database monolith to a service-per-subdomain model over 18 months. I didn't mandate the change — I built the case incrementally: starting with a written proposal, running a low-risk pilot in one domain, measuring the outcomes, and using those results to get buy-in for the broader rollout. The hardest part wasn't the technology; it was aligning 4 teams on the migration approach.

## What the Interviewer Is Looking For

This is a **technical leadership question** testing your ability to drive large-scale change across people, process, and technology simultaneously. Interviewers want to see:

- You can construct a compelling case for architectural change — not just "this is better" but "here's the evidence and here's the risk-managed path."
- You understand that architecture is a socio-technical problem: the human side is as hard as the technical side.
- You can execute a complex, multi-phase migration without breaking the existing product.
- You have the judgment to know when to push and when to defer.

### Dimensions Being Assessed

| Dimension | What a Strong Answer Shows |
|-----------|---------------------------|
| Technical depth | You understood the architecture at the level required to design the change |
| Influence | You built consensus before (not after) the decision was made |
| Risk management | You managed the transition period where both old and new coexisted |
| Measurement | You defined success metrics and evaluated outcomes |

> **⚠ Warning:** Interviewers will probe whether you drove *the change* or just implemented someone else's decision. Be clear about your specific role in originating and shaping the proposal.

## Example STAR Answer

**Situation:**
Our e-commerce platform used a single shared database accessed by 8 services. As the team grew to 30 engineers across 4 squads, merge conflicts in schema migrations were causing 2–3 deployment failures per week, and every schema change required coordination across all squads.

**Task:**
As the principal engineer, I identified this as a fundamental scalability problem. No one had formally tasked me with solving it — I initiated the proposal myself.

**Action:**

*Phase 1 — Building the case:*
I spent two weeks documenting the current pain with data: deployment failure rate, hours per week spent on migration coordination, number of tables owned by more than one team. I proposed a boundary-based database ownership model: each domain (orders, inventory, users, payments) would own its schema exclusively, with cross-domain data accessed via APIs.

I presented this to the CTO and all tech leads in a 90-minute session — not as a mandate but as a proposal with explicit trade-offs and a pilot plan.

*Phase 2 — The pilot:*
We chose the Inventory domain for the pilot — small, well-bounded, no external dependencies. Over 6 weeks, we migrated it to its own database schema with an API boundary. We measured: zero cross-team schema conflicts for inventory after migration, 15% reduction in integration test complexity.

*Phase 3 — Broader rollout:*
Using pilot results as evidence, I got CTO sign-off for the full migration. I created a migration playbook so each team could self-serve their domain migration. I ran monthly architecture reviews to address blockers.

**Result:**
18 months to complete the full migration across all 4 domains. Deployment failures from migration conflicts went to zero. Each squad could now deploy independently — deploy frequency increased from twice-weekly to on-demand.

## Reflection / What I'd Do Differently
I would have defined team-level data ownership earlier — ideally before the codebase grew to its level of entanglement. The migration took 18 months partly because of the accumulated coupling. Architectural boundaries are easiest to establish when teams are small.

## Common Follow-up Questions
- How do you decide when an architectural change is worth the disruption cost?
- What's your approach to running a migration when the existing system can't go down?
- How do you handle teams that resist an architectural change they didn't choose?
- What's your approach to backwards compatibility during a migration?
- How do you know when an architecture change is "done"?
- What would you have done if the pilot had failed to show improvement?

## Common Mistakes / Pitfalls
- **No pilot or incremental approach** — "we redesigned the whole thing" without a pilot suggests poor risk management.
- **Top-down mandate** — driving architectural change by authority without evidence is fragile and resented.
- **No data** — "it felt slower" isn't a case for a major architectural investment.
- **Missing the human element** — the migration will affect other teams' workflows; show you managed that.
- **No definition of done** — what does success look like? Migrations without exit criteria can run indefinitely.
- **Skipping the retrospective** — what would you do differently if you started again?

## References
- [Domain-Driven Design — Eric Evans](https://www.domainlanguage.com/ddd/) (book reference)
- [Strangler Fig Application — Martin Fowler](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Architecture Decision Records — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Team Topologies — Skelton & Pais](https://teamtopologies.com/) (book reference — on team cognitive load and service ownership)
- [Building Microservices — Sam Newman](https://samnewman.io/books/building_microservices/) (book reference)
