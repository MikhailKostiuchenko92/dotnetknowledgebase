# How Do You Skip a Test in xUnit?

**Category:** Testing / xUnit
**Difficulty:** 🟡 Middle
**Tags:** `xunit`, `skip`, `[Fact]`, `[Theory]`, `conditional-skip`

## Question
> How do you skip a test in xUnit?

## Short Answer
Pass a `Skip` reason string to `[Fact]` or `[Theory]`: `[Fact(Skip = "reason")]`. The test is then reported as *skipped* (not failed) in all test runners. For conditional, runtime skipping use the `xunit.skippable.fact` package.

## Detailed Explanation

### Static Skip: `Skip` Parameter
The simplest approach — adds a compile-time reason to the attribute:

```csharp
[Fact(Skip = "Flaky on CI — tracked in #1234")]
public void SomeTest() { ... }

[Theory(Skip = "Not implemented yet")]
[InlineData(1), InlineData(2)]
public void AnotherTest(int x) { ... }
```

The test is compiled and discovered but reported as **skipped** rather than run. No assertion is executed.

### When to Use Static Skip
| Scenario | Appropriate? |
|---|---|
| Bug in the code under test being tracked | ✅ Short-term |
| Feature not yet implemented | ✅ Short-term |
| Environment-specific test (e.g., Windows only) | ⚠️ Use conditional skip instead |
| Test permanently excluded | ❌ Delete it instead |

> ⚠️ **Warning:** Accumulating skipped tests is a smell ([test-smells.md](test-smells.md)). Every skipped test should have a linked work item. A test skipped for months should be deleted.

### Conditional / Dynamic Skip: `xunit.skippable.fact`
The community package [xunit.skippable.fact](https://www.nuget.org/packages/Xunit.SkippableFact/) enables runtime skipping:

```bash
dotnet add package Xunit.SkippableFact
```

```csharp
[SkippableFact]
public void RunsOnlyOnWindows()
{
    Skip.If(!OperatingSystem.IsWindows(), "Windows-only test");
    // test body runs only on Windows
}

[SkippableTheory]
[InlineData(1)]
public void RunsOnlyInCI(int x)
{
    Skip.IfNot(
        Environment.GetEnvironmentVariable("CI") == "true",
        "Only runs in CI environment");
    // ...
}
```

### Skipping a Single `[Theory]` Row
Skipping one data row (not the whole theory) is not natively supported in xUnit. Workarounds:
1. Move the problematic row to a separate `[Fact]` and apply `Skip` there.
2. Add a `bool skip` parameter to each row and use `Skip.If(skip)` from `SkippableFact`.

### Platform/OS Conditional Tests (Built-in .NET)
For OS gating without a package:

```csharp
[Fact]
public void LinuxOnlyTest()
{
    if (!OperatingSystem.IsLinux())
        return; // silently passes on non-Linux — not ideal

    // ...
}
```

The above *passes* silently on other platforms. `SkippableFact.Skip.If` is cleaner because it reports the test as *skipped* rather than passing vacuously.

## Code Example
```csharp
namespace Infrastructure.Tests;

public class FileSystemTests
{
    // Static skip — reason recorded, test won't run
    [Fact(Skip = "Flaky in Docker — investigate in #789")]
    public void ReadFile_WhenMounted_ReturnsContent()
    {
        // ...
    }

    // Conditional skip — requires Xunit.SkippableFact package
    [SkippableFact]
    public void CreateSymlink_OnlyRunsOnLinux()
    {
        Skip.IfNot(OperatingSystem.IsLinux(), "Symlink tests require Linux");

        var result = FileHelper.CreateSymlink("/tmp/link", "/tmp/target");
        result.Should().BeTrue();
    }

    // Skipping based on environment variable
    [SkippableFact]
    public void SendRealEmail_OnlyRunsInIntegrationMode()
    {
        Skip.IfNot(
            Environment.GetEnvironmentVariable("RUN_INTEGRATION") == "1",
            "Set RUN_INTEGRATION=1 to execute this test");

        // real integration test
    }
}
```

## Common Follow-up Questions
- How do you skip an entire test class in xUnit?
- How do you skip a single row in a `[Theory]` without skipping all rows?
- What is the difference between a skipped test and a disabled test?
- How do you write a test that should only run on a specific OS?
- How do you track and manage skipped tests so they don't accumulate?
- How does xUnit report skipped tests in the CI pipeline?

## Common Mistakes / Pitfalls
- **Silently returning from a test instead of skipping** — the test passes vacuously on the non-target platform, masking the fact that it was not exercised.
- **Accumulating skipped tests without cleanup** — treated as technical debt; stale skips should be deleted or fixed.
- **Skip with no reason** — `Skip = ""` provides no context; always include a reason and ideally a ticket reference.
- **Using `[Fact(Skip = ...)]` for permanently unused tests** — permanently skipped = dead code; delete it.
- **Conditional skip logic inside the test body without a proper skip mechanism** — e.g., `if (!condition) Assert.True(true)` — the test passes vacuously and does not signal "skipped" in test output.

## References
- [xUnit documentation — Skipping tests](https://xunit.net/docs/getting-started/netcore/cmdline)
- [NuGet — Xunit.SkippableFact](https://www.nuget.org/packages/Xunit.SkippableFact/)
- [GitHub — xunit.skippable.fact source](https://github.com/AArnott/Xunit.SkippableFact)
- [Microsoft Learn — Unit testing in .NET](https://learn.microsoft.com/en-us/dotnet/core/testing/)
