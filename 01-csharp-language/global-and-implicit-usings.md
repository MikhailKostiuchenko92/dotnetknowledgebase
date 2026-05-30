# Global and Implicit Usings

**Category:** C# / Modern C# Features
**Difficulty:** Middle
**Tags:** `global-using`, `implicit-usings`, `sdk-style-projects`, `csharp-10`, `msbuild`

## Question

> What are `global using` directives and implicit usings in modern C#, and how do they differ?

Also asked as:
- "What does `global using` do, and where should I put it?"
- "Which namespaces does `<ImplicitUsings>enable</ImplicitUsings>` add automatically?"
- "How can I disable or remove implicit usings for a specific project?"

## Short Answer

`global using` is a C# language feature that makes a using directive apply to every file in the compilation. Implicit usings are an SDK feature that auto-generates a predefined set of global usings based on the project SDK, such as console or web. In .NET 8/9 projects, they reduce repetition, but teams should still manage them deliberately so namespace dependencies stay visible and unambiguous.

## Detailed Explanation

### `global using` vs implicit usings

These two ideas are related but not the same.

| Feature | Defined by | Scope | Typical control point |
|---|---|---|---|
| `global using` | C# language | Whole compilation | Source file such as `GlobalUsings.cs` |
| Implicit usings | .NET SDK / MSBuild | Whole project | Project file (`<ImplicitUsings>`) |

A `global using` is explicit source code that you own. Implicit usings are generated for you by the SDK based on project type.

### How implicit usings behave by SDK

The exact default namespaces depend on the SDK. For example, a console app and an ASP.NET Core web app do not get the same set of namespaces. That is why interview answers should say **"implicit usings are SDK-dependent"**, not "C# always imports the same namespaces."

In practice:
- `Microsoft.NET.Sdk` brings a basic set
- `Microsoft.NET.Sdk.Web` adds web-oriented namespaces
- test project templates often include additional framework-related usings

### Disabling or removing them

You can disable the whole feature with:

```xml
<ImplicitUsings>disable</ImplicitUsings>
```

You can also remove or add individual generated usings with `Using` items in the project file. That gives teams fine-grained control when a default import causes ambiguity or hides an important dependency.

> **Warning:** Hidden imports are convenient, but too many of them can make code examples harder to read because a file compiles without showing where key namespaces come from.

### Design guidance

Use `global using` for namespaces that are truly pervasive in the project, such as domain abstractions or shared BCL namespaces that appear in nearly every file. Do **not** move every using into a global file just because you can. That often makes local dependencies less obvious.

This topic connects well with [file-scoped-namespaces.md](./file-scoped-namespaces.md): both are modern syntax features that flatten file boilerplate, but neither should hide important structure.

## Code Example

```csharp
// GlobalUsings.cs
global using Demo.Shared;
global using System.Globalization;
```

```csharp
// Program.cs
using System;

namespace Demo;

var invoice = new Invoice(123.45m);
Console.WriteLine(invoice.Format());

public sealed class Invoice(decimal amount)
{
    public string Format()
        => amount.ToString("C", CultureInfo.InvariantCulture); // CultureInfo comes from a global using.
}
```

```csharp
// Shared/MoneyExtensions.cs
namespace Demo.Shared;

public static class MoneyExtensions
{
    public static decimal ApplyTax(this decimal amount, decimal rate)
        => amount * (1 + rate);
}
```

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <Using Remove="System.Net.Http" />
    <Using Include="System.Collections.Immutable" />
  </ItemGroup>
</Project>
```

## Common Follow-up Questions

- Why are implicit usings considered an SDK feature rather than a pure language feature?
- Why can two project types have different implicit namespace sets?
- When should a team prefer an explicit `global using` over relying on implicit usings?
- How do you disable all implicit usings or remove one specific generated using?
- What readability problems can appear when too many namespaces are imported globally?

## Common Mistakes / Pitfalls

- Assuming implicit usings are identical across all .NET SDKs and templates.
- Moving too many namespaces into global scope and making local dependencies invisible.
- Forgetting that hidden imports can cause ambiguous type-name collisions.
- Confusing source-level `global using` with SDK-generated implicit usings.
- Relying on implicit imports in shared snippets where explicit `using` directives would be clearer.

## References

- [using directive - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/using-directive)
- [MSBuild props and items - ImplicitUsings](https://learn.microsoft.com/dotnet/core/project-sdk/msbuild-props#implicitusings)
- [See: file-scoped-namespaces.md](./file-scoped-namespaces.md)
- [See: target-typed-new.md](./target-typed-new.md)
- [See: raw-string-literals.md](./raw-string-literals.md)
