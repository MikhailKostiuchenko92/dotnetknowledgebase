# GC Handles in .NET

**Category:** .NET Runtime / GC
**Difficulty:** 🔴 Senior
**Tags:** `GCHandle`, `Normal`, `Pinned`, `Weak`, `WeakTrackResurrection`, `interop`

## Question

> What is a `GCHandle`, and when would you use the different `GCHandleType` values in .NET?

Also asked as:
> What is the difference between `Normal`, `Pinned`, `Weak`, and `WeakTrackResurrection` handles?
> How do `GCHandle.ToIntPtr` and `GCHandle.FromIntPtr` help with native callbacks?

## Short Answer

`GCHandle` is a low-level runtime API that creates explicit handles the GC can track outside normal managed references. `Normal` keeps an object alive, `Pinned` keeps it alive and prevents relocation, `Weak` allows collection while still letting you test whether the object survived, and `WeakTrackResurrection` continues tracking through finalization. It is powerful for interop and advanced runtime scenarios, but forgetting to call `Free()` leaks handles and can pin objects indefinitely.

## Detailed Explanation

### Why `GCHandle` Exists

Most managed code never needs `GCHandle` because normal references are enough. `GCHandle` exists for cases where managed objects must be represented through a runtime handle that can cross boundaries the GC does not automatically understand, especially native interop.

Examples include:
- passing a managed object token to native code and getting it back in a callback
- pinning a managed buffer before a P/Invoke call
- keeping an object alive beyond the scope of a temporary managed reference
- creating weak tracking semantics at the handle level

### The Four Common Handle Types

| Type | Keeps object alive? | Prevents movement? | Typical use |
|---|---|---|---|
| `Normal` | Yes | No | Native callback state, lifetime bridging |
| `Pinned` | Yes | Yes | P/Invoke buffer or address passing |
| `Weak` | No | No | Optional cache or observer tracking |
| `WeakTrackResurrection` | No | No | Rare finalization/resurrection scenarios |

`GCHandleType.Normal` acts like an explicit strong root. The object may move during compaction, but it will not be collected until the handle is freed.

`GCHandleType.Pinned` is stronger: it keeps the object alive **and** fixes its address so native code can safely use a pointer. That convenience comes at a GC cost because pinned objects interfere with compaction.

`GCHandleType.Weak` does not keep the object alive. If the target is collected, `handle.Target` becomes `null`.

`GCHandleType.WeakTrackResurrection` behaves similarly but can continue tracking past finalization. This is niche and tied to resurrection behavior.

> **Warning:** `Pinned` is not a performance optimization. It is an interop escape hatch, and overuse can fragment the managed heap.

### Why `Free()` Is Mandatory

A `GCHandle` is backed by runtime bookkeeping outside normal managed references. If you do not call `Free()`, the handle entry persists. With `Normal`, you leak liveness and memory. With `Pinned`, you also leak fragmentation pressure because the GC must keep working around that object.

That is why `GCHandle` should be treated like an unmanaged resource. Wrap it in `try/finally` or a small disposable helper when possible.

### `ToIntPtr` / `FromIntPtr` for Native Callbacks

Interop often requires passing `void*`-style user data to native code. `GCHandle.ToIntPtr(handle)` converts the handle into an opaque pointer-sized token. Native code stores and later returns that value. Managed callback code reconstructs the handle with `GCHandle.FromIntPtr` and recovers the original target.

This pattern avoids raw object references crossing the native boundary and is a standard way to attach callback state.

### GC Handles vs Higher-Level Alternatives

Prefer higher-level APIs when possible:
- `WeakReference<T>` instead of weak `GCHandle` in normal managed code
- `fixed` for very short-lived pinning within one scope
- `SafeHandle` for native handles from the OS

Use `GCHandle` when you specifically need runtime handle semantics or a pointer-sized token that native code can round-trip.

Related: [Object pinning](./object-pinning.md).

## Code Example

```csharp
using System.Runtime.InteropServices;

namespace DotNetRuntimeExamples;

internal sealed class CallbackState(string name)
{
    public string Name { get; } = name;
}

internal static class Program
{
    private static void Main()
    {
        object payload = new CallbackState("download-42");

        GCHandle normal = GCHandle.Alloc(payload, GCHandleType.Normal);
        GCHandle pinned = GCHandle.Alloc(new byte[256], GCHandleType.Pinned);
        GCHandle weak = GCHandle.Alloc(new object(), GCHandleType.Weak);
        GCHandle weakLong = GCHandle.Alloc(new object(), GCHandleType.WeakTrackResurrection);

        try
        {
            nint cookie = GCHandle.ToIntPtr(normal); // Pass this to native code.
            GCHandle roundTripped = GCHandle.FromIntPtr(cookie);
            var state = (CallbackState)roundTripped.Target!;
            Console.WriteLine(state.Name);

            nint address = pinned.AddrOfPinnedObject(); // Stable pointer for interop.
            Console.WriteLine($"Pinned buffer address: 0x{address:X}");

            Console.WriteLine($"Weak target alive: {weak.Target is not null}");
            Console.WriteLine($"Long weak target alive: {weakLong.Target is not null}");
        }
        finally
        {
            normal.Free();
            pinned.Free();
            weak.Free();
            weakLong.Free();
        }
    }
}
```

## Common Follow-up Questions

- Why is `GCHandleType.Pinned` more expensive than `Normal`?
- When should you use `fixed` instead of a pinned handle?
- Why is `WeakReference<T>` usually preferable to weak `GCHandle` in managed code?
- What happens if native code keeps a `GCHandle` cookie after managed code frees it?
- How does `GCHandle` relate to `SafeHandle`?
- Can a `GCHandle` keep a collectible `AssemblyLoadContext` alive indirectly?

## Common Mistakes / Pitfalls

- Forgetting to call `Free()`, which leaks handles and can leak object lifetimes.
- Using `Pinned` handles for long-lived objects without measuring fragmentation impact.
- Treating `Weak` handles as if they guarantee the target will still exist later.
- Passing the address of a managed object to native code without pinning it first.
- Reconstructing a handle from an invalid `IntPtr` after the original handle was freed.

## References

- [GCHandle](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.gchandle)
- [GCHandleType](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.gchandletype)
- [Memory<T> and friends usage guidelines](https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines)
- [Native interoperability best practices](https://learn.microsoft.com/dotnet/standard/native-interop/best-practices)
