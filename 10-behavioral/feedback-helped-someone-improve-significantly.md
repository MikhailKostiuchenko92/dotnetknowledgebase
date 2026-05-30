# Tell me about a time your feedback helped someone improve significantly.

**Category:** Mentorship & Growing Others
**Difficulty:** 🟡 Middle
**Tags:** `feedback`, `mentorship`, `growth`, `communication`, `impact`

## Question
> Tell me about a time your feedback helped someone improve significantly.

## Short Answer
A mid-level developer on my team had a pattern of submitting PRs without any context — no description of what changed or why. After one honest, specific conversation about the downstream cost of this habit (other engineers spending 30 extra minutes understanding context), they completely changed their PR discipline within two weeks. The feedback worked because I made the impact visible, not just the behaviour.

## What the Interviewer Is Looking For

This question tests your **feedback quality** and your ability to **create meaningful change in others**. Interviewers want to see:

- Your feedback was specific, kind, and focused on behaviour and impact — not personality.
- You delivered it at the right moment and in the right setting (usually private, one-on-one).
- You followed up to confirm the improvement, not just gave feedback and moved on.
- The improvement was real and measurable.

### The SBI Feedback Model

A highly effective feedback framework:

| Component | Meaning | Example |
|-----------|---------|---------|
| **S**ituation | When and where | "In the past three PRs..." |
| **B**ehaviour | What specifically | "...the description was blank or one line" |
| **I**mpact | What it caused | "...and other reviewers spent 20–30 minutes reading git history to understand the context" |

> **⚠ Key Principle:** Effective feedback describes *behaviour* and *impact*, not *personality* or *intent*. "Your PRs lack context" is behaviour. "You're careless" is personality.

## Example STAR Answer

**Situation:**
A mid-level engineer on my team consistently submitted PRs with either no description or a single sentence ("fixed bug"). After reviewing 6 of their PRs over a month, I noticed I was spending 20–30 extra minutes per review reconstructing the context: reading the commit history, searching Jira for the ticket, comparing before/after states.

**Task:**
I was the senior engineer and informal PR reviewer for the team. I wanted to address this constructively without damaging their confidence — their technical work was solid.

**Action:**

*Setup:*
I asked for a 15-minute private chat. Not in Slack, not in a PR comment, not in standup — feedback that matters deserves a dedicated, private space.

*The feedback (SBI model):*
"I've been reviewing your PRs for the past month and I want to share something I've noticed. In the last 6 PRs, the descriptions were very minimal — sometimes blank. When I reviewed PR #47 last week, I spent about 25 minutes reading the git history and related tickets to understand what the change was actually doing. That's time I couldn't spend on my own work, and it's also time other reviewers will spend too. A 5-minute description would save everyone that 25 minutes."

*Check for understanding:*
I asked: "Does that make sense? Is there something making it hard to write the descriptions?" They said they thought the ticket link was enough context. I explained that reviewers often don't have access to the ticket, and that the PR description should stand alone.

*Follow-up:*
The next PR they submitted had a thorough description — problem, solution, what wasn't changed and why, testing notes. I commented publicly on the PR: "This is exactly the kind of context that makes reviews fast and valuable — thank you."

**Result:**
Their PR descriptions improved immediately and durably. Three months later, they were the team member writing the most thorough PR descriptions — they had internalised it. They also told me in a 1:1 that no one had ever explained *why* PR descriptions mattered before.

## Reflection / What I'd Do Differently
I would share what a great PR description looks like before relying on feedback to correct a gap. Showing a model early is more efficient than correcting a habit later. We've since added an example PR description to our contributing guide.

## Common Follow-up Questions
- How do you decide *when* to give feedback vs. letting something go?
- What do you do when feedback doesn't result in improvement?
- How do you give feedback to someone who is significantly more senior than you?
- What's the difference between feedback that sticks and feedback that's forgotten?
- Have you ever given feedback that backfired or damaged a relationship?
- How do you receive feedback yourself?

## Common Mistakes / Pitfalls
- **Personality-based feedback** — "you're disorganised" is not actionable. "Your PR descriptions don't include test notes" is.
- **Public feedback** — corrective feedback should almost always be private first.
- **No follow-up** — giving feedback and not checking whether it worked is a missed opportunity.
- **No positive reinforcement** — when the person improves, acknowledge it explicitly.
- **Vague impact** — "it was frustrating for the team" is less powerful than "it cost each reviewer 25 extra minutes per PR."
- **Timing** — feedback given in the heat of the moment (right after a bad PR) is less effective than feedback given calmly and intentionally.

## References
- [Situation-Behaviour-Impact (SBI) — Centre for Creative Leadership](https://www.ccl.org/articles/leading-effectively-articles/closing-the-gap-between-intent-vs-impact-core-leadership-skill/)
- [Radical Candor — Kim Scott](https://www.radicalcandor.com/our-approach/)
- [The Feedback Loop — HBR](https://hbr.org/2019/03/the-feedback-fallacy) (verify exact URL)
- [STAR Interview Method — Indeed Career Advice](https://www.indeed.com/career-advice/interviewing/star-interview-questions)
- *Thanks for the Feedback* — Stone & Heen (book reference — feedback theory)
