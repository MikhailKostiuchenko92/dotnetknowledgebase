# Describe how you have driven adoption of a new technology or practice in your organization.

**Category:** Adaptability & Change
**Difficulty:** 🔴 Senior
**Tags:** `change-management`, `adoption`, `influence`, `technology`, `organisational-impact`

## Question
> Describe how you have driven adoption of a new technology or practice in your organization.

## Short Answer
I drove the adoption of OpenTelemetry-based observability across 3 engineering teams. I didn't mandate it — I made the value undeniable through a pilot, documented the results, and created a migration guide that made adoption easier than the status quo. The pattern: prove value locally, lower the barrier to adoption, let pull replace push.

## What the Interviewer Is Looking For

This is a **senior-level change leadership question** about driving organisational change beyond your immediate team. Interviewers want to see:

- You understand that technology adoption is a human problem, not a technical one.
- You build evidence before asking others to change their practices.
- You reduce friction to adoption — you don't just announce the change and expect compliance.
- You measure adoption success in terms of business outcomes, not tool usage.

> **Note:** This question is similar to "convinced skeptical team" from Section 1 but focuses on **organisational scope** — multiple teams, not just your own. The distinction matters.

## Example STAR Answer

**Situation:**
Our engineering department had 4 teams, each with bespoke logging and monitoring setups. Incidents affecting multiple services required manual correlation across 4 different log formats, dashboards, and alerting systems. Mean time to investigate was 30+ minutes for cross-service issues.

**Task:**
I was the principal engineer on the platform team. No one had formally asked me to solve this — I initiated it after being the on-call engineer during two multi-service incidents in one month.

**Action:**

*Phase 1 — Pilot and prove:*
I spent 3 weeks instrumenting our platform team's own services with OpenTelemetry: traces, metrics, and structured logs exported to our existing Azure Monitor workspace. I measured: mean time to investigate dropped from 28 minutes to 6 minutes for incidents in our services.

*Phase 2 — Create the adoption path:*
I wrote a 5-page "Observability Migration Guide" for .NET services: step-by-step setup, a base `appsettings.json` configuration, and a 30-minute migration estimate for a typical service (I timed this personally).

I added an OpenTelemetry setup project template to our internal `dotnet new` template gallery.

*Phase 3 — Make the value visible:*
I gave a 20-minute "lunch & learn" demo showing the before/after: same incident type, same services, old vs. new investigation experience. I showed a trace visualization that pinpointed a database slow query in 90 seconds that had previously taken 25 minutes to diagnose.

*Phase 4 — Lower the barrier, not mandate:*
I published the migration guide on our internal portal and offered 1-hour pairing sessions for any team that wanted help migrating. I explicitly said: "This is optional. I think you'll want it once you see it."

Within 2 months, all 4 teams had opted in. No mandate. No enforcement.

**Result:**
Organisation-wide mean time to investigate cross-service incidents: 8 minutes (was 30+). One team migrated mid-incident to test the value — they were impressed enough to do the full migration the following sprint.

## Reflection / What I'd Do Differently
I would involve at least one tech lead from a non-platform team in the pilot design, so that when I presented the results, there was a peer voice saying "yes, this made a real difference" rather than just my own. Peer advocates are more persuasive than internal champions.

## Common Follow-up Questions
- What do you do when a team refuses to adopt a standard that you believe is important for the organisation?
- How do you handle a situation where two teams have adopted competing approaches?
- How do you maintain a technology standard as the tool evolves over time?
- What's the difference between a standard and an architectural mandate?
- How do you build a community of practice around a new technology?
- What's your approach when the technology you've championed turns out to have significant limitations?

## Common Mistakes / Pitfalls
- **Mandate without proof** — enforcing adoption before demonstrating value creates resentment.
- **No friction reduction** — if adopting your new approach requires more work than the status quo, adoption will stall.
- **Only measuring adoption** — count the business outcome (incident time, test coverage, deployment frequency), not just "N teams are using it."
- **Missing the peer advocate** — you can't be the only voice; find early adopters who can advocate within their own teams.
- **All-at-once adoption** — a phased, opt-in approach is more sustainable than a hard cutover deadline.
- **Ignoring the sunset path** — if you're introducing something new, what happens to the old approach? Define a sunset plan.

## References
- [OpenTelemetry for .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel)
- [Golden Paths — Spotify Engineering](https://engineering.atspotify.com/2020/08/how-we-use-golden-paths-to-solve-fragmentation-in-our-software-ecosystem/) (verify exact URL)
- [Azure Monitor — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-monitor/overview)
- [Accelerate — Forsgren, Humble, Kim](https://itrevolution.com/product/accelerate/) (book reference — observability as a DORA capability)
- *Team Topologies* — Skelton & Pais (enabling team patterns)
