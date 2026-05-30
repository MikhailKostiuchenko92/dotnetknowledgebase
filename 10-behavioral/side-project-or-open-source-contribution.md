# Tell me about a side project or open-source contribution and what you learned from it.

**Category:** Career Growth & Self-Development
**Difficulty:** 🟢 Junior/Middle
**Tags:** `side-projects`, `open-source`, `learning`, `personal-development`, `community`

## Question
> Tell me about a side project or open-source contribution and what you learned from it.

## Short Answer
I built a CLI tool in .NET that generates Architecture Decision Record (ADR) files from templates. What I thought would be a 2-day project became a 3-week learning exercise in .NET CLI development, `System.CommandLine`, NuGet packaging, and what it's actually like to be an API designer rather than an API consumer. The main lesson: designing for unknown users is much harder than writing code for a known team.

## What the Interviewer Is Looking For

This question tests your **intrinsic motivation, curiosity, and initiative** outside of work obligations. Interviewers want to see:

- You build and explore for the joy of learning, not just for career advancement.
- You can reflect on what a project taught you — including failures.
- You understand the difference between "I wrote code" and "I learned something."
- You're engaged with the wider engineering community.

> **⚠ Note:** "I don't have a side project" is a valid answer for many people — work-life balance is important and not everyone has time. If you don't have a side project, substitute with: "The most interesting thing I've built outside of my primary work responsibilities" (internal tool, hackathon, personal automation) or discuss open-source contributions in your team.

## Example STAR Answer

**The project:**
I built `adrtool` — a .NET Global Tool for initialising and managing Architecture Decision Records in a repository. The idea came from my work frustration: every project, I had to manually copy ADR templates and number files manually.

**What I thought I'd learn:**
File I/O, template rendering. Basic CLI work.

**What I actually learned:**

*1. API design is harder than API implementation:*
When building a CLI that others might use, every design decision is a trade-off: `adrtool add "Use Redis for caching"` vs. `adrtool new --title "Use Redis for caching"`. I read the outputs from 6 similar CLI tools, studied the `git` and `dotnet` CLI conventions, and made deliberate, documented choices. This exercise made me think about API design from the user's perspective in a way I never had as a library consumer.

*2. `System.CommandLine` (preview) at the time had significant breaking changes between versions:*
I learned to pin experimental APIs aggressively in a project's `global.json` and `.csproj`, and documented the version constraint in my README. The cost of not doing this is discovering 3 months later that your project no longer builds.

*3. NuGet packaging is underappreciated:*
Getting a `dotnet tool install -g adrtool` experience right required understanding `PackAsTool`, package metadata, versioning strategy, and what an upgrade experience looks like. I had never packaged a NuGet package before; I now understand why thoughtful library authors spend so much time on the packaging and versioning experience.

*4. Writing for unknown users vs. known teammates:*
Error messages for a teammate can be terse: they'll ask you what it means. Error messages for strangers must be complete and actionable. Rewriting my error handling with this principle changed how I think about diagnostics in all my code.

**Result:**
The tool has ~40 GitHub stars and is used in 3 other projects (from the GitHub dependency graph). Small scale, but real users. I maintain it at ~2 hours/month.

## Reflection / What I'd Do Differently
I would write the README and usage documentation before writing any code. I eventually did this as part of a "README-driven development" experiment and it completely changed the design of the CLI's commands. Designing from the user's perspective up-front produces better interfaces than designing implementation-first.

## Common Follow-up Questions
- What would you build next if you had unlimited time?
- Have you ever contributed to an open-source project you use professionally?
- How do you decide whether to build something vs. finding an existing tool?
- How do you manage side projects alongside full-time work without burning out?
- What's the most important thing you've learned from open source that has changed your professional work?
- Do you read open-source code as a learning practice? What have you learned from it?

## Common Mistakes / Pitfalls
- **"I've never had time for side projects"** — this is fine, but follow up with how you learn and grow outside of your day-to-day responsibilities.
- **Listing a project without a lesson** — "I built a to-do app" is not a learning story unless you can articulate what it taught you.
- **Projects too trivial** — "I automated my Spotify playlists" is a pleasant project but doesn't say much about engineering depth.
- **Projects too ambitious / unfinished** — "I'm building a distributed database" that never shipped says less than a small, completed project.
- **Not discussing what went wrong** — the learning in side projects is usually from the unexpected difficulties, not the parts that went as planned.
- **No open-source engagement** — if you use open-source daily, it's reasonable for an interviewer to ask if you've contributed (issue reports, docs, PRs). "Never thought to" is a missed opportunity.

## References
- [System.CommandLine — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/commandline/)
- [NuGet Packaging — .NET Global Tools](https://learn.microsoft.com/en-us/dotnet/core/tools/global-tools-how-to-create)
- [Architecture Decision Records — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [README-Driven Development — Tom Preston-Werner](https://tom.preston-werner.com/2010/08/23/readme-driven-development.html)
- [Open Source Etiquette — GitHub Guides](https://docs.github.com/en/get-started/exploring-projects-on-github/contributing-to-a-project)
