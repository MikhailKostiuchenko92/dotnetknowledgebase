# What Is Strong Naming in .NET and Does It Still Matter?

**Category:** .NET Runtime / CLR
**Difficulty:** 🟡 Middle
**Tags:** `strong name`, `signing`, `public key token`, `assembly identity`, `NuGet`

## Question

> What is a strong-named assembly in .NET? Why was strong naming introduced, and is it still relevant for modern .NET development?

Also asked as:
> What is the difference between a strong name and Authenticode signing?
> Do NuGet packages need to be strong-named in .NET 5+?

## Short Answer

A strong-named assembly is signed with an RSA key pair; the assembly's identity includes its name, version, culture, and an 8-byte `PublicKeyToken` derived from the public key. Strong naming was introduced to prevent assembly spoofing in the GAC and to enforce version binding in .NET Framework. In .NET Core and .NET 5+, strong names are still supported and honoured for binary compatibility, but the CLR no longer enforces full trust/partial trust policies, so strong naming is primarily a compatibility and source-identity signal rather than a security mechanism.

## Detailed Explanation

### What Makes an Assembly "Strong Named"

A strong name is produced by signing the assembly with a private RSA key. The result is embedded in the assembly:

- **Public key** stored in the assembly manifest
- **Digital signature** over the assembly hash (computed at build time)
- **PublicKeyToken** = 8-byte truncated SHA-1 hash of the public key (displayed by tools)

Full assembly identity with strong name:
```
System.Text.Json, Version=8.0.0.0, Culture=neutral, PublicKeyToken=cc7b13ffcd2ddd51
```

### The Original Purpose (GAC / Partial Trust)

In .NET Framework, strong names served two goals:

1. **GAC identity** — only strong-named assemblies could be installed in the GAC; the key guaranteed no two assemblies shared an identity.
2. **Partial trust enforcement** — Code Access Security required strong names to grant assemblies specific permissions. `[AllowPartiallyTrustedCallers]` was needed for a strong-named library to be called by partially trusted code.

Both of these scenarios are **removed in .NET Core**:
- There is no GAC.
- Code Access Security is gone; all managed code is fully trusted.

### Strong Naming in .NET Core / .NET 5+

The CLR still validates strong names when loading assemblies, but:
- The **security enforcement is gone** — no CAS policies
- The **identity function remains** — two assemblies with the same name but different public key tokens are treated as different assemblies (prevents accidental mixing)
- **Binary compatibility** — if library authors change their public key between releases, consumers referencing the old key token get a bind failure

> **Microsoft's guidance:** New libraries targeting only .NET 5+ don't *need* to strong-name, but libraries distributed via NuGet that support .NET Framework should strong-name for compatibility. For pure .NET 5+ libraries, strong naming is optional.

### Signing Methods

| Method | Purpose | Prevents spoofing? |
|--------|---------|-------------------|
| **Strong naming** | Assembly identity in CLR | Within CLR binding only |
| **Authenticode** (`SignTool`) | Authenticates publisher of the file | Yes, via code-signing certificate |
| **NuGet package signing** | Authenticates NuGet package author | Yes, via nuget.org certificate |

Strong naming ≠ Authenticode. Authenticode signs the PE file for Windows SmartScreen / enterprise trust; strong naming signs the assembly metadata for CLR binding identity.

### Creating a Strong-Named Assembly

```xml
<!-- .csproj -->
<PropertyGroup>
  <SignAssembly>true</SignAssembly>
  <AssemblyOriginatorKeyFile>MyKey.snk</AssemblyOriginatorKeyFile>
  <!-- Delay signing: embed public key but sign later (CI/CD) -->
  <DelaySign>false</DelaySign>
</PropertyGroup>
```

Generate a key:
```bash
sn -k MyKey.snk          # .NET Framework SDK
# or
dotnet tool install -g dotnet-sn
dotnet sn -k MyKey.snk
```

For open-source projects, many libraries use a **publicly known key** (e.g., the .NET Foundation key) so developers can build and test without needing the private key, while releases are signed with the real private key.

### `InternalsVisibleTo` and Strong Names

When a library is strong-named, all `[InternalsVisibleTo("TestProject")]` attributes must also specify the test project's public key:

```csharp
[assembly: InternalsVisibleTo(
    "MyLib.Tests, PublicKeyToken=0024000004800000...")]
```

For unsigned assemblies, just the assembly name suffices. This is a common pain point when adding strong naming to a library mid-project.

## Code Example

```csharp
using System.Reflection;

// Inspect strong naming information at runtime
Assembly asm = typeof(System.Text.Json.JsonSerializer).Assembly;
AssemblyName name = asm.GetName();

Console.WriteLine($"Name:            {name.Name}");
Console.WriteLine($"Version:         {name.Version}");

byte[]? token = name.GetPublicKeyToken();
if (token is { Length: > 0 })
{
    string hex = Convert.ToHexString(token).ToLower();
    Console.WriteLine($"PublicKeyToken:  {hex}");
    // e.g. cc7b13ffcd2ddd51
}
else
{
    Console.WriteLine("PublicKeyToken:  (not strong-named)");
}

// Check if an assembly is signed (has a public key)
byte[]? pubKey = name.GetPublicKey();
Console.WriteLine($"Strong-named:    {pubKey is { Length: > 0 }}");
```

```bash
# View strong name info from command line
sn -T MyLib.dll              # display PublicKeyToken
sn -vf MyLib.dll             # verify signature (force, even if already cached)
```

## Common Follow-up Questions

- Does NuGet package signing replace strong naming?
- What is delay signing and when is it used in large organisations?
- How do you add `[InternalsVisibleTo]` to a strongly-named assembly for unit tests?
- What is the `[AllowPartiallyTrustedCallers]` attribute and is it still needed?
- How does the .NET team manage the keys for `System.Text.Json`, `Newtonsoft.Json`, etc.?
- Can you strong-name an assembly without the private key using delay signing?

## Common Mistakes / Pitfalls

- **Assuming strong naming = security** — strong naming only prevents accidental identity collision; it doesn't protect against a malicious assembly that generates its own key pair with the same name.
- **Forgetting `InternalsVisibleTo` public key requirement** — adding strong naming to an existing library breaks `[InternalsVisibleTo]` declarations that lack the `PublicKeyToken` value.
- **Changing the key between NuGet releases** — a new key changes the `PublicKeyToken`, effectively creating a different assembly identity. Consumers get binding failures even if the version is compatible.
- **Using the same `.snk` file in a public repo** — the private key in the `.snk` file gives anyone the ability to sign assemblies with your identity. Use delay signing for open-source, or exclude the key file from version control.
- **Believing strong naming prevents tampering** — it does validate that the assembly wasn't modified *after* signing, but only if the CLR actually verifies the signature. In practice, .NET Core doesn't always re-verify on every load.

## References

- [Strong-named assemblies — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/assembly/strong-named)
- [Create and use strong-named assemblies — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/assembly/create-use-strong-named)
- [Strong naming and .NET libraries best practices — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/library-guidance/strong-naming)
- [Authenticode signing — Microsoft Learn](https://learn.microsoft.com/windows/win32/seccrypto/authenticode)
- [NuGet package signing — Microsoft Learn](https://learn.microsoft.com/nuget/create-packages/sign-a-package)
