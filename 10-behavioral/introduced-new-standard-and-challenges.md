# Describe a time you introduced a new standard and the challenges you faced in adoption.

**Category:** Process Improvement & Engineering Culture
**Difficulty:** 🔴 Senior
**Tags:** `standards`, `adoption`, `engineering-culture`, `architecture`, `change-management`

## Question
> Describe a time you introduced a new standard (coding style, architecture pattern, etc.) and the challenges you faced in adoption.

## Short Answer
I introduced structured logging as a team standard to replace 4 years of mixed `Console.WriteLine` and `Debug.Write` patterns. The technical change was straightforward; the adoption challenge was cultural — engineers felt their existing approach "worked fine" and saw the new standard as overhead. I made adoption frictionless (a base logger setup auto-configured in the project template), demonstrated the operational value quickly (within 2 weeks we used structured logs to diagnose an incident in 10 minutes that would have taken hours before), and made it the path of least resistance.

## What the Interviewer Is Looking For

Standards adoption is a **leadership and influence** challenge. Interviewers want to see:

- You understand that the technical definition of a standard is the easy part; adoption is the hard part.
- You use demonstration, friction reduction, and peer advocacy — not mandates — to drive adoption.
- You can acknowledge and address legitimate resistance without capitulating to irrational resistance.
- You know how to distinguish between "we don't want to change" and "this standard isn't right for us."

> **⚠ Insight:** The most common reason a good standard fails is that it requires more effort than the status quo. Lower the barrier to adoption so the new way is easier than the old way. This is a golden rule for technical standards.

### Standard Adoption Strategy

| Phase | Action |
|-------|--------|
| Define | Write the standard clearly with rationale; include examples |
| Reduce friction | Build templates, snippets, project scaffolding that make the new way the default |
| Demonstrate value | Find (or create) a situation where the standard proves its value visibly |
| Peer advocates | Identify early adopters from each team who can champion within their context |
| Review integration | Integrate the standard into code review expectations so it's reinforced consistently |
| Grandfather clause | Give teams time to migrate; don't require immediate legacy remediation |

## Example STAR Answer

**Situation:**
Our .NET backend services had inconsistent logging: raw string messages at various log levels, no structured properties, no correlation IDs. Production investigations required manual text parsing of log files. The approach had evolved organically over 4 years across 3 teams.

**Task:**
Introduce a structured logging standard using Serilog with JSON output and standard properties (correlation ID, service name, environment, request ID) across all 3 teams, approximately 12 engineers.

**Action:**

*Challenge 1 — "Our approach works fine":*
The biggest resistance was passive: "we've been logging for 4 years without problems." I needed to demonstrate the cost of the status quo, not just the benefit of the new standard.

I found a recent incident where investigation had taken 4 hours because we couldn't correlate logs across services. I showed: with structured logging and a correlation ID, the same investigation is a single Kusto query. I estimated 3–4 hours saved per incident; we had approximately 2 incidents/month at this severity.

*Challenge 2 — Friction of adoption:*
The biggest practical barrier to adoption is always "this takes time I don't have." I made the new standard the path of least resistance:
- Added a Serilog setup package (our own NuGet package) that configured all standard properties from 3 lines of `Program.cs`.
- Added a `dotnet new` project template with Serilog pre-configured.
- Wrote a 1-page migration guide for existing services: "Replace your current logging setup in approximately 30 minutes."

*Challenge 3 — Inconsistent review enforcement:*
After 2 weeks, some teams were still using `Console.WriteLine`. I added structured logging compliance to our code review checklist — not as a mandatory block, but as a flagged item for PRs in new services.

*Phase 4 — Early win demonstration:*
3 weeks after the first team adopted, we had an incident. Using structured logs + correlation ID, we diagnosed root cause in 8 minutes. I shared this in the team Slack with the exact query that found it. This was the tipping point — the other two teams adopted within the next sprint.

**Result:**
All 12 engineers using structured logging within 6 weeks. Incident investigation time (cross-service, P2+): average 4 hours → average 45 minutes over the following quarter.

## Reflection / What I'd Do Differently
I would involve one engineer from each of the 3 teams in the standard definition before publishing it. Even small input ("can we also include the tenant ID in the standard properties?") creates ownership. My top-down definition, even though technically good, required extra effort to build trust.

## Common Follow-up Questions
- How do you enforce a standard without becoming the "standards police"?
- How do you sunset an old standard while a new one is being adopted?
- What do you do when a team argues the standard doesn't fit their context?
- How do you balance team autonomy with organisation-wide consistency?
- How do you write a standard that's prescriptive enough to be useful but flexible enough to adapt?
- How do you keep standards up-to-date as technology evolves?

## Common Mistakes / Pitfalls
- **No rationale** — "use X because it's a standard" without "and here's why" invites passive non-compliance.
- **Mandate without enablement** — requiring the standard but not providing templates/tooling makes it harder than the status quo.
- **Immediate legacy remediation requirement** — requiring all old code to be migrated immediately is overwhelming; grandfather existing code and apply the standard to new code.
- **No champion network** — you alone can't enforce a standard across 3 teams. Identify peer advocates.
- **Perfect adoption immediately** — standards take time to propagate. Define "done" as 100% of new code, not 100% of all code.
- **Over-specific standards** — a standard that specifies every implementation detail reduces developer agency and will be resisted. Standards should specify the "what" (use structured logging) not every "how" (Serilog vs. NLog is a local choice).

## References
- [Serilog Documentation](https://serilog.net/)
- [Structured Logging in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/logging/)
- [OpenTelemetry Logging for .NET — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel)
- [Golden Path — Spotify Engineering](https://engineering.atspotify.com/2020/08/how-we-use-golden-paths-to-solve-fragmentation-in-our-software-ecosystem/) (verify exact URL)
- *Team Topologies* — Skelton & Pais (enabling team patterns for standards propagation)
