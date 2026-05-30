# How do you approach knowledge sharing within your team?

**Category:** Mentorship & Growing Others
**Difficulty:** 🟡 Middle
**Tags:** `knowledge-sharing`, `team-culture`, `documentation`, `mentorship`, `learning`

## Question
> How do you approach knowledge sharing within your team?

## Short Answer
I prefer pull-based over push-based knowledge sharing: instead of dumping information in a team meeting, I write it down where people will find it when they need it — documented in code, in wikis, or in ADRs. I supplement this with short "lightning talks" for things that benefit from a live conversation. The goal is to reduce the number of questions that require me specifically to answer.

## What the Interviewer Is Looking For

This is a **process and culture question** about your philosophy on building team knowledge. Interviewers want to see:

- You think about knowledge as a team asset, not just personal expertise.
- You have specific, reusable mechanisms — not just "I explain things when asked."
- You understand the difference between synchronous knowledge sharing (meetings, talks) and asynchronous (docs, wikis, ADRs).
- You reduce single points of failure, including yourself.

### Knowledge Sharing Mechanisms

| Mechanism | Best For |
|-----------|----------|
| Code comments | Why a decision was made; non-obvious constraints |
| ADRs (Architecture Decision Records) | Significant architectural choices |
| Wiki / runbook | How-to guides, setup, operational knowledge |
| PR descriptions | Context for a change that isn't obvious from the diff |
| Lightning talks (15 min) | New concepts; live demo works better than docs |
| Pairing / ensemble sessions | Tacit knowledge; process knowledge; problem-solving style |
| README.md | What a service/module does; how to run it |

> **⚠ Note:** This question asks for your *approach* — a philosophy and set of practices — not a single story. Anchor in a specific context but describe a repeatable system.

## Example STAR Answer

**Context:**
On my most recent team (5 backend engineers, growing to 8), I noticed we had a bus factor of 1 for several parts of the codebase. Two services were effectively "owned" by single individuals, and when either was on holiday, those services' deployments and incidents were left unresolved until they returned.

**What I introduced:**

### 1. Documented everything that lived in someone's head

I ran a "knowledge audit": I asked each engineer, "What do you know about this system that isn't written down anywhere?" We generated a list of 23 undocumented knowledge items in one session. Over the following month, each item became either a wiki page, a code comment, or an ADR.

### 2. Made PR descriptions mandatory knowledge artifacts

I proposed that PR descriptions for non-trivial changes include three things: what changed, why it changed, and what was explicitly *not* changed (and why). This made the PR history a knowledge base, not just a change log.

### 3. Fortnightly 20-minute lightning talks

Every two weeks, one engineer does a 20-minute slot: either "something I learned this week" or "here's how this part of the system works." No slides required — a whiteboard or a code walkthrough is fine. Attendance is optional but typically high because the format is low-ceremony.

### 4. Rotate ownership

For our two "single-owner" services, I proposed that we rotate the on-call and deployment responsibility every sprint, with the previous owner available for questions but not the default responder. This forced documentation and knowledge transfer by necessity.

**Result:**
Within 3 months: both single-owner services had been successfully deployed by engineers who hadn't done it before. The knowledge audit wiki pages were referenced 15+ times during on-call incidents in the following quarter. The lightning talks became the team's favourite ritual according to our retrospective.

## Reflection / What I'd Do Differently
I would run the knowledge audit at project kickoff, not after noticing the bus factor problem. The best time to document is when the knowledge is fresh, not when you're scrambling to transfer it before someone leaves.

## Common Follow-up Questions
- How do you keep documentation up-to-date as the system changes?
- How do you encourage knowledge sharing in a team where engineers are very protective of their expertise?
- What's your approach when documentation exists but is outdated or wrong?
- How do you balance knowledge sharing activities with delivery commitments?
- What's the difference between documentation that helps people and documentation that nobody reads?
- How do you create a team culture where asking questions is valued, not penalised?

## Common Mistakes / Pitfalls
- **"I'm always happy to explain things"** — this is people-dependent knowledge transfer, not scalable knowledge sharing.
- **Documentation for its own sake** — docs that no one can find or that become outdated quickly are worse than no docs.
- **Only synchronous sharing** — team meetings don't scale; asynchronous artifacts are more durable.
- **Not measuring the bus factor** — show you proactively identified knowledge concentration risks.
- **Forgetting to maintain** — knowledge sharing is a habit, not a one-time event.
- **No cultural element** — docs and wikis help, but the team's willingness to ask questions and share openly matters too.

## References
- [Architecture Decision Records — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [The Documentation System — Divio](https://documentation.divio.com/) — tutorials, how-to, reference, explanation
- [Writing Good Documentation — Write the Docs](https://www.writethedocs.org/guide/writing/beginners-guide-to-docs/) (verify exact URL)
- [Bus Factor — Wikipedia](https://en.wikipedia.org/wiki/Bus_factor)
- [Learning Organisation — Peter Senge, The Fifth Discipline](https://www.amazon.com/Fifth-Discipline-Practice-Learning-Organization/dp/0385517254) (book reference)
