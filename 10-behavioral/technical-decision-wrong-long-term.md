# Have you ever made a technical decision that turned out to be wrong long-term? How did you address it?

**Category:** Failure & Mistakes
**Difficulty:** 🔴 Senior
**Tags:** `technical-debt`, `decision-making`, `architecture`, `accountability`, `long-term-thinking`

## Question
> Have you ever made a technical decision that turned out to be wrong long-term? How did you address it?

## Short Answer
I chose a synchronous HTTP-based integration pattern between two services that worked fine at launch but became a scalability and reliability bottleneck 18 months later as traffic grew 10x. Addressing it meant both fixing the technical problem and owning the decision transparently with the team — explaining the context that made it seem right at the time, and leading the migration to an async messaging pattern.

## What the Interviewer Is Looking For

This is a **senior-level question** requiring genuine intellectual humility and systems thinking. Interviewers want to see:

- You can acknowledge that some decisions were correct in context but aged poorly — this is different from carelessness.
- You distinguish between "I made a mistake" and "the context changed and the decision no longer fit."
- You addressed the problem proactively rather than letting it accumulate indefinitely.
- You learned something about *how* to make decisions better, not just about the specific technology.

### The Anatomy of a Well-Aged Mistake

| Phase | What to Cover |
|-------|--------------|
| Original decision | What the context was and why it seemed reasonable |
| The inflection point | What changed — traffic, team size, requirements — that made it wrong |
| Diagnosis | How you realised it was wrong and what the actual impact was |
| Response | How you addressed it, including communicating to stakeholders |
| Lesson | What you now do differently in equivalent decisions |

> **⚠ Warning:** The best answers acknowledge that the original decision was *reasonable given the information available at the time* — showing maturity and context-sensitivity rather than just saying "I was wrong."

## Example STAR Answer

**Situation:**
In 2021, I architected a product inventory service that queried the pricing service via synchronous REST calls before returning product listings. At the time, both services handled ~50 requests per second and had sub-50ms response times. The simplicity of synchronous HTTP made the code easy to understand and debug.

**Task:**
I was the tech lead and my design was accepted without significant pushback. I documented it as the intended pattern in our architecture wiki.

**What went wrong:**
By mid-2023, our platform had grown to 2,000 RPS at peak. The pricing service — used by 4 other services in addition to inventory — became a cascading failure point. During a pricing service slowdown (caused by an unrelated database query regression), all services that called it synchronously degraded together. The inventory service response time went from 80ms to 4.2 seconds. Users saw blank product pages.

**How I diagnosed it:**
A distributed tracing review during a postmortem showed that 60% of our P99 latency was attributable to the synchronous inter-service call chain, not our own service logic. The architecture I designed had created a distributed monolith — services that were physically separate but temporally coupled.

**How I addressed it:**
I owned the finding openly with the team: "I designed this pattern and it has become a bottleneck. Let me propose the migration path." I created an ADR (Architecture Decision Record) for the original decision with a `[SUPERSEDED]` header explaining what had changed and why.

We migrated the pricing dependency to an async model: the pricing service published price-change events to a message bus; inventory cached the latest prices locally and served them from the cache. This eliminated the synchronous call entirely.

**Result:**
After migration: inventory service P99 latency dropped from 800ms to 45ms. Pricing service slowdowns no longer cascaded. The team's confidence in the architecture reviews improved because I had modelled what it looks like to own and correct a past decision.

## Reflection / What I'd Do Differently
I would document the **assumptions** underlying major architecture decisions and the **conditions under which the decision should be revisited** (e.g., "if traffic exceeds X RPS or the call chain grows beyond N services, revisit this synchronous pattern"). The decision was fine — but without a tripwire to force the review, it drifted past its useful life silently.

## Common Follow-up Questions
- How do you communicate to your team that a design you championed needs to be replaced?
- How do you distinguish between a wrong decision and a decision that simply aged out?
- What's your process for revisiting architectural decisions over time?
- How do you prevent technical debt from accumulating to the point of causing production incidents?
- What role do Architecture Decision Records (ADRs) play in managing long-lived systems?
- How do you balance the cost of migrating away from a wrong decision vs. living with it?

## Common Mistakes / Pitfalls
- **Choosing a recent, obvious mistake** — the question asks about *long-term* wrongness, implying something that worked for a while and then broke down.
- **Pure self-criticism without context** — the strongest answers explain why the decision was reasonable at the time.
- **No concrete impact data** — quantify what the wrong decision cost (latency, incidents, developer hours).
- **"We just replaced it"** — show the process of recognising, acknowledging, and planning the change, not just the end state.
- **Hiding the decision from the team** — senior engineers own past decisions transparently; they don't quietly fix problems and hope no one notices.
- **No process change** — the lesson must change how you make future decisions, not just the specific technology you use.

## References
- [Architecture Decision Records — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) (verify exact URL)
- [Strangler Fig Pattern — Martin Fowler](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Distributed Tracing — OpenTelemetry](https://opentelemetry.io/docs/concepts/signals/traces/)
- [Async Messaging Patterns — Microsoft Azure Architecture](https://learn.microsoft.com/en-us/azure/architecture/guide/technology-choices/messaging)
- *A Philosophy of Software Design* — John Ousterhout (book reference — on complexity and debt)
