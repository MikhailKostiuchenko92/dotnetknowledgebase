# Tell me about a time you had to convince a skeptical team to adopt a new practice or tool.

**Category:** Conflict & Disagreement
**Difficulty:** 🔴 Senior
**Tags:** `influence`, `change-management`, `technical-leadership`, `adoption`, `culture`

## Question
> Tell me about a time you had to convince a skeptical team to adopt a new practice or tool.

## Short Answer
I don't rely on authority to drive adoption — I make the case with data, remove the friction to try it, and let results do the persuading. I start with a limited pilot with a willing teammate, document what improved, then present the findings to the broader team. Engineers trust evidence from colleagues far more than top-down mandates.

## What the Interviewer Is Looking For

This is a **senior-level influence and change-management question**. Interviewers want to see:

- You understand that technical change is as much human change as it is technical.
- You build coalitions rather than forcing adoption.
- You address the *reasons* for skepticism, not just dismiss them.
- You measure outcomes — not just "did they use it?" but "did it improve things?"

### Dimensions Being Assessed

| Dimension | What a Strong Answer Shows |
|-----------|---------------------------|
| Empathy | You understood why the team was skeptical and took that seriously |
| Strategy | You had a structured adoption plan, not just enthusiasm |
| Evidence | You used metrics to validate the value of the change |
| Patience | You allowed the team to come to the conclusion themselves |

> **⚠ Warning:** The worst version of this story is "I pushed it through anyway because I knew I was right." Show genuine engagement with the team's concerns.

## Example STAR Answer

**Situation:**
I joined a team of five developers where there were no automated integration tests — only unit tests. The team had attempted integration testing twice before and abandoned it because the tests were slow and flaky. The prevailing opinion was "integration tests don't work here."

**Task:**
I believed the root cause was a lack of test infrastructure (no test containers, no shared fixtures) rather than the concept being invalid. I needed to change a deep-seated cultural belief, not just introduce a tool.

**Action:**
I started by listening: I ran one-on-ones with each team member to understand their specific frustrations. I got three consistent themes: tests were slow (30+ minutes), tests broke on environment changes (DB schema drift), and nobody owned fixing flaky tests so they were ignored.

I didn't propose "let's do integration tests again." Instead, I proposed a small, bounded experiment: I would spend two days writing three integration tests for our most bug-prone service (the order processing flow) using Testcontainers for .NET and a proper test fixture pattern. No commitment from the team beyond reviewing the result.

At the end of two days, I demoed: the three tests ran in under 90 seconds using Testcontainers, caught a real regression I had planted deliberately, and were simple enough to read without a testing background. I documented the patterns and posted them in a shared "testing playbook" document.

Two volunteers from the team picked up the approach. Over the next month, coverage grew to 40 integration tests. After two instances where tests caught production bugs before deployment, the remaining skeptics opted in.

**Result:**
Six months later: 180 integration tests, CI pipeline under 8 minutes, and the team self-reported in our retrospective that they felt "much more confident shipping." The practice is now part of our Definition of Done.

## Reflection / What I'd Do Differently
I would involve a skeptical team member as a co-author of the initial experiment — not just a reviewer of my result. Co-authorship generates ownership in a way that demos alone cannot. The person most resistant often becomes the biggest advocate when they help design the solution.

## Common Follow-up Questions
- What if the team had remained skeptical even after the pilot showed results?
- How do you handle a team that tries the new practice inconsistently and then blames the practice for problems?
- What's your approach when the tool you want to introduce costs money and you need budget approval?
- How do you manage adoption across multiple teams, not just one?
- What's the difference between a "best practice" and an "imposed standard"?
- How do you decide when to stop pushing for a change you believe in?

## Common Mistakes / Pitfalls
- **"I showed them why they were wrong"** — this framing signals poor emotional intelligence. Lead with listening, not lecturing.
- **No pilot / proof of concept** — abstract arguments rarely convince engineers. A working example does.
- **Ignoring legacy concerns** — if the team has burned their hands on this before, you must address those specific past failures, not just sell the new thing.
- **No measurement** — "the team liked it" is not a result. Quantify the improvement (test run time, bug escape rate, cycle time).
- **Skipping the skeptics** — the most resistant person is often the most influential. Engage them directly, not last.
- **Big bang adoption** — mandating team-wide adoption before proving value is the fastest way to kill trust in the change.

## References
- [Testcontainers for .NET — Official Docs](https://dotnet.testcontainers.org/)
- [Diffusion of Innovations — Everett Rogers](https://en.wikipedia.org/wiki/Diffusion_of_innovations) (book reference)
- [How to Champion a New Idea at Work — HBR](https://hbr.org/2019/02/how-to-champion-a-new-idea-at-work) (verify exact URL)
- *Team Topologies* — Matthew Skelton & Manuel Pais (book reference, chapter on enabling teams)
- [Accelerate — Nicole Forsgren, Jez Humble, Gene Kim](https://itrevolution.com/product/accelerate/) — data on what engineering practices improve performance
