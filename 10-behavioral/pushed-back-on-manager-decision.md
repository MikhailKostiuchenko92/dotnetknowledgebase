# Tell me about a time you pushed back on a decision made by your manager and what happened.

**Category:** Conflict & Disagreement
**Difficulty:** 🔴 Senior
**Tags:** `conflict`, `leadership`, `upward-feedback`, `courage`, `technical-judgment`

## Question
> Tell me about a time you pushed back on a decision made by your manager and what happened.

## Short Answer
I pushed back by preparing a concise written summary of my concerns — risks, alternatives, and trade-offs — and requested a private conversation rather than challenging the decision publicly. I framed it as "here's what I'm seeing from the technical trenches" rather than "you're wrong." Most managers welcome well-reasoned dissent delivered respectfully; what they don't welcome is grandstanding.

## What the Interviewer Is Looking For

This is a **senior-level question** about courage, professional judgment, and organisational maturity. Interviewers want to see:

- You have the backbone to voice concerns even when it's uncomfortable.
- You know *how* to push back — privately, with evidence, with respect.
- You understand the difference between advocating and undermining.
- You can **disagree and commit** once a decision is made and your concern is heard.

### Dimensions Being Assessed

| Dimension | What a Strong Answer Shows |
|-----------|---------------------------|
| Courage | You actually raised the concern, not just thought about it |
| Preparation | You backed your position with data or concrete reasoning |
| Tone | You were direct without being insubordinate or passive-aggressive |
| Maturity | Once the decision was made — even if against your advice — you executed fully |

> **⚠ Warning:** This question is a trap for both extremes. "I never push back on my manager" signals you lack spine. "I fought the decision until I won" signals you're difficult. Show the middle path.

## Example STAR Answer

**Situation:**
My manager decided to skip integration tests for a critical payment gateway migration because the sprint deadline was tight and they felt the manual QA pass was "good enough." This was a system processing €2M/day.

**Task:**
I strongly disagreed — the payment gateway had edge cases around currency rounding and idempotency keys that were notoriously difficult to catch manually. I needed to make my case without undermining my manager's authority or embarrassing them in front of the team.

**Action:**
I asked for 15 minutes that afternoon — one-on-one, not in standup. I came prepared with a two-page document: three specific scenarios our integration tests covered that manual QA was likely to miss, an estimate of the remediation cost if one of those slipped to production (based on a previous incident), and a concrete proposal — a subset of the most critical integration tests we could run in 4 hours instead of the full 8-hour suite.

My manager heard me out, pushed back initially on the timeline, and we negotiated: I would run the smoke test subset in parallel while QA was testing. They signed off on the extra 4 hours.

**Result:**
The truncated integration suite caught one idempotency bug that would have caused duplicate charges for approximately 3% of transactions during high load. The full rollout proceeded without incident the following week. My manager later mentioned this episode when advocating for me in my performance review.

## Reflection / What I'd Do Differently
I should have established a standing practice of "minimum integration coverage" for payment-path changes earlier, so this conversation never needed to happen as a last-minute push. Reactive firefighting is less effective than proactive quality standards embedded in the team's definition of done.

## Common Follow-up Questions
- What if your manager had rejected your pushback and proceeded anyway — would you have escalated further?
- Have you ever pushed back on a decision and later realised your manager was right?
- How do you handle it when you strongly disagree with a company-level decision you had no input on?
- What's the difference between pushing back and being insubordinate?
- How do you "disagree and commit" — fully executing on a decision you think is wrong?
- How has your approach to upward feedback changed as you've become more senior?

## Common Mistakes / Pitfalls
- **Public pushback** — challenging a manager's decision in a standup or group meeting is almost always the wrong move.
- **Emotion over evidence** — "I just had a bad feeling about it" is not a compelling argument. Use data.
- **No outcome** — tell the interviewer what actually happened, including whether the decision changed.
- **Showing bitterness** — if the manager proceeded despite your pushback, show you executed professionally anyway.
- **Escalating too fast** — going over your manager's head before having a direct conversation signals poor judgment.
- **Winning every time** — if you always push back and always succeed, you may sound like you're rewriting history.

## References
- [How to Disagree with Your Boss — Harvard Business Review](https://hbr.org/2016/09/how-to-disagree-with-your-boss)
- [Disagree and Commit — Jeff Bezos, Amazon Shareholder Letter 2016](https://www.aboutamazon.com/news/company-news/2016-letter-to-shareholders) (verify exact URL)
- [Speaking Truth to Power at Work — MIT Sloan Management Review](https://sloanreview.mit.edu/) (verify exact URL)
- *The Manager's Path* — Camille Fournier (book reference, chapter on being managed)
- [Psychological Safety — Amy Edmondson](https://hbr.org/2023/02/what-is-psychological-safety) (verify exact URL)
