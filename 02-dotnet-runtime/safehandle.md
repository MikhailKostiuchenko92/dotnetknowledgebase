# SafeHandle in .NET

**Category:** .NET Runtime / Interop
**Difficulty:** 🟡 Middle
**Tags:** `SafeHandle`, `CriticalFinalizerObject`, `IntPtr`, `Dispose`, `native-resources`, `interop`

## Question
> Why should you prefer `SafeHandle` over raw `IntPtr` for native resources?

> How does `SafeHandle` guarantee cleanup more reliably than a normal finalizer?

> What is `DangerousGetHandle()`, and why is it dangerous?

## Short Answer
`SafeHandle` is the recommended base class for wrapping OS and native handles because it centralizes ownership and guarantees cleanup through `ReleaseHandle()`, even in hard-to-test failure scenarios. It inherits through `CriticalFinalizerObject`, which gives its finalization path stronger reliability guarantees than an ordinary finalizer. Compared with raw `IntPtr`, `SafeHandle` makes lifetime explicit, prevents many leak and double-free bugs, and integrates cleanly with `IDisposable` and P/Invoke.

## Detailed Explanation
### Why Raw `IntPtr` Is Fragile
A raw `IntPtr` is just a number. It does not know whether it owns the underlying resource, whether it has already been freed, or whether another API still depends on it. If you store native handles as bare pointers, cleanup becomes a discipline problem spread across the codebase.

That leads to classic bugs:
- leaks because cleanup was forgotten
- double free because ownership was unclear
- use-after-free because a handle outlived its resource

### What `SafeHandle` Adds
`SafeHandle` wraps the native handle in an object whose job is resource ownership. You provide a subclass and implement `ReleaseHandle()`. The runtime then ensures the cleanup path runs once when the handle is disposed or finalized.

| Approach | Ownership tracking | Cleanup reliability |
|---|---|---|
| `IntPtr` | Manual only | Easy to get wrong |
| `SafeHandle` | Encapsulated in type | Deterministic via `Dispose`, fallback via critical finalizer |

### Critical Finalization
`SafeHandle` ultimately inherits from `CriticalFinalizerObject`. That matters because native resource cleanup is often more important than normal managed cleanup. Even during exceptional or constrained shutdown paths, the runtime tries hard to run critical finalizers so OS handles are not silently abandoned.

This does not mean finalizers are your primary cleanup strategy. `Dispose` should still be the normal path. The finalizer is the safety net.

### Built-In SafeHandle Types
The BCL already ships common wrappers such as `SafeFileHandle`, `SafeWaitHandle`, and `SafeMemoryMappedViewHandle`. If one exists for your resource, prefer it over creating your own.

### `DangerousGetHandle()`
Sometimes a native API requires a raw handle value, and `DangerousGetHandle()` exposes it. The method name is deliberate: once you hand out the raw value, you can bypass lifetime guarantees. If the `SafeHandle` is disposed while native code still uses that handle, you can crash or corrupt state.

### Why P/Invoke Signatures Often Accept `SafeHandle`
A good P/Invoke signature can take a `SafeHandle` parameter directly instead of `IntPtr`. That lets the runtime cooperate with the wrapper’s reference counting so the underlying resource is kept alive for the duration of the native call. It is both safer and easier to review because ownership remains visible in the type system instead of being hidden in comments.

> **Warning:** Only use `DangerousGetHandle()` when you completely control the lifetime of both the `SafeHandle` and the native consumer. Otherwise, prefer signatures that accept `SafeHandle` directly.

### Interview Rule of Thumb
Use `SafeHandle` whenever your code owns a native handle for more than an immediate local call. It improves correctness, readability, and resilience far more than a naked `IntPtr`.

Related: [IDisposable and using](./idisposable-and-using.md) and [SuppressFinalize](./suppress-finalize.md).

## Code Example
```csharp
using Microsoft.Win32.SafeHandles;
using System.Runtime.InteropServices;

namespace DotNetRuntimeExamples;

public sealed class SafeNativeBufferHandle() : SafeHandleZeroOrMinusOneIsInvalid(ownsHandle: true)
{
    public SafeNativeBufferHandle(nint existingHandle, bool ownsHandle)
        : this()
    {
        SetHandle(existingHandle); // Wrap an existing native pointer safely.
    }

    protected override bool ReleaseHandle()
    {
        Marshal.FreeHGlobal(handle); // Guaranteed cleanup path.
        return true;
    }
}

public static class SafeHandleDemo
{
    public static void Run()
    {
        using var buffer = new SafeNativeBufferHandle(Marshal.AllocHGlobal(256), ownsHandle: true);
        Console.WriteLine($"Allocated native buffer at 0x{buffer.DangerousGetHandle().ToInt64():X}"); // Safe only because lifetime is controlled here.
    }
}
```

## Common Follow-up Questions
- Why is `SafeHandle` better than writing a finalizer around `IntPtr` yourself?
- What does `CriticalFinalizerObject` guarantee?
- When should a P/Invoke signature take `SafeHandle` directly?
- What risks come with `DangerousGetHandle()`?
- Which built-in `SafeHandle` subclasses exist in the BCL?

## Common Mistakes / Pitfalls
- Storing ownership-bearing native handles as raw `IntPtr` values throughout the codebase.
- Relying on finalization instead of disposing deterministically.
- Calling `DangerousGetHandle()` and then using the raw value after the `SafeHandle` is disposed.
- Writing `ReleaseHandle()` implementations that throw.
- Creating custom wrappers when a built-in `SafeFileHandle` or similar type already exists.

## References
- [SafeHandle class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.safehandle)
- [CriticalFinalizerObject class](https://learn.microsoft.com/dotnet/api/system.runtime.constrainedexecution.criticalfinalizerobject)
- [SafeFileHandle class](https://learn.microsoft.com/dotnet/api/microsoft.win32.safehandles.safefilehandle)
- [Cleaning up unmanaged resources](https://learn.microsoft.com/dotnet/standard/garbage-collection/unmanaged)
