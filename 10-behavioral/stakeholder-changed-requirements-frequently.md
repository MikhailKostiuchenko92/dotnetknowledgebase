# Tell me about a time a stakeholder changed requirements frequently. How did you manage it?

**Category:** Stakeholder Management & Communication
**Difficulty:** 🟡 Middle
**Tags:** `requirements`, `stakeholders`, `scope-creep`, `communication`, `agile`

## Question
> Tell me about a time a stakeholder changed requirements frequently. How did you manage it?

## Short Answer
A product director would add requirements mid-sprint almost every week, which destabilised sprint commitments and frustrated the team. Rather than just absorbing the changes, I introduced a lightweight change process: all new requirements go on the backlog, scope changes within a sprint require removing equivalent scope, and the sprint goal is protected. The director adapted quickly once she saw the team's output actually improve.

## What the Interviewer Is Looking For

This question tests your ability to **manage scope and stakeholder relationships** professionally. Interviewers want to see:

- You handled the situation professionally, not by passive resistance or passive acceptance.
- You introduced a process that helped both the team and the stakeholder.
- You understand that frequent requirement changes often signal a problem upstream (unclear goals, missing refinement, poor communication) that can be addressed.
- You can disagree with a stakeholder's behaviour while maintaining a productive working relationship.

> **⚠ Note:** "We just absorbed the changes" is a weak answer — it shows no advocacy for the team or the quality of the work. "I told the stakeholder they were wrong" without a productive process change is also weak.

### Managing Frequent Requirement Changes

| Strategy | Description |
|----------|-------------|
| Protect the sprint goal | Changes within a sprint require removing equivalent scope |
| Backlog triage | All new requirements go into the backlog, evaluated and prioritised |
| Impact visibility | Show the cost of each change: story points, delayed items, sprint stability score |
| Root cause conversation | Understand *why* requirements change frequently — and fix the upstream issue |
| Sprint review as the boundary | New requirements are welcome; they queue for the next sprint |

## Example STAR Answer

**Situation:**
I was the tech lead on a 3-developer team. The product director had a habit of adding requirements to the active sprint ("while you're in that area, can you also...") 2–3 times per week. The team was technically delivering but morale was low — they never knew what they were actually building, sprint goals were meaningless, and quality was suffering because nothing was fully done before the next request arrived.

**Task:**
Address the requirement instability without damaging the relationship with the product director, who was the team's primary internal customer.

**Action:**

*Step 1 — Understand the root cause:*
Before proposing a process change, I had a 1:1 with the product director. Her perspective: she trusted the team and wanted to take advantage of "being in the code" to add quick wins. She genuinely didn't realise each change had a cost.

*Step 2 — Visualise the problem with data:*
I shared our sprint completion data: in the last 4 sprints, we had completed an average of 58% of original sprint commitments. I showed her a simple diagram: the 6 original stories, plus the 4 mid-sprint additions, and which 6 had actually been completed (a mix, nothing fully finished).

*Step 3 — Propose a system, not a rule:*
I proposed the "sprint goal is protected" model:
- Any new requirement goes on the backlog (triage during the next refinement session).
- A change within an active sprint requires an explicit swap: we add X, we remove Y of equivalent size.
- The sprint review is the designed moment for "I have new ideas" — it naturally triggers backlog discussion.

I framed this as enabling her to get more from the team, not restricting access to the team.

*Step 4 — Make it easy to comply:*
I set up a shared Jira board view showing the current sprint goal, original commitments, and what would be displaced by a mid-sprint addition. This gave the director visibility without needing to ask.

**Result:**
Within 2 sprints, the director was routing new ideas to the backlog by default. Sprint completion rate rose from 58% to 83% over the following quarter. She told her VP that the team had "become more reliable" — not realising the primary change was in the process she now followed.

## Reflection / What I'd Do Differently
I would have had the root cause conversation earlier — in week 2, not after 3 months of instability. The pattern was visible immediately; I was too conflict-averse to address it directly.

## Common Follow-up Questions
- How do you tell the difference between legitimate requirement evolution and scope creep?
- What do you do when a stakeholder refuses to follow the change process you've established?
- How do you handle an urgent mid-sprint request that genuinely cannot wait?
- How do you involve stakeholders in sprint planning to reduce mid-sprint surprises?
- What's your approach when you disagree with a product decision but are asked to implement it?
- How do you build trust with a product stakeholder who has been burned by engineering teams before?

## Common Mistakes / Pitfalls
- **Silent absorption** — absorbing every change without communicating the cost creates a burned-out team and a confused stakeholder (they don't understand why delivery slows).
- **Adversarial framing** — "stakeholders are the problem" is a bad frame; they're partners. The process should serve both parties.
- **No data** — proposing a change process without showing the cost of the current situation lacks persuasion.
- **Rigid process** — "all mid-sprint changes are banned" ignores legitimate urgency and damages trust. "All mid-sprint changes require a swap" is flexible and fair.
- **Skipping the root cause conversation** — frequent requirement changes usually have a cause (unclear goals, missed refinement, decision anxiety). Fix the cause, not just the symptom.
- **Not making the process easy** — a good process that requires effort to follow will not be followed. Visibility tools (boards, dashboards) make compliance effortless.

## References
- [Agile Manifesto — Responding to Change](https://agilemanifesto.org/)
- [Scrum Guide — Sprint Goal](https://scrumguides.org/scrum-guide.html#sprint-goal)
- [Shape Up — Basecamp](https://basecamp.com/shapeup) — appetite-driven scoping
- [User Story Mapping — Jeff Patton](https://www.jpattonassociates.com/story-mapping/) (book reference)
- [Backlog Refinement Best Practices — Atlassian](https://www.atlassian.com/agile/scrum/backlog-refinement) (verify exact URL)
