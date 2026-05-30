# Describe how you balance pragmatism vs. perfectionism in your engineering decisions.

**Category:** Problem Solving & Technical Decisions
**Difficulty:** 🔴 Senior
**Tags:** `pragmatism`, `perfectionism`, `technical-debt`, `trade-offs`, `engineering-judgment`

## Question
> Describe how you balance pragmatism vs. perfectionism in your engineering decisions.

## Short Answer
My frame is "good enough for now, easy to change later." I make the simplest design that solves the current problem well, but I invest in properties — tests, clean interfaces, good naming — that make future changes safe and fast. The goal isn't perfect code today; it's not regretting the code you shipped 6 months from now.

## What the Interviewer Is Looking For

This is a **seniority and judgment** question. Interviewers want to see:

- You've moved past the perfectionism of early career and have a mature framework for calibrating quality.
- You understand that both extremes (ship anything, never ship because it's not perfect) are failure modes.
- You make context-dependent decisions: production criticality, reversibility, team ownership, and time horizon all factor in.
- You've had real experiences on both ends of the spectrum — over-engineering and under-engineering — and learned from them.

> **⚠ Warning:** "I'm always pragmatic, I ship fast" signals low quality standards. "I always take the time to do things right" signals slow delivery and difficulty prioritising. The best answer calibrates to context.

### The Pragmatism Calibration Framework

| Dimension | Lean Pragmatic | Lean Thorough |
|-----------|---------------|--------------|
| **Production risk** | Low — internal tool, non-critical | High — payments, auth, data integrity |
| **Reversibility** | Easy to change later | Hard or expensive to change (DB schema, public API) |
| **Lifespan** | Short-lived (prototype, spike) | Long-lived (core domain model, platform service) |
| **Ownership** | You alone, for now | Shared by team; other teams depend on it |
| **Customer visibility** | Internal only | Customer-facing, contractual SLA |

## Example STAR Answer

**Situation:**
I was working on two parallel workstreams: (1) a data export feature for an internal operations team with a 1-week deadline, and (2) a new authentication module for our customer-facing API.

**Task:**
Deliver both on different quality bars, demonstrating contextual judgment rather than applying one standard to everything.

**Action:**

*Feature 1 — Data export (lean pragmatic):*
This was a one-off CSV export for the ops team, used weekly by 5 internal users. I used an existing LINQ-to-CSV library, wrote a single service class with no abstraction layer (just direct implementation), added a smoke test, and shipped in 3 days.

What I accepted: no dependency injection for the CSV library, no interface, no generic reuse point. The code is straightforward but not elegant.

What I refused to skip: the smoke test (it exports real data — I had to verify correctness), proper error handling for malformed records, and security check (ops team members had the right access level).

*Feature 2 — Authentication module (lean thorough):*
Authentication is a security boundary, hard to change after clients depend on it, and the consequences of getting it wrong (credential leak, broken client auth) are severe.

I invested: proper interface design (`ITokenIssuer`, `ITokenValidator`), full unit and integration test coverage, an ADR for the token algorithm choice (RS256 over HS256), and peer review from 2 engineers before merging.

What I refused to gold-plate: I didn't build a token rotation service or a custom PKCE flow before they were needed. "We might need this later" is not a reason to build it today.

*The framework I use:*
For every significant code decision, I ask:
- **What's the blast radius if this is wrong?** (Auth: high. CSV export: low.)
- **How reversible is this decision?** (DB schema: not reversible. Service method: very reversible.)
- **Who else will depend on this?** (Published API: many. Internal tool: one team.)

**Result:**
Both features shipped. The data export has needed 2 minor changes in 18 months — both took under 30 minutes. The authentication module has had 3 significant extensions — all made safely without architectural changes, because the interfaces were solid.

## Reflection / What I'd Do Differently
Early in my career I leaned too far toward perfectionism — spending a week on code that would be replaced in a month. The correction was the realisation that "tests + clean interfaces" buys most of the safety you actually need, at a fraction of the cost of gold-plating the entire implementation.

## Common Follow-up Questions
- How do you handle it when a teammate has a different quality threshold than you?
- What do you do when a manager pushes to skip testing to ship faster?
- How do you recognise over-engineering in your own code before it ships?
- What is technical debt and when is it acceptable to incur it deliberately?
- How do you decide when a "good enough" solution has become a liability that needs to be replaced?
- What's your definition of "done"?

## Common Mistakes / Pitfalls
- **False dichotomy** — framing the choice as "fast and dirty" vs. "slow and perfect" misses the middle: "deliberate, contextual."
- **Perfectionism dressed as professionalism** — "I take pride in my code" is not a calibration framework; it's a reason for over-investment.
- **Pragmatism as an excuse** — "we had to move fast" used to justify code with no tests or error handling in production-critical paths.
- **Applying one standard everywhere** — a 5-user internal ops tool and a customer-facing payment endpoint are not the same risk class.
- **No criteria for the decision** — if you can't articulate what factors drove the quality level you chose, you're improvising, not exercising judgment.
- **Not paying down deliberate debt** — incurring technical debt is sometimes right; not scheduling its repayment is always wrong.

## References
- [Technical Debt — Ward Cunningham / Martin Fowler](https://martinfowler.com/bliki/TechnicalDebt.html)
- [YAGNI — Martin Fowler](https://martinfowler.com/bliki/Yagni.html)
- [The Pragmatic Programmer — Hunt & Thomas](https://pragprog.com/titles/tpp20/the-pragmatic-programmer-20th-anniversary-edition/) (book reference)
- [Boring Technology — Dan McKinley](https://mcfunley.com/choose-boring-technology)
- [Software Design X-Rays — Adam Tornhill](https://pragprog.com/titles/atevol/software-design-x-rays/) (book reference on code complexity prioritisation)

[See also: Balanced Technical Debt Against Feature Delivery](balanced-technical-debt-against-feature-delivery.md)
