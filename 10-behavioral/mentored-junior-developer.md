# Tell me about a time you mentored a junior developer. What was your approach?

**Category:** Mentorship & Growing Others
**Difficulty:** 🟡 Middle
**Tags:** `mentorship`, `junior-developer`, `teaching`, `growth`, `feedback`

## Question
> Tell me about a time you mentored a junior developer. What was your approach?

## Short Answer
My approach is to balance teaching with doing: I explain the *why* before the *how*, give them real work (not toy exercises), and let them struggle productively before stepping in. The most effective thing I do is ask "what have you tried so far?" before giving answers — it builds independent problem-solving habits, not just dependency on me.

## What the Interviewer Is Looking For

This question assesses your **mentorship philosophy**, **empathy**, and **ability to grow engineers**. Interviewers want to see:

- You have a deliberate approach, not just "I was helpful when they asked."
- You balance support with autonomy — you don't solve every problem for them.
- You adapt to their specific learning style and gaps.
- You measure the outcome: did they actually improve?

### Mentorship Anti-Patterns to Avoid

| Anti-Pattern | Problem |
|-------------|---------|
| Just solving their problems | Creates dependency, not capability |
| Only giving positive feedback | Doesn't accelerate growth |
| One-size-fits-all approach | Different juniors have different gaps |
| No structured check-in | Progress is assumed, not measured |
| Waiting for them to come to you | Some juniors don't ask for help even when they need it |

> **⚠ Note:** The best mentorship stories show a junior who grew into greater independence — not one who needed more and more help over time.

## Example STAR Answer

**Situation:**
A graduate developer joined the team. They had strong CS fundamentals (algorithms, data structures) but no production .NET experience. Their early PRs showed good intent but had recurring patterns: missing error handling, no logging, and a tendency to write synchronous code where async was needed.

**Task:**
I volunteered to be their primary mentor for the first 3 months. I wanted them to become independently productive on our codebase, not just dependent on my reviews to catch issues.

**Action:**

*Week 1 — Understand their mental model:*
I had them walk me through code *they* wrote while I listened and asked questions: "What do you think happens if this throws?" I wasn't grading — I was mapping where their intuitions were right, and where there were gaps. This told me what to focus on: async/await and error handling first.

*Weekly pattern — Guide don't solve:*
In my PR reviews, I adopted a rule: if I could explain *why* something was a problem, I wrote that explanation. If I just said "change this to async," they'd make the change but not learn. If I wrote "this blocks the thread because... consider...", they learned a transferable principle.

When they came to me stuck, I asked: "What have you tried? What do you think is happening?" before offering a direction. This took more time per question but built problem-solving confidence.

*Month 2 — Increase autonomy:*
I assigned them a small feature with a well-defined scope but no pairing. I checked in at 48 hours — not to supervise, but to ask: "Anything blocking you or surprising you?" I gave them space to make small mistakes, then addressed them in the PR review.

*Month 3 — Meta-mentorship:*
I asked them to write up a short guide: "What I learned about async/await in .NET that wasn't obvious from the documentation." This forced articulation of their own learning and produced a document that helped the next junior hire.

**Result:**
By the end of month 3, their PR quality had improved to the point where reviews were mostly suggestions, not corrections. They were also independently flagging potential issues in *other* people's PRs — a confidence signal I was watching for. They later said the "explain your reasoning" approach in code reviews was the single most valuable practice for their growth.

## Reflection / What I'd Do Differently
I would set explicit, observable goals at the start: "By week 4, I want you to be able to write an async API endpoint from scratch, handle errors with `ILogger`, and write integration tests for it." Without explicit goals, mentorship drift is common — you help with whatever comes up, but don't develop complete capabilities.

## Common Follow-up Questions
- How do you tailor your mentorship approach to different learning styles?
- What do you do when a junior isn't progressing at the expected rate?
- How do you give critical feedback to someone who takes it personally?
- What's the difference between mentoring and managing?
- How do you mentor someone remotely vs. in person?
- Have you ever mentored someone who ultimately left the field or switched careers? How did you feel about that?

## Common Mistakes / Pitfalls
- **"I was always available to help"** — availability alone is not mentorship. Show structured intent.
- **No evidence of growth** — the story must show that the junior improved, not just that you were supportive.
- **Solving every problem** — creating dependency is the opposite of good mentorship.
- **Only technical mentorship** — the most impactful mentors also help with career development, team navigation, and professional confidence.
- **No feedback cadence** — good mentorship includes regular, explicit feedback, not just ad-hoc help.
- **Missing the meta-skill** — you want them to learn how to learn, not just what to learn.

## References
- [Pair Programming — Martin Fowler](https://martinfowler.com/articles/on-pair-programming.html)
- [The Coaching Habit — Michael Bungay Stanier](https://boxofcrayons.com/the-coaching-habit-book/) (book reference — ask-first mentoring)
- [Socratic Method in Technical Education](https://en.wikipedia.org/wiki/Socratic_method)
- [async/await Best Practices in C# — Stephen Cleary](https://blog.stephencleary.com/2012/07/dont-block-on-async-code.html)
- [The Manager's Path — Camille Fournier](https://www.oreilly.com/library/view/the-managers-path/9781491973882/) (book reference — mentoring chapter)
