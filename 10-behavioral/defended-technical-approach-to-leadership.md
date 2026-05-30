# Tell me about a time you had to defend a technical approach to leadership.

**Category:** Stakeholder Management & Communication
**Difficulty:** 🟡 Middle
**Tags:** `leadership`, `communication`, `influence`, `technical-advocacy`, `persuasion`

## Question
> Tell me about a time you had to defend a technical approach to leadership.

## Short Answer
When I recommended a message broker over a database-polling approach for our new integration pipeline, the engineering director questioned whether the added complexity was justified given our team size. I presented a structured comparison on the three dimensions that mattered most to him — operational overhead, delivery guarantees, and scalability — and showed that the broker's complexity cost was a 1-week investment with a 2-year payoff. He approved it.

## What the Interviewer Is Looking For

This question tests **technical advocacy** — your ability to stand behind a technical recommendation when challenged by someone with authority. Interviewers want to see:

- You don't capitulate under authority pressure when you have solid technical reasoning.
- You listen carefully to the objection and address it specifically, not just repeat your original argument.
- You frame technical arguments in terms that matter to leadership (cost, risk, speed, simplicity).
- You know how to disagree and commit: you advocate strongly, but once the decision is made, you execute with full commitment.

> **⚠ Note:** This is different from a conflict resolution question. The question is about defending a technical stance to someone with formal authority over the decision — not resolving a peer disagreement.

## Example STAR Answer

**Situation:**
I was proposing an Azure Service Bus-based integration pipeline to replace a polling-based database approach. The polling approach was simple but had known reliability and scalability problems. Service Bus added operational complexity (dead-letter handling, message ordering, concurrency configuration).

The engineering director challenged the proposal in the architecture review: "We're a team of 6. Do we really need a message broker? Can't we just fix the polling approach?"

**Task:**
Defend the Service Bus recommendation with data, not just preference, and either persuade him or genuinely update my thinking if his challenge revealed a blind spot.

**Action:**

*Listen first — understand the actual objection:*
I asked a clarifying question: "Is your concern primarily the operational overhead of running a message broker, or is it the team's familiarity with the tooling, or something else?" He confirmed it was operational overhead — he was worried about the team's on-call burden.

*Address the specific concern, not the generic debate:*
I prepared a focused response to the on-call overhead concern:
- Azure Service Bus is a managed service — no infrastructure to run. The operational surface was dead-letter queue monitoring and message ordering configuration, not broker operations.
- I quantified: 1 week of setup vs. the current polling approach's known issue rate (2 incidents/month, average 4 hours each to investigate).

*Acknowledge the trade-off honestly:*
I said: "You're right that this is more complex than polling. The question is whether that complexity is worth the reliability improvement and the elimination of 8 hours/month of on-call investigation. I think it is, but if the team's bandwidth is the constraint, Option B is a targeted fix to the polling approach."

I presented Option B: fixing the specific known failure modes in the polling approach. I was honest: it was cheaper short-term, and I genuinely didn't know which was right without more discussion.

*The conversation:*
The director asked two more questions (both on the on-call side). I answered both with specific data from our existing on-call records. He approved Service Bus.

**Result:**
Service Bus implementation shipped in 2 weeks. In 6 months: zero integration incidents related to the pipeline (vs. the previous 2/month). The director referenced the discussion in a team retrospective as an example of "data-backed technical advocacy."

## Reflection / What I'd Do Differently
I would prepare the decision document in writing before the architecture review, not just as a verbal presentation. Written documents allow leadership to review asynchronously, ask questions with more context, and engage more analytically. Verbal-only presentations can feel more like debate, which makes it easier for authority dynamics to override technical substance.

## Common Follow-up Questions
- How do you handle it when leadership overrules a technical decision you strongly disagree with?
- What's the difference between advocating for a technical approach and being stubborn?
- How do you decide when to stop defending your approach and commit to the decision made?
- How do you build credibility with leadership so your technical recommendations carry weight?
- What do you do when you realise mid-discussion that the challenge has revealed a genuine flaw in your approach?
- How do you disagree in a way that maintains a collaborative relationship with leadership?

## Common Mistakes / Pitfalls
- **Capitulating under authority pressure** — changing your recommendation because the director pushed back, without new information, signals weak conviction.
- **Not listening to the actual objection** — defending against the wrong concern wastes everyone's time.
- **Being inflexible** — if the challenge reveals a genuine gap, updating your recommendation shows intellectual honesty, not weakness.
- **Jargon-heavy defense** — leadership questions are usually about cost, risk, and simplicity. Answer in those terms.
- **No written backup** — verbal debates rely on memory and presence; a written decision document survives the meeting.
- **"Because it's best practice"** — never defend a technical choice with authority appeal. Defend it with specific evidence relevant to your context.

## References
- [Architecture Decision Records — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Disagree and Commit — Amazon Leadership Principles](https://www.aboutamazon.com/about-us/leadership-principles) (verify exact URL)
- [Azure Service Bus — Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-messaging-overview)
- *Staff Engineer: Leadership Beyond the Management Track* — Will Larson (technical advocacy patterns)
- *Radical Candor* — Kim Scott (challenging directly while caring personally)
