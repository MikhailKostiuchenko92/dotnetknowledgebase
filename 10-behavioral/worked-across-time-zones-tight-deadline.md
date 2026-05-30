# Tell me about a time you worked across time zones on a tight deadline.

**Category:** Remote Work & Distributed Teams
**Difficulty:** 🟡 Middle
**Tags:** `distributed-teams`, `timezones`, `remote-work`, `coordination`, `deadlines`

## Question
> Tell me about a time you worked across time zones on a tight deadline. How did you coordinate?

## Short Answer
For a 3-week integration sprint with a team split across London and Bangalore (5.5 hour difference), I set up a daily 30-minute overlap window, established async daily logs so each team arrived knowing exactly where the other had left off, and front-loaded blocking questions to the morning so the other team could answer before I finished my day. The sprint delivered on time with zero coordination-related delays.

## What the Interviewer Is Looking For

This question tests your ability to **manage distributed work effectively under time pressure**. Interviewers want to see:

- You have practical, concrete strategies for distributed coordination.
- You understand that time zone gaps require coordination systems, not just good intentions.
- You've actually navigated a time zone challenge — not just described what you would do.
- You optimise for the system (how do we hand off cleanly?) not just individual effort (I worked long hours).

### Cross-Timezone Coordination Strategies

| Strategy | Description |
|----------|-------------|
| Overlap window | Identify and protect the daily overlap time for synchronous decisions |
| Async handoff log | End-of-day notes: what I finished, what I need from you, what you should start |
| Front-load blockers | Raise blocking questions early in your day (before EOD at the other location) |
| Design for handoff | Structure work so each location owns a complete slice, minimising handoff points |
| Shared board visibility | Real-time status visible to both teams: in-progress, blocked, done |
| Overlap for decisions | Schedule architecture decisions for overlap time; don't push them to async |

## Example STAR Answer

**Situation:**
We had a 3-week sprint to integrate our .NET API with a third-party CRM system. Our team: 3 engineers in London (me included), 2 integration specialists in Bangalore. 5.5-hour time difference. The CRM vendor had a hard go-live date — no flexibility.

**Task:**
Coordinate the integration work across locations and time zones such that the sprint delivered on time, with no delays caused by handoff friction or coordination failures.

**Action:**

*Step 1 — Establish the overlap:*
London morning (9 AM) = Bangalore afternoon (2:30 PM). I scheduled a daily 30-minute sync at 9 AM London time. Agenda was fixed: what was completed yesterday, what's blocked, what's starting today. The meeting was strictly timeboxed — no design discussions; those were handled async before the meeting.

*Step 2 — Daily async handoff log:*
I created a simple Notion page with a table: Date | London team | Bangalore team | Blockers. Each team wrote a 3–5 line update at end of their day. When London arrived in the morning, we had full context on what Bangalore had done without waiting for a meeting.

*Step 3 — Front-load blocking questions:*
My personal rule: any question or blocker I identified in the afternoon (London time) got raised by 2 PM at the latest — leaving 1.5 hours before Bangalore's end of day (their 7:30 PM). This eliminated overnight waits on blockers.

*Step 4 — Design for independent delivery:*
I split the integration work into components with clear interfaces: Bangalore owned the CRM data model mapping and the outbound sync; London owned the inbound events and the API layer. We shared a clear contract document (JSON schema + API spec). Each team could proceed independently and would only need to integrate at the final stage.

*Handling a real coordination challenge:*
In week 2, Bangalore discovered an undocumented CRM API field that changed the data model. This was a shared dependency. I held an emergency call at our overlap time (9 AM London / 2:30 PM Bangalore), we agreed the model change in 20 minutes, and each team updated independently the same day.

**Result:**
Sprint delivered on time. 0 delays attributable to coordination gaps. The Bangalore team lead's retrospective comment: "The handoff log was the most useful thing — we knew exactly where London left off every morning."

## Reflection / What I'd Do Differently
I would create the handoff log template before the sprint started, not in week 1 when we'd already lost one morning to "what did they finish yesterday?" The setup cost is trivial; the benefit is immediate.

## Common Follow-up Questions
- What's your approach when you're the only person in your time zone on a distributed team?
- How do you make time zone-distributed architecture decisions without everyone being online simultaneously?
- What's the risk of "always on" culture in distributed teams and how do you avoid it?
- How do you handle a distributed team where one location consistently delivers less than expected?
- How do you maintain team cohesion and trust across time zones?
- What tools have you used for asynchronous distributed collaboration?

## Common Mistakes / Pitfalls
- **"I worked longer hours to cover the overlap"** — sustainable coordination systems beat heroic effort.
- **No explicit handoff** — assuming the other team knows where you left off is the most common distributed team failure.
- **Meeting-first coordination** — scheduling a meeting for everything in a distributed team creates meeting overhead that kills productivity.
- **Not front-loading blockers** — raising a question at EOD that won't be answered for 14 hours wastes a full day.
- **One-size communication** — urgent issues need synchronous escalation; routine updates should be async. Mixing the two creates noise.
- **Timezone insensitivity** — scheduling every meeting at a time convenient for your location creates resentment in the other location.

## References
- [GitLab Remote Collaboration Handbook](https://about.gitlab.com/handbook/communication/)
- [Working Across Time Zones — HBR](https://hbr.org/2009/12/managing-a-virtual-team) (verify exact URL)
- [Notion — Team Handoff Templates](https://www.notion.so/templates) (verify exact URL)
- *Remote: Office Not Required* — Fried & Hansson
- [Async Work Guide — Basecamp](https://basecamp.com/guides/how-we-communicate)
