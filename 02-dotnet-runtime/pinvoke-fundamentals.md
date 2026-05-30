# P/Invoke Fundamentals

**Category:** .NET Runtime / Interop
**Difficulty:** 🟢 Junior
**Tags:** `p-invoke`, `DllImport`, `LibraryImport`, `interop`, `marshalling`, `NativeLibrary`

## Question
> What is P/Invoke, and what does the CLR do when managed code calls a native DLL function?

> How do `[DllImport]` and `[LibraryImport]` differ in modern .NET?

> What are entry points and calling conventions in native interop?

## Short Answer
Platform Invoke (P/Invoke) lets managed code call functions exported by native libraries. The CLR locates the DLL, resolves the target entry point, marshals arguments and return values between managed and native representations, invokes the function with the correct calling convention, and then marshals the result back. In .NET 7+, `[LibraryImport]` is often preferred over `[DllImport]` because it uses source generation, improves trimming and NativeAOT compatibility, and can reduce runtime marshalling overhead.

## Detailed Explanation
### What P/Invoke Does
P/Invoke is the bridge between managed .NET code and unmanaged functions exported from native DLLs or shared libraries. When you declare a method with `[DllImport]` or `[LibraryImport]`, you are describing a contract the runtime can use to issue a native call.

The call flow is roughly:
1. locate the library
2. resolve the exported symbol or configured entry point
3. marshal parameters into native layout
4. perform the call using the correct ABI/calling convention
5. marshal the return value and out parameters back

### Entry Point Resolution
The runtime normally looks for the method name as the native export. If `EntryPoint` is specified, it uses that exact export name instead. Historically on Windows, some APIs also had ANSI and Unicode suffixes such as `FooA` and `FooW`, and P/Invoke could participate in that naming pattern depending on configuration.

| Declaration detail | Meaning |
|---|---|
| `EntryPoint = "FuncName"` | Use that exact exported symbol |
| `CharSet = CharSet.Unicode` | Influences string marshalling and some name resolution behavior |
| `ExactSpelling = true` | Avoid alternate name probing |

### Calling Conventions Matter
The managed declaration must match the native ABI. A mismatch can corrupt the stack or crash the process.

Common conventions include:
- `StdCall`: common Win32 default for many Windows APIs
- `Cdecl`: caller cleans the stack; common in C libraries
- `ThisCall`: instance-method calling convention in some C++ scenarios
- `FastCall`: specialized convention, less common in P/Invoke work

### `[DllImport]` vs `[LibraryImport]`
`[DllImport]` is the classic attribute and still works well. `[LibraryImport]` is newer and uses a Roslyn source generator to emit the interop stub at compile time.

| API | Characteristics |
|---|---|
| `[DllImport]` | Classic runtime-generated marshalling path |
| `[LibraryImport]` | Source-generated, more explicit, better for trimming/AOT |

`[LibraryImport]` is especially attractive in NativeAOT and high-performance interop because it avoids some runtime code generation assumptions.

### Manual Library Loading
Sometimes you do not want the runtime to bind a library automatically at first use. `NativeLibrary.Load` and `TryLoad` let you control probing, versioning, fallback logic, or plugin loading yourself.

### Error Reporting Across the Boundary
Many native APIs communicate failure through return codes plus a thread-local OS error slot. In those cases, the P/Invoke declaration may need `SetLastError = true`, and managed code can then read the value with interop helpers such as `Marshal.GetLastPInvokeError()`. That pattern is common in Win32 and is separate from managed exceptions: the native call may “succeed” at the ABI level while still reporting an OS error code you must translate.

> **Warning:** P/Invoke signatures are part of your memory-safety boundary. One wrong type, wrong charset, or wrong calling convention can turn a normal method call into process corruption.

### Practical Guidance
Start simple: use built-in types, explicit entry points where helpful, and source-generated interop for new code. Reach for custom marshalling only when the default rules are not enough.

Related: [Marshalling Types](./marshalling-types.md).

## Code Example
```csharp
using System.Runtime.InteropServices;

namespace DotNetRuntimeExamples;

internal static partial class NativeMethods
{
    [DllImport("kernel32.dll", EntryPoint = "GetCurrentThreadId", CallingConvention = CallingConvention.Winapi)]
    internal static extern uint GetCurrentThreadId(); // Classic P/Invoke.

    [LibraryImport("kernel32.dll", EntryPoint = "GetTickCount")]
    [return: MarshalAs(UnmanagedType.U4)]
    internal static partial uint GetTickCount(); // Source-generated P/Invoke.
}

public static class PInvokeDemo
{
    public static void Run()
    {
        var threadId = NativeMethods.GetCurrentThreadId();
        var tickCount = NativeMethods.GetTickCount();

        Console.WriteLine($"Managed thread is backed by native thread id {threadId}.");
        Console.WriteLine($"Tick count from native API: {tickCount}.");

        if (NativeLibrary.TryLoad("kernel32.dll", out var handle))
        {
            Console.WriteLine($"Loaded native library handle: 0x{handle.ToInt64():X}");
            NativeLibrary.Free(handle); // Free manually loaded handles.
        }
    }
}
```

## Common Follow-up Questions
- What exactly does the runtime marshal during a P/Invoke call?
- When should I choose `[LibraryImport]` over `[DllImport]`?
- What problems come from a mismatched calling convention?
- How does `EntryPoint` resolution interact with `CharSet` and A/W suffixes?
- When is `NativeLibrary.Load` useful instead of attribute-based loading?

## Common Mistakes / Pitfalls
- Declaring the wrong calling convention and corrupting the native call stack.
- Assuming managed `bool` and native `BOOL` always marshal the same way without checking.
- Letting the runtime guess export names when explicit `EntryPoint` would be safer.
- Using `[DllImport]` signatures that work in JIT scenarios but are fragile under trimming or NativeAOT.
- Forgetting to free handles loaded manually with `NativeLibrary.Load`.

## References
- [DllImportAttribute class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.dllimportattribute)
- [LibraryImportAttribute class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.libraryimportattribute)
- [NativeLibrary class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.nativelibrary)
- [Best practices for native interoperability](https://learn.microsoft.com/dotnet/standard/native-interop/best-practices)
