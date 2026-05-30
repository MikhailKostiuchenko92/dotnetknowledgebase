# Describe a time you introduced or improved CI/CD practices on your team.

**Category:** Process Improvement & Engineering Culture
**Difficulty:** 🔴 Senior
**Tags:** `cicd`, `devops`, `automation`, `pipelines`, `github-actions`, `azure-devops`

## Question
> Describe a time you introduced or improved CI/CD practices on your team.

## Short Answer
When I joined a team that was deploying via manual SSH scripts and shared credentials, I introduced a GitHub Actions CI/CD pipeline with environment-specific approvals, secret management via Azure Key Vault, and automated integration tests as a deployment gate. Deployment time went from 40 minutes to 6 minutes, the "only two people know how to deploy" problem was eliminated, and we went from 2 deploys/week to on-demand deploys within the first month.

## What the Interviewer Is Looking For

CI/CD is a **core engineering practice** at senior level. Interviewers want to see:

- You understand the end-to-end flow: source control → build → test → deploy → monitor.
- You've improved a real CI/CD pipeline, not just consumed one someone else built.
- You know the key quality gates: fast feedback on pull requests, blocked deploys on test failure, environment-specific approvals.
- You understand the security aspects: secrets management, least-privilege service principals, audit trails.

### CI/CD Maturity Levels

| Level | Characteristics |
|-------|-----------------|
| 0 — Manual | Deploy by SSH script; shared credentials; single person who knows the process |
| 1 — Basic CI | Automated build + unit tests on PR; no automated deployment |
| 2 — CI + CD to non-prod | Automated deploy to staging; manual production deploy |
| 3 — Full CI/CD | Automated deploy to all environments with quality gates and approvals |
| 4 — Continuous Deployment | Automated production deploy on every merged PR (no manual approval) |

## Example STAR Answer

**Situation:**
I joined a 5-developer team that had been deploying a .NET API and a React frontend via a custom bash script that:
- Required SSH access to the production server with a shared key stored in a team Slack channel
- Was executed only by the two most senior developers (knowledge bottleneck)
- Included no automated tests; testing was manual pre-deploy
- Took approximately 40 minutes to execute, mostly waiting

The team was doing 2 deploys per week because the process was painful and risky.

**Task:**
Modernise the CI/CD pipeline to remove the manual process, the knowledge bottleneck, and the security risk — while increasing deployment frequency.

**Action:**

*Phase 1 — Secure the secrets:*
The shared SSH key in Slack was the highest-risk item. I provisioned an Azure service principal with minimum necessary permissions (read/write to the specific resource group only), stored its credentials in Azure Key Vault, and configured GitHub Actions to access Key Vault via managed identity — no static secrets in environment variables.

*Phase 2 — Build the CI pipeline:*
GitHub Actions workflow triggered on every PR:
- .NET build
- Unit tests (existing 47 tests)
- Integration tests against a test database (new — I wrote 12 integration tests for the critical paths)
- Test coverage report (configured minimum 70% — lower than ideal, but a realistic baseline)

*Phase 3 — Build the CD pipeline:*
Two pipelines:
- `deploy-staging`: triggered on merge to `main`, automatically deploys to staging, runs smoke tests.
- `deploy-production`: triggered manually, requires approval from 2 engineers (GitHub environment protection rule), deploys to production.

*Phase 4 — Team enablement:*
I ran a 1-hour team session on the new pipeline, walked through the approval flow, and showed how to read pipeline failures. I also wrote a 2-page runbook for troubleshooting common pipeline issues.

**Result:**
- Deployment time: 40 minutes → 6 minutes.
- All 5 engineers can now deploy independently (vs. 2 before).
- Deploy frequency: 2/week → 8–10/week (on-demand, low friction).
- Security: shared SSH key in Slack removed; all access audited via Azure AD.
- Defect escape rate: 2 post-deploy bugs/month → 0 in the first 3 months (integration tests catching issues pre-deploy).

## Reflection / What I'd Do Differently
I would add deployment analytics from day one: deploy frequency, change failure rate, and mean time to recovery — the DORA metrics. I measured the improvement retrospectively, which was harder than if I'd established baseline metrics before starting.

## Common Follow-up Questions
- What is the difference between Continuous Integration, Continuous Delivery, and Continuous Deployment?
- How do you manage secrets in a CI/CD pipeline securely?
- What tests should be in the CI pipeline vs. run separately?
- How do you handle a failed deployment that needs to be rolled back automatically?
- What is a deployment gate and what are good examples of them?
- How do you set up blue/green or canary deployments?

## Common Mistakes / Pitfalls
- **No quality gates** — a CI/CD pipeline that never fails a deploy on test failure provides no safety guarantee.
- **Secrets in environment variables** — static secrets in CI environment variables are a security risk. Use secret managers (Key Vault, AWS Secrets Manager, HashiCorp Vault).
- **Too long a pipeline** — a CI run that takes 20 minutes kills developer flow. Keep the PR feedback loop under 5 minutes; move longer tests to post-merge pipelines.
- **Knowledge silo on the pipeline** — if only one person can maintain the pipeline YAML, you've created a new bottleneck.
- **No monitoring after deploy** — deploying without checking if the deployment succeeded is incomplete automation.
- **Skipping staging** — deploying directly from development to production without a staging gate is high risk, even with automated tests.

## References
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Key Vault — Microsoft Learn](https://learn.microsoft.com/en-us/azure/key-vault/general/overview)
- [GitHub Environments and Required Reviewers](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [DORA Metrics — Google Cloud](https://cloud.google.com/blog/products/devops-sre/using-the-four-keys-to-measure-your-devops-performance) (verify exact URL)
- [Accelerate — Forsgren, Humble, Kim](https://itrevolution.com/product/accelerate/) (DORA research underpinning CI/CD value)

[See also: Improved Process That Saved Team Time](improved-process-saved-team-time.md)
