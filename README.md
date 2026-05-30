# .NET Software Engineer — Interview Preparation

> A personal, structured knowledge base for preparing for **.NET Software Engineer** interviews (Middle / Senior / Lead).
> Covers C#, .NET runtime internals, ASP.NET Core, EF Core, architecture, system design, algorithms, and behavioral questions — with deep explanations, code samples, and real interview retrospectives.

---

## 📌 About

This repository is my personal study hub for .NET interviews. Each topic is documented as a standalone Markdown file containing:

- The **question** as typically asked.
- A **short answer** suitable for a verbal response (~30 seconds).
- A **deep-dive explanation** with internals and trade-offs.
- **Code examples** in modern C# (.NET 8 / .NET 9).
- **Common follow-up questions** and **pitfalls**.
- **References** to official documentation.

Content is generated and maintained with the help of [Claude Code](https://claude.ai/code) — see [`CLAUDE.md`](./CLAUDE.md) for the conventions and templates used.

---

## 🗂️ Table of Contents

| # | Section | Description |
|---|---------|-------------|
| 01 | [C# Language](./01-csharp-language/) | Language features: async/await, generics, delegates, records, LINQ, pattern matching |
| 02 | [.NET Runtime](./02-dotnet-runtime/) | CLR, Garbage Collection, memory model, JIT/AOT, threading |
| 03 | [OOP & Design](./03-oop-and-design/) | OOP principles, SOLID, GoF design patterns, DDD basics |
| 04 | [Data Access](./04-data-access/) | EF Core, Dapper, ADO.NET, SQL, transactions, performance |
| 05 | [ASP.NET Core](./05-aspnet-core/) | Web API, middleware, DI, authentication, minimal APIs |
| 06 | [Architecture](./06-architecture/) | Clean Architecture, CQRS, Mediator, microservices, messaging |
| 07 | [Testing](./07-testing/) | xUnit, NUnit, Moq, NSubstitute, integration & E2E testing |
| 08 | [System Design](./08-system-design/) | High-level design problems (rate limiter, URL shortener, cache, queue) |
| 09 | [Algorithms & Data Structures](./09-algorithms-and-ds/) | Coding problems with multiple C# solutions and complexity analysis |
| 10 | [Behavioral](./10-behavioral/) | STAR-format answers for soft-skill and experience questions |
| 11 | [Real Interviews](./11-real-interviews/) | Anonymized retrospectives of actual interviews |

---

## 🎯 How To Use This Repo

### As a study guide
1. Pick a section from the table above.
2. Read questions in order — each folder lists them from foundational to advanced.
3. Try to answer **before** reading the explanation. Compare your answer to the "Short Answer" and then the "Detailed Explanation."

### As a quick refresher (day before an interview)
- Skim the **Short Answer** sections only.
- Review the [Behavioral](./10-behavioral/) folder for STAR-format stories.
- Review the most recent entries in [Real Interviews](./11-real-interviews/).

### As a coding practice tool
- Go to [`09-algorithms-and-ds/problems/`](./09-algorithms-and-ds/problems/).
- Read the problem, attempt a solution, then compare with the provided approaches.

---

## 📝 Content Templates

Reusable templates live in [`_templates/`](./_templates/):

- [`question-template.md`](./_templates/question-template.md) — theory / conceptual questions
- [`coding-problem-template.md`](./_templates/coding-problem-template.md) — algorithm & coding problems
- [`behavioral-template.md`](./_templates/behavioral-template.md) — STAR-format behavioral answers

When adding new content, copy the appropriate template and fill it in.

---

## 🚀 Priority Topics

If you're short on time, focus on these high-frequency interview topics first:

1. `async` / `await` internals, `ConfigureAwait`, `SynchronizationContext`
2. Garbage Collection (generations, LOH, server vs workstation GC)
3. `IEnumerable` vs `IQueryable` and deferred execution
4. EF Core: change tracking, N+1, projections, `AsNoTracking`
5. Dependency Injection lifetimes (Singleton / Scoped / Transient)
6. ASP.NET Core middleware pipeline & request lifecycle
7. SOLID principles with real C# examples
8. Common GoF patterns (Strategy, Factory, Decorator, Mediator)
9. Concurrency primitives (`lock`, `SemaphoreSlim`, `Channel<T>`)
10. Value vs reference types, boxing, `Span<T>`, `Memory<T>`

See [`CLAUDE.md`](./CLAUDE.md#topics-to-prioritize-backlog) for the full priority backlog.

---

## 🎚️ Difficulty Legend

Questions are tagged with one of:

| Badge | Level | Typical role |
|-------|-------|--------------|
| 🟢 **Junior** | Foundational knowledge | Junior / Trainee |
| 🟡 **Middle** | Solid practical experience | Middle |
| 🔴 **Senior** | Deep internals & architectural reasoning | Senior / Lead |

---

## 🛠️ Tech Stack Covered

- **Language:** C# 12 / C# 13
- **Runtime:** .NET 8 (LTS), .NET 9
- **Web:** ASP.NET Core, Minimal APIs, gRPC, SignalR
- **Data:** EF Core 8/9, Dapper, SQL Server, PostgreSQL
- **Testing:** xUnit, NUnit, Moq, NSubstitute, FluentAssertions, Testcontainers
- **Architecture:** Clean Architecture, DDD, CQRS, MediatR, Microservices
- **Messaging:** RabbitMQ, Kafka, Azure Service Bus, MassTransit
- **Cloud / DevOps:** Docker, Kubernetes, Azure, CI/CD

---

## 🤝 Contributing (to myself)

When adding new content:

1. Use the correct template from [`_templates/`](./_templates/).
2. Place the file in the most appropriate top-level folder.
3. Follow the [writing guidelines in `CLAUDE.md`](./CLAUDE.md#writing-guidelines-for-claude).
4. Use [Conventional Commits](./CLAUDE.md#commit-message-convention) for commit messages.
5. Update this README's table of contents if you add a new top-level section.

---

## 📚 Recommended External Resources

### Books
- *CLR via C#* — Jeffrey Richter
- *Pro C# 10 with .NET 6* — Andrew Troelsen
- *Concurrency in C# Cookbook* — Stephen Cleary
- *Dependency Injection Principles, Practices, and Patterns* — Mark Seemann
- *Clean Architecture* — Robert C. Martin
- *Designing Data-Intensive Applications* — Martin Kleppmann
- *Cracking the Coding Interview* — Gayle Laakmann McDowell

### Online
- [Microsoft Learn — .NET](https://learn.microsoft.com/dotnet/)
- [Stephen Cleary's blog](https://blog.stephencleary.com/) — async/await deep dives
- [Andrew Lock's blog](https://andrewlock.net/) — ASP.NET Core internals
- [.NET Source Browser](https://source.dot.net/)
- [LeetCode](https://leetcode.com/) — coding practice (C# supported)

---

## 📄 License

This is a personal study repository. Content is for **personal use and learning**. If you find it useful, feel free to fork and adapt for your own preparation.

---

_Last updated: 2026-05-30_