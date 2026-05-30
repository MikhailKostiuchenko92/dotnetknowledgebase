# Tell me about a time you had to change direction on a major project due to shifting priorities.

**Category:** Adaptability & Change
**Difficulty:** 🔴 Senior
**Tags:** `priorities`, `change-management`, `stakeholders`, `sunk-cost`, `communication`

## Question
> Tell me about a time you had to change direction on a major project due to shifting priorities.

## Short Answer
Six months into building a custom recommendation engine, the business acquired a vendor solution that made our in-house build obsolete. I was responsible for shutting down the internal project cleanly: extracting reusable components, documenting what we had learned, reassigning the team, and integrating the vendor solution instead. The hardest part was helping the team let go of work they were proud of.

## What the Interviewer Is Looking For

This is a **senior-level question** testing your ability to handle sunk-cost situations professionally. Interviewers want to see:

- You can disengage from a project you or your team are invested in, without blame or bitterness.
- You communicate the change clearly to stakeholders and the team.
- You extract value from what was built, rather than declaring it wasted.
- You understand that "change of direction" is sometimes the right technical and business decision.

> **⚠ Warning:** The sunk-cost fallacy ("we've already invested 6 months") is a trap senior engineers must actively resist. The best stories show you acknowledged the change, advocated for salvaging what you could, and helped the team move forward cleanly.

### Change-of-Direction Framework

| Phase | Key Action |
|-------|-----------|
| Receive the change | Acknowledge clearly; separate emotional from analytical reaction |
| Assess salvageable value | What components, learnings, or assets can be reused? |
| Plan the shutdown | Document everything; archive, don't delete |
| Communicate to team | Honest about the business reason; acknowledge the team's work |
| Transition | Reassign work; integrate the new direction |

## Example STAR Answer

**Situation:**
We had been building an in-house content recommendation engine for an e-learning platform for 6 months. The system was roughly 70% complete: a collaborative filtering model, a feature extraction pipeline, and an API layer. The business then acquired a SaaS recommendation vendor whose platform was immediately available and covered 90% of our use case.

**Task:**
As tech lead, I was asked by the CTO to evaluate whether to continue the in-house build or pivot to the vendor. Then, once the decision was made (pivot), I was responsible for executing the shutdown of the internal project and delivering the vendor integration.

**Action:**

*Decision phase:*
I produced a 1-page comparison for the CTO:
- **Continue in-house**: 2 months to MVP, full control, ongoing ML engineering cost.
- **Vendor pivot**: 3 weeks to integration, 80% feature parity on day one, vendor dependency risk.

I recommended the pivot, because the 3-week difference in time-to-market was significant given an upcoming partnership deadline.

*Shutdown phase:*
I ran a "knowledge harvest" session with the team: we documented every algorithm decision, dataset insight, and architecture choice in a `POST-MORTEM.md` in the repository. This was not a failure post-mortem — it was a learning archive.

I identified two reusable components: a data normalisation library and a feature extraction pipeline that could be repurposed for our analytics infrastructure. I formally proposed both to the platform team.

*Team communication:*
I held a 30-minute team meeting before any announcement went wider. I was direct: "The business has made a decision, and I supported it. Here's why." I acknowledged the quality of the work — the collaborative filtering model was genuinely impressive — and explained that good engineering that solves the wrong problem at the wrong time is still good engineering.

*Integration phase:*
I led the vendor integration over 3 weeks. We delivered on schedule, in time for the partnership deadline.

**Result:**
Vendor integration shipped on time. Two reusable components were adopted by the platform team. One engineer who was most invested in the in-house model specifically thanked me after the team meeting for being honest about the reasoning — they'd been in situations before where the team was kept in the dark.

## Reflection / What I'd Do Differently
I would push for a "build vs. buy" analysis at the start of any significant in-house tooling project — especially for ML/recommendation systems where mature vendor options exist. We lost 6 months of work that could have been 3 weeks of integration from day one.

## Common Follow-up Questions
- How do you handle a team member who refuses to accept a direction change they fundamentally disagree with?
- How do you identify which parts of shut-down work are worth salvaging vs. archiving?
- How do you manage stakeholder communication when a project change affects commitments made externally?
- What's the difference between changing direction and abandoning a commitment?
- How do you maintain team morale through repeated direction changes?
- What's your decision framework for build vs. buy?

## Common Mistakes / Pitfalls
- **Sunk-cost framing** — "we can't stop now, we've already spent 6 months" is the wrong frame. Sunk costs don't change the future cost-benefit calculation.
- **Blaming the business** — "the business changed direction again" without nuance sounds bitter. Show that you understand the business reason, even if you don't fully agree.
- **No salvage analysis** — just walking away from 6 months of work without identifying what can be reused is wasteful and demoralizing.
- **Skipping the team conversation** — announcing a project shutdown via a Jira ticket update is poor leadership.
- **Not learning from the pivot** — the best pivot stories end with "and here's what we now do differently to avoid this situation."
- **Over-dramatising** — projects change direction all the time; the best candidates treat it as business-as-usual.

## References
- [Build vs. Buy Decision Framework — Martin Fowler](https://martinfowler.com/articles/buy-vs-build.html)
- [Post-Project Reviews — retrospective practices](https://www.mountaingoatsoftware.com/blog/what-makes-a-good-sprint-retrospective) (verify exact URL)
- [Sunk Cost Fallacy — Psychology Today](https://www.psychologytoday.com/us/blog/the-art-of-self-improvement/202001/the-sunk-cost-fallacy)
- [Making Large-Scale Direction Changes — LeadDev](https://leaddev.com/) (verify exact URL)
- *An Elegant Puzzle — Systems of Engineering Management* — Will Larson (strategy and priority shifts)
