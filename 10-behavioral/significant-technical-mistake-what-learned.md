# Tell me about a significant technical mistake you made. What happened and what did you learn?

**Category:** Failure & Mistakes
**Difficulty:** 🟡 Middle
**Tags:** `failure`, `learning`, `accountability`, `debugging`, `growth`

## Question
> Tell me about a significant technical mistake you made. What happened and what did you learn?

## Short Answer
I shipped a caching bug to production that returned stale pricing data for a subset of users. I owned it immediately, communicated the scope, deployed a fix within two hours, and wrote a post-mortem. The lesson wasn't just about cache invalidation — it was about the absence of observable alerts that would have caught it sooner.

## What the Interviewer Is Looking For

This is a **self-awareness and growth question**. Interviewers are not trying to catch you — they want to see:

- You can admit mistakes clearly, without excessive self-flagellation or excuse-making.
- You demonstrate **ownership** — not blame-shifting to processes, tools, or teammates.
- You **learn systemically** — the lesson is about improving the system, not just "I'll be more careful next time."
- You recover effectively under pressure.

### Dimensions Being Assessed

| Dimension | What a Strong Answer Shows |
|-----------|---------------------------|
| Honesty | You describe a real mistake, not a disguised success story |
| Accountability | "I" did this — not "we" or "the system" |
| Analytical thinking | You diagnosed the root cause accurately, not just the surface symptom |
| Growth | The change you made afterward was structural, not just behavioural |

> **⚠ Warning:** The most common failure in this question is choosing a "humble brag" — a mistake so minor it sounds like a success. Choose a real mistake with real impact. Interviewers see through sanitised stories.

> **⚠ Warning 2:** Avoid blaming anyone else. Even if others were involved, focus entirely on your actions and your learning.

## Example STAR Answer

**Situation:**
I introduced a distributed cache layer (Redis) for product pricing lookups to reduce database load. I implemented it using absolute expiration — cache keys expired after 30 minutes regardless of whether the underlying price had changed.

**Task:**
The feature went through code review and QA without issues. I was responsible for the implementation and the deployment.

**Action (what went wrong):**
Three days after deployment, a pricing manager reported that some users were seeing outdated prices after a manual price update. I investigated and found that prices updated via the admin portal were not invalidating the corresponding cache keys — the invalidation code I wrote targeted the wrong key format (it prefixed keys with the user ID, but the product lookup used the product ID as the key root).

**What I did:**
I immediately flagged the issue in the team channel, documented the scope (estimated ~4% of sessions in the prior 3 days), deployed a hotfix within 90 minutes that invalidated the full price cache on any admin update, and sent a status update to the product manager and pricing team with an ETA.

After the fix was stable, I wrote a post-mortem. Root causes identified: (1) the key naming convention wasn't documented, (2) we had no test asserting that admin price updates invalidated the cache, (3) we had no alerting on cache hit rate anomalies that would have surfaced the stale data pattern within minutes.

**Result:**
The hotfix resolved the issue with no data corruption (prices are reference data, not transactional). The post-mortem resulted in three concrete improvements: a documented key naming convention, integration tests for cache invalidation paths, and a Redis hit rate dashboard with alert thresholds.

## Reflection / What I'd Do Differently
I would define cache key naming as an explicit design document before writing a single line of code. It's the kind of decision that seems trivial — until it breaks silently in production. I also now treat "what happens when this is wrong?" as a required design question for every cache layer I build.

## Common Follow-up Questions
- How do you distinguish between a mistake and a learning experience?
- What did you change about your personal process after this mistake?
- Have you ever made the same mistake twice? What does that tell you about learning from failure?
- How do you communicate a mistake to your manager when you're not sure of the full scope yet?
- What does a good post-mortem look like to you?
- How do you prevent yourself from being defensive when discussing past mistakes in performance reviews?

## Common Mistakes / Pitfalls
- **Choosing a trivial mistake** — "I once forgot a semicolon" is not a significant technical mistake. The story needs real stakes.
- **The humble brag** — "I worked too hard and burned myself out" is not a technical mistake.
- **Blame-shifting** — "the system was poorly designed" or "no one told me" removes your agency from the story.
- **No systemic improvement** — "I'll be more careful next time" is not a lesson. What did you change in the process or tooling?
- **Excessive self-criticism** — the story should end with learning and recovery, not ongoing guilt.
- **Vague impact** — "some users were affected" is weak. Quantify where possible (4% of sessions, 2-hour window, €X revenue at risk).

## References
- [Post-Mortem Template — PagerDuty](https://postmortems.pagerduty.com/) (verify exact URL)
- [Blameless Post-Mortems — Google SRE Book](https://sre.google/sre-book/postmortem-culture/)
- [Redis Cache Invalidation Strategies — Microsoft Learn](https://learn.microsoft.com/en-us/azure/architecture/patterns/cache-aside)
- [STAR Interview Method — Indeed Career Advice](https://www.indeed.com/career-advice/interviewing/star-interview-questions)
- *The Phoenix Project* — Kim, Behr, Spafford (book reference — learning from failure at team level)
