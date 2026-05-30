# Tell me about a time you introduced or improved code review practices.

**Category:** Process Improvement & Engineering Culture
**Difficulty:** 🟡 Middle
**Tags:** `code-review`, `engineering-culture`, `process`, `quality`, `feedback`

## Question
> Tell me about a time you introduced or improved code review practices.

## Short Answer
Our code reviews were taking 2–3 days to get feedback and were inconsistent — some PRs got thorough reviews, others were rubber-stamped. I introduced a review standards guide, a PR template, and a 24-hour SLA with daily triage. Average review time dropped to 6 hours, rubber-stamping became visible and accountable, and junior developers started receiving consistent feedback rather than depending on which senior was available.

## What the Interviewer Is Looking For

This question tests your understanding that **code review is a team process, not just an individual act**. Interviewers want to see:

- You've thought about code review as a system with consistent inputs and outputs.
- You understand both the quality and the educational value of code review.
- You can improve a team process without mandating rigid rules that kill developer autonomy.
- You've seen how code review culture affects team learning and code quality over time.

### Code Review Improvement Dimensions

| Dimension | Symptom of Weakness | Improvement |
|-----------|--------------------|----|
| Timeliness | PRs wait 2–3 days | 24-hour SLA; daily review triage; reviewer assignment policy |
| Consistency | Some PRs deep-reviewed, others rubber-stamped | Review checklist; PR template; automated checks |
| Educational value | Junior devs get approval but no feedback | Comment standards guide; required inline feedback for complex changes |
| Tone | Harsh or ambiguous comments | "Questions first" guideline; examples of good review comments |
| Scope | Reviews too broad or too vague | PR size limit; single-concern PRs |

## Example STAR Answer

**Situation:**
Our team of 7 engineers had informal code review: any engineer could review any PR, there was no SLA, and the quality varied widely. Some PRs sat for 3 days. Others were merged within minutes with a single 👍. Junior developers were getting inconsistent feedback — some reviews taught them something, others did nothing.

**Task:**
Improve code review quality and consistency without adding heavy process overhead that would slow development.

**Action:**

*Step 1 — Understand the current state:*
I spent 1 week observing: I read 20 recent PRs and their reviews. I categorised: "thorough review," "partial review," "rubber stamp," and "no feedback." About 40% were rubber stamps.

I also surveyed the 3 junior developers informally: all 3 said they couldn't predict what kind of review they'd get or how long they'd wait.

*Step 2 — Define what good looks like:*
I wrote a 1-page "Code Review Standards" guide covering:
- What reviewers should look for (in priority order: correctness, tests, readability, performance).
- Tone guidance: lead with questions for non-bugs; state corrections for clear bugs.
- Time commitment: a thorough review of a 200-line PR takes 15–30 minutes.
- Rubber-stamping defined: approving without reading is not a review.

*Step 3 — Structure the process:*
- PR template: added a checklist (tests added, docs updated for API changes, migration script if needed).
- 24-hour SLA: each morning, PRs without a reviewer were assigned by the team lead in standup.
- PR size guideline (not rule): PRs over 400 lines of change get a comment asking if they can be split.

*Step 4 — Rollout:*
I shared the guide in a team retro, invited feedback, updated it based on discussion, and shared the final version in the team Confluence. No mandate — "here's what I think good looks like; let's try it for a month."

**Result:**
- Average time to first review: 2.5 days → 6 hours.
- Rubber-stamp rate: ~40% → ~8% (visible in PR review history).
- Junior developer survey (1 month later): all 3 rated review feedback quality improved.
- 2 senior engineers independently told me review felt more "fair" — less random.

## Reflection / What I'd Do Differently
I would add automated checks (linting, formatting, test coverage gate) before deploying the standards guide. Automating the "mechanical" checks removes them from the human review entirely, letting reviewers focus on logic and design — which is where human judgment actually adds value.

## Common Follow-up Questions
- How do you handle a developer who doesn't follow the code review standards?
- What's your view on approving a PR you have concerns about vs. blocking it?
- How do you review a PR for a technology or area you're not familiar with?
- What are the most important things to look for in a code review?
- How do you keep code reviews fast when the team is under delivery pressure?
- What's the right PR size? How do you enforce it without creating friction?

## Common Mistakes / Pitfalls
- **Rubber-stamping as politeness** — "I didn't want to slow them down" is not a code review.
- **Reviewing style instead of substance** — automated linters handle style; code review is for logic, correctness, and design.
- **Bloated PRs** — a PR that changes 1,500 lines across 20 files is not reviewable. Encourage small, focused PRs.
- **Tone in reviews** — "this is wrong" is less effective than "what was your thinking on X? I'd normally use Y approach for this because..." — both result in a fix, but the question approach teaches.
- **No SLA** — without an expected response time, PRs sit in queues and become a source of friction.
- **Process for its own sake** — a review checklist that no one reads is overhead, not improvement.

## References
- [Google Engineering Practices — Code Review](https://google.github.io/eng-practices/review/)
- [The Art of Readable Code — Boswell & Foucher](https://www.oreilly.com/library/view/the-art-of/9781449318482/) (book reference)
- [Code Review Best Practices — Palantir](https://blog.palantir.com/code-review-best-practices-19e02780015f) (verify exact URL)
- [GitHub Pull Request Templates](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository)
- [Conventional Comments](https://conventionalcomments.org/) — structured comment syntax for code reviews

[See also: Code Reviews Constructive and Educational](code-reviews-constructive-and-educational.md)
