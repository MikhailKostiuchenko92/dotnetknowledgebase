# Describe a situation where different teams had competing goals. How did you navigate it?

**Category:** Collaboration & Teamwork
**Difficulty:** 🔴 Senior
**Tags:** `cross-team`, `competing-priorities`, `negotiation`, `stakeholder-management`, `alignment`

## Question
> Describe a situation where different teams had competing goals. How did you navigate it?

## Short Answer
Our team needed to ship a breaking API change; the dependent team needed stability. The typical escalation would have taken weeks. Instead, I scheduled a joint session, mapped the concrete constraints on both sides, and we designed a versioned API migration with a 6-week parallel-run window — a solution neither team would have reached alone. Cross-team conflict is usually a shared constraint problem with multiple viable solutions.

## What the Interviewer Is Looking For

This is a **senior-level influence and negotiation question**. Interviewers want to see:

- You can navigate organisational tension without escalating to management as the first move.
- You understand both teams' constraints — not just your own.
- You identify shared goals and use them as the alignment anchor.
- You design solutions that work for both sides, not just compromise in the middle.

### The Cross-Team Conflict Resolution Playbook

| Step | Description |
|------|-------------|
| Listen first | Understand the other team's actual constraints, not your assumptions about them |
| Find the shared goal | Both teams want the product to succeed; anchor on that |
| Separate positions from interests | "We need stability" (position) vs. "we can't afford to break our release" (interest) |
| Generate multiple options | Avoid binary "we win or you win" framing |
| Negotiate on criteria | Use objective criteria (timelines, SLAs, business impact) rather than bargaining power |

> **⚠ Warning:** "We escalated to our manager and they sorted it out" is not a senior-level answer. Show that you navigated this peer-to-peer before involving management.

## Example STAR Answer

**Situation:**
Our team was refactoring a core authentication API that was used by 3 other teams. We needed to change the token structure to support multi-tenant architecture — a breaking change to the existing API contract. One dependent team was in the middle of their own release cycle and their tech lead pushed back hard: "We can't absorb this change for 3 months."

**Task:**
I was the tech lead on the authentication team. My PM needed the migration completed in 6 weeks for a compliance deadline. The dependent team's constraint was real — they had a frozen code window due to a financial audit.

**Action:**

*Step 1 — Listen, don't push:*
I requested a meeting with the dependent team's tech lead and their PM — not to present my timeline, but to understand theirs. I learned: their code freeze was for 4 weeks, not 3 months. The "3 months" had been a precautionary estimate.

*Step 2 — Reframe the problem:*
The shared constraint we both faced was: the compliance deadline was fixed. The question was how to meet it without breaking the dependent team's release. I reframed: "Is the problem that you can't make the change, or that you can't make the change *without preparation time*?"

*Step 3 — Design the solution together:*
In a 2-hour joint session, we designed a versioned API approach: the new multi-tenant endpoint was published alongside the existing one (`/v2/auth` alongside `/v1/auth`). The old endpoint would stay functional for 8 weeks (giving the dependent team 4 weeks after their freeze lifted). Migration guides were written by both teams.

I took on the extra cost of maintaining dual endpoints for 8 weeks — a real cost, but smaller than missing the compliance deadline or forcing a risky change on a partner team.

**Result:**
Compliance deadline met. Dependent team migrated smoothly 3 weeks after their freeze lifted. Zero production incidents during the migration window. The joint session became a model for how we handle breaking API changes organisation-wide.

## Reflection / What I'd Do Differently
I would create a "breaking change communication protocol" — a lightweight process where any team planning a breaking API change notifies dependent teams 4+ weeks out as standard practice, with a shared migration planning session. This would prevent the conflict from arising reactively in the first place.

## Common Follow-up Questions
- What do you do when the other team is genuinely unreasonable or uncooperative?
- How do you escalate a cross-team conflict to management without burning bridges?
- How do you handle competing goals when one team has more organisational power than the other?
- What's the difference between compromise and a creative solution?
- How do you maintain a relationship with a team after a difficult negotiation?
- Have you ever been the "losing" side in a cross-team negotiation? How did you handle it?

## Common Mistakes / Pitfalls
- **Starting with your own timeline** — the other team's constraints must be understood first.
- **Binary framing** — "either we change the timeline or you accept the breaking change" eliminates creative solutions.
- **Escalating too early** — going to management before trying peer-level negotiation is a junior move.
- **No shared outcome** — the best resolution gives both teams something they need, not a 50/50 split of neither.
- **Missing the organisational lesson** — at the senior level, you should also reflect on the process gap that allowed this conflict to arise.
- **"We compromised"** — compromise (each gives up something) is weaker than "we created a better solution that served both."

## References
- [Getting to Yes — Fisher, Ury, Patton](https://www.pon.harvard.edu/bookshop/getting-to-yes-negotiating-agreement-without-giving-in/) (book reference — principled negotiation)
- [API Versioning Strategies — Microsoft Learn](https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design#versioning-a-restful-web-api)
- [Consumer-Driven Contracts — Martin Fowler](https://martinfowler.com/articles/consumerDrivenContracts.html)
- [Difficult Conversations — Stone, Patton, Heen](https://www.amazon.com/Difficult-Conversations-Discuss-What-Matters/dp/0143118447) (book reference)
- [Team Topologies — Skelton & Pais](https://teamtopologies.com/) — on team interaction modes
