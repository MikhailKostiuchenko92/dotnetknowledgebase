# Architecture Decision Records (ADRs)

**Category:** Architecture / Clean Architecture & Layering
**Difficulty:** 🔴 Senior
**Tags:** `ADR`, `architecture-decisions`, `documentation`, `adr-tools`, `living-documentation`, `technical-debt`

## Question

> What is an Architecture Decision Record (ADR)? When should you write one, and what format do you use? How do ADRs prevent architecture knowledge from being lost as teams change?

## Short Answer

An **Architecture Decision Record** (Michael Nygard, 2011) is a short document capturing a single architectural decision: the context that made it necessary, the decision itself, the alternatives considered, and the consequences. ADRs live in the repository alongside code (`docs/adr/` or `Architecture/Decisions/`), are versioned with the codebase, and are written in the past tense once a decision is made. When a decision is superseded, you don't delete the old ADR — you mark it as "Superseded by ADR-0042" and write a new one. This builds a permanent decision log that explains *why* the system is the way it is.

## Detailed Explanation

### The Problem ADRs Solve

A new developer joins the team and asks: "Why do we use MediatR here instead of direct service calls?" The answer exists only in the head of the developer who made that decision three years ago — who has now left. Without ADRs, the team either continues following the pattern without understanding it, or reverses it and rediscovers the original problems that motivated it.

ADRs are the institutional memory of architectural decisions.

### When to Write an ADR

Write an ADR when you make a decision that:
- Is **hard to reverse** (choosing an event sourcing store, multi-tenant DB strategy, deployment topology)
- Involves **evaluated alternatives** (you considered at least two options)
- Has **non-obvious trade-offs** that future developers will need to understand
- Will **affect multiple teams** or future architecture choices
- Replaces or modifies an existing decision

Do NOT write an ADR for:
- Everyday implementation choices (which LINQ method to use)
- Style preferences handled by a linter
- Decisions that can be freely changed without downstream impact

### Standard ADR Format (Nygard Template)

```markdown
# ADR-0012: Use Vertical Slice Architecture for Feature Organization

**Date:** 2025-11-15
**Status:** Accepted
**Deciders:** [Alice, Bob, Carol]
**Technical Area:** Solution Structure

## Context

Our Clean Architecture solution with Domain/Application/Infrastructure layers made simple
feature additions require changes across 4 projects. PR reviews were difficult because the
reviewer had to navigate multiple namespaces to understand a single feature. We evaluated
three approaches:

1. Continue with horizontal layers
2. Adopt Vertical Slice Architecture (feature folders)
3. Migrate to a microservices per feature

## Decision

We adopt Vertical Slice Architecture for organizing feature code within the Application and
Infrastructure projects while keeping a shared Domain project for business entities and rules.
Each feature (e.g., `PlaceOrder`, `GetOrders`) lives in its own folder with command/handler/
validator/endpoint co-located.

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| Horizontal layers (status quo) | Familiar, enforced by project references | Cross-feature navigation is slow; PRs touch multiple projects |
| Vertical Slices | Feature cohesion, fast PR review, easy deletion | Risk of slice-to-slice coupling if undisciplined |
| Microservices per feature | Ultimate isolation | Massive operational overhead for 5 devs |

## Consequences

**Positive:**
- Feature PRs are self-contained in one folder
- Easier onboarding — "the code for X is all in Features/X/"
- Simpler deletion of deprecated features

**Negative:**
- Shared domain logic must be explicitly moved to Domain project
- Risk of duplicating query logic across slices (accepted trade-off)
- Requires discipline: handlers must not import other handlers

## Status History

- 2025-11-15: Proposed by Bob
- 2025-11-20: Accepted after team review
```

### ADR Status Lifecycle

```
Proposed → Accepted → [Deprecated | Superseded by ADR-XXXX]
                    → Rejected (with reasoning)
```

Never delete an ADR — even rejected ones capture why an option was not chosen.

### Tooling

**adr-tools** (command-line helper):
```bash
# Install: brew install adr-tools (macOS) or manual install
adr init docs/adr
adr new "Use PostgreSQL as primary database"
# Creates docs/adr/0001-use-postgresql-as-primary-database.md

adr new -s 1 "Use CockroachDB instead of PostgreSQL"
# Marks ADR-0001 as superseded and creates ADR-0002
```

**Log4brains** (web viewer for ADR browsing — verify URL for latest):
```bash
npx log4brains init
npx log4brains serve    # live viewer at localhost:4004
npx log4brains build    # static HTML for GitHub Pages
```

**Repository layout**:
```
docs/
  adr/
    0001-use-postgresql.md
    0002-adopt-clean-architecture.md
    0003-use-mediatr-for-cqrs.md
    0004-replace-rabbitmq-with-azure-service-bus.md
    README.md   ← index of all decisions
```

### ADR Index Pattern

```markdown
# Architecture Decision Records

| # | Title | Status | Date |
|---|-------|--------|------|
| [0001](./0001-use-postgresql.md) | Use PostgreSQL as primary database | Accepted | 2024-03-01 |
| [0002](./0002-adopt-clean-architecture.md) | Adopt Clean Architecture | Accepted | 2024-03-15 |
| [0003](./0003-use-mediatr.md) | Use MediatR for CQRS dispatch | Accepted | 2024-04-01 |
| [0004](./0004-replace-rabbitmq.md) | Replace RabbitMQ with Azure Service Bus | Supersedes 0001 | 2024-09-10 |
```

## Code Example

```markdown
# ADR-0007: Use Outbox Pattern for Reliable Event Publishing

**Date:** 2025-04-22
**Status:** Accepted
**Deciders:** [Engineering Lead, Backend Team]
**Technical Area:** Messaging / Data Consistency

## Context

We encountered lost domain events when the message broker was unavailable at the moment
`SaveChangesAsync` succeeded. The event was raised in memory, SaveChanges committed,
then the broker call failed — the event was lost permanently.

## Decision

Implement the Transactional Outbox pattern: domain events are written to an `OutboxMessages`
table in the same database transaction as the aggregate change. A background worker polls
the outbox and publishes to the broker with at-least-once delivery.

## Alternatives Considered

| Option | Reason not chosen |
|--------|------------------|
| Retry the broker call in the handler | Still fails if process crashes between save and publish |
| Two-phase commit (DTC) | Not available in cloud environments; performance penalty |
| Event-carried state transfer via CDC (Debezium) | Additional infra complexity, team unfamiliar |

## Consequences

- **Positive:** Guaranteed at-least-once delivery; survives process crashes and broker downtime
- **Negative:** Consumers must be idempotent; slight latency for event delivery; outbox table grows
- **Follow-up required:** Implement idempotency checks in all event consumers (ADR-0008)
```

## Common Follow-up Questions

- How do you decide which decisions are significant enough to warrant an ADR vs a code comment?
- How do you handle ADRs when the team is distributed and decisions are made asynchronously via PR reviews?
- How do you prevent ADRs from becoming stale or ignored over time?
- What is the "lightweight" ADR format (Y-Statements) and when do you use it instead of the full Nygard format?
- How do you link ADRs to the code changes they motivated?

## Common Mistakes / Pitfalls

- **Writing ADRs retroactively to justify past decisions**: ADRs are most valuable when written during the decision, with the real alternatives and trade-offs. Retroactive ADRs often omit the rejected options.
- **ADRs that describe implementation, not decisions**: "We implemented the order service using EF Core" is implementation documentation. "We chose EF Core over Dapper for the write model because…" is a decision record.
- **Deleting or editing accepted ADRs when decisions change**: supersede with a new ADR, don't edit. The history of why you changed direction is as valuable as the current decision.
- **ADRs too large**: if an ADR is more than 2 pages, it's probably covering multiple decisions. Split it.

## References

- [Architecture Decision Records — Michael Nygard (original post)](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) (verify URL)
- [adr-tools — GitHub](https://github.com/npryce/adr-tools)
- [ADR GitHub organization (templates and examples)](https://adr.github.io/) (verify URL)
- [Documenting Software Architectures — Bass, Clements, Kazman](https://www.sei.cmu.edu/our-work/publications/index.cfm) (verify URL)
- [See: fitness-functions.md](./fitness-functions.md)
