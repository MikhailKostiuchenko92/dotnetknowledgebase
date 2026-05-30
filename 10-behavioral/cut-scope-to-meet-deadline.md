# Describe a time you had to cut scope to meet a deadline. How did you decide what to cut?

**Category:** Dealing with Pressure & Tight Deadlines
**Difficulty:** 🟡 Middle
**Tags:** `scope`, `prioritisation`, `mvp`, `delivery`, `trade-offs`

## Question
> Describe a time you had to cut scope to meet a deadline. How did you decide what to cut?

## Short Answer
We had to cut scope on a reporting module to hit a client contract deadline. I applied a simple filter: "what does the client need to do their job on day 1?" — that became the MVP. Everything else was moved to a backlog with committed follow-up dates. The key is making cuts with the PM's explicit buy-in and ensuring stakeholders understand what's in and out before launch.

## What the Interviewer Is Looking For

This question tests your **scope judgment**, **stakeholder communication**, and ability to **make decisive trade-offs under constraints**. Interviewers want to see:

- You have a principled method for deciding what to cut (not just "whatever seemed less important").
- You involved the right people (PM, stakeholders) in the scope decision.
- You documented what was cut and committed to a delivery date.
- You didn't silently cut scope and hope no one noticed.

### Scope Cutting Decision Framework

Ask these questions in order:

```
1. What does the user NEED to achieve their core workflow? → Must ship
2. What makes the experience better but isn't needed day 1? → Cut to follow-up
3. What do we want eventually but isn't urgent for anyone? → Backlog
4. What was built speculatively without user validation? → Potentially remove
```

> **⚠ Warning:** Never cut tests, security, or data integrity to meet a deadline. These protect correctness, not features.

## Example STAR Answer

**Situation:**
We were building a reporting module for a B2B client that had a contractual go-live date. With 5 days left, it became clear we would finish only 3 of the 5 planned report types. The client contract required "a reporting module" but didn't specify which reports.

**Task:**
I needed to decide which 3 reports to deliver and communicate the scope change clearly to the PM and client — without making them feel short-changed.

**Action:**

*Step 1 — Understand what matters:*
I asked the PM: "Which of the 5 reports does this client use in their daily workflow?" They checked with the client account manager. The answer: revenue summary and user activity reports were used daily; the other 3 were used "occasionally" or "not yet deployed."

*Step 2 — Define the MVP:*
Revenue summary + user activity = the 2 daily-use reports → must ship. The most technically complex of the remaining 3 (cohort analysis) → cut. The other two (export to CSV, drill-down filter) → cut.

*Step 3 — Transparent communication:*
I prepared a one-page scope change notice: what ships on day 1, what ships in sprint+2 (committed), what ships in Q3 (planned). I shared it with the PM before sending it to the client.

The PM shared it with the client account manager with a framing: "We're prioritising the reports you use daily to ensure they're solid; the advanced analytics follow in week 3."

*Step 4 — Track the cuts:*
All three cut reports became sprint tickets with sprint+2 assignment. I added a personal reminder to check their status in week 2.

**Result:**
Go-live on the contract date. Client received the two daily-use reports polished and performant. The remaining three shipped 2 weeks later. The client's account manager cited the transparent communication as a positive in their quarterly review.

## Reflection / What I'd Do Differently
I would build a "day 1 user journey" document as part of every feature specification — a list of the exact tasks the user must be able to complete on the first day of use. This makes scope decisions much faster because the MVP is already defined, not something we figure out under deadline pressure.

## Common Follow-up Questions
- How do you decide what's an acceptable MVP vs. what's too minimal to be useful?
- What do you do when a stakeholder refuses to accept any scope cuts?
- How do you ensure cut scope actually gets delivered in the follow-up sprint?
- Have you ever cut scope that turned out to be more important than you thought?
- What's the difference between cutting scope and reducing quality?
- How do you handle the team's morale when they've worked hard on something that gets cut?

## Common Mistakes / Pitfalls
- **Cutting without a principle** — "I removed the less important stuff" is vague. Show the specific filter you applied.
- **No stakeholder sign-off** — unilateral scope cuts that surprise the client are worse than negotiated ones.
- **Cutting silently** — stakeholders should know exactly what isn't shipping and when they'll get it.
- **No follow-through commitment** — cut scope that never makes it back to the backlog becomes permanent loss.
- **Cutting tests or correctness** — these are not features; cutting them creates technical debt that compounds.
- **Only cutting from your own work** — if the scope cut requires another team member to deprioritise their work, they need to be part of the conversation.

## References
- [Minimum Viable Product — Lean Startup](http://theleanstartup.com/principles) (verify exact URL)
- [MoSCoW Method — Agile Alliance](https://www.agilealliance.org/glossary/moscow/)
- [Shape Up — Basecamp](https://basecamp.com/shapeup) — appetite-based scoping
- [STAR Interview Method — Indeed Career Advice](https://www.indeed.com/career-advice/interviewing/star-interview-questions)
- [Continuous Discovery Habits — Teresa Torres](https://www.producttalk.org/2021/05/continuous-discovery-habits/) (book reference)
