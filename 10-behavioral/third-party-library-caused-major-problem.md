# Tell me about a time a third-party library or dependency caused a major problem.

**Category:** Problem Solving & Technical Decisions
**Difficulty:** 🟡 Middle
**Tags:** `dependencies`, `third-party`, `nuget`, `supply-chain`, `incident`, `dependency-management`

## Question
> Tell me about a time a third-party library or dependency caused a major problem. How did you handle it?

## Short Answer
A transitive NuGet dependency update silently changed JSON serialisation behaviour and caused our API to reject valid client payloads in production. I identified the dependency culprit by bisecting recent package updates, implemented a compatibility shim for the changed behaviour, and added a contract test that would catch serialisation regressions in future. The incident led us to pin all transitive dependency versions in our project files.

## What the Interviewer Is Looking For

This question tests your **dependency management discipline** and **incident response under an unusual root cause**. Interviewers want to see:

- You understand that third-party dependencies are a risk surface that must be managed.
- You have techniques for bisecting dependency-related regressions.
- You implement preventive measures after a dependency incident (contract tests, pinning, SBOM).
- You don't just blame the library — you own the system that depends on it.

> **⚠ Note:** "We rolled back" is an acceptable emergency response but not a complete answer. The question is really asking: how did you prevent it from happening again?

### Dependency Risk Management Strategies

| Strategy | Description |
|----------|-------------|
| Version pinning | Lock exact versions in `packages.lock.json` or `*.csproj` |
| Transitive dependency audit | Review `dotnet list package --include-transitive` regularly |
| Contract / snapshot tests | Catch serialisation, interface, or behaviour regressions |
| Dependabot / Renovate | Automated PRs for updates with changelog review |
| Software Bill of Materials (SBOM) | Inventory of all dependencies for security and audit |

## Example STAR Answer

**Situation:**
Our ASP.NET Core API had been running stably for 6 months. After a CI build that updated our NuGet packages (no-pinned `PackageReference` with floating versions), a subset of API clients began receiving HTTP 400 errors for valid JSON payloads. The issue appeared without any code changes to our controllers or models.

**Task:**
Root-cause the regression, restore service, and prevent recurrence.

**Action:**

*Phase 1 — Confirm the dependency change:*
The CI build log showed `Newtonsoft.Json` had updated from `13.0.1` to `13.0.3` as a transitive dependency of our serialisation library. I checked the `13.0.3` release notes and found a documented behaviour change: strict validation of `$type` discriminators was now enabled by default.

Our client SDKs were sending payloads with `$type` fields in a format the new strict validator rejected. The behaviour had always been technically wrong on the client side — but the old version had accepted it silently.

*Phase 2 — Immediate mitigation:*
I pinned `Newtonsoft.Json` to `13.0.1` in the project file and deployed. 400 errors stopped immediately.

*Phase 3 — Permanent fix:*
Rather than staying on `13.0.1` indefinitely, I reviewed what the correct fix was:
- **Option A**: Update client SDKs to send correct `$type` format.
- **Option B**: Configure our API to tolerate the old format for the transition period.

I implemented option B with a custom `JsonSerializerSettings` configuration that accepted both formats, and coordinated with the client teams on a migration timeline.

*Phase 4 — Prevention:*
1. Added a contract test: a JSON deserialization test using the exact payload format sent by clients. This would fail on any future serialisation behaviour change.
2. Added `packages.lock.json` to the repository — all transitive versions are now locked and only updated deliberately via PRs.
3. Set up Dependabot to create PRs for package updates rather than auto-updating in CI.

**Result:**
Zero recurrence. The contract tests caught one additional serialisation regression 4 months later during a deliberate upgrade, before it reached staging.

## Reflection / What I'd Do Differently
I would treat `packages.lock.json` as a project default, not an afterthought. Floating transitive dependencies in a CI environment that auto-builds are a silent regression risk. Every project I create now includes `RestorePackagesWithLockFile = true` in the project file.

## Common Follow-up Questions
- How do you manage NuGet package updates in a production codebase?
- What is `packages.lock.json` and when should you use it?
- How do you evaluate whether a third-party library is safe to add as a dependency?
- What is a Software Bill of Materials (SBOM) and when do you need one?
- How do you handle a critical security vulnerability in a transitive dependency you can't update immediately?
- What's your strategy for deprecating or replacing a third-party library over time?

## Common Mistakes / Pitfalls
- **Floating versions for all dependencies** — `<PackageReference Include="Foo" Version="*" />` means any CI build can produce a different binary.
- **No regression tests for external contracts** — serialisation, HTTP response shapes, and integration behaviour need snapshot/contract tests.
- **Rolling back as the complete solution** — rollback is the emergency brake; the root cause still needs fixing.
- **Blaming the library** — you own the code that depends on it. If the change is a documented breaking change in a minor version, that's on the library vendor; if it's in a major version, that's on you for not testing upgrades.
- **Ignoring transitive dependencies** — your direct dependencies' transitive dependencies can also introduce breaking changes. Review the full tree.
- **No change process for dependency updates** — dependency updates should be reviewed PRs, not auto-merged CI builds.

## References
- [NuGet Package Locking — Microsoft Learn](https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#locking-dependencies)
- [Dependabot — GitHub Docs](https://docs.github.com/en/code-security/dependabot)
- [Software Bill of Materials — CISA](https://www.cisa.gov/sbom)
- [Newtonsoft.Json Migration Guide](https://www.newtonsoft.com/json/help/html/Introduction.htm) (verify exact URL)
- [dotnet list package — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-list-package)
