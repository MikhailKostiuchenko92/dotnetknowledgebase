# Describe how you communicate technical risk to product managers or business owners.

**Category:** Stakeholder Management & Communication
**Difficulty:** 🔴 Senior
**Tags:** `risk-communication`, `stakeholders`, `technical-risk`, `influence`, `product-management`

## Question
> Describe how you communicate technical risk to product managers or business owners.

## Short Answer
My formula: translate technical risk into business impact, quantify probability and consequence where possible, and present options rather than just alarms. "This service has no retry logic on the payment gateway call" means nothing to a PM. "If the gateway call fails — which happens roughly once per 500 requests — we currently lose that payment silently, with no retry and no alert" is actionable.

## What the Interviewer Is Looking For

This question tests **senior engineering communication** — specifically the ability to help non-technical decision-makers make informed decisions about risk. Interviewers want to see:

- You translate technical risk into business terms (revenue, customer experience, compliance, reputation).
- You're specific about probability and consequence, not vague ("there might be issues").
- You present options, not just problems — you're a partner, not an alarm system.
- You understand that the business owner has the right to accept risk; your job is to ensure they understand what they're accepting.

### Risk Communication Template

| Component | Example |
|-----------|---------|
| **What could go wrong** | "The scheduled job has no idempotency check" |
| **Business consequence** | "A duplicate run would charge some customers twice" |
| **Probability** | "Our infrastructure restarts happen roughly once per 2 weeks; in each case a duplicate run is possible" |
| **Current detection** | "We would only find out when a customer complains" |
| **Options** | "Fix now (2-day effort), add monitoring now and fix next sprint, or accept and prepare a support playbook" |

> **⚠ Warning:** Communicating risk without options puts the business owner in an impossible position. They can't make a decision if the only option you've given them is "it's risky." Present at least two ways to address the risk, including accepting it with mitigation.

## Example STAR Answer

**Situation:**
During a sprint review, I discovered that our newly deployed order processing pipeline had no retry logic on its call to the 3rd-party shipping label API. The API had an SLA of 99.5%, meaning it was unavailable roughly 2 hours per month. During those windows, our orders would fail silently — no error to the customer, no alert to operations, no retry.

**Task:**
Communicate this risk clearly to the PM (who owned the product roadmap) and the Head of Operations (who owned the customer experience), and get alignment on how to address it before the next peak period (Black Friday, 3 weeks away).

**Action:**

*Frame the risk in business terms:*
I prepared a 5-slide summary for a 20-minute meeting:

**Slide 1 — What the risk is:**
"Our order confirmation pipeline sends shipping labels to our logistics partner. If their API is unavailable, orders are silently abandoned — no label created, no customer notification, no operations alert."

**Slide 2 — How often this happens:**
"Their API SLA is 99.5%. That's ~2 hours of unavailability per month. At our current order rate, that's approximately 40–60 orders per incident."

**Slide 3 — What a customer experiences:**
"They receive an order confirmation email, their card is charged, and then... nothing. No shipping notification. They contact support, which manually investigates and discovers the pipeline failure."

**Slide 4 — Options:**
- **Option A** (fix now): Add retry + dead-letter queue + alert. 3 days of work. Zero silent failures.
- **Option B** (monitor first, fix next sprint): Add an alert only. Operations is notified within minutes and can manually retry. 4-hour effort.
- **Option C** (accept with playbook): Document the scenario and a support response runbook. Zero engineering effort but risk accepted.

**Slide 5 — My recommendation:**
Option A, given Black Friday timing. 3 days now vs. 40–60 affected customers per incident at peak.

*The meeting:*
The PM immediately prioritised Option A into the current sprint. The Head of Operations asked to be added to the alert notification list (which we added as part of Option A anyway).

**Result:**
Retry + alerting shipped before Black Friday. During the week of Black Friday, the shipping label API had a 45-minute outage. The queue backed up, retried successfully when the API recovered, all orders processed, zero customer-facing failures.

## Reflection / What I'd Do Differently
I would add a recurring "risk register review" to our quarterly planning cycle, so risks like this are caught proactively rather than discovered by accident. A 30-minute quarterly review of known risks is significantly cheaper than discovering them during a peak period.

## Common Follow-up Questions
- How do you prioritise technical risks when there are many and not all can be fixed immediately?
- What do you do when a product manager accepts a risk you believe is unacceptable?
- How do you track accepted risks so they're not forgotten?
- What is a risk register and when do you use one?
- How do you communicate ongoing risk during an active incident?
- How do you balance transparency about technical risk with not alarming stakeholders unnecessarily?

## Common Mistakes / Pitfalls
- **Technical framing** — "we have no idempotency on the retry handler" is not a risk communication; it's an implementation detail.
- **Alarmism without options** — "this is a critical risk and could break everything" without options is noise, not signal.
- **Over-quantifying vague data** — claiming "0.001% failure rate" with no actual measurement data destroys credibility.
- **Under-communicating consequences** — "there could be some failures" is not the same as "40–60 customers per incident will have their orders silently abandoned."
- **Single-option presentation** — presenting only the engineering fix as the option removes the business owner's agency. They may choose to accept the risk with good reason.
- **No follow-up** — communicating a risk is step one; confirming the decision and tracking its execution is step two.

## References
- [Risk Management in Software Projects — PMI](https://www.pmi.org/) (verify exact URL)
- [Non-Abstract Large Scale Design — Google SRE Workbook](https://sre.google/workbook/non-abstract-design/) (verify exact URL)
- [Azure Service Bus Dead-Letter Queue — Microsoft Learn](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-dead-letter-queues)
- [Polly — .NET Resilience Library](https://www.pollydocs.org/)
- *Thinking in Bets* — Annie Duke (probability-based risk communication)
