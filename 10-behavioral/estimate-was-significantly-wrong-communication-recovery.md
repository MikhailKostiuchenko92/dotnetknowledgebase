# Tell me about a time your estimate was significantly wrong. How did you communicate and recover?

**Category:** Stakeholder Management & Communication
**Difficulty:** 🟡 Middle
**Tags:** `estimation`, `communication`, `accountability`, `recovery`, `transparency`

## Question
> Tell me about a time your estimate was significantly wrong. How did you communicate and recover?

## Short Answer
I estimated a data migration task at 3 days — it took 14. The estimate was wrong because I hadn't accounted for data quality issues in the source system, which required custom transformation logic I hadn't anticipated. I communicated the overrun daily once I identified the scope, delivered a revised plan with a credible commitment, and post-mortem'd the estimation failure so I and the team could learn from it.

## What the Interviewer Is Looking For

Estimation failure is universal — every engineer gets this wrong at some point. The question is not "have you ever been wrong?" (everyone has). It's testing:

- Your **transparency** when you discover the estimate is wrong.
- Your **recovery** — do you come with a plan or just bad news?
- Your **accountability** — do you own it or blame the unknown variables?
- Your **learning** — what did you change so it doesn't happen the same way again?

> **⚠ Warning:** "I worked overtime to make up the time without telling anyone" hides risk from stakeholders and usually fails anyway. The strong answer is early, honest communication with a recovery plan.

### Estimation Recovery Framework

| Step | Action |
|------|--------|
| Detect | Recognise that the estimate is wrong as early as possible |
| Communicate | Inform stakeholders immediately — before being asked |
| Explain | What made the estimate wrong? (Not as an excuse — as a learning for everyone) |
| Revised plan | Give a new estimate with explicit assumptions and a confidence interval |
| Deliver on revised estimate | The revised commitment is the one that must be met |
| Post-mortem | What will you do differently to avoid this class of estimation error? |

## Example STAR Answer

**Situation:**
I was assigned a data migration task: move 18 months of order history from a legacy system to our new data warehouse. I estimated 3 days based on the table schema, row count, and a quick look at the source data. The migration was on the critical path for a reporting feature with a committed demo date in 2 weeks.

**Task:**
Complete the migration on time, or manage the situation if it became clear the timeline wasn't achievable.

**Action:**

*Day 1 — Discovery:*
I started the migration. Within 4 hours, it became clear that approximately 30% of records had data quality issues: nulls in required fields, inconsistent date formats across 3 different export generations, and foreign key references to deleted records. None of this was visible from the schema alone.

*Day 1, afternoon — Communicate immediately:*
I told the PM the same day: "My 3-day estimate is wrong. I've found data quality issues I didn't anticipate. I need 2 days to understand the full scope before I can give you a revised estimate. I'll update you at end of day tomorrow."

I did not wait until I had a perfect picture. I gave a realistic "I need time to re-assess" timeframe.

*Day 3 — Revised estimate with explicit assumptions:*
I delivered a revised estimate: 14 days total (11 remaining). I included:
- A breakdown of where the extra time was going (data cleaning rules: 6 days; re-running and validating: 3 days; buffer for unknown issues: 2 days).
- The specific assumptions the 14-day estimate rested on.
- An option for a partial migration (clean records only) in 4 days that would cover 70% of the data — usable for the demo.

The PM chose the partial migration for the demo, with the full migration following.

*Post-mortem with the team:*
After delivery, I held a 30-minute team session on estimation for data migration tasks. The learning: always sample the source data before estimating a migration. A 2-hour data audit would have revealed the quality issues upfront.

**Result:**
Demo held on schedule with 70% data (acceptable to the stakeholder). Full migration completed on the revised schedule. The data audit step became a standard pre-estimation task for any migration work.

## Reflection / What I'd Do Differently
My original 3-day estimate was based on schema and row count — neither of which tells you anything about data quality. I would now always include a "data quality spike" in migration estimates: sample 1,000 records, identify data issues, add transformation time. The 2-hour spike would have changed my estimate from 3 days to something closer to 8 days — still wrong, but much closer.

## Common Follow-up Questions
- How do you estimate complex tasks with high uncertainty?
- What's the difference between an estimate and a commitment?
- How do you prevent a wrong estimate from being treated as a hard commitment?
- What estimation techniques do you use (story points, T-shirt sizes, time-based)?
- How do you build buffer or contingency into estimates without sandbagging?
- What do you do when you're asked for an estimate before you have enough information to give one confidently?

## Common Mistakes / Pitfalls
- **Hiding the overrun** — working late in secret without communicating removes the stakeholder's ability to adjust. And it usually fails anyway.
- **Communicating too late** — "I found out yesterday that this will take 3 more weeks" is worse than "I found out 2 weeks ago and here's the plan."
- **Blame-shifting** — "the data quality was terrible" is factually true but unhelpful. Own the failure to identify the data quality risk upfront.
- **No revised plan** — "I was wrong, I'm sorry" without a recovery plan creates panic.
- **Overly optimistic revised estimate** — the revised commitment is the one you will be held to. Be conservative.
- **No post-mortem** — the same estimation failure will recur if you don't change something about the process.

## References
- [Software Estimation — Steve McConnell](https://www.construx.com/resources/software-estimation-demystifying-the-black-art/) (book reference)
- [Agile Estimating and Planning — Mike Cohn](https://www.mountaingoatsoftware.com/books/agile-estimating-and-planning)
- [Three-Point Estimation — PMI](https://www.pmi.org/) (optimistic / most likely / pessimistic range)
- [Estimation Anti-Patterns — Jacob Kaplan-Moss](https://jacobian.org/2021/may/25/estimation/) (verify exact URL)
- *Thinking, Fast and Slow* — Daniel Kahneman (planning fallacy and estimation biases)
