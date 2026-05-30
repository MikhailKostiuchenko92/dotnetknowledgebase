# How Does .NET Versioning and Support Policy Work?

**Category:** .NET Runtime / Deployment
**Difficulty:** 🟢 Junior
**Tags:** `versioning`, `LTS`, `STS`, `global.json`, `netstandard`

## Question

> How does the .NET release and support policy work, and what should teams target by default?

Also asked as:
> When is `netstandard2.0` still useful?
> What does `global.json` do for SDK versioning and reproducible builds?

## Short Answer

Modern .NET ships a major release every November. Even-numbered releases are LTS and supported for three years, while odd-numbered releases are STS and supported for 18 months, so most production teams should target the latest LTS unless they specifically need a newer feature. `netstandard2.0` is mainly for libraries that still need to support .NET Framework or older consumers, and `global.json` helps pin SDK behavior and roll-forward policy so local and CI builds stay predictable.

## Detailed Explanation

### Release Cadence and Support Types

Since .NET 5, Microsoft has followed an annual major release cadence. The support type alternates:

| Release type | Support window | Typical recommendation |
|---|---|---|
| LTS (even-numbered) | 3 years | Default choice for most production systems |
| STS (odd-numbered) | 18 months | Use when you need newer features sooner |

This means .NET 8 is LTS, .NET 9 is STS, and future even-numbered versions continue the longer support model. A team that values operational stability normally picks the newest LTS and upgrades deliberately.

### What About .NET Standard?

`.NET Standard` is a compatibility contract, not a runtime. In practice, `netstandard2.0` still matters mainly for libraries that must support both old .NET Framework applications and modern .NET. If your library or application only targets modern .NET consumers, targeting `net8.0` is usually better because it gives access to newer BCL APIs, better analyzers, and simpler packaging.

A common interview answer is: use `netstandard2.0` for broad legacy library reach; otherwise prefer a real modern TFM.

### `global.json` and SDK Control

Runtime version and SDK version are different concerns. You can compile a `net8.0` app with different installed SDKs unless you pin the SDK selection. `global.json` lets a repository request a specific SDK version and configure `rollForward` behavior, which reduces “works on my machine” drift between developer laptops and CI agents.

That is especially important when tooling, source generators, or publish behavior changed between SDK bands.

> Warning: pinning a runtime TFM is not the same as pinning the SDK. Without `global.json`, developers may restore and build with different SDK feature bands even if the app targets the same framework.

### End-of-Life Awareness

Teams should track end-of-support dates because unsupported runtimes stop receiving security and servicing updates. .NET 5 is long out of support, .NET 7 reached end of support in May 2024, and .NET 6 reached end of support in November 2024. Interviewers often want to hear that version choice is not just about APIs; it is also an operations and patching decision.

### A Practical Upgrade Strategy

A practical team policy is to standardize new work on the latest LTS, test against preview or STS releases only when there is a concrete feature need, and keep SDK pinning under source control with `global.json`. That gives you predictable local builds while still allowing planned upgrades. The important engineering habit is to treat runtime upgrades as regular maintenance, not as once-every-few-years migration projects. Smaller, scheduled upgrades are safer than waiting until the runtime is already out of support.

For targeting strategy, see [multi-targeting-and-tfms.md](./multi-targeting-and-tfms.md). For deployment consequences, see [self-contained-vs-framework-dependent.md](./self-contained-vs-framework-dependent.md).

## Code Example

```csharp
using System.Runtime.InteropServices;

namespace DotNetRuntimeSamples.Versioning;

internal static class Program
{
    private static void Main()
    {
        Console.WriteLine($"Framework: {RuntimeInformation.FrameworkDescription}");
        Console.WriteLine($"RID: {RuntimeInformation.RuntimeIdentifier}");

#if NET8_0_OR_GREATER
        Console.WriteLine("This build targets .NET 8 or later.");
#endif

        // Example global.json:
        // {
        //   "sdk": {
        //     "version": "8.0.204",
        //     "rollForward": "latestFeature"
        //   }
        // }
    }
}
```

## Common Follow-up Questions

- Why would a library still target `netstandard2.0` in 2025?
- What problem does `global.json` solve that a TFM does not?
- When should a team choose STS instead of LTS?
- Why are support dates an operational concern rather than just a developer concern?
- How does SDK roll-forward affect local and CI reproducibility?

## Common Mistakes / Pitfalls

- Treating `.NET Standard` as the default target for every new project.
- Confusing the installed SDK version with the runtime version the app targets.
- Staying on unsupported runtimes because “the app still runs.”
- Assuming all developers build with the same SDK without a `global.json` policy.
- Upgrading runtime versions without checking library and deployment compatibility.

## References

- [.NET support policy](https://dotnet.microsoft.com/platform/support/policy/dotnet-core)
- [Select the .NET version to use — Microsoft Learn](https://learn.microsoft.com/dotnet/core/versions/selection)
- [global.json overview — Microsoft Learn](https://learn.microsoft.com/dotnet/core/tools/global-json)
- [.NET Standard — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/net-standard)
- [Target frameworks in SDK-style projects — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/frameworks)
