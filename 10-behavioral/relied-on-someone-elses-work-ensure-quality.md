# Describe a situation where you had to rely on someone else's work. How did you ensure quality?

**Category:** Collaboration & Teamwork
**Difficulty:** 🟡 Middle
**Tags:** `collaboration`, `quality`, `dependency-management`, `trust`, `contracts`

## Question
> Describe a situation where you had to rely on someone else's work. How did you ensure quality?

## Short Answer
My service depended on a teammate's search API that wasn't yet complete. Instead of waiting and hoping, I agreed on a contract early — an OpenAPI spec — wrote integration tests against a mock, and scheduled checkpoint reviews. When the real API was ready, my integration tests caught two deviations from the contract immediately. Shared contracts eliminate surprises.

## What the Interviewer Is Looking For

This question assesses your **professional trust practices**, **dependency management**, and ability to **ensure quality without controlling others**. Interviewers want to see:

- You don't just assume dependencies will be fine — you create checkpoints.
- You establish shared contracts rather than discovering mismatches at integration time.
- You maintain a collaborative relationship while still holding a quality bar.
- You can work in parallel with dependencies that aren't complete yet.

### Dependency Management Strategies

| Strategy | When to Use |
|----------|-------------|
| Contract-first (OpenAPI, Protobuf) | API integration between services or teams |
| Mock the dependency early | Allows parallel development and decoupling |
| Integration test at the boundary | Catches drift between expectation and reality |
| Regular checkpoint reviews | Aligns on changes before they surprise you |
| Shared Definition of Done | Agree on acceptance criteria before work starts |

> **⚠ Warning:** This question is not about distrust. Frame your approach as professional engineering practice, not surveillance of a colleague.

## Example STAR Answer

**Situation:**
I was building a product recommendation engine that depended on a search relevance API being built by a colleague on another squad. The search API was estimated to take 3 weeks; my integration layer was estimated at 2 weeks. There was a risk that my work would be done but blocked, or that I would make assumptions about the API shape that turned out to be wrong.

**Task:**
I needed to deliver my component on time while managing the dependency risk. I also needed to maintain a positive working relationship with my colleague — not create a dynamic where they felt scrutinised.

**Action:**

*Step 1 — Agree on a contract upfront:*
In week 1, I met with my colleague and we co-authored an OpenAPI spec for the search API. This took about 2 hours. The spec defined request/response shapes, error codes, and pagination contract.

*Step 2 — Build against a mock:*
I used WireMock.Net to stub the search API locally. This let me build and test my recommendation engine against a known, stable interface without waiting for the real API.

*Step 3 — Checkpoint reviews:*
We agreed on two "contract review" checkpoints: end of week 1 and end of week 2. At each, my colleague shared what had changed in the implementation vs. the spec. One field (`relevanceScore`) changed from `float` to `decimal` — a small breaking change we caught during week 2 review, not at integration time.

*Step 4 — Integration test at the boundary:*
Once the real API was available, I ran my integration test suite against it. Two tests failed: a pagination edge case and an error response shape that differed from the contract. Both were fixed within a day.

**Result:**
Integration completed with zero surprises at delivery time. What could have been a 2-day integration debugging session took 3 hours. My colleague appreciated the early contract work because it also helped them clarify their own API design earlier.

## Reflection / What I'd Do Differently
I would make contract-first API design a standard practice for any cross-team dependency, not something we do ad-hoc when I'm concerned. It adds a small upfront investment and saves a disproportionate amount of downstream rework.

## Common Follow-up Questions
- How do you handle it when someone else's work is late and it's blocking you?
- What do you do when the dependency owner changes the contract after you've built against it?
- How do you balance trusting a colleague's work against your own quality standards?
- Have you ever been in a dependency situation that went badly despite your best efforts?
- How do you handle dependencies on external teams (outside your engineering department)?
- What's your approach when the dependency is a third-party service with no contract guarantees?

## Common Mistakes / Pitfalls
- **No proactive structure** — "I trusted them to deliver what I needed" is not a quality strategy.
- **Making it about distrust** — frame your practices as professional engineering norms, not monitoring.
- **No shared contract** — verbal agreements about API shapes always drift. Show you used a written artifact.
- **Waiting for the dependency to be complete** — parallel development with mocks is a senior-level technique.
- **No integration testing** — unit tests can't catch contract drift; integration tests at the boundary can.
- **Missing the relationship story** — how did you maintain a collaborative working relationship while managing quality?

## References
- [Contract Testing with Pact — Pact Foundation](https://pact.io/)
- [WireMock.Net — HTTP API Mocking for .NET](https://github.com/WireMock-Net/WireMock.Net)
- [Consumer-Driven Contract Testing — Martin Fowler](https://martinfowler.com/articles/consumerDrivenContracts.html)
- [OpenAPI Specification — Swagger](https://swagger.io/specification/)
- [Testing Pyramid — Martin Fowler](https://martinfowler.com/bliki/TestPyramid.html)
