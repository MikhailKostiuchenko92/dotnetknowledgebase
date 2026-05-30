# Describe a disagreement you had about priorities or deadlines and how it was settled.

**Category:** Conflict & Disagreement
**Difficulty:** 🟡 Middle
**Tags:** `priorities`, `deadlines`, `negotiation`, `communication`, `stakeholders`

## Question
> Describe a disagreement you had about priorities or deadlines and how it was settled.

## Short Answer
I tackle priority disagreements by making the trade-offs explicit and quantified, not abstract. When someone wants everything done now, I produce a visual stack-rank with estimated costs and ask them to tell me what drops from the bottom when the new item goes in at the top. That forces a real conversation about value, not preferences.

## What the Interviewer Is Looking For

This question probes your ability to **navigate competing demands** and **communicate trade-offs** without losing relationships. Interviewers want to see:

- You use structured reasoning (value vs. cost) rather than gut feel or seniority.
- You involve the right people in prioritisation decisions.
- You're not a pushover who accepts every scope change, nor a blocker who refuses to adapt.
- You build shared understanding, not just compliance.

### Dimensions Being Assessed

| Dimension | What a Strong Answer Shows |
|-----------|---------------------------|
| Analytical thinking | You quantified effort, risk, or value to anchor the conversation |
| Communication | You made trade-offs clear to both technical and non-technical participants |
| Influence | You shaped the outcome through reasoning, not just by deferring to authority |
| Outcome | The disagreement produced a better plan, not just a temporary truce |

> **⚠ Warning:** Avoid stories where you simply gave in to pressure. That signals you lack backbone. Also avoid stories where you "won" by refusing to budge — that signals inflexibility.

## Example STAR Answer

**Situation:**
During the planning of a Q3 roadmap, my manager and a product manager had scheduled four features for the sprint including a "quick win" security patch the PM wanted. Our tech lead estimated the patch at 3 days. I had reviewed the codebase and believed it was closer to 10 days due to dependencies in the authentication middleware.

**Task:**
I disagreed with both the estimate and the priority ordering — if the security patch took 10 days and was treated as a "quick win," two higher-priority features would slip into Q4.

**Action:**
I requested 30 minutes on the next planning call with both my manager and the PM. I came prepared with a written breakdown: the authentication middleware touched five services, each requiring regression tests; the "quick win" assumption missed the cross-service impact entirely.

I created a simple priority matrix on paper — impact vs. effort — and placed all four features on it. The security patch moved from the top-right (high impact, low effort) to the top-left (high impact, high effort) once the true cost was visible.

I proposed a sequencing change: deliver the two low-complexity features first (1.5 weeks), then tackle the security patch with a clear scope boundary — only the public-facing endpoints, with internal services patched in Q4 under a separate ticket.

**Result:**
The PM agreed once they saw the actual risk to Q3 revenue features. We hit all three items on time. The scoped security patch was completed in 6 days. The remaining internal services were patched in Q4 as planned.

## Reflection / What I'd Do Differently
I would push for estimates to be a team activity, not something the tech lead does alone before the planning meeting. Estimation disagreements often signal that important context hasn't been shared yet — a group estimation session (even 30 minutes) surfaces that context early.

## Common Follow-up Questions
- How do you handle it when someone claims an estimate is "too pessimistic" without looking at the details?
- What frameworks do you use to prioritise — MoSCoW, RICE, value vs. effort?
- How do you communicate a reprioritisation decision to the rest of the team?
- What do you do when a deadline is externally fixed (a regulatory date, a conference demo) and the scope is too large?
- How do you balance technical debt work against business feature requests in prioritisation?
- Have you ever been overruled on a priority decision that then proved you were right?

## Common Mistakes / Pitfalls
- **No concrete mechanism for resolution** — "we discussed it and agreed" is insufficient. Show the artifact (matrix, list, doc) that anchored the conversation.
- **Siding entirely with engineering** — sometimes the business deadline is real and non-negotiable; show that you factor this in.
- **Telling it without the trade-off** — the story must show what was given up or deferred, not just what was done.
- **Presenting as a binary** — the strongest outcomes are usually creative re-scoping, not one side winning.
- **Forgetting to communicate the outcome** — after reprioritisation, the whole team needs to understand why, or you'll face the same conversation again in two weeks.
- **Skipping the estimate validation** — if your point was "the estimate is wrong," show how you validated your own estimate, not just why theirs was wrong.

## References
- [RICE Scoring for Prioritisation — Intercom](https://www.intercom.com/blog/rice-simple-prioritization-for-product-managers/) (verify exact URL)
- [MoSCoW Prioritisation Method — Agile Alliance](https://www.agilealliance.org/glossary/moscow/) (verify exact URL)
- [Planning Fallacy — Daniel Kahneman, Thinking Fast and Slow](https://en.wikipedia.org/wiki/Planning_fallacy)
- *Continuous Delivery* — Jez Humble & David Farley (book reference, chapters on deployment planning)
- [STAR Interview Method — Indeed Career Advice](https://www.indeed.com/career-advice/interviewing/star-interview-questions)
