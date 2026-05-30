# Describe a time when you and another engineer had completely different architectural approaches. How did you align?

**Category:** Conflict & Disagreement
**Difficulty:** 🔴 Senior
**Tags:** `architecture`, `alignment`, `technical-leadership`, `trade-offs`, `decision-making`

## Question
> Describe a time when you and another engineer had completely different architectural approaches. How did you align?

## Short Answer
We each wrote up our proposals — assumptions, trade-offs, failure modes — and ran a structured architectural review with a small group. I steered the discussion toward the concrete constraints we agreed on (latency budget, team expertise, deployment model), and we converged on a hybrid approach that took the best elements from both designs. The key was shifting from "whose design wins" to "what constraints must the design satisfy."

## What the Interviewer Is Looking For

This is a senior question probing **systems thinking**, **technical leadership**, and **collaborative design skills**. Interviewers want to see:

- You can articulate your own architectural position clearly with trade-off reasoning.
- You engage with the *other* engineer's reasoning, not just dismiss it.
- You have a structured process for resolving architectural disagreements (not just "we argued until one person gave up").
- You distinguish between **reversible decisions** (easy to try both; pick later) and **irreversible ones** (high cost to change; need consensus now).

### Dimensions Being Assessed

| Dimension | What a Strong Answer Shows |
|-----------|---------------------------|
| Systems thinking | You reasoned about constraints, not just preferences |
| Facilitation | You guided the conversation toward resolution |
| Pragmatism | You were willing to abandon parts of your design if the other was better |
| Documentation | You left behind an ADR or written rationale for future team members |

> **⚠ Warning:** If your story ends with "we agreed to go with my approach," make sure you explain *why* — via evidence, not authority.

## Example STAR Answer

**Situation:**
We were designing the backend for a new notification service. I proposed an event-sourced design using Azure Event Hubs with a consumer per notification channel (email, push, SMS). A senior engineer on the team proposed a simpler synchronous design: a single `NotificationService` class with direct HTTP calls to third-party providers, justified by the team's limited familiarity with event-sourcing.

**Task:**
Both approaches had real merit. The project timeline was tight, the team was mid-size, and we couldn't afford months of architectural debate. I was the tech lead and needed to drive us to a decision while preserving the quality of both engineers' contributions.

**Action:**
I proposed we each write a one-page Architecture Decision Record (ADR) covering: the core design, assumptions, expected failure modes, operational complexity, and estimated time-to-implement. We shared them asynchronously so everyone could read in full without interruption.

Then I facilitated a 90-minute review session. I started by listing the non-negotiable constraints everyone agreed on: <100ms p99 latency for push notifications, at-least-once delivery guarantees, and the team needed to operate this without an SRE team.

Mapping both designs to these constraints revealed: my event-sourced approach gave better decoupling and resiliency but added significant operational complexity (consumer lag monitoring, dead-letter handling). My colleague's synchronous design was operationally simpler but introduced tight coupling and would struggle under burst load.

The resolution: we adopted the synchronous design for v1, with explicit interfaces (`INotificationChannel`) enabling a future event-driven replacement, and added an in-memory retry queue as a lightweight delivery guarantee. We documented this trade-off in the ADR with a "revisit at 10K daily notifications" trigger.

**Result:**
We shipped v1 three weeks later. Eighteen months on, notification volume tripled and we partially migrated push notifications to an event-driven model exactly as the ADR described, with minimal refactoring needed because of the interface boundary.

## Reflection / What I'd Do Differently
I would involve the whole team in defining the constraints *before* either engineer started designing. Having shared constraints upfront would have shortened the design phase significantly and built broader ownership of the final decision.

## Common Follow-up Questions
- How do you know when an architectural disagreement has gone on too long and needs a tie-breaker decision?
- What tools or processes do you use to document architectural decisions?
- How do you handle it when the "wrong" architecture was already chosen and you're asked to build on it?
- What's your opinion on Architecture Decision Records (ADRs)?
- How do you handle architectural disagreements when one person significantly outranks the other?
- When is it OK to go with "good enough" architecture vs. investing in the "right" architecture?

## Common Mistakes / Pitfalls
- **No structured process** — "we debated for a while and reached consensus" is not a process. Describe the mechanism.
- **Winner takes all** — the best resolutions are often hybrids; show that you synthesised both approaches.
- **Ignoring context** — team size, timeline, operational maturity, and reversibility constraints must drive the decision.
- **Assuming your approach was correct** — the strongest answers acknowledge what was genuinely good in the other engineer's proposal.
- **No documentation trail** — senior engineers leave ADRs; show you think about the team members who weren't in the room.
- **Technical jargon without depth** — if you mention CQRS or event sourcing, be ready to explain the trade-offs in detail.

## References
- [Architecture Decision Records (ADRs) — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) (verify exact URL)
- [Designing Data-Intensive Applications — Martin Kleppmann](https://dataintensive.net/) (book reference)
- [.NET Application Architecture Guide — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/architecture/)
- [System Design Interview Patterns — ByteByteGo](https://bytebytego.com/) (verify exact URL)
- *A Philosophy of Software Design* — John Ousterhout (book reference)
