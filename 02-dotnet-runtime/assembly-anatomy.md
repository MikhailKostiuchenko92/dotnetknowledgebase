# What Does a .NET Assembly Contain?

**Category:** .NET Runtime / CLR
**Difficulty:** 🟢 Junior
**Tags:** `assembly`, `PE format`, `manifest`, `metadata`, `IL`, `module`

## Question

> What is a .NET assembly, and what does it contain internally?

Also asked as:
> What is the difference between an assembly and a namespace?
> What information is stored in an assembly manifest?

## Short Answer

A .NET assembly is a self-describing deployment unit — a PE (Portable Executable) file containing: an assembly manifest (identity, version, culture, referenced assemblies), type metadata (names, methods, fields, attributes), IL bytecode for method bodies, and optionally embedded resources. A namespace is purely a logical grouping in source code; assemblies are the physical unit of deployment, versioning, and loading.

## Detailed Explanation

### PE File Structure

.NET assemblies use the standard Windows PE/COFF file format extended with CLR-specific sections:

```
PE File (.dll / .exe)
├── PE headers         (standard Win32 metadata: machine type, subsystem)
├── CLR header         (CLR version, entry point token, metadata root offset)
├── Metadata section   (assembly manifest, type definitions, method signatures)
├── IL code section    (method bodies as MSIL bytecode)
└── Resources          (embedded images, strings, RESX data)
```

This layout lets the OS loader recognise the file as a valid PE while the CLR reads the CLR-specific sections.

### Assembly Manifest

Every assembly carries a **manifest** — metadata that identifies the assembly to the CLR:

| Manifest field | Purpose |
|---------------|---------|
| `AssemblyName` | Simple name (e.g., `System.Text.Json`) |
| `Version` | Major.Minor.Build.Revision (e.g., `8.0.0.0`) |
| `Culture` | Neutral or a locale (e.g., `en-US` for satellite assemblies) |
| `PublicKeyToken` | 8-byte hash of strong-name public key (optional) |
| `AssemblyRef` list | All other assemblies this assembly depends on |
| `ModuleRef` list | Additional modules (multi-module assemblies, rare today) |

The manifest is visible via `ildasm.exe` (Windows), `dotnet-ildasm`, or the `.Modules` / `.GetReferencedAssemblies()` reflection APIs.

### Metadata Tables

IL alone cannot describe types — metadata tables store:
- **TypeDef** — all types defined in this assembly (classes, interfaces, structs, enums, delegates)
- **MethodDef** — method signatures, attributes, IL offset within the code section
- **FieldDef** — field names, types, access modifiers
- **CustomAttribute** — attributes attached to any token (type, method, parameter, assembly)
- **Param**, **Property**, **Event**, **GenericParam** — further type-system details

The CLR's type loader reads these tables to build `MethodTable` and `EEClass` structures in memory when a type is first used.

### IL Code Section

Method bodies are stored as IL (CIL) bytecode — a stack-based instruction set. Example decompiled IL for `int Add(int a, int b)`:
```
ldarg.0   // push a
ldarg.1   // push b
add       // pop two, push sum
ret       // return top of stack
```
The JIT compiles this to native code on first call.

### Assembly vs. Module vs. Namespace

| Concept | What it is |
|---------|-----------|
| **Namespace** | Logical grouping in source code; no runtime existence |
| **Module** | A single `.netmodule` file; one assembly usually has exactly one module |
| **Assembly** | The unit of identity, versioning, and loading; contains one or more modules |

> Multi-module assemblies (one assembly = multiple `.netmodule` files) are extremely rare in practice and unsupported by the .NET SDK build tooling.

### Single-File Assemblies vs. Multi-Module

Modern .NET always produces single-module assemblies. The distinction matters when reading old documentation about `System.Reflection.Module` — today `Assembly.GetModules()` always returns a single element.

### Viewing Assembly Contents

```bash
# Inspect IL and metadata
dotnet tool install -g dotnet-ildasm
dotnet-ildasm MyLib.dll

# Or use ILSpy / dnSpy for a GUI decompiler
# Or use reflection at runtime:
```

```csharp
using System.Reflection;

Assembly asm = typeof(string).Assembly; // mscorlib / System.Private.CoreLib
Console.WriteLine(asm.GetName().Version);   // e.g. 8.0.0.0
Console.WriteLine(asm.Location);           // path on disk

// All types in the assembly
foreach (Type t in asm.GetExportedTypes().Take(5))
    Console.WriteLine(t.FullName);

// Referenced assemblies
foreach (AssemblyName dep in asm.GetReferencedAssemblies())
    Console.WriteLine($"  → {dep.Name} {dep.Version}");
```

## Common Follow-up Questions

- What is the difference between a strong-named assembly and a regular assembly?
- How does the CLR decide which assembly to load when multiple versions exist side by side?
- What is an AssemblyLoadContext and how does it relate to assemblies?
- What are satellite assemblies and how are they used for localisation?
- Can two assemblies define the same fully-qualified type name, and what happens?
- What does `AssemblyVersion` vs `FileVersion` vs `InformationalVersion` mean?

## Common Mistakes / Pitfalls

- **Confusing namespace with assembly** — a namespace like `System.Text.Json` can span multiple assemblies; an assembly can contain multiple namespaces. They are orthogonal.
- **Assuming `Assembly.Location` is always set** — for assemblies loaded from memory (`Assembly.Load(byte[])`) or in single-file published apps, `Location` returns an empty string.
- **Ignoring `AssemblyVersion` in NuGet libraries** — changing `AssemblyVersion` in a library is a breaking change for consumers using binding redirects. Prefer only bumping `FileVersion` for bug fixes.
- **Using `GetTypes()` instead of `GetExportedTypes()`** — `GetTypes()` returns all types including private/internal; it throws `ReflectionTypeLoadException` if any type fails to load. `GetExportedTypes()` returns only public types.
- **Thinking `Assembly.Load` and `Assembly.LoadFrom` are interchangeable** — they use different load contexts and can result in duplicate type identities if the same assembly file is loaded twice.

## References

- [Assemblies in .NET — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/assembly/)
- [Assembly manifest — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/assembly/manifest)
- [PE format for managed assemblies — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/assembly/file-format)
- [Metadata and self-describing components — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/metadata-and-self-describing-components)
- [ILSpy — open source .NET decompiler](https://github.com/icsharpcode/ILSpy)
