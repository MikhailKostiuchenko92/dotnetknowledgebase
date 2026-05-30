# What does "good engineering" mean to you?

**Category:** Motivation & Values
**Difficulty:** 🟡 Middle
**Tags:** `engineering-values`, `craftsmanship`, `quality`, `philosophy`, `professional-standards`

## Question
> What does "good engineering" mean to you?

## Short Answer
Good engineering is building software that solves the right problem reliably, in a way that the next person can understand and change safely. It's not about clever code; it's about appropriate code. It includes writing tests that catch real bugs, making systems that fail predictably, and leaving the codebase in a better state than you found it — without over-engineering for problems you don't have yet.

## What the Interviewer Is Looking For

This is a **values and philosophy question** that reveals how you think about your craft. Interviewers want to see:

- You have a coherent, reasoned view — not a list of buzzwords.
- Your definition is practical and calibrated, not idealistic.
- You balance correctness, maintainability, and pragmatism appropriately.
- Your values are consistent with how you describe your work in other answers.

> **⚠ Warning:** Two failure modes: (1) "Writing clean, elegant code" — too abstract, and "elegance" without correctness is vanity. (2) An exhaustive list of engineering principles without prioritisation — shows you've read the books but haven't synthesised them.

### Dimensions of Good Engineering (with trade-offs)

| Dimension | What It Means | What It Doesn't Mean |
|-----------|---------------|----------------------|
| Correctness | Behaves as specified in all edge cases | Perfect; flawless; zero bugs |
| Maintainability | The next person can understand, test, and change it safely | Over-abstracted; maximally generic |
| Reliability | Fails predictably; recovers gracefully | Never fails |
| Appropriate complexity | No simpler than it needs to be; no more complex | Maximally simple (sometimes simple is not enough) |
| Testability | Designed for verification; test suite that catches real bugs | 100% code coverage |
| Operational readiness | Observable, deployable, runnable in production | Perfect on developer laptop |

## Example Answer

**My definition:**

Good engineering is the practice of building systems that:

**1. Solve the right problem:**
The most common engineering failure isn't bad code — it's building the wrong thing correctly. Good engineering includes enough problem understanding to know what you're actually trying to solve.

**2. Are correct — especially in the edge cases:**
Any engineer can make the happy path work. Good engineering means the system behaves correctly when the API returns an error, when the database is unavailable, when the user input is unexpected, when two concurrent requests arrive simultaneously. Edge cases are where software fails in production.

**3. Fail predictably and visibly:**
I'd rather have a system that crashes with a clear error than one that silently produces wrong results. Observability — logs, metrics, traces — is part of the system design, not an afterthought.

**4. Can be understood and changed safely:**
Code is read far more than it's written. Good engineering names things clearly, structures code so that related concerns are together, and provides test coverage that makes changes safe. I judge my code not by whether I understand it today, but by whether someone unfamiliar with it could understand it in 6 months.

**5. Is appropriately, not maximally, complex:**
Good engineering resists the temptation to over-engineer. YAGNI ("you aren't gonna need it") is as important as clean architecture. Building for 10 million users when you have 10,000 is not good engineering; it's premature optimisation at system scale.

**Where I disagree with "good engineering = clean code":**
"Clean" code that doesn't work isn't good engineering. Tested, deployed, observable, production-hardened code that's somewhat less elegant is better than a perfect architecture that never ships.

## Reflection / What I'd Add
The discipline I've added to my own definition over time: operational readiness. Early in my career, I thought good engineering was about the code. Now I believe it extends to: can I deploy this reliably? Can I diagnose issues in production? Can I run this safely on call? Code that's brilliant to read but nightmare to operate is not finished engineering.

## Common Follow-up Questions
- What's the tension between "good engineering" and shipping fast?
- How do you know when code is good enough vs. when it needs more work?
- What's your definition of "technical debt"?
- How do you encourage good engineering practices in a team that has historically shipped quickly without them?
- What's the biggest mistake engineers make in the name of "good engineering"?
- What's something you used to think was good engineering that you no longer believe?

## Common Mistakes / Pitfalls
- **Listing principles without prioritisation** — "SOLID, DRY, KISS, YAGNI, clean code, testing pyramid, twelve-factor app" is a reading list, not a philosophy.
- **Elegance over correctness** — elegant code that fails in edge cases is not good engineering.
- **Over-engineering as craft** — adding unnecessary complexity because it's "architecturally sound" is not good engineering; it's engineering for engineers.
- **Testing as metric rather than practice** — "we have 80% coverage" is not the same as "our test suite catches real bugs."
- **Not including the operational dimension** — code that can't be deployed, monitored, or debugged in production is unfinished engineering.
- **Dogmatic application of any single principle** — every principle has a context where it doesn't apply. Good engineering requires judgment, not rulebook application.

## References
- [YAGNI — Martin Fowler](https://martinfowler.com/bliki/Yagni.html)
- [Technical Debt — Martin Fowler](https://martinfowler.com/bliki/TechnicalDebt.html)
- [The Pragmatic Programmer — Hunt & Thomas](https://pragprog.com/titles/tpp20/the-pragmatic-programmer-20th-anniversary-edition/)
- *A Philosophy of Software Design* — John Ousterhout (book reference on managing complexity)
- *The Software Craftsman* — Sandro Mancuso (book reference on craft and professionalism)
