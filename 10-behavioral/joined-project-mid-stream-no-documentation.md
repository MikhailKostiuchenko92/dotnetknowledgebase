# Tell me about a time you joined a project mid-stream with no documentation. What did you do?

**Category:** Adaptability & Change
**Difficulty:** 🟡 Middle
**Tags:** `onboarding`, `legacy-code`, `investigation`, `knowledge-transfer`, `adaptability`

## Question
> Tell me about a time you joined a project mid-stream with no documentation. What did you do?

## Short Answer
When I joined a payment processing service mid-sprint with zero documentation, I treated the codebase as the documentation: I read commit history, traced execution flows, ran the application locally, and wrote down what I discovered in a running architecture document. Within two weeks I had produced the documentation that didn't exist, and that document became the team's reference for the next year.

## What the Interviewer Is Looking For

This question tests your **self-sufficiency**, **investigation skills**, and **generosity with knowledge**. Interviewers want to see:

- You can operate and become productive in an unfamiliar, under-documented codebase.
- You use systematic approaches (commit history, tests, execution tracing) rather than just asking endless questions.
- You document your discoveries rather than keeping them in your head.
- You understand that creating documentation IS the job in this scenario, not a nice-to-have.

### Common Approaches to Undocumented Systems

| Approach | What It Reveals |
|----------|-----------------|
| Read `git log --oneline` history | Intent and evolution of key decisions |
| Find the entry point (startup, `Program.cs`) | System topology, dependencies, startup order |
| Run the tests | Intended behaviour at the component level |
| Search for `TODO / HACK / FIXME` comments | Pain points and known problems |
| Trace a critical path end-to-end | The "happy path" flow for the core business operation |
| Find the oldest, most experienced contributor | Oral history for design decisions |

## Example STAR Answer

**Situation:**
I joined a backend team to cover a developer who had left unexpectedly. The system was a payment processing service in production, handling 50k+ transactions/day. There was no architecture document, no onboarding guide, and the one remaining team member had joined only 6 months before the departed developer.

**Task:**
Get productive quickly enough to cover on-call duties within 2 weeks, and contribute to the sprint backlog within 3 weeks.

**Action:**

*Week 1 — Investigation mode:*
I cloned the repo and ran the service locally before touching anything else. I then followed a methodical discovery process:

1. **Read `git log`** for the top 5 most-changed files. This told me where the team had been spending effort and where complexity lived.
2. **Traced the payment flow end-to-end** from `POST /payments` to the database write, mapping every service, class, and integration point in a local draw.io diagram.
3. **Read all unit and integration tests** — they documented expected behaviour better than any README would have.
4. **Searched for `TODO`, `FIXME`, and `HACK`** comments. Found 11, two of which were related to a known data inconsistency in charge reconciliation — important for on-call.
5. **Met with the remaining developer for 30 minutes per day** (not a marathon dump — focused 30-minute sessions on one area each day).

*Week 2 — Documentation:*
I consolidated my notes into a `ARCHITECTURE.md` in the repo: service topology, key data flows, known gotchas, external dependencies, and on-call runbook for the 3 most common alert types.

**Result:**
I was on-call by week 2, as planned. I used my own architecture document twice during on-call incidents in that first month. The document was peer-reviewed, merged, and became the team's official reference. The engineering manager specifically noted it during my 90-day review.

## Reflection / What I'd Do Differently
I would add "architecture archaeology" to my day-1 checklist: check for any infrastructure-as-code (Terraform, Bicep, Kubernetes manifests) in addition to source code. The infrastructure layer often reveals integration points and external dependencies that the application code hides.

## Common Follow-up Questions
- How do you prioritise what to learn first when everything is unfamiliar?
- How do you balance investigation time against delivery pressure when joining mid-sprint?
- What's your approach when the code you discover is doing something fundamentally wrong?
- How would you handle it if the existing team resisted documenting because "we know how it works"?
- How do you test your own understanding of a system you've never seen before?
- What do you do when running the application locally is impossible (no local dev setup)?

## Common Mistakes / Pitfalls
- **Asking too much without investigating first** — reading code and tests before asking questions is more respected and more efficient.
- **Not documenting discoveries** — knowledge in your head doesn't help the team after you move on.
- **Ignoring tests** — existing tests are the best specification of intended behaviour in an undocumented system.
- **Trying to understand everything before contributing** — time-box your investigation; contribute small things early to build context through doing.
- **Rewrting before understanding** — the urge to "clean this up" before fully understanding it is how production bugs are introduced.
- **Skipping the commit history** — `git log` is a narrative of every decision the team ever made.

## References
- [Working Effectively with Legacy Code — Michael Feathers](https://www.goodreads.com/book/show/44919.Working_Effectively_with_Legacy_Code) (book reference)
- [Git Log Documentation — git-scm.com](https://git-scm.com/docs/git-log)
- [Code Archaeology with Git — Michał Łuczak (verify URL)](https://blog.pragmaticengineer.com/a-software-engineers-self-assessment/) — self-assessment reference, not direct link
- [Architecture Decision Records — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Onboarding Engineers — Stripe Engineering Blog](https://stripe.com/blog/engineering-onboarding) (verify exact URL)
