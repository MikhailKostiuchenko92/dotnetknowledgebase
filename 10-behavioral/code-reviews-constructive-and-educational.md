# Describe how you conduct code reviews to be both constructive and educational.

**Category:** Mentorship & Growing Others
**Difficulty:** 🔴 Senior
**Tags:** `code-review`, `mentorship`, `feedback`, `team-culture`, `engineering-excellence`

## Question
> Describe how you conduct code reviews to be both constructive and educational.

## Short Answer
I use a labelling system — nit/suggestion/blocker — so the author knows what must change vs. what's optional. For every blocker, I explain the *why*, not just the *what*. I look for opportunities to ask "have you considered X?" rather than just asserting "do X." And I always find at least one thing to genuinely praise — not as a courtesy, but because good code deserves recognition.

## What the Interviewer Is Looking For

This is a **leadership and culture question** dressed as a technical one. Interviewers want to see:

- You've thought about code review as a teaching tool, not just a gatekeeping mechanism.
- Your feedback is **clear**, **specific**, and **actionable**.
- You calibrate feedback to the author's experience level.
- You model the behaviour you want others to adopt in their own reviews.

### Code Review Principles

| Principle | Application |
|-----------|-------------|
| Review the code, not the person | "This function is complex" not "you wrote this poorly" |
| Explain the why | "This can cause a deadlock because..." not just "change this" |
| Use labels for severity | nit / suggestion / blocker — author should never have to guess |
| Praise genuinely | Notice and comment on good patterns, not just problems |
| Ask questions | "Have you considered...?" invites reflection rather than compliance |
| Be consistent | Apply the same standards to everyone, including senior engineers |

> **⚠ Warning:** Code review is often where team culture is most visible. How you review reflects how you treat people. Even a technically correct comment can damage relationships if it's dismissive or condescending.

## Example STAR Answer

**Context:**
I developed my code review philosophy over several years after noticing that many reviews I had received — and some I had written — generated friction, defensiveness, or compliance without understanding. I deliberately redesigned my approach.

**My current approach:**

### Before reviewing
I read the PR description and linked ticket first. I try to understand *what problem the author was solving* and *what constraints they were working under*. A suboptimal implementation in a codebase with no tests is a different conversation than the same implementation in a well-tested service.

### Comment severity labelling
Every comment I write has a prefix:
- **nit:** cosmetic, take-it-or-leave-it. "nit: consider renaming this to `maxRetryCount` for clarity."
- **suggestion:** improvement worth considering, but I won't block on it. "suggestion: this could be simplified with LINQ's `GroupBy`."
- **blocker:** must be addressed. "blocker: this `ConfigureAwait(false)` is missing on a UI-context path — this will deadlock in ASP.NET Framework."

The label removes the author's need to guess whether I'll reject the PR over a cosmetic comment.

### Explaining the why
For blockers, I always explain the root cause:

```
// Instead of:
"This is wrong."

// I write:
"blocker: using Task.Result here will deadlock if called from a synchronous
context that has a SynchronizationContext (e.g., ASP.NET Framework, UI thread).
Use await instead, or if you need to call synchronously, use .GetAwaiter().GetResult()
and note the trade-offs. See: https://blog.stephencleary.com/2012/07/dont-block-on-async-code.html"
```

### Educational opportunity in every review
If I spot a pattern I've seen three or more times across the codebase, I don't just comment on the current instance. I write a short "team note" in our internal wiki — a single reusable explanation the next person can link to.

### Calibrating to the author
For junior engineers: I explain more, ask more questions rather than asserting, and keep the comment volume manageable (5–7 focused points, not 30 minor items).

For seniors: I'm more direct and expect a response that either accepts the feedback or pushes back with reasoning — both are valid.

**Result:**
After introducing the labelling convention to my team, PR cycle time dropped from 3.5 days to 1.9 days. Engineers reported less anxiety about submitting PRs. The team's "nit" comments became a cultural in-joke — indicating healthy, non-adversarial review culture.

## Reflection / What I'd Do Differently
I would establish team code review norms in the first week of any new team, not retroactively. The initial norms (implicit or explicit) shape the culture; changing them later requires overcoming established habits.

## Common Follow-up Questions
- How do you review code in a domain where you have less expertise than the author?
- What do you do when an author repeatedly ignores your suggestions?
- How do you handle a very large PR (500+ lines)? Do you approve it or ask them to split it?
- What's your approach when reviewing code from someone who is significantly more senior than you?
- How has your code review philosophy evolved over the years?
- What's the highest-value category of bug that code review typically catches vs. what it misses?

## Common Mistakes / Pitfalls
- **No severity distinction** — every comment feeling equal creates anxiety and causes important issues to be buried.
- **"This is wrong" without explanation** — criticism without reasoning teaches nothing.
- **Reviewing style when a linter should** — use automated tools for formatting; focus human review on logic, design, and correctness.
- **Only finding problems** — never mentioning what's good signals to the author that their work is purely a deficit to be corrected.
- **Overwhelming junior engineers** — 30 comments on a first PR is demoralising. Prioritise and focus.
- **Not pushing back when the author disagrees** — if you have a blocker comment, articulate *why* clearly. If they have a good counter-argument, update your view.

## References
- [Google Engineering Practices — Code Review](https://google.github.io/eng-practices/review/)
- [How to Make Your Code Reviewer Fall in Love With You — Michael Lynch](https://mtlynch.io/code-review-love/)
- [Thoughtbot Code Review Guide](https://github.com/thoughtbot/guides/tree/main/code-review)
- [Don't Block on Async Code — Stephen Cleary](https://blog.stephencleary.com/2012/07/dont-block-on-async-code.html)
- *The Pragmatic Programmer* — Hunt & Thomas (book reference — feedback culture)
