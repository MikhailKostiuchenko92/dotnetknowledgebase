# Tell me about a time requirements changed mid-project. How did you handle it?

**Category:** Adaptability & Change
**Difficulty:** 🟡 Middle
**Tags:** `requirements`, `change-management`, `agile`, `adaptability`, `communication`

## Question
> Tell me about a time requirements changed mid-project. How did you handle it?

## Short Answer
Mid-way through building a reporting module, the business pivoted from daily to real-time reporting requirements. Instead of rewriting everything, I assessed what could be reused, identified the architectural gap (polling model vs. event-driven), and presented a phased plan: deliver the daily reports on schedule, then migrate to real-time in the next sprint. Requirements change — the skill is absorbing the change without throwing away everything done so far.

## What the Interviewer Is Looking For

This question tests your **adaptability**, **technical flexibility**, and **stakeholder communication skills**. Interviewers want to see:

- You respond to requirements changes with assessment, not panic.
- You identify what can be preserved vs. what must be rebuilt.
- You communicate the impact of the change honestly and give stakeholders real options.
- You understand that requirements change is normal, not a failure.

### Responding to Mid-Project Requirements Changes

| Step | Description |
|------|-------------|
| Assess scope of change | What exactly changed? Does it affect architecture, data model, or just logic? |
| Evaluate impact | How much of what's built is still valid? |
| Present options | Full change now, phased change, minimum viable change? |
| Communicate costs | What does absorbing the change cost in time, quality, or scope? |
| Decide and adapt | Get alignment, then execute cleanly |

> **⚠ Warning:** "We had to change everything and started over" suggests poor architecture or poor communication with the business earlier. The strongest stories show that a well-designed system can absorb reasonable changes with bounded cost.

## Example STAR Answer

**Situation:**
I was 3 weeks into a 5-week project to build a product analytics dashboard. The original requirement: nightly batch reports (data refreshed at midnight). At week 3, the product team announced that a key client needed near-real-time data updates (every 5 minutes) for their operations team.

**Task:**
I needed to assess how much of my completed work was still viable, communicate the impact to the PM, and deliver a plan for absorbing the change.

**Action:**

*Step 1 — Assess what changed and what didn't:*
I spent 2 hours mapping the original design against the new requirement:
- Database schema: still valid — no changes needed.
- Data aggregation logic: still valid for the nightly version; would need a streaming variant for real-time.
- API layer: still valid.
- Infrastructure: the batch job (Azure Function with Timer Trigger) would need a companion streaming processor (Azure Function with Service Bus trigger).

Approximately 70% of completed work was still usable. The main gap was infrastructure and a new aggregation path.

*Step 2 — Present options:*
I met with the PM and presented three options:
- **Option A** (full pivot): Implement real-time only. 3-week additional effort. Original timeline slips by 2 weeks.
- **Option B** (phased): Deliver daily reports as planned (original timeline). Deliver real-time updates 2 sprints later.
- **Option C** (hybrid): Deliver daily reports + basic 15-minute polling cache for real-time feel, then upgrade to true real-time streaming in sprint N+2.

I recommended option B for its minimal risk and immediate value delivery.

**Result:**
PM chose option C — the client would accept 15-minute refresh as a starting point. I delivered the dashboard with polling cache on the original timeline. The streaming migration shipped 3 weeks later.

## Reflection / What I'd Do Differently
I would include a "how fresh does this data need to be?" question in the initial requirements gathering for any dashboard or reporting feature. "Real-time" vs. "daily batch" is a foundational architectural decision — discovering it at week 3 is avoidable with one upfront question.

## Common Follow-up Questions
- How do you prevent requirements from changing mid-project?
- At what point is a requirements change so significant that you need to escalate and possibly stop the project?
- How do you maintain team morale when requirements keep shifting?
- How do you design software to better accommodate future requirements changes?
- What's the difference between scope creep and legitimate requirements evolution?
- How do you protect your estimate and timeline when requirements change?

## Common Mistakes / Pitfalls
- **"We just had to restart"** — a well-designed system should absorb reasonable changes without full restart.
- **No options presented** — saying "we need more time because requirements changed" gives the PM nothing to decide on.
- **Blaming the business** — requirements change is a feature of software development, not a failure of product management.
- **No assessment first** — diving into adaptation without understanding the scope of the change wastes time.
- **Passive acceptance** — "I just did what they asked" doesn't show the analytical thinking and communication the question is looking for.
- **Missing the upfront lesson** — the best answer includes what you now ask upfront to prevent mid-project pivots.

## References
- [Managing Requirements Change — Agile Alliance](https://www.agilealliance.org/glossary/change/)
- [Event-Driven Architecture — Microsoft Learn](https://learn.microsoft.com/en-us/azure/architecture/guide/architecture-styles/event-driven)
- [Azure Function Triggers — Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-functions/functions-triggers-bindings)
- [Shape Up — Basecamp](https://basecamp.com/shapeup) — appetite-based scoping to limit mid-project changes
- *Agile Estimating and Planning* — Mike Cohn (book reference — planning for change)
