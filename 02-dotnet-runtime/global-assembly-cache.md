# What Is the GAC and Why Was It Removed from .NET Core?

**Category:** .NET Runtime / CLR
**Difficulty:** 🟢 Junior
**Tags:** `GAC`, `assembly versioning`, `.NET Framework`, `.NET Core`, `side-by-side`

## Question

> What is the Global Assembly Cache (GAC), and why was it not carried over to .NET Core?

Also asked as:
> How does .NET Core handle shared framework assemblies without the GAC?
> What problems did the GAC solve, and what problems did it create?

## Short Answer

The GAC was a machine-wide repository in .NET Framework where shared, strongly-named assemblies were installed so multiple applications could reference the same copy instead of shipping their own. .NET Core removed the GAC entirely because NuGet, self-contained deployment, and side-by-side framework installs make it unnecessary — and because the GAC's machine-global scope caused the "DLL Hell" problems it was meant to solve in a new form.

## Detailed Explanation

### The GAC in .NET Framework

The Global Assembly Cache lived at `C:\Windows\Microsoft.NET\assembly\` (for .NET Framework 4.x). Its key characteristics:

- Stored **strongly-named assemblies** only (a public/private key pair was required)
- Allowed **multiple versions of the same assembly** to coexist, distinguished by (Name, Version, Culture, PublicKeyToken)
- Applications could reference the shared copy; the CLR's assembly binder checked the GAC first
- Administered via `gacutil.exe` or Windows Installer

```
GAC structure (conceptual)
C:\Windows\Microsoft.NET\assembly\GAC_MSIL\
├── System\
│   ├── v4.0_4.0.0.0__b77a5c561934e089\System.dll
│   └── v4.0_4.0.0.0__b77a5c561934e089\System.xml
└── System.Web\
    └── v4.0_4.0.0.0__b03f5f7f11d50a3a\System.Web.dll
```

### Why the GAC Was Created

In the COM/Win32 era, "DLL Hell" meant multiple apps competed for a single copy of a DLL in `C:\Windows\System32`. A newer installer could overwrite a DLL an older app depended on. The GAC solved this by:

1. Allowing multiple versions of an assembly to coexist (key = name + version + culture + token)
2. Requiring a cryptographic strong name to prove assembly identity and prevent spoofing

### Why .NET Core Removed It

| Problem with GAC | .NET Core solution |
|-----------------|-------------------|
| Machine-wide state — installing one app's runtime could affect another app | Self-contained deployment — apps bundle their own runtime copy |
| Strong naming required — extra friction for library authors | NuGet identity replaces strong naming for most purposes |
| Admin rights needed to `gacutil` | No special permissions needed; packages are per-user in NuGet cache |
| Versioning via binding redirects was fragile | Exact version pinning in `.csproj` / `packages.lock.json` |
| GAC itself became a form of DLL Hell for .NET assemblies | Side-by-side CLR installs; each app gets its own CLR version |

### How .NET Core Shares Framework Assemblies

.NET Core (and .NET 5+) installs framework assemblies into a versioned, **read-only** shared framework store:

```
C:\Program Files\dotnet\shared\
├── Microsoft.NETCore.App\
│   ├── 8.0.0\        ← .NET 8.0.0 runtime
│   └── 9.0.0\        ← .NET 9.0.0 runtime side-by-side
└── Microsoft.AspNetCore.App\
    └── 8.0.0\
```

Framework-dependent apps reference this store via `runtimeconfig.json`. Multiple versions coexist safely because the CLR version is part of the path, not a machine-global registry key. No admin required for new installs in user-local paths.

### Strong Naming in .NET Core

Strong names still exist and are supported, but:
- The CLR does **not** enforce assembly identity by default in .NET Core (no partial trust)
- Strong names in .NET Core serve primarily as a NuGet source-compatibility signal
- `gacutil.exe` does not exist for .NET Core; there is no machine-wide cache to install into

> **Rule of thumb:** If you're targeting .NET 5+, you don't need to think about the GAC at all. Use NuGet for package distribution and let the SDK manage framework references.

## Code Example

```csharp
using System.Reflection;

// In .NET Framework, you could load from GAC by name:
// Assembly.Load("System.Web, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a");

// In .NET 8, shared framework assemblies are loaded from the shared store automatically.
// You can inspect where the runtime was loaded from:
Assembly coreLib = typeof(object).Assembly;
Console.WriteLine(coreLib.Location);
// e.g. C:\Program Files\dotnet\shared\Microsoft.NETCore.App\8.0.0\System.Private.CoreLib.dll

// To see all runtimes installed side-by-side on a machine:
// dotnet --list-runtimes
//
// Microsoft.NETCore.App 8.0.0 [C:\Program Files\dotnet\shared\Microsoft.NETCore.App]
// Microsoft.NETCore.App 9.0.0 [C:\Program Files\dotnet\shared\Microsoft.NETCore.App]

// NuGet package cache (per-user, no admin required):
// C:\Users\<user>\.nuget\packages\
```

## Common Follow-up Questions

- What is a strong name, and does it still matter in .NET 5+?
- How does `runtimeconfig.json` specify which shared framework version an app uses?
- What is the difference between a framework-dependent and a self-contained deployment?
- How do binding redirects work in .NET Framework, and what replaces them in .NET Core?
- Can you load an assembly directly from a file path in .NET Core, and what are the implications?
- What is the NuGet fallback folder, and how does it relate to the concept of a shared cache?

## Common Mistakes / Pitfalls

- **Assuming `gacutil.exe` works on .NET Core** — it doesn't; there is no GAC in .NET Core/5+.
- **Forgetting strong naming requirements for .NET Framework NuGet packages** — libraries targeting .NET Framework must be strong-named to be used by strong-named callers.
- **Confusing the shared framework store with the GAC** — the shared framework store in .NET Core is immutable and versioned per path, not a registry-backed global cache.
- **Using `Assembly.Load` with a full GAC-style name in .NET Core** — loading by long-form name (`Assembly.Load("Name, Version=..., PublicKeyToken=...")`) still works for already-loaded assemblies but won't search any machine-wide store.
- **Assuming side-by-side installs always isolate apps** — framework-dependent apps can be affected if `dotnet` rolls forward to an unexpected patch version. Use `rollForward: "disable"` in `runtimeconfig.json` to pin exactly.

## References

- [Global Assembly Cache — Microsoft Learn](https://learn.microsoft.com/dotnet/framework/app-domains/gac)
- [.NET Core does not have a GAC — .NET Blog](https://devblogs.microsoft.com/dotnet/net-core-application-deployment/)
- [Strong-named assemblies — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/assembly/strong-named)
- [Runtime configuration options — Microsoft Learn](https://learn.microsoft.com/dotnet/core/runtime-config/)
- [Framework-dependent vs self-contained deployment — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/)
