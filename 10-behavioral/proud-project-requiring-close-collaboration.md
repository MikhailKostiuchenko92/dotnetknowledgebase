# Describe a project you're proud of that required close collaboration.

**Category:** Collaboration & Teamwork
**Difficulty:** 🟢 Junior
**Tags:** `collaboration`, `pride`, `teamwork`, `delivery`, `product-development`

## Question
> Describe a project you're proud of that required close collaboration.

## Short Answer
I'm proud of building a real-time inventory allocation system that required tight daily collaboration between backend, frontend, QA, and operations. What made it special was that we shipped it on time with zero P1 bugs — because the team had built shared ownership of the quality bar, not just individual responsibility for their own lane.

## What the Interviewer Is Looking For

This question gives you a chance to show **enthusiasm, collaboration instinct**, and **project pride** — all positive signals. It's a 🟢 Junior question, so interviewers primarily want:

- You can describe specific collaboration dynamics, not just "we worked well together."
- You can articulate *what you contributed* without minimising others.
- You genuinely care about the product and the team's outcome.
- You understand that great projects require great teamwork, not just individual heroism.

### What Makes a Collaboration Story Compelling

| Element | Why It Matters |
|---------|---------------|
| Specific interactions | "I learned X from [role]" is more vivid than "we worked together" |
| Shared challenge | Something that required multiple roles to solve together |
| Your specific contribution | What did *you* bring to the collaboration? |
| Team outcome | A result the whole team could be proud of |

> **⚠ Note:** It's fine for this story to be from a previous job, a side project, or even a university group project — what matters is that you can describe real collaboration dynamics.

## Example STAR Answer

**Situation:**
I worked on a new inventory reservation system for an e-commerce platform. When customers added items to their cart, the system needed to temporarily reserve inventory for 15 minutes to prevent overselling. This required coordination between the backend API I was building, the frontend team handling the cart UX, QA automating the edge cases, and the operations team who managed the warehouse integration.

**Task:**
I was one of two backend engineers. My specific responsibility was the reservation state machine and the expiry background job.

**Action:**
The project required close cross-disciplinary collaboration from day one:

**With the frontend team:** I shared an early Swagger spec so they could mock the API and begin building cart UI in parallel. We had a 15-minute "API sync" three times per week to align on any changes. When I needed to add a `conflictReason` field to the reservation response, I consulted the frontend developer before adding it to understand how it would be surfaced to users — their feedback changed the field design.

**With QA:** I invited the QA engineer into my planning session for the expiry job because race conditions in expiry logic are notoriously hard to test after the fact. Together, we designed the test harness that could simulate time acceleration for expiry tests. This meant QA had 90% of their automation ready before the feature was complete.

**With operations:** The warehouse integration had a 5-second polling delay that I initially wasn't aware of. An early call with the ops engineer revealed this constraint, which changed my reservation state design — I added a "pending confirmation" state to handle the polling window.

**Result:**
Shipped on time, with zero P1 bugs in the first 30 days of production. The project became an internal reference for how to run cross-functional delivery.

## Reflection / What I'd Do Differently
I would involve operations even earlier — ideally in the initial design phase, not just once I'd begun implementation. The polling delay they knew about should have been in the architecture from day one.

## Common Follow-up Questions
- What specifically are you most proud of about your contribution to this project?
- What would have happened if one of the teams had been unavailable or uncooperative?
- What was the hardest moment of the collaboration and how did you get through it?
- What did you learn about collaboration from this project that you apply today?
- How did the team celebrate or acknowledge the success?
- Is there anything about the project you would have done differently, in hindsight?

## Common Mistakes / Pitfalls
- **Claiming all the credit** — "I built X" when the question is about collaboration signals poor self-awareness.
- **Generic praise** — "the team was great" is not a story. Describe specific interactions and dynamics.
- **No tension or challenge** — projects with no friction or difficulty are boring. Mention what was hard.
- **No personal contribution** — you need to describe what *you* specifically brought to the team.
- **Forgetting to explain why you're proud** — the emotional note is part of the question. Share genuine enthusiasm.
- **Choosing a story that was actually solo work** — if close collaboration wasn't essential, find a different example.

## References
- [Working Agreement for Agile Teams — Atlassian](https://www.atlassian.com/team-playbook/plays/working-agreements) (verify exact URL)
- [OpenAPI Specification — Swagger](https://swagger.io/specification/)
- [The Five Dysfunctions of a Team — Patrick Lencioni](https://www.tablegroup.com/product/dysfunctions/) (book reference)
- [STAR Interview Method — Indeed Career Advice](https://www.indeed.com/career-advice/interviewing/star-interview-questions)
- [Agile Retrospectives — Making Good Teams Great](https://pragprog.com/titles/dlret/agile-retrospectives/) (book reference)
