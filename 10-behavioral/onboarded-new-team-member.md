# Tell me about a time you had to onboard a new team member. How did you approach it?

**Category:** Collaboration & Teamwork
**Difficulty:** 🟡 Middle
**Tags:** `onboarding`, `mentorship`, `knowledge-transfer`, `team-culture`, `documentation`

## Question
> Tell me about a time you had to onboard a new team member. How did you approach it?

## Short Answer
I onboard new engineers with a 30-60-90 day plan: 30 days to understand the system and make a small contribution, 60 days to own a feature end-to-end, 90 days to be independent and contributing to architecture discussions. The key insight is that a new engineer's most valuable contribution in month 1 is documenting what confused them — they're the best guide to what's missing in your onboarding.

## What the Interviewer Is Looking For

This question assesses your **mentorship instinct**, **empathy for newcomers**, and **process-oriented thinking**. Interviewers want to see:

- You've thought about onboarding as a structured process, not just "sit next to them for a week."
- You understand the newcomer's perspective — the gap between your knowledge and theirs.
- You balance guided support with autonomy.
- You've improved the onboarding process based on experience.

### Good Onboarding: What to Cover

| Domain | What New Engineers Need |
|--------|------------------------|
| Technical | Codebase tour, architecture overview, local setup guide |
| Process | How PRs are reviewed, how stories are estimated, how incidents are handled |
| Social | Team norms, communication preferences, who knows what |
| Domain | Business context — what does the product do and why does it matter? |

> **⚠ Note:** The best onboarding is documentation-driven — the new person can progress independently and contribute improvements to the docs as they go.

## Example STAR Answer

**Situation:**
I was asked to onboard a mid-level developer who was joining from a background primarily in Node.js and was new to C#, .NET, and our domain (financial services). We had minimal onboarding documentation — the previous approach was "just ask someone."

**Task:**
I was the point of contact for their first month. I wanted them to be independently productive and feel confident in the team as quickly as possible, without overwhelming them.

**Action:**

*Before their first day:*
I spent 4 hours creating a structured onboarding document:
- Local development setup (step-by-step, including the hidden `.env` variables no one had written down)
- Architecture map — a simple diagram of our 6 services with a one-sentence description of each
- "First-week task list" — small, well-scoped tickets I specifically selected because they touched common patterns without requiring domain expertise
- Links to the three most-read design docs and the PR review guide

*Week 1 — Guided:*
We did daily 30-minute check-ins. I used them to answer questions but also to ask: "What was confusing about X? What would have helped you understand it faster?" I added their answers to the onboarding doc in real time.

*Weeks 2–4 — Semi-guided:*
They took ownership of a small feature end-to-end. I was available but didn't hover. I reviewed their PRs with extra context ("this pattern exists because of X historical decision") rather than just code comments.

*End of month 1:*
I asked them to do a retrospective on their onboarding experience and write a 1-page "what I wish I'd known on day 1" doc. This became the most useful section of our onboarding guide.

**Result:**
By week 6, they were independently shipping features and contributing to sprint planning. The onboarding document they improved now reduced the average time to first meaningful PR from "2–3 weeks" to 4–5 days for subsequent new hires.

## Reflection / What I'd Do Differently
I would create a "reading list" of the 5 most important architectural decisions (ADRs) for the codebase, ordered by impact. Understanding *why* the system is built the way it is accelerates context-building far more than understanding *what* the code does.

## Common Follow-up Questions
- How do you tailor onboarding for a junior vs. a senior new hire?
- What do you do when a new team member is struggling to ramp up after the first month?
- How do you onboard someone remotely vs. in-person?
- What's the biggest mistake you see in how teams onboard new engineers?
- How do you balance your own delivery commitments with onboarding responsibilities?
- What's your philosophy on "sink or swim" vs. highly structured onboarding?

## Common Mistakes / Pitfalls
- **"Just ask me anything"** — informal onboarding is slow, stressful for the newcomer, and interruption-heavy for you.
- **Technical-only focus** — new engineers also need process, social, and domain context.
- **No 30-60-90 framework** — without milestones, it's impossible to assess whether onboarding is going well.
- **No documentation** — verbal onboarding doesn't scale and degrades with each iteration.
- **Not involving the new hire in improving the docs** — they're the best source of feedback on what's missing.
- **Too much handholding** — autonomy is important; over-supervision undermines confidence.

## References
- [Developer Onboarding Guide — GitHub Blog](https://github.blog/2023-03-10-onboarding-a-new-engineer/) (verify exact URL)
- [30-60-90 Day Plan for Engineering — Camille Fournier](https://www.oreilly.com/library/view/the-managers-path/9781491973882/) (book reference)
- [Architecture Decision Records](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) — onboarding value
- [The First 90 Days — Michael Watkins](https://www.amazon.com/First-90-Days-Strategies-Expanded/dp/1422188612) (book reference)
- [Documentation as a First-Class Citizen — Write the Docs](https://www.writethedocs.org/guide/writing/beginners-guide-to-docs/) (verify exact URL)
