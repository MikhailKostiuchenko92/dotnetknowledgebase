# Finalizers and the Dispose Pattern

**Category:** C# / OOP in C#
**Difficulty:** Senior
**Tags:** `finalizer`, `dispose`, `idisposable`, `safehandle`, `gc`

## Question

> When should you write a finalizer in C#, and what does the full dispose pattern look like?

Also asked as:
- "What is the difference between a finalizer and `Dispose()`?"
- "Why do most .NET types not need a finalizer?"
- "What does `GC.SuppressFinalize(this)` actually do, and why is `SafeHandle` preferred?"

## Short Answer

`Dispose()` is deterministic cleanup that your code calls explicitly or through `using`, while a finalizer is a nondeterministic last-resort cleanup mechanism run by the GC on a special finalizer thread. Most types should not have a finalizer because finalizable objects are more expensive and slower to reclaim. You normally implement the dispose pattern only when your type directly owns unmanaged resources or must coordinate cleanup across inheritance; when possible, wrap native handles in `SafeHandle` and avoid writing your own finalizer.

## Detailed Explanation

### Deterministic vs Nondeterministic Cleanup

Managed memory is reclaimed automatically, but unmanaged resources are not. Examples include native handles, unmanaged buffers, sockets exposed through native wrappers, and OS resources that are scarce even if memory is plentiful.

`Dispose()` exists so you can release those resources *now*, not "whenever GC eventually notices." A finalizer exists only as a safety net in case `Dispose()` was never called.

| Mechanism | Trigger | Timing | Typical use |
|---|---|---|---|
| `Dispose()` | Caller / `using` | Deterministic | Normal cleanup path |
| Finalizer | GC | Nondeterministic | Last-chance unmanaged cleanup |
| `SafeHandle` finalization | Runtime + handle wrapper | Nondeterministic, but safer | Preferred native-handle ownership |

### When You Usually Should **Not** Write a Finalizer

Most types should not define `~TypeName()`.

Reasons:

- Finalizable objects survive at least one extra GC cycle.
- They are placed on the finalization queue.
- Finalizers run on a dedicated thread, so ordering is limited and timing is unpredictable.
- Finalizers make object lifetime and shutdown behavior harder to reason about.

If your type only contains managed fields such as `FileStream`, `HttpClient`, `DbConnection`, or `MemoryStream`, then those fields already know how to clean themselves up. Your type may still implement `IDisposable` to dispose those members, but it usually does **not** need its own finalizer.

> **Warning:** A finalizer should almost never touch other managed objects, because during finalization you cannot safely assume their state or ordering.

### When a Finalizer *Is* Appropriate

A finalizer is justified when your type directly owns unmanaged state that must be released even if the consumer forgets to dispose the object. Classic examples include a raw native handle, unmanaged memory from `Marshal.AllocHGlobal`, or custom interop wrappers.

Even then, the preferred design is usually to put the native lifetime into a `SafeHandle` subclass and let that wrapper handle finalization. Your higher-level type then only needs `IDisposable`, not a finalizer.

### The Full Dispose Pattern

The classic full pattern is mainly for unsealed types or types with unmanaged ownership:

1. public `Dispose()` calls `Dispose(true)`
2. `Dispose()` calls `GC.SuppressFinalize(this)`
3. finalizer calls `Dispose(false)`
4. `Dispose(bool disposing)` frees unmanaged resources in both paths
5. managed resources are disposed only when `disposing == true`

That split matters because the finalizer path is not a safe place to rely on other managed objects.

### What `GC.SuppressFinalize(this)` Does

If cleanup already happened through `Dispose()`, there is no value in running the finalizer later. `GC.SuppressFinalize(this)` removes the object from finalization if it is eligible, reducing unnecessary work.

Interview-safe wording: **it does not destroy the object; it just tells the GC not to run that object's finalizer later because cleanup already occurred.**

### SafeHandle Preference

`SafeHandle` is preferred because it centralizes tricky native-handle lifetime rules in a framework-supported abstraction. It helps avoid writing fragile finalizer code yourself and is resilient in exceptional execution paths. In modern .NET, "use `SafeHandle` instead of a custom finalizer when you can" is the expected answer.

### Sealed vs Inheritable Types

For a sealed type that just owns disposable fields, a simple `Dispose()` implementation is often enough. The full `Dispose(bool)` pattern mainly matters when inheritance or direct unmanaged ownership is involved.

This topic pairs naturally with [idisposable-and-using.md](./idisposable-and-using.md) and [constructors-chaining-and-static.md](./constructors-chaining-and-static.md).

## Code Example

```csharp
using System;
using System.IO;
using System.Runtime.InteropServices;

using var owner = new UnmanagedBufferOwner(256);
owner.WriteByte(0, 42);
Console.WriteLine(owner.ReadByte(0)); // 42

public class UnmanagedBufferOwner : IDisposable
{
    private readonly MemoryStream _auditStream = new(); // Managed resource.
    private IntPtr _buffer;
    private bool _disposed;

    public UnmanagedBufferOwner(int size)
    {
        if (size <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(size));
        }

        _buffer = Marshal.AllocHGlobal(size); // Direct unmanaged allocation.
        Size = size;
    }

    public int Size { get; }

    public void WriteByte(int index, byte value)
    {
        ThrowIfDisposed();
        ArgumentOutOfRangeException.ThrowIfNegative(index);
        ArgumentOutOfRangeException.ThrowIfGreaterThanOrEqual(index, Size);

        Marshal.WriteByte(_buffer, index, value);
        _auditStream.WriteByte(value); // Safe only in the explicit dispose path.
    }

    public byte ReadByte(int index)
    {
        ThrowIfDisposed();
        ArgumentOutOfRangeException.ThrowIfNegative(index);
        ArgumentOutOfRangeException.ThrowIfGreaterThanOrEqual(index, Size);

        return Marshal.ReadByte(_buffer, index);
    }

    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this); // No need for finalizer later if we already cleaned up.
    }

    protected virtual void Dispose(bool disposing)
    {
        if (_disposed)
        {
            return;
        }

        if (disposing)
        {
            _auditStream.Dispose(); // Dispose managed state only on deterministic cleanup.
        }

        if (_buffer != IntPtr.Zero)
        {
            Marshal.FreeHGlobal(_buffer); // Free unmanaged memory in both paths.
            _buffer = IntPtr.Zero;
        }

        _disposed = true;
    }

    ~UnmanagedBufferOwner()
    {
        Dispose(disposing: false); // Last-chance cleanup if caller forgot Dispose().
    }

    private void ThrowIfDisposed()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
    }
}
```

## Common Follow-up Questions

- Why is `Dispose()` preferred over relying on finalization?
- Why should managed objects usually not be touched in the finalizer path?
- What problem does `GC.SuppressFinalize(this)` prevent?
- When can a sealed type implement a simpler dispose pattern than an inheritable type?
- Why is `SafeHandle` safer than writing your own finalizer around an `IntPtr`?
- What happens to finalizable objects during GC compared with ordinary objects?

## Common Mistakes / Pitfalls

- Writing a finalizer for a type that only owns managed disposable fields.
- Forgetting to call `GC.SuppressFinalize(this)` after successful deterministic cleanup.
- Disposing managed fields in `Dispose(false)` where finalization ordering is unsafe.
- Making finalizer logic complex, blocking, or exception-prone.
- Using raw `IntPtr` ownership when `SafeHandle` would model the resource more safely.
- Assuming finalizers run quickly or at process shutdown in a predictable order.

## References

- [Finalize and Dispose](https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-dispose)
- [Finalizers (C# Programming Guide)](https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/finalizers)
- [Cleaning up unmanaged resources](https://learn.microsoft.com/dotnet/standard/garbage-collection/unmanaged)
- [SafeHandle Class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.safehandle)
- [See: idisposable-and-using.md](./idisposable-and-using.md)
