# Tell me about a time you advocated for slowing down to do something right, and the outcome.

**Category:** Dealing with Pressure & Tight Deadlines
**Difficulty:** 🔴 Senior
**Tags:** `quality`, `advocacy`, `engineering-culture`, `technical-debt`, `leadership`

## Question
> Tell me about a time you advocated for slowing down to do something right, and the outcome.

## Short Answer
I pushed back on a plan to ship a security feature without penetration testing because the business deadline "wasn't flexible." I made the risk quantifiable: exposure to GDPR fines if a vulnerability was exploited. The PM changed course. The pen test found two medium-severity issues. Slowing down for a week saved what could have been months of incident response.

## What the Interviewer Is Looking For

This is a **senior-level engineering leadership question**. Interviewers want to see:

- You have the professional courage to advocate for doing the right thing when it's inconvenient.
- You make the case with evidence and risk analysis, not just professional preference.
- You accept the outcome gracefully when overruled, while ensuring the risk is documented.
- You validate your position — what actually happened as a result of slowing down?

### The Right Way to Advocate for Slowing Down

| Step | Example |
|------|---------|
| Identify the specific risk | "Missing pen test means X vulnerability class won't be caught" |
| Quantify the business cost | "GDPR fine exposure up to €20M or 4% of revenue" |
| Propose a bounded delay | "One additional week covers pen test and fix cycle" |
| Offer the alternative | "If we can't delay, we need to de-scope the feature until it's tested" |
| Document if overruled | Risk register entry; written acknowledgment from decision-maker |

> **⚠ Warning:** Advocating for slowing down repeatedly without results signals you're not influencing effectively. Show that your advocacy changed the decision or that you learned how to make your case more effectively.

## Example STAR Answer

**Situation:**
We were shipping a new user authentication flow — SSO integration with external providers — on a tight Q2 deadline. The product manager had confirmed to the CTO that it would be live by a specific date. Four weeks before launch, I raised that we had not included time for penetration testing or security review.

**Task:**
I was the tech lead. The authentication flow handled login, session management, and token storage — three of the most security-sensitive areas of our product. I believed shipping without a security review was a material risk.

**Action:**

*Step 1 — Make the risk concrete:*
Rather than saying "we need pen testing because it's best practice," I wrote a 1-page risk brief:
- The feature handles OAuth tokens — a common vector for session hijacking and CSRF attacks.
- Our GDPR data processor agreement required us to implement "appropriate technical measures" before handling EU user authentication.
- A breach through an authentication vulnerability would require notifying regulators within 72 hours — GDPR fine exposure proportional to the severity.

*Step 2 — Quantify the delay:*
I got a quote from our security vendor: 3 days for a focused pen test. With remediation buffer: 1 week total.

*Step 3 — Present options:*
I requested 30 minutes with the PM and CTO. I presented:
- Option A: Delay by 1 week, pen test, launch clean.
- Option B: Launch as planned but de-scope external SSO (reduce the attack surface); add SSO after pen test.
- Option C: Launch as planned and accept the risk in writing.

They chose option A.

**Result:**
Pen test completed. Two medium-severity findings: one CSRF token implementation gap and one refresh token rotation issue. Both fixed before launch. The PM later told me "you saved us from a bad news story."

## Reflection / What I'd Do Differently
I would build a security review step into our Definition of Done for any feature involving authentication, payments, or personal data — so this isn't a reactive advocacy moment each time, but a standard pre-launch gate.

## Common Follow-up Questions
- What do you do when your advocacy to slow down is rejected and the product ships anyway?
- How do you avoid being seen as the person who always slows things down?
- When is slowing down the wrong decision, despite quality concerns?
- How do you document a rejected risk recommendation to protect yourself professionally?
- What's your threshold for escalating a "slow down" recommendation beyond the PM to the CTO or CEO?
- Have you ever advocated for slowing down and been wrong — i.e., the risk didn't materialise?

## Common Mistakes / Pitfalls
- **Vague risk framing** — "we should be careful" is not advocacy. Specific risk + quantified business impact is.
- **Recurring objections without influence** — if you always advocate and are always overruled, examine why your case isn't landing.
- **No alternative path** — always offer an alternative: de-scope, delay, or feature flag — not just "we can't ship."
- **Losing gracefully** — if overruled, document the risk, confirm the decision, and execute professionally.
- **Perfectionism framing** — "it's not perfect yet" is not a valid reason to delay; "it has a specific, quantified risk" is.
- **No outcome validation** — show what happened as a result of slowing down (or not slowing down if overruled).

## References
- [OWASP OAuth 2.0 Security — OWASP](https://owasp.org/www-project-cheat-sheets/cheatsheets/OAuth_Cheat_Sheet.html)
- [GDPR Notification Requirements — ICO](https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/personal-data-breaches/)
- [Risk Register — PMI](https://www.pmi.org/learning/library/risk-register-four-keys-managing-risks-8470) (verify exact URL)
- [Security Development Lifecycle — Microsoft](https://www.microsoft.com/en-us/securityengineering/sdl)
- *The Phoenix Project* — Kim, Behr, Spafford (book reference — constraint theory, DevOps culture)
