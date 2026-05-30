# Describe how you approached a greenfield project with no existing architecture.

**Category:** Problem Solving & Technical Decisions
**Difficulty:** 🔴 Senior
**Tags:** `architecture`, `greenfield`, `design`, `adr`, `decision-making`, `system-design`

## Question
> Describe how you approached a greenfield project with no existing architecture.

## Short Answer
For a new event-driven notification platform, my approach was: understand the business problem deeply before designing anything, make architecture decisions as late as responsibly possible (to maximise information), document every architectural decision in ADRs, and start with the simplest architecture that could work — then evolve it. The system launched successfully and the initial architecture absorbed 18 months of feature growth without a rewrite.

## What the Interviewer Is Looking For

This question tests **architectural thinking** and **design process**. Interviewers want to see:

- You start from requirements and constraints, not from technology choices.
- You use a disciplined process: understand → explore options → decide → document → evolve.
- You avoid over-engineering on day one ("we might need this later").
- You involve the team in architectural decisions rather than designing in isolation.

### Greenfield Architecture Process

| Phase | Key Activities |
|-------|---------------|
| Problem understanding | Functional requirements, non-functional requirements, constraints (team, budget, timeline) |
| Context mapping | Identify domains, external integrations, data flows |
| Architecture exploration | Options for key decisions (storage, communication style, deployment model) |
| ADR writing | Document key decisions before code is written |
| Spike / prototype | Validate highest-risk architectural decisions empirically |
| Skeleton build | Walking skeleton — end-to-end thin slice, infrastructure proven |
| Evolve | Iterate behind stable interfaces |

> **⚠ Warning:** "We picked the technology stack on day one and then designed around it" is an anti-pattern. Technology should follow requirements — especially for greenfield projects where you have the most freedom.

## Example STAR Answer

**Situation:**
I was the tech lead for a new notification platform: a system to deliver email, SMS, and push notifications across multiple product teams' services. This replaced a patchwork of per-team notification implementations. Greenfield: no existing code, no existing architecture, 2-developer team plus myself.

**Task:**
Design and deliver an MVP in 3 months that could handle 50k notifications/day, extensible for future channels, observable, and not a single point of failure.

**Action:**

*Phase 1 — Requirements and constraints first (week 1):*
I ran a 2-hour requirements workshop with product and operations:
- **Functional**: multi-channel (email, SMS, push), templated messages, scheduling, delivery tracking.
- **Non-functional**: at-least-once delivery; no data loss; observable; extensible for new channels.
- **Constraints**: team of 3; no dedicated DevOps; Azure-native preferred; 3-month MVP.

*Phase 2 — Identify the key architectural decisions:*
I listed the decisions that were hard to reverse:
1. Message persistence model (DB queue vs. message broker)
2. Channel plug-in model (hardcoded vs. extensible provider interface)
3. Deployment model (monolith vs. services)
4. Retry and failure model

*Phase 3 — Document ADRs before writing code:*
For each decision, I wrote a 1-page ADR: context, options considered, decision, rationale, and trade-offs accepted. Four ADRs in total. Reviewed with the team before any code was written.

Key decision: Azure Service Bus as the message broker (rather than outbox pattern + DB). Rationale: team familiarity, built-in retry + DLQ, no infrastructure to maintain.

*Phase 4 — Walking skeleton:*
Before building anything fully, I built a walking skeleton: one notification type (email), one trigger (API call), one delivery (SendGrid). End-to-end in production (not staging) within week 2. This validated deployment, secrets management, and Service Bus setup under real conditions.

*Phase 5 — Evolve behind stable interfaces:*
All channel implementations backed by `INotificationChannel` interface. Adding SMS in week 6 was a single new implementation class — no changes to the dispatch pipeline.

**Result:**
MVP delivered in 11 weeks. Successfully onboarded 4 product teams in month 4. 18 months later: 2 new channels added (WhatsApp, in-app), no architectural rewrites.

## Reflection / What I'd Do Differently
I would run a **lightweight event storming session** in week 1 to map the notification domain with all stakeholders. My requirements workshop was largely functional; event storming would have surfaced cross-domain events and edge cases (e.g., notification deduplication) earlier.

## Common Follow-up Questions
- What is a "walking skeleton" and why is it valuable early in a project?
- How do you decide between a monolith and microservices for a new project?
- What is an Architecture Decision Record (ADR) and what should it contain?
- How do you handle architectural decisions that the team disagrees on?
- How do you design for extensibility without over-engineering?
- What's your approach when the requirements are genuinely unclear at the start?

## Common Mistakes / Pitfalls
- **Technology-first design** — choosing the tech stack before understanding requirements constrains the solution space unnecessarily.
- **Over-engineering on day one** — designing for 10 million users when you have 10,000 is wasted complexity.
- **No ADRs** — architectural decisions not written down are made again by the next developer, often reaching a different conclusion.
- **No walking skeleton** — building all components in isolation and then integrating them at the end hides integration risks until the worst possible moment.
- **Designing in isolation** — the team should own the architecture. A design handed down from the tech lead without discussion creates resentment and blind spots.
- **Ignoring the "boring" NFRs** — security, observability, and on-call runbook are often skipped in greenfield projects and become crises 6 months later.

## References
- [Architecture Decision Records — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Walking Skeleton — Alistair Cockburn](http://wiki.c2.com/?WalkingSkeleton) (verify exact URL)
- [Event Storming — Alberto Brandolini](https://www.eventstorming.com/)
- [Clean Architecture — Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Azure Service Bus — Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-messaging-overview)

[See also: Drove Significant Architectural Change](drove-significant-architectural-change.md)
