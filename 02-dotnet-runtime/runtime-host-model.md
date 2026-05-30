# Custom .NET Hosting: Embedding the Runtime in Native Applications

**Category:** .NET Runtime / CLR
**Difficulty:** 🔴 Senior
**Tags:** `runtime host`, `hostfxr`, `custom host`, `embedding .NET`, `native hosting`, `MAUI`

## Question

> How do you embed the .NET runtime inside a native (C/C++) application, and what APIs does the .NET SDK provide for this?

Also asked as:
> What is the `hostfxr` hosting API and when would you write a custom .NET host?
> How does .NET MAUI / Blazor Hybrid embed the .NET runtime in a native mobile app?

## Short Answer

The .NET SDK exposes `hostfxr.dll` / `libhostfxr.so` as a public, stable C API for embedding the .NET runtime in native applications. A native host calls `hostfxr_initialize_for_runtime_config`, then `hostfxr_get_runtime_delegate` to get function pointers for loading assemblies and invoking managed methods. Frameworks like .NET MAUI, Blazor Desktop, and Unity use this API. For pure .NET scenarios, writing a custom host is rarely needed — most scenarios are served by `Worker Service`, `IHostedService`, or simply `dotnet run`.

## Detailed Explanation

### Why Custom Hosting Exists

The standard `dotnet` muxer and `apphost.exe` cover 99% of use cases. Custom hosting is needed when:

| Scenario | Why custom host |
|----------|----------------|
| Native game engine (Unity) | Engine is a C++ app; .NET is a scripting guest |
| Mobile app (.NET MAUI) | OS app lifecycle is controlled by ObjC/Swift/Java; .NET is embedded |
| Blazor Hybrid | WinForms/WPF/MAUI host embeds a WebView that runs Blazor |
| SQL Server CLR | SQL Server hosts the CLR to run stored procedures |
| Embedding .NET in IoT firmware | Firmware is C; .NET provides managed logic |

### The Hosting API Layers

```
Native app (C/C++)
    │  dlopen / LoadLibrary
    ▼
hostfxr  (public, stable API — versioned separately from .NET runtime)
    │  hostfxr_initialize_for_runtime_config
    │  hostfxr_get_runtime_delegate
    ▼
hostpolicy  (selected by hostfxr based on runtimeconfig.json)
    │
    ▼
coreclr  (the actual CLR — loaded via hostpolicy)
    │
    ▼
Managed Assembly  (your .NET code)
```

### Key `hostfxr` Functions

```c
// C API (simplified signatures)

// 1. Find hostfxr path (use nethost.h helper)
get_hostfxr_path(buffer, &bufferSize, NULL);

// 2. Load hostfxr
void* hostfxr = dlopen(hostfxr_path, RTLD_LAZY);
auto init_fn = (hostfxr_initialize_for_runtime_config_fn)
    dlsym(hostfxr, "hostfxr_initialize_for_runtime_config");

// 3. Initialize from runtimeconfig.json
hostfxr_handle ctx;
init_fn(L"MyApp.runtimeconfig.json", NULL, &ctx);

// 4. Get a delegate type
auto get_delegate = (hostfxr_get_runtime_delegate_fn)
    dlsym(hostfxr, "hostfxr_get_runtime_delegate");

// 5. Get the managed entry point loader
load_assembly_and_get_function_pointer_fn load_fn;
get_delegate(ctx, hdt_load_assembly_and_get_function_pointer, &load_fn);

// 6. Load assembly and get a managed method pointer
typedef void (CORECLR_DELEGATE_CALLTYPE* managed_callback_t)(const wchar_t* input);
managed_callback_t callback;
load_fn(L"MyLib.dll",
        L"MyLib.MyClass, MyLib",
        L"HelloFromManaged",
        L"MyLib.MyClass+HelloDelegate, MyLib",
        NULL,
        (void**)&callback);

// 7. Call managed code
callback(L"Hello from native!");
```

### The Managed Side

The managed assembly exports a callback using `UnmanagedCallersOnly` (for NativeAOT) or a standard delegate match:

```csharp
namespace MyLib;

public class MyClass
{
    // Called from native via function pointer
    public static void HelloFromManaged(IntPtr input, int inputSize)
    {
        string message = Marshal.PtrToStringUni(input) ?? "";
        Console.WriteLine($"Managed received: {message}");
    }

    // Delegate type matching the native typedef
    public delegate void HelloDelegate(IntPtr input, int inputSize);
}
```

### NativeAOT Hosting (Simplified)

With NativeAOT, the managed assembly compiles to a native shared library (`.so` / `.dll`) with no runtime host needed:

```csharp
// Marked as a native export — callable from C without any hosting setup
[UnmanagedCallersOnly(EntryPoint = "hello")]
public static void Hello()
{
    Console.WriteLine("Hello from NativeAOT!");
}
```

```bash
dotnet publish -r linux-x64 -p:NativeAot=true -p:PublishAot=true
# Produces: MyLib.so — a native shared library with 'hello' export
```

NativeAOT hosting is the simplest option for new native-interop scenarios because it eliminates the entire host initialization dance.

### .NET MAUI's Hosting Model

.NET MAUI uses the `AppHostBuilder` pattern on top of the hosting APIs:
- On iOS/Android, the ObjC/Java app lifecycle is the outer process
- `.NET MAUI` registers as an embedded runtime using platform-specific hosting
- `MauiProgram.CreateMauiApp()` is the managed entry point called by the native bootstrap

Most .NET developers never need to deal with this directly — the MAUI tooling handles it.

## Code Example

```csharp
// Managed side: method callable from a native host via hostfxr delegate

using System.Runtime.InteropServices;

namespace HostedLib;

public class EntryPoints
{
    // Signature must match the delegate typedef in the native host
    public static int ComputeSum(int a, int b)
    {
        Console.WriteLine($"Managed: computing {a} + {b}");
        return a + b;
    }

    // For NativeAOT export (no host needed — compile to native .so)
    [UnmanagedCallersOnly(EntryPoint = "compute_sum")]
    public static int ComputeSumNative(int a, int b) => a + b;
}
```

```bash
# Build for hosting consumption
dotnet publish -r linux-x64 --self-contained false
# → HostedLib.dll + HostedLib.runtimeconfig.json (required by hostfxr)

# Build as NativeAOT shared library (no CLR host needed by the consumer)
dotnet publish -r linux-x64 -p:PublishAot=true -p:NativeLib=Shared
# → HostedLib.so with exported 'compute_sum' symbol
```

## Common Follow-up Questions

- What is the difference between `hostfxr`, `hostpolicy`, and `coreclr`?
- How does NativeAOT differ from the traditional CLR hosting approach?
- How does Unity embed Mono vs the CoreCLR in its engine?
- What are the threading constraints when calling managed code from a native thread?
- How do you marshal complex types (strings, arrays, objects) across the native/managed boundary in a hosted scenario?
- What is `IJsRuntime` in Blazor WebAssembly and how is it different from Blazor Desktop hosting?

## Common Mistakes / Pitfalls

- **Not providing `runtimeconfig.json` alongside the assembly** — the hosting API requires `runtimeconfig.json` to find and initialize the correct runtime version.
- **Calling managed methods from multiple native threads without synchronization** — the CLR is fully thread-safe, but the managed code you invoke may not be. Create a managed synchronization boundary.
- **Forgetting `GC.KeepAlive` on objects passed as `IntPtr` to native** — the GC may collect the object between the pointer extraction and the native call. Use `GCHandle.Alloc(obj, GCHandleType.Pinned)`.
- **Using the hostfxr API for simple in-process calls** — if you're already in a .NET process, use `Assembly.LoadFrom` + reflection. The hostfxr API is only for bootstrapping .NET from a *native* host.
- **Mixing NativeAOT and the hosting API** — NativeAOT-compiled assemblies are native shared libraries; they don't need or use hostfxr. Mixing them leads to two separate runtimes in the same process.

## References

- [Write a custom .NET host — Microsoft Learn](https://learn.microsoft.com/dotnet/core/tutorials/netcore-hosting)
- [hostfxr hosting API reference — .NET runtime GitHub](https://github.com/dotnet/runtime/blob/main/docs/design/features/host-api-with-runtime-host.md)
- [NativeAOT — publish as shared library — Microsoft Learn](https://learn.microsoft.com/dotnet/core/deploying/native-aot/)
- [UnmanagedCallersOnly attribute — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.unmanagedcallersonlyattribute)
- [.NET MAUI architecture — Microsoft Learn](https://learn.microsoft.com/dotnet/maui/what-is-maui)
