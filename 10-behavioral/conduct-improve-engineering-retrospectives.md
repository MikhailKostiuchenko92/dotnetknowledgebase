# Describe how you conduct or improve engineering retrospectives.

**Category:** Process Improvement & Engineering Culture
**Difficulty:** 🔴 Senior
**Tags:** `retrospectives`, `agile`, `process-improvement`, `psychological-safety`, `facilitation`

## Question
> Describe how you conduct or improve engineering retrospectives.

## Short Answer
The most important thing I changed about retrospectives was making them action-oriented and psychologically safe. I introduced a rule: every retro ends with at most 3 action items, all owned by specific people with a due date. And I introduced anonymous input for sensitive topics. The result: retrospectives went from "vent sessions that changed nothing" to the most productive 60 minutes in the team's sprint.

## What the Interviewer Is Looking For

This question tests your understanding of retrospectives as a **continuous improvement tool**, not just a ritual. Interviewers want to see:

- You understand the mechanics of a good retrospective (safety, breadth, focus, action).
- You've improved a retrospective format that was dysfunctional in some way.
- You know how to facilitate psychological safety for retrospective discussions.
- You understand that retrospectives with no follow-through are worse than no retrospectives (they breed cynicism).

### Common Retrospective Dysfunctions and Fixes

| Dysfunction | Symptom | Fix |
|-------------|---------|-----|
| No psychological safety | Same 2 people talk; everyone else silent | Anonymous input round; "Vegas rule" (what's said here stays here) |
| No action items | Good discussion, no outcomes | Max 3 actions; each owned by a named person with a due date |
| Action item graveyard | Actions raised but never done | Review previous actions first; if not done, discuss why |
| Same issues every sprint | Recurring complaints about unchanged problems | Root cause analysis on recurring items; escalate if team can't resolve |
| Too long | Engineers stop attending or zone out | Timeboxed sections; async input before the meeting |

## Example STAR Answer

**Situation:**
I joined a team that ran fortnightly retrospectives as a ritual: a Scrum master collected "what went well / what didn't / what to improve" on sticky notes, the team discussed for 60 minutes, and the notes were saved in Confluence. Three months of retrospective notes showed the same 4 themes recurring with no resolution. Engineers had started skipping the retro because "nothing changes anyway."

**Task:**
Reform the retrospective to make it produce real outcomes, while addressing the psychological safety gap that was silencing most of the team.

**Action:**

*Problem 1 — No psychological safety:*
I introduced async anonymous input via a shared Google Form (anonymous, team-only access), sent 24 hours before the meeting. Engineers filled it out privately before the session. The facilitator used the aggregated themes as the starting point — not open-floor discussion.

This immediately surfaced issues that had never been raised publicly: a frustration with unclear sprint goals (mentioned by 4 of 7 engineers anonymously, never once raised in the room).

*Problem 2 — Action item quality:*
Previous action items were vague: "improve communication," "be more careful with estimates." I introduced a strict format:

> **Action:** [Specific action] | **Owner:** [Name] | **Done when:** [Measurable outcome] | **Due:** [Date]

Example: "Action: Add sprint goal statement to all sprint boards. Owner: Scrum master. Done when: Sprint goal is visible in the Jira board header for sprint N+1. Due: Next sprint start."

*Problem 3 — No action review:*
I added a 10-minute "previous actions review" at the start of every retro. Actions not completed were discussed: was it the wrong action? Was there a blocker? Do we still care?

*Format (60 minutes):*
1. Previous actions review — 10 min
2. Async inputs review (themed by Scrum master before meeting) — 15 min
3. Discuss top 3 themes by vote — 25 min
4. Define actions (max 3) — 10 min

**Result:**
- Average actions completed per sprint: 0.8 (from previous retros) → 2.6.
- Attendance rate: 5/7 engineers → 7/7.
- The recurring "unclear sprint goal" theme was resolved within 2 sprints after becoming visible.
- Engagement survey Q "Our retrospectives help us improve": 2.4/5 → 4.1/5 over 3 months.

## Reflection / What I'd Do Differently
I would introduce a retrospective format rotation after the first 3 months — same structure gets stale. Formats like "Sailboat," "Start/Stop/Continue," or "4Ls" keep the session fresh and surface different types of insight. Variety in format prevents retrospective fatigue.

## Common Follow-up Questions
- What's the difference between a retrospective and a post-mortem?
- How do you handle a senior engineer who dominates the retrospective discussion?
- What do you do when the team's top retrospective issue is outside their control (e.g., external dependencies)?
- How do you keep retrospectives feeling safe when there are real interpersonal tensions in the team?
- How do you run a retrospective for a distributed/remote team?
- What retrospective formats do you like and why?

## Common Mistakes / Pitfalls
- **No action items** — a retrospective that ends with "good discussion" and no actions is a vent session.
- **Vague action items** — "improve communication" can't be executed or measured.
- **No action follow-up** — the fastest way to kill retrospective culture is to raise actions sprint after sprint and never complete them.
- **One-size-fits-all format** — the same sticky-note format every sprint for years produces diminishing returns.
- **Facilitator as participant** — the facilitator should manage time and draw out quiet voices, not advocate for their own view.
- **Too many actions** — 10 actions per retro means 10 things that get deprioritised. Max 3, actually done, is more valuable.

## References
- [Retrospectives Guide — Agile Alliance](https://www.agilealliance.org/glossary/heartbeatretro/)
- [Agile Retrospectives: Making Good Teams Great — Larsen & Derby](https://pragprog.com/titles/dlret/agile-retrospectives/) (book reference)
- [Google Project Aristotle — re:Work](https://rework.withgoogle.com/print/guides/5721312655835136/) (psychological safety)
- [Sailboat Retrospective Format](https://www.funretrospectives.com/sailboat-boat/) (verify exact URL)
- [Scrum Guide — Sprint Retrospective](https://scrumguides.org/scrum-guide.html#sprint-retrospective)
