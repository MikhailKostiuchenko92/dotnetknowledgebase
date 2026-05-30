# Describe how you stay current with .NET and the wider engineering landscape.

**Category:** Career Growth & Self-Development
**Difficulty:** 🔴 Senior
**Tags:** `learning`, `dotnet`, `engineering-landscape`, `self-development`, `continuous-learning`

## Question
> Describe how you stay current with .NET and the wider engineering landscape.

## Short Answer
I have a systematic approach: I track 10–15 high-quality sources across different channels (official .NET release notes, 3–4 trusted .NET bloggers, 2 engineering podcasts, and conference talks), dedicate 2–3 hours per week to deliberate learning, and convert learning into something durable — a note, a code experiment, a team lunch-and-learn. The goal is understanding, not just exposure.

## What the Interviewer Is Looking For

Interviewers want to see that you're a **self-directed, continuous learner** who has a sustainable system — not someone who passively absorbs social media or claims to "just follow updates." For .NET engineers specifically:

- You know the release cycle of .NET and C# and can speak to recent additions.
- You have strong, specific sources — not just "I read Hacker News."
- You filter signal from noise — you're selective, not just consuming everything.
- You apply what you learn — learning that doesn't change your practice is entertainment.

> **Tip:** The interviewer may follow up with "what's new in .NET 9?" or "what C# 13 feature are you excited about?" — be ready to speak substantively.

### High-Quality .NET Learning Sources

| Type | Source | What It Covers |
|------|--------|---------------|
| Official | [.NET Blog](https://devblogs.microsoft.com/dotnet/) | Release notes, performance improvements, new APIs |
| Official | [C# Language Design GitHub](https://github.com/dotnet/csharplang) | Upcoming language features, design rationale |
| Blog | [Andrew Lock — andrewlock.net](https://andrewlock.net/) | ASP.NET Core, middleware, DI, observability |
| Blog | [Stephen Cleary — blog.stephencleary.com](https://blog.stephencleary.com/) | Async/await, threading, concurrency |
| Blog | [Nick Chapsas — YouTube](https://www.youtube.com/@nickchapsas) | Practical .NET, performance, modern APIs |
| Blog | [Scott Hanselman](https://www.hanselman.com/blog/) | .NET ecosystem, tooling |
| Conference | .NET Conf (annual) | All major .NET announcements |
| Conference | NDC Conference talks | Architecture, DDD, distributed systems |
| Podcast | .NET Rocks | .NET ecosystem, community |
| Source | [dotnet/runtime GitHub](https://github.com/dotnet/runtime) | Internals, performance PRs |

## Example STAR Answer

**My system (how I actually do this):**

*Weekly routine:*
I maintain an RSS feed with the .NET Blog, Andrew Lock, Stephen Cleary, and Nick Chapsas. I read it on Monday morning for 30 minutes. I take 1–2 notes in my personal Obsidian vault per week.

*Monthly:*
I run the latest .NET preview (if in preview) against a personal project to experience new APIs firsthand. This gives me hands-on intuition that reading doesn't.

I listen to .NET Rocks while commuting — 1–2 episodes per week. I use this for landscape awareness, not deep technical learning.

*Annually:*
I watch .NET Conf in full every November. This is where Microsoft announces the year's .NET release; I take structured notes and triage which features I want to experiment with.

I attend 1–2 conference talks or NDC sessions per year (in person or video).

*Signal filtering:*
My rule: if I read a blog post and don't end up writing a note or running code, I probably didn't need to read it. I optimise for fewer, deeper engagements over high-volume consumption.

*Converting learning to practice:*
Every 4–6 weeks, I bring something I've learned to the team. This forces me to synthesise, not just read. The preparation for a 15-minute lunch-and-learn consolidates learning more effectively than any amount of reading.

*Current watch list (.NET 9 / C# 13):*
- `params` collections — can now use `IEnumerable<T>` not just arrays
- `Lock` type — dedicated low-overhead lock primitive
- Performance improvements in the JIT and GC (Gen2 compaction improvements)
- `System.Text.Json` incremental source generation improvements
- Blazor 9 hybrid and server improvements

**Result of the system:**
I'm rarely caught off-guard in architecture discussions about .NET features. When a colleague asks "has anyone looked at the new X in .NET 9?", I usually have a prepared view — not because I'm exceptional, but because I have a system.

## Reflection / What I'd Do Differently
I would have started reading the dotnet/runtime GitHub PRs earlier in my career. Performance improvements in the .NET runtime are documented in extraordinary detail in the GitHub PR discussions — this is where the deep understanding of GC, JIT, and memory management lives, and it's public.

## Common Follow-up Questions
- What's a recent .NET or C# feature that you've been using and found valuable?
- How do you evaluate whether a new library or pattern is worth adopting for production use?
- How do you avoid "chasing shiny things" — learning things that are interesting but not useful?
- How do you stay current in domains outside .NET (distributed systems, cloud, security)?
- Do you contribute to open source? Why or why not?
- What's your view on the current direction of the .NET ecosystem?

## Common Mistakes / Pitfalls
- **"I just follow Twitter/X/LinkedIn"** — social media algorithms are not a learning system.
- **High volume, low depth** — reading 20 blog posts a week without retaining anything is not learning.
- **Only following .NET** — senior engineers also need awareness of the broader software engineering landscape (distributed systems, security, testing, architecture).
- **No application** — knowledge not applied is forgotten within weeks.
- **Not knowing your sources** — vague answers ("I just keep up with things") signal lack of intentionality.
- **Outdated knowledge** — claiming to "stay current" but not knowing about .NET 8/9 features or C# 12/13 additions is immediately apparent in technical interviews.

## References
- [.NET Blog — Microsoft DevBlogs](https://devblogs.microsoft.com/dotnet/)
- [C# Language Design — GitHub](https://github.com/dotnet/csharplang)
- [Andrew Lock's Blog](https://andrewlock.net/)
- [Stephen Cleary's Blog](https://blog.stephencleary.com/)
- [.NET Conf — Annual Conference](https://www.dotnetconf.net/)
