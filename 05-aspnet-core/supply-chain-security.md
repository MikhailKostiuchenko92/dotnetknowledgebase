# Supply Chain Security in .NET

**Category:** ASP.NET Core / Security Best Practices
**Difficulty:** 🔴 Senior
**Tags:** `supply-chain`, `NuGet-audit`, `Dependabot`, `SBOM`, `dotnet-list-package`, `vulnerable`

## Question

> What supply chain security risks apply to .NET projects, and how do you use `dotnet list package --vulnerable`, NuGet audit, Dependabot, and SBOM generation to mitigate them?

## Short Answer

Supply chain attacks compromise your software through dependencies, build tools, or CI/CD pipelines rather than your own code. In .NET, this means NuGet package vulnerabilities, typosquatting, and transitive dependency issues. Key defenses are: `dotnet list package --vulnerable` for manual checks, NuGet's built-in audit (automatically runs on `restore`), Dependabot for automated PRs, and SBOM (Software Bill of Materials) generation with `dotnet sbom-tool` or `syft` to enumerate all components in a release artifact.

## Detailed Explanation

### `dotnet list package --vulnerable`

```bash
# Lists packages with known CVEs from the NuGet vulnerability database
dotnet list package --vulnerable

# Include transitive (indirect) dependencies
dotnet list package --vulnerable --include-transitive

# Sample output:
# Project 'MyApi' has the following vulnerable packages
#    [net8.0]:
#    Top-level Package      Requested   Resolved   Severity   Advisory URL
#    > Newtonsoft.Json       12.0.1      12.0.1     High       https://github.com/advisories/GHSA-...
```

> **Tip:** Run this in CI to fail the build on high/critical vulnerabilities.

### NuGet restore audit (SDK 8.0.100+)

Starting with .NET 8 SDK, `dotnet restore` automatically checks for known vulnerabilities and warns if any are found. You can configure it in `NuGet.config` or `.csproj`:

```xml
<!-- NuGet.config — treat high/critical vulnerabilities as errors -->
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <auditSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </auditSources>
</configuration>
```

```xml
<!-- .csproj — fail build on critical vulnerabilities -->
<PropertyGroup>
  <NuGetAudit>true</NuGetAudit>
  <NuGetAuditLevel>critical</NuGetAuditLevel>
  <NuGetAuditMode>direct</NuGetAuditMode> <!-- or 'all' for transitive -->
</PropertyGroup>
```

### GitHub Dependabot

Create `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "nuget"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 10
    reviewers:
      - "your-team-slug"
    labels:
      - "dependencies"
    ignore:
      # Ignore major version bumps for breaking packages
      - dependency-name: "Microsoft.EntityFrameworkCore"
        update-types: ["version-update:semver-major"]
```

Dependabot will open automated PRs when:
- New patch/minor/major versions are released
- A package you use has a published CVE

### SBOM generation

An SBOM is a structured list of all components in a released artifact (direct + transitive packages, versions, licenses).

#### With `dotnet-sbom-tool` (Microsoft):

```bash
dotnet tool install --global Microsoft.Sbom.DotNetTool

sbom-tool generate \
  -b ./publish \         # build drop directory
  -bc . \                # source/build component path
  -pn MyApi \            # package name
  -pv 1.0.0 \            # package version
  -ps MyCompany          # package supplier
```

Produces an SPDX 2.2 JSON file:

```json
{
  "spdxVersion": "SPDX-2.2",
  "packages": [
    {
      "name": "Microsoft.AspNetCore.App",
      "versionInfo": "8.0.0",
      "licenseConcluded": "MIT"
    }
  ]
}
```

#### With `syft` (Anchore, cross-language):

```bash
syft dir:./publish -o spdx-json > sbom.spdx.json
# Or scan a container image:
syft myapi:latest -o spdx-json > sbom.spdx.json
```

### Typosquatting prevention

Typosquatting attacks publish packages with names similar to popular packages (e.g., `Newtonsoft.Jsoon`). Mitigations:

1. **Pin exact versions** in `packages.lock.json`:

```bash
dotnet restore --use-lock-file
# Generates packages.lock.json — commit this file
```

2. **Use a private NuGet feed** (Azure Artifacts, GitHub Packages) as a proxy/mirror:

```xml
<!-- NuGet.config — only allow packages from your private feed -->
<packageSources>
  <clear /> <!-- Removes nuget.org -->
  <add key="private" value="https://pkgs.dev.azure.com/org/feed/nuget/v3/index.json" />
</packageSources>
```

3. **Enable `packageSourceMapping`** (.NET 6+) to restrict which packages can come from which feeds:

```xml
<packageSourceMapping>
  <packageSource key="nuget.org">
    <package pattern="*" />
  </packageSource>
  <packageSource key="private">
    <package pattern="MyCompany.*" />
  </packageSource>
</packageSourceMapping>
```

### CI/CD pipeline integration

```yaml
# .github/workflows/security.yml
- name: Check vulnerable packages
  run: dotnet list package --vulnerable --include-transitive
  # Returns exit code 1 if vulnerabilities found (SDK 8.0.400+)

- name: Generate SBOM
  run: |
    dotnet tool install --global Microsoft.Sbom.DotNetTool
    sbom-tool generate -b ./publish -bc . -pn MyApi -pv ${{ github.ref_name }} -ps MyCompany

- name: Upload SBOM
  uses: actions/upload-artifact@v4
  with:
    name: sbom
    path: _manifest/spdx_2.2/manifest.spdx.json
```

## Code Example

```xml
<!-- MyApi.csproj — hardened supply chain settings -->
<PropertyGroup>
  <NuGetAudit>true</NuGetAudit>
  <NuGetAuditLevel>high</NuGetAuditLevel>
  <NuGetAuditMode>all</NuGetAuditMode>
  <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>
</PropertyGroup>
```

```bash
# Initial lock file generation
dotnet restore --use-lock-file

# CI restore — fails if packages.lock.json is inconsistent (no tampering)
dotnet restore --locked-mode

# Manual vulnerability scan
dotnet list package --vulnerable --include-transitive
```

## Common Follow-up Questions

- What is the difference between SPDX and CycloneDX SBOM formats, and which should you use?
- How do you handle a vulnerable transitive dependency that you cannot directly update?
- What is `packages.lock.json` and how does `--locked-mode` restore prevent tampering?
- How do you respond when a critical CVE is published for a package in a released container image?
- What is Package Source Mapping and why is it a defense against dependency confusion attacks?

## Common Mistakes / Pitfalls

- **Not scanning transitive dependencies** — most supply chain vulnerabilities are in transitive packages, not direct ones; always use `--include-transitive`.
- **Not committing `packages.lock.json`** — without it, `--locked-mode` cannot detect tampering or unexpected version changes.
- **Ignoring Dependabot PRs indefinitely** — accumulating ignored PRs means your dependencies drift further from patched versions over time.
- **Using `<clear/>` in NuGet.config to block nuget.org but not setting package source mapping** — without source mapping, `dotnet restore` may still resolve packages from unexpected sources.
- **Not generating an SBOM for container images** — the SBOM must cover the final image, not just the build output; vulnerabilities in base image layers are invisible otherwise.

## References

- [Microsoft Learn — Auditing NuGet packages for security vulnerabilities](https://learn.microsoft.com/nuget/concepts/auditing-packages)
- [Microsoft SBOM Tool](https://github.com/microsoft/sbom-tool)
- [GitHub Dependabot — NuGet configuration](https://docs.github.com/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file)
- [NuGet Package Source Mapping](https://learn.microsoft.com/nuget/consume-packages/package-source-mapping)
- [OWASP — Software Component Verification Standard](https://owasp.org/www-project-software-component-verification-standard/)
