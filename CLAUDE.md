# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## Project Overview

This is a **personal knowledge base and study resource for .NET Software Engineer interview preparation**. The repository collects, organizes, and explains the most common interview questions, practical coding tasks, system design problems, and real-world experience scenarios encountered when interviewing for .NET developer roles (Middle / Senior / Lead).

The audience is primarily the repository owner (self-study), but content should be written clearly enough to be shared with other developers preparing for similar interviews.

## Goals

- Build a structured, searchable library of interview questions with **deep, accurate explanations** — not just surface-level answers.
- Cover both **theory** (CLR, GC, async/await, memory model) and **practice** (LINQ, EF Core, ASP.NET Core, design patterns, SOLID).
- Include **coding exercises** with multiple solutions, complexity analysis, and trade-offs.
- Document **behavioral / experience-based questions** ("Tell me about a time…") with STAR-format templates and example answers.
- Track **real interview situations** the owner has encountered, with retrospective analysis.

## Repository Structure

```
.
├── CLAUDE.md                       # This file
├── README.md                       # Public-facing overview & how to navigate
├── 01-csharp-language/             # C# language features, syntax, advanced topics
│   ├── async-await.md
│   ├── delegates-events.md
│   ├── generics.md
│   ├── records-and-structs.md
│   └── ...
├── 02-dotnet-runtime/              # CLR, GC, memory, JIT, AOT
│   ├── garbage-collection.md
│   ├── memory-management.md
│   ├── threading-model.md
│   └── ...
├── 03-oop-and-design/              # OOP, SOLID, GoF patterns, DDD
│   ├── solid-principles.md
│   ├── design-patterns/
│   └── ...
├── 04-data-access/                 # EF Core, Dapper, ADO.NET, SQL
│   ├── ef-core-basics.md
│   ├── ef-core-performance.md
│   └── ...
├── 05-aspnet-core/                 # Web API, middleware, DI, auth
│   ├── middleware-pipeline.md
│   ├── dependency-injection.md
│   ├── authentication-authorization.md
│   └── ...
├── 06-architecture/                # Clean Architecture, DDD, CQRS, microservices
├── 07-testing/                     # xUnit, NUnit, Moq, integration testing
├── 08-system-design/               # High-level design problems
├── 09-algorithms-and-ds/           # Coding problems, with C# solutions
│   └── problems/
│       └── two-sum/
│           ├── README.md
│           ├── solution-v1.cs
│           └── solution-v2.cs
├── 10-behavioral/                  # STAR-format answers, soft skills
│   ├── conflict-resolution.md
│   ├── leadership.md
│   └── ...
├── 11-real-interviews/             # Anonymized retrospectives of actual interviews
│   └── 2026-05-company-x.md
└── _templates/                     # Markdown templates (see below)
    ├── question-template.md
    ├── coding-problem-template.md
    └── behavioral-template.md
```

> When asked to add new content, place it in the most appropriate top-level folder. If none fits, ask before creating a new top-level folder.

## Content Templates

All new content should follow one of the templates in `_templates/`. Use them verbatim as a starting point.

### Theory Question Template

```markdown
# <Question Title>

**Category:** <e.g., C# / Async>
**Difficulty:** Junior | Middle | Senior
**Tags:** `async`, `await`, `threading`

## Question
> The exact question as typically asked in an interview.

## Short Answer
A 2–3 sentence summary suitable for a verbal response.

## Detailed Explanation
In-depth explanation with internals, edge cases, and "why it matters."

## Code Example
```csharp
// Minimal, runnable example
```

## Common Follow-up Questions
- ...
- ...

## Common Mistakes / Pitfalls
- ...

## References
- [Microsoft Docs](https://...)
- Book/blog references
```

### Coding Problem Template

```markdown
# <Problem Name>

**Source:** LeetCode #X / Custom / Real interview
**Difficulty:** Easy | Medium | Hard
**Topics:** Arrays, HashMap, ...

## Problem Statement
...

## Examples
...

## Constraints
...

## Approach 1: <Name> — O(n²) time, O(1) space
Explanation...

## Approach 2: <Name> — O(n) time, O(n) space
Explanation...

## Final Solution
See `solution.cs`.

## Interview Tips
- What to clarify with the interviewer
- Edge cases to mention out loud
```

### Behavioral Question Template

```markdown
# <Question>

## Situation
...

## Task
...

## Action
...

## Result
...

## Reflection / What I'd Do Differently
...
```

## Writing Guidelines for Claude

When creating or editing content:

1. **Accuracy first.** This is study material — incorrect explanations are worse than no explanation. If unsure about a CLR/GC/runtime detail, say so explicitly and link to official Microsoft documentation rather than guessing.
2. **Target .NET 8 / .NET 9** unless the user specifies otherwise. Mention version-specific behavior when relevant (e.g., "introduced in C# 12", "changed in .NET 7").
3. **Always include a runnable C# code sample** for technical questions, even if small. Use modern C# syntax (top-level statements, file-scoped namespaces, primary constructors where appropriate).
4. **Explain the "why," not just the "what."** Compare alternatives and discuss trade-offs.
5. **Use Markdown consistently:**
   - H1 for the question/topic title (one per file).
   - Fenced code blocks with language tags (` ```csharp `, ` ```sql `, ` ```bash `).
   - Tables for comparisons.
   - Callouts using `>` blockquotes for warnings/tips.
6. **Cross-link** related questions using relative Markdown links: `[See: Async vs Threads](../01-csharp-language/async-await.md)`.
7. **Keep answers interview-realistic.** Provide both a "30-second elevator answer" and a "deep dive" version.
8. **No fluff.** Skip filler like "Great question!" — this is reference material.

## Code Sample Conventions

- Use `csharp` syntax highlighting.
- Prefer minimal, self-contained, copy-pasteable samples.
- For larger samples, create a separate `.cs` file in the same folder and reference it.
- Follow standard .NET naming conventions (PascalCase types/methods, camelCase locals, `_camelCase` private fields).
- Use `var` only when the type is obvious from the right-hand side.
- Include `using` directives at the top of standalone `.cs` files.

## Topics To Prioritize (Backlog)

When the user asks "what should I add next?", suggest from this priority list:

1. `async`/`await` internals, `SynchronizationContext`, `ConfigureAwait(false)`
2. Garbage Collection (generations, LOH, server vs workstation GC)
3. `IEnumerable` vs `IQueryable`, deferred execution
4. EF Core: change tracking, N+1, projections, `AsNoTracking`
5. Dependency Injection lifetimes (Singleton/Scoped/Transient) and pitfalls
6. ASP.NET Core middleware pipeline & request lifecycle
7. SOLID principles with C# examples
8. Common GoF patterns (Strategy, Factory, Decorator, Mediator)
9. Concurrency primitives: `lock`, `Monitor`, `SemaphoreSlim`, `Channel<T>`
10. Value types vs reference types, boxing, `Span<T>`, `Memory<T>`
11. Authentication & authorization (JWT, OAuth2, OpenID Connect)
12. Clean Architecture, CQRS, MediatR
13. Unit testing patterns, AAA, mocking with Moq / NSubstitute
14. System design: rate limiter, URL shortener, distributed cache, message queue
15. Behavioral: conflict, failure, leadership, mentorship, disagreement with manager

## How To Help The User

Typical requests you should expect:

- **"Add a question about X"** → Create a new `.md` file in the correct folder using the theory-question template.
- **"Solve this coding problem"** → Create a folder under `09-algorithms-and-ds/problems/` with README + solution files, multiple approaches, complexity analysis.
- **"Review my answer to X"** → Critique constructively, point out missing depth, suggest follow-ups an interviewer might ask.
- **"Generate practice questions for topic Y"** → Produce 5–10 questions of mixed difficulty with brief answer outlines.
- **"Help me write up this interview I just had"** → Use the `11-real-interviews/` folder, anonymize company names if asked, structure as: questions asked → my answer → better answer → lessons learned.

## Things NOT To Do

- ❌ Do not invent Microsoft documentation links — only link to URLs you are confident exist.
- ❌ Do not give shallow one-liner answers to senior-level questions.
- ❌ Do not duplicate existing content — search the repo first and link/extend instead.
- ❌ Do not include personal identifying information (real company names, colleagues' names) in `11-real-interviews/` unless explicitly told to.
- ❌ Do not use deprecated APIs (`BinaryFormatter`, `WebClient`, etc.) without flagging them as deprecated.

## Commit Message Convention

Use Conventional Commits:

- `feat(csharp): add question on ConfigureAwait`
- `feat(algo): add two-sum problem with 3 approaches`
- `docs(readme): update topic index`
- `fix(ef-core): correct explanation of change tracker`
- `refactor(structure): reorganize design patterns folder`

## Quick Commands / Workflows

When the user says:

- **"new question <topic>"** → Scaffold a new file from `_templates/question-template.md` in the right folder, fill in title + tags, leave sections as TODO.
- **"new problem <name>"** → Scaffold a folder under `09-algorithms-and-ds/problems/<kebab-name>/` with README + empty `solution.cs`.
- **"index"** → Regenerate the topic index in `README.md` based on current folder contents.