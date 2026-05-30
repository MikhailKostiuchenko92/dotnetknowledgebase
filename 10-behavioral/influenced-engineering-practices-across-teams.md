# Describe how you have influenced engineering practices or standards across multiple teams.

**Category:** Leadership & Ownership
**Difficulty:** 🔴 Senior
**Tags:** `influence`, `engineering-culture`, `standards`, `cross-team`, `technical-leadership`

## Question
> Describe how you have influenced engineering practices or standards across multiple teams.

## Short Answer
I introduced an observability standard — structured logging, distributed tracing, and SLO-based alerting — that started on my team and was adopted by four others. I didn't mandate it; I documented our approach as a "golden path," offered to run sessions with other teams, and let the adoption happen through demonstrated value. The pattern that works at scale is: prove locally, document clearly, offer help, let others choose.

## What the Interviewer Is Looking For

This is a **principal engineer / tech lead level question** about technical influence at organisational scale. Interviewers want to see:

- You can influence beyond your immediate team without formal authority.
- You understand the difference between a mandate (brittle, resentful) and an earned standard (durable, adopted).
- You think at the organisational level — what are the patterns that compound across teams?
- You have a track record of other teams voluntarily adopting your practices.

### The Influence Playbook at Scale

| Step | Description |
|------|-------------|
| Prove locally | Establish the practice on your own team with measurable results |
| Document the pattern | Write a clear guide that others can follow independently |
| Make it easy to adopt | Provide templates, tooling, starter code, or pairing sessions |
| Show the results | Share metrics; let evidence spread the practice |
| Create pull, not push | Teams should *want* to adopt it, not feel obligated |

> **⚠ Warning:** "I introduced a standard and made sure everyone followed it" sounds like a mandate. "I demonstrated value and created resources that made adoption easy" sounds like a leader. The framing matters enormously.

## Example STAR Answer

**Situation:**
Our engineering department had 6 teams, each with different logging approaches: some used `Console.WriteLine`, some used `ILogger<T>` without structured properties, and some had no logging at all beyond exceptions. During incidents, correlating logs across services required an ops engineer and often took 30+ minutes just to find the relevant entries.

**Task:**
I was a senior engineer on the platform team. No one asked me to solve this organisation-wide — I identified it as a systemic gap that was slowing down incident resolution across all teams.

**Action:**

*Phase 1 — Prove on my team:*
Over two sprints, I established a structured logging standard on the platform team using `Serilog`, `ILogger<T>`, and correlation ID propagation via `IHttpContextAccessor`. I defined a small set of required log properties (`ServiceName`, `CorrelationId`, `UserId`, `RequestId`). Within a month, our mean time to investigate incidents dropped significantly.

*Phase 2 — Document:*
I wrote a single-page "Structured Logging Guide" with:
- Why structured logging matters
- 5-minute setup with our existing DI container
- Copy-pasteable base `appsettings.json` configuration
- 3 code examples (info, warning, error)
- A do/don't table for common logging anti-patterns

I posted it in the engineering Confluence space and linked it from our internal developer portal.

*Phase 3 — Create adoption tools:*
I added a `StructuredLogging` project template to our internal .NET template gallery (`dotnet new --install OurCompany.Templates`). New services got structured logging by default.

*Phase 4 — Passive spreading:*
I ran two optional "30-minute lunch sessions" on structured logging and distributed tracing. About 20 engineers attended across 4 teams. I made it clear these were informational, not mandatory.

**Result:**
Within 4 months, 4 of the 6 teams had adopted the standard. One team adopted it mid-incident response when their tech lead saw how quickly we diagnosed a P1 using correlation IDs. The other team adopted it during a new service build because the template made it the path of least resistance.

Organisation-wide mean time to investigate incidents fell from 35 minutes (informal estimate) to 8 minutes for services using the standard.

## Reflection / What I'd Do Differently
I would publish the standard with a "health check" script — a small tool that scans a service's log output and rates its observability maturity (e.g., 0–5 stars). Teams are more motivated by a concrete score they can improve than by an abstract guide they can read.

## Common Follow-up Questions
- How do you handle teams that refuse to adopt a standard that would benefit them?
- What's the difference between a standard and a best practice? When should something be mandatory vs. optional?
- How do you keep standards up-to-date as the technology landscape changes?
- Have you ever introduced a standard that turned out to be wrong or counterproductive?
- How do you coordinate a cross-team standard without a formal architecture function?
- What's your process for deprecating an old standard when a better one emerges?

## Common Mistakes / Pitfalls
- **Mandate framing** — "I made sure all teams adopted X" signals authority-based rather than influence-based leadership.
- **No proof of local value** — you must demonstrate the standard works on your own team before spreading it.
- **No documentation** — verbal evangelism doesn't scale; show you created reusable assets.
- **No measurement** — quantify what improved (incident time, onboarding time, defect rate).
- **All-or-nothing adoption** — partial adoption with 4/6 teams is a success, not a failure.
- **Ignoring friction** — show you understood and addressed why some teams hesitated.

## References
- [Structured Logging with Serilog — Serilog Docs](https://serilog.net/)
- [ILogger in .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging)
- [OpenTelemetry for .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel)
- [Golden Paths — Spotify Engineering Blog](https://engineering.atspotify.com/2020/08/how-we-use-golden-paths-to-solve-fragmentation-in-our-software-ecosystem/) (verify exact URL)
- *Team Topologies* — Skelton & Pais (book reference — enabling team patterns)
