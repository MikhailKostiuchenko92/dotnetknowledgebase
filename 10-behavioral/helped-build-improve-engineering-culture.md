# Describe how you have helped build or improve an engineering culture in your organization.

**Category:** Process Improvement & Engineering Culture
**Difficulty:** 🔴 Senior
**Tags:** `engineering-culture`, `leadership`, `psychological-safety`, `practices`, `community`

## Question
> Describe how you have helped build or improve an engineering culture in your organization.

## Short Answer
When I joined a team where failure was hidden — bugs discovered in production were quietly fixed, incidents had no post-mortems, and no one asked questions in architecture reviews out of fear of looking inexperienced — I introduced blameless post-mortems, weekly learning sessions, and "question-first" code review norms. Over 6 months the incident discussion rate tripled, PRs became collaborative rather than adversarial, and two junior engineers told me they had started contributing architectural opinions for the first time.

## What the Interviewer Is Looking For

Engineering culture is one of the highest-leverage areas for a senior/staff engineer. Interviewers want to see:

- You understand that culture is changed through behaviour and systems, not just values statements.
- You've made observable, specific changes to team culture — not just described ideals.
- You understand psychological safety as a prerequisite for a high-performing engineering team.
- You think beyond your own work to the team's collective capability.

> **⚠ Note:** "I always write clean code" is not an engineering culture answer. "I model the behaviour I want to see and create systems that reinforce it" is. Culture is about collective behaviour, not individual excellence.

### Culture Change Through Behaviour and Systems

| Desired Cultural Outcome | Behaviour That Models It | System That Reinforces It |
|--------------------------|--------------------------|--------------------------|
| Blameless incident culture | Public post-mortems where you own your mistakes | Blameless post-mortem template; blame-language prohibition |
| Psychological safety | "What am I missing?" asked in public reviews | "Question-first" code review norms |
| Continuous learning | Sharing what you got wrong in team sessions | Weekly learning sessions; learning-from-failure channel |
| Quality mindset | Refusing to ship without tests in a pressured sprint | Test coverage gates in CI |
| Knowledge sharing | Writing your own discoveries in a team wiki | PR templates that require docs updates |

## Example STAR Answer

**Situation:**
I joined a 9-person team where the engineering culture was silently fearful: production bugs were fixed without post-mortems (to avoid embarrassment), no one asked questions in architecture reviews (to avoid looking uninformed), and the two most senior engineers made all decisions unilaterally.

**Task:**
I didn't have formal authority. I was a senior engineer. I could model behaviour and propose changes; I couldn't mandate them. My goal was to make it safe to be honest, ask questions, and share mistakes.

**Action:**

*Change 1 — Blameless post-mortems:*
After a production incident that was quietly fixed, I volunteered to run a post-mortem and write it up. I was explicit in the document: "Root cause: I missed the edge case in the release check. Preventive action: add this check to the pre-release checklist."

Owning my own mistake publicly changed the dynamic. Two other engineers started bringing incidents to post-mortems in the following month. Within 2 months, post-mortems were standard — not because anyone mandated them, but because I modelled that it was safe to own mistakes.

*Change 2 — Weekly "what I learned this week":*
I started a Slack thread every Friday: "This week I learned: X (and got Y wrong before understanding it)." Framing it as learning from mistakes, not just discoveries, mattered. 3–4 engineers started contributing within 2 weeks.

*Change 3 — Architecture review norms:*
In the weekly architecture review (which had been a one-person presentation to silent observers), I started asking questions deliberately — "I'm not sure I understand why we chose X approach, can someone walk through the alternatives?" — even when I did understand. This modelled that questions were welcome.

I also introduced an explicit norm: "All technical decisions should be challenged before they're ratified, not after they're built."

**Result:**
Over 6 months:
- Post-mortem rate: 0 in the 3 months before → 8 post-mortems in 6 months, team-run.
- Architecture review participation: 1–2 voices → 5–6 voices per session.
- Two junior engineers told me during 1:1s that they now contributed architectural opinions because "it feels safe to be wrong here now."
- Team retrospective sentiment scores (tracked by Scrum master): "I feel safe to raise problems" metric went from 3.1/5 to 4.4/5 in 2 quarters.

## Reflection / What I'd Do Differently
I would have had a direct conversation with the two senior engineers whose unilateral decision-making was contributing to the silence. I worked around them rather than addressing the source. Culture change is faster when you address the biggest signals directly.

## Common Follow-up Questions
- How do you improve engineering culture when you don't have formal authority?
- What is psychological safety and why does it matter for engineering team performance?
- How do you run a blameless post-mortem?
- What's the difference between a good team retrospective and a bad one?
- How do you handle a team member who actively undermines the culture you're trying to build?
- How do you measure engineering culture health?

## Common Mistakes / Pitfalls
- **Values without behaviour** — posting "we value quality" on the wall changes nothing. Behaviour changes culture.
- **Systems without modelling** — introducing a post-mortem process while senior engineers avoid blame doesn't work. Leaders must go first.
- **Mandating from above** — culture changes imposed top-down without buy-in create resentment, not genuine change.
- **Ignoring the sources of fear** — if two senior engineers are creating a culture of silence through their behaviour, addressing the systems without addressing the people is incomplete.
- **Expecting fast results** — culture change happens over months and quarters, not sprints.
- **Measuring inputs, not outcomes** — counting "post-mortems run" is a proxy; what you really want is "incident recurrence rate" and "team psychological safety score."

## References
- [Psychological Safety — Amy Edmondson, Harvard Business School](https://www.hbs.edu/faculty/Pages/item.aspx?num=54851) (verify exact URL)
- [Google Project Aristotle — re:Work](https://rework.withgoogle.com/print/guides/5721312655835136/)
- [Blameless Post-Mortems — John Allspaw / Etsy](https://www.etsy.com/codeascraft/blameless-postmortems/) (verify exact URL)
- *An Elegant Puzzle* — Will Larson (engineering culture and strategy)
- *The Five Dysfunctions of a Team* — Patrick Lencioni (trust and psychological safety in teams)
