# IDisposable, using Statements, and Deterministic Cleanup

**Category:** .NET Runtime / GC
**Difficulty:** 🟢 Junior
**Tags:** `IDisposable`, `using`, `Dispose`, `finalizer`, `deterministic cleanup`, `resource management`

## Question

> What is the `IDisposable` pattern, and when should you implement it vs relying on the garbage collector?

Also asked as:
> What is the difference between `using` statement and `using` declaration in C#?
> When should a class implement both `IDisposable` and a finalizer?

## Short Answer

`IDisposable` enables *deterministic* cleanup of unmanaged resources (file handles, sockets, database connections) at a known point in the code. The GC manages *memory* automatically but doesn't know about OS handles — if you don't `Dispose()`, those resources leak until the finalizer runs (non-deterministic). The `using` statement/declaration guarantees `Dispose()` is called even when exceptions are thrown. A finalizer (`~MyClass()`) is a safety net for callers who forget to dispose; most classes should use `SafeHandle` instead of implementing their own finalizer.

## Detailed Explanation

### Why `IDisposable` Exists

The GC reclaims managed heap memory automatically. But many objects *wrap* unmanaged resources:

| Resource | If not released |
|----------|----------------|
| `FileStream` | File locked until process exits or GC runs finalizer |
| `DbConnection` | Connection pool slot occupied; pool exhaustion |
| `HttpClient` | Socket not returned to OS (TIME_WAIT) |
| `Mutex` | Other waiters blocked indefinitely |
| `GCHandle` | Managed object pinned forever; GC fragmentation |

The CLR's finalizer queue is a safety net, but it runs on a dedicated thread at non-deterministic time — too late for resources you need back immediately.

### The `using` Statement vs Declaration

```csharp
// using statement (C# 1+) — block scope, explicit { }
using (var conn = new SqlConnection(connectionString))
{
    conn.Open();
    // conn.Dispose() called here, even if exception thrown
}

// using declaration (C# 8+) — disposed at end of enclosing scope
using var conn2 = new SqlConnection(connectionString);
conn2.Open();
// conn2.Dispose() called at end of method / block
```

Both expand to a try/finally:

```csharp
SqlConnection conn = new(connectionString);
try { conn.Open(); /* ... */ }
finally { conn?.Dispose(); }
```

### Implementing `IDisposable` Without a Finalizer

For managed wrappers that hold other `IDisposable` objects:

```csharp
public sealed class FileProcessor : IDisposable
{
    private StreamReader _reader;
    private bool _disposed;

    public FileProcessor(string path) =>
        _reader = new StreamReader(path);

    public void Dispose()
    {
        if (_disposed) return;
        _reader.Dispose();
        _disposed = true;
    }
}
```

**Sealed + no native resources = no finalizer needed.**

### The Full Dispose Pattern (with Finalizer)

Only implement a finalizer when you *directly* hold an unmanaged handle (rare — prefer `SafeHandle`):

```csharp
public class NativeResourceWrapper : IDisposable
{
    private IntPtr _handle;   // OS handle
    private bool _disposed;

    public NativeResourceWrapper() =>
        _handle = OpenNativeResource(); // hypothetical native call

    // Called by consumer explicitly
    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this); // tell GC: don't run finalizer
    }

    // Called by GC finalizer thread if consumer forgot to dispose
    ~NativeResourceWrapper() => Dispose(disposing: false);

    protected virtual void Dispose(bool disposing)
    {
        if (_disposed) return;

        if (disposing)
        {
            // Safe to access other managed IDisposable objects here
        }

        // Always release the unmanaged handle
        if (_handle != IntPtr.Zero)
        {
            CloseNativeResource(_handle);
            _handle = IntPtr.Zero;
        }

        _disposed = true;
    }

    // ... native p/invoke methods
    static IntPtr OpenNativeResource() => IntPtr.Zero;
    static void CloseNativeResource(IntPtr h) { }
}
```

### `SafeHandle`: The Preferred Alternative

`SafeHandle` subclasses handle finalizer registration automatically and are more reliable than manual finalizers:

```csharp
public sealed class MySafeHandle : SafeHandleZeroOrMinusOneIsInvalid
{
    public MySafeHandle() : base(ownsHandle: true) { }

    protected override bool ReleaseHandle()
    {
        CloseNativeResource(handle);
        return true;
    }
}

// Usage: wrap in SafeHandle — no manual finalizer in the consumer
public class BetterNativeWrapper : IDisposable
{
    private readonly MySafeHandle _handle = new();

    public void Dispose() => _handle.Dispose(); // SafeHandle handles the rest
}
```

`SafeHandle` is immune to handle-recycling races and is the .NET team's recommended approach.

### `IAsyncDisposable` (.NET Core 3+)

For async cleanup (closing a `DbConnection` over async I/O):

```csharp
public class AsyncResource : IAsyncDisposable
{
    public async ValueTask DisposeAsync()
    {
        await FlushAsync();
        await CloseConnectionAsync();
    }
}

await using var res = new AsyncResource();
// DisposeAsync called at end of scope
```

## Code Example

```csharp
using System.IO;

// ── Basic using declaration ──────────────────────────────────────
using var file = File.OpenRead("data.txt");
using var reader = new StreamReader(file);
string content = reader.ReadToEnd();
// Both disposed at end of method — even if ReadToEnd throws

// ── Multiple resources, correct nesting ─────────────────────────
using var input  = new FileStream("in.bin",  FileMode.Open);
using var output = new FileStream("out.bin", FileMode.Create);
input.CopyTo(output);

// ── Checking for double-dispose (defensive) ──────────────────────
var processor = new FileProcessor("log.txt");
processor.Dispose();
processor.Dispose(); // should be idempotent — no exception

// ── IAsyncDisposable ─────────────────────────────────────────────
await using var conn = new System.Data.SqlClient.SqlConnection("...");
await conn.OpenAsync();
// Async dispose when scope exits

// ── Canonical sealed IDisposable (managed resources only) ────────
sealed class FileProcessor(string path) : IDisposable
{
    private readonly StreamReader _reader = new StreamReader(path);
    private bool _disposed;

    public string ReadLine() => _reader.ReadLine() ?? string.Empty;

    public void Dispose()
    {
        if (_disposed) return;
        _reader.Dispose();
        _disposed = true;
    }
}
```

## Common Follow-up Questions

- When does the GC call a finalizer, and in what order?
- What is `GC.SuppressFinalize` and why is it called in `Dispose()`?
- What happens if `Dispose()` is called multiple times — should it be idempotent?
- How does `IAsyncDisposable` differ from `IDisposable`, and when should you prefer it?
- What is `SafeHandle` and why is it preferable to writing your own finalizer?
- Can you `await` inside a `Dispose()` method? (No — use `DisposeAsync` instead.)

## Common Mistakes / Pitfalls

- **Not disposing `IDisposable` objects** — even with a finalizer as a safety net, relying on finalization ties up resources until the next GC pass, which may not happen for minutes in low-allocation code paths.
- **Making `Dispose()` throw exceptions** — `Dispose()` should be a best-effort cleanup. Throwing inside `Dispose()` during stack unwinding can mask the original exception.
- **Not implementing `Dispose()` as idempotent** — calling `Dispose()` twice must be safe. Track `_disposed` and return early on second call.
- **Accessing managed objects in a finalizer** — the finalizer runs on a separate thread and may run *after* those objects have been collected. Only access unmanaged handles in a finalizer; for managed objects, use the `Dispose(bool disposing)` pattern with the `disposing` flag.
- **Forgetting `IAsyncDisposable` when async cleanup is needed** — implementing only synchronous `Dispose()` and calling blocking `.Wait()` on async operations inside it can cause deadlocks in ASP.NET Core.

## References

- [Implement a Dispose method — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-dispose)
- [Implement DisposeAsync — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-disposeasync)
- [using statement — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/using)
- [SafeHandle — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.safehandle)
- [IDisposable best practices — Stephen Cleary's blog](https://blog.stephencleary.com/2009/08/idisposable-and-finalizers.html) (verify URL)
