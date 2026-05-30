# .NET Runtime

> CLR, Garbage Collection, memory model, JIT/AOT, threading.

## Questions

_No questions added yet. Use the [question template](../_templates/question-template.md) to add one._

## Index

### §1 CLR Fundamentals
- [appdomain-removal.md](./appdomain-removal.md) — AppDomain in .NET Framework vs .NET Core, migration to AssemblyLoadContext
- [assembly-anatomy.md](./assembly-anatomy.md) — Assembly manifest, modules, metadata, MSIL, PE format
- [assembly-load-context-basics.md](./assembly-load-context-basics.md) — AssemblyLoadContext, isolated ALCs, plugin loading pattern
- [assembly-loading-and-binding.md](./assembly-loading-and-binding.md) — Assembly resolution rules, binding redirects, probing paths
- [clr-execution-model.md](./clr-execution-model.md) — IL → JIT → native pipeline, CLR services overview
- [clr-startup-sequence.md](./clr-startup-sequence.md) — hostfxr → hostpolicy → coreclr, startup hooks, type init
- [global-assembly-cache.md](./global-assembly-cache.md) — GAC in .NET Framework, why removed from .NET Core, side-by-side
- [managed-vs-unmanaged-code.md](./managed-vs-unmanaged-code.md) — CLR supervision, unsafe keyword, P/Invoke boundary
- [runtime-configuration.md](./runtime-configuration.md) — runtimeconfig.json, DOTNET_ env vars, AppContext switches
- [strong-naming-and-signing.md](./strong-naming-and-signing.md) — Strong name key pairs, PublicKeyToken, Authenticode vs strong naming