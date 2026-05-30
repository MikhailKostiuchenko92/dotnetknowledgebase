# Tell me about a time you disagreed with a teammate's technical decision.

**Category:** Conflict & Disagreement
**Difficulty:** 🟡 Middle
**Tags:** `conflict`, `technical-decision`, `communication`, `collaboration`

## Question
> Tell me about a time you disagreed with a teammate's technical decision.

## Short Answer
I focus on facts and outcomes, not personalities. I raised my concern privately first with evidence to back it up — benchmarks, maintainability scenarios, or concrete risk analysis — then brought it to a team forum. We either aligned on a better solution or found a third option together that neither of us had initially considered.

## What the Interviewer Is Looking For

This question probes your **technical credibility**, **emotional intelligence**, and **team-player mindset**. Interviewers want to see:

- You can **disagree without being disagreeable** — professional, fact-based pushback.
- You listen actively and can update your view when presented with new evidence.
- You escalate constructively rather than letting disagreements fester.
- You distinguish between "I prefer X" (opinion) and "X causes Y measurable problem" (evidence).

### Dimensions Being Assessed

| Dimension | What a Strong Answer Shows |
|-----------|---------------------------|
| Technical depth | You understood *why* the decision was problematic, not just that you disliked it |
| Influence | You persuaded with reasoning, not authority or volume |
| Empathy | You respected your teammate's perspective and acknowledged the merit in their idea |
| Outcome | Something measurable improved, or you learned from being wrong |

> **⚠ Warning:** Never name the person or make them look bad. Frame the story around the technical trade-off, not the individual.

## Example STAR Answer

**Situation:**
At my previous company, a teammate proposed switching our internal messaging abstraction from a custom `IMessageBus` interface to raw `System.Threading.Channels` used directly in every service — essentially removing the abstraction layer entirely.

**Task:**
I was responsible for the shared infrastructure libraries. I believed this would introduce tight coupling across 12 microservices to a concrete implementation, making future transport changes expensive.

**Action:**
Instead of raising this immediately in PR comments — which tends to escalate into a thread — I scheduled a 30-minute one-on-one with my teammate. I prepared a short document with three concrete scenarios where the change would require touching all 12 services simultaneously. I also explicitly acknowledged the strengths of their proposal: it removed an extra indirection layer and improved code discoverability.

In the conversation, we identified a middle ground: keep the `IMessageBus` interface, but replace its internal implementation from `BlockingCollection<T>` to `System.Threading.Channels` — addressing the throughput concern that originally motivated the change.

**Result:**
The refactored version was merged without friction. Load tests showed approximately a 40% improvement in message throughput. More importantly, the interface boundary proved valuable eight months later when we migrated the underlying transport to Azure Service Bus with a single implementation swap.

## Reflection / What I'd Do Differently
I would write a brief trade-off document upfront as standard practice for any significant technical disagreement, rather than relying on ad-hoc PR comment debates. Async text debates rarely produce alignment; a structured discussion with shared written context is far more effective.

## Common Follow-up Questions
- What if your teammate had rejected your argument and gone ahead anyway — how would you have handled it?
- Have you ever lost a technical argument and later been vindicated? What did you do?
- How do you decide when a technical disagreement is worth escalating to your manager?
- What's the line between a personal preference and a genuine engineering principle?
- How do you handle repeated disagreements with the same colleague?
- How do you ensure a resolved disagreement doesn't leave lingering resentment?

## Common Mistakes / Pitfalls
- **Vague resolution** — "We talked it through and found a solution" tells the interviewer nothing. Specify exactly what you said and did.
- **Making the teammate the villain** — interviewers will flag this as a poor collaboration signal immediately.
- **No measurable outcome** — "I raised the concern and it was noted" is weak. Show what actually changed.
- **Always being right** — if every story ends with "I was correct," you appear inflexible. Be willing to share a story where you updated your view.
- **Avoidance framing** — "I decided it wasn't worth the fight" is a red flag for any senior or lead role.
- **Missing the merits of the opposing view** — a strong candidate acknowledges what was *right* about the other proposal.

## References
- [STAR Interview Method — Indeed Career Advice](https://www.indeed.com/career-advice/interviewing/star-interview-questions)
- [How to Disagree with Your Colleagues — Harvard Business Review](https://hbr.org/2016/05/how-to-have-difficult-conversations) (verify exact URL)
- *Cracking the Coding Interview*, 6th ed. — Behavioral Questions chapter (Gayle Laakmann McDowell)
- [System.Threading.Channels — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/extensions/channels)
- [Radical Candor — Kim Scott](https://www.radicalcandor.com/our-approach/) — framework for honest, caring feedback
