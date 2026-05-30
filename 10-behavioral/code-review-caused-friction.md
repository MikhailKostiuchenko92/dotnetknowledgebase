# Tell me about a time a code review caused friction. What did you do?

**Category:** Conflict & Disagreement
**Difficulty:** 🔴 Senior
**Tags:** `code-review`, `feedback`, `conflict`, `mentorship`, `team-culture`

## Question
> Tell me about a time a code review caused friction. What did you do?

## Short Answer
Code reviews create friction when feedback is ambiguous about severity or personal in tone. I've learned to flag friction early — if a review thread goes more than two rounds without converging, that's a signal to switch to a synchronous conversation. I also helped my team adopt a comment labeling convention (nit/suggestion/blocker) that eliminated most review ambiguity within a month.

## What the Interviewer Is Looking For

This question targets your ability to **give and receive feedback professionally**, **maintain team culture**, and **resolve friction without management intervention**. At the senior level, interviewers also want to see that you improve the system, not just survive it.

- You distinguish between a critique of code and a critique of a person.
- You can deliver hard feedback without being harsh, and receive it without being defensive.
- You identify the root cause of friction (unclear standards? power dynamics? poor tone?) and address it structurally.
- You think about code review culture at the team level, not just in individual interactions.

### Dimensions Being Assessed

| Dimension | What a Strong Answer Shows |
|-----------|---------------------------|
| Self-awareness | Whether the friction came from your review style or your response to feedback |
| Systems thinking | You identified a process gap, not just a personality conflict |
| Courage | You addressed the friction, not just tolerated it |
| Culture impact | You improved the process for the whole team, not just this one case |

> **⚠ Warning:** Avoid answers that cast blame entirely on the other person. Even if the reviewer was harsh, reflect on whether your PR had inadequate context or your response escalated the situation.

## Example STAR Answer

**Situation:**
Six months into a new role, I submitted a PR refactoring a critical payment validation module. The senior engineer who reviewed it left 14 comments in a row, several phrased as "this is wrong" or "why would you do this?" — without explanation. I was three weeks into the team and found it discouraging and unclear about what to fix.

**Task:**
I needed to respond constructively, understand the real concerns, and also address a pattern I was seeing — our team's code reviews had no shared norms, which was creating recurring friction for others too.

**Action:**
For the immediate situation: instead of responding defensively or submitting revised code without asking, I sent a message asking for a 20-minute call to walk through the comments together. The reviewer was actually happy to explain — the terse comments reflected their writing style, not hostility. We went through each comment, I asked "what's the failure mode you're protecting against?" and we resolved all 14 points in 20 minutes. Several of their concerns were valid; two I successfully pushed back on with reasoning.

For the systemic issue: I drafted a simple code review guide for the team. I introduced comment labels:
- **nit:** cosmetic, take-it-or-leave-it
- **suggestion:** improvement, but won't block merge
- **blocker:** must be addressed before merge

I also added a "context" section template to our PR description — what changed, why, what was not changed and why — to reduce back-and-forth.

I proposed these in a team retrospective, framed as "tools I wish we had, not rules." The team adopted them within a sprint.

**Result:**
Average PR cycle time dropped from 3.5 days to 1.8 days over the following two months. Anecdotally, the team reported fewer "dreaded reviews." The senior engineer who had been the source of friction became one of the most effective reviewers on the team once the structure gave them a way to communicate severity clearly.

## Reflection / What I'd Do Differently
I should have had the review norms conversation earlier — during my onboarding, not after a friction incident. Establishing shared code review expectations is one of the first conversations I now have when joining or leading a new team.

## Common Follow-up Questions
- What's your philosophy on code review — what's it for and what's it not for?
- How do you handle it when someone consistently ignores your review comments?
- How do you review code from someone far more experienced than you?
- Have you ever had to review code you thought was architecturally wrong but was technically correct?
- How do you balance thoroughness with turnaround time in code reviews?
- What do you do when a reviewer keeps bikeshedding (focusing on trivial style issues)?

## Common Mistakes / Pitfalls
- **No systemic improvement** — resolving one incident without improving the process is a missed opportunity at the senior level.
- **Only describing friction you received** — the question applies equally to friction you caused as a reviewer.
- **No specifics** — "we had different styles" is not a story. Name the specific type of friction.
- **Missing the process outcome** — quantify the improvement if possible (cycle time, PR iteration count, team survey).
- **Framing reviews as gatekeeping** — code review is a collaborative learning process; frame it that way.
- **Ignoring the relationship repair** — after friction, did you rebuild trust with the other engineer?

## References
- [Code Review Best Practices — Google Engineering Practices](https://google.github.io/eng-practices/review/)
- [How to Make Your Code Reviewer Fall in Love With You — Michael Lynch](https://mtlynch.io/code-review-love/)
- [Constructive Code Review — Thoughtbot](https://github.com/thoughtbot/guides/tree/main/code-review) (verify exact URL)
- [The Gentle Art of Patch Review — Sage Sharp](https://sage.thesharps.us/2014/09/01/the-gentle-art-of-patch-review/) (verify exact URL)
- *The Pragmatic Programmer* — Hunt & Thomas (section on feedback culture)
