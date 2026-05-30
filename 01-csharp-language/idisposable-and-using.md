# `IDisposable` and the `using` Statement

**Category:** C# / Type System / Resource Management
**Difficulty:** 🟡 Middle
**Tags:** `IDisposable`, `using`, `Dispose`, `IAsyncDisposable`, `finalizer`, `resource-management`

## Question

> What is `IDisposable`, and how does the `using` statement/declaration relate to it? When should you implement it?

Additional phrasings:
- *"What is the difference between `using` statement and `using` declaration (C# 8+)?"*
- *"When would you implement `IDisposable` vs `IAsyncDisposable`?"*

## Short Answer

`IDisposable` provides a deterministic way to release unmanaged or expensive resources (file handles, database connections, sockets) without waiting for the GC. The `using` statement guarantees `Dispose()` is called even if an exception is thrown by compiling to a `try/finally` block. Implement `IDisposable` on any type that owns resources with a defined end-of-use: file streams, database connections, `HttpClient`, `CancellationTokenSource`, and similar. `IAsyncDisposable` (C# 8 / .NET Core 3.0+) adds `DisposeAsync()` for resources that must be released asynchronously.

## Detailed Explanation

### Why Deterministic Cleanup Matters

The GC collects objects non-deterministically — a file stream left to finalization might hold an OS file handle for seconds or minutes. For scarce resources (database connections, file locks, network sockets), you need cleanup to happen **now**, when you're done with them. `IDisposable` is the contract for that.

### The `using` Statement (Classic)

```csharp
using (var stream = new FileStream("data.txt", FileMode.Open))
{
    // use stream
}
// stream.Dispose() guaranteed here — even if an exception was thrown
```

The compiler transforms this to:

```csharp
FileStream stream = new FileStream("data.txt", FileMode.Open);
try
{
    // use stream
}
finally
{
    stream?.Dispose();
}
```

### The `using` Declaration (C# 8+)

A `using` declaration disposes the variable at the **end of the enclosing scope** (closing `}` of the containing block or method):

```csharp
void ProcessFile(string path)
{
    using var stream = new FileStream(path, FileMode.Open); // no extra braces needed
    using var reader = new StreamReader(stream);
    Console.WriteLine(reader.ReadToEnd());
} // reader.Dispose(), then stream.Dispose() called here (reverse declaration order)
```

This is syntactically cleaner for deeply nested code. Disposal order is **reverse of declaration order**, matching the classic `using` statement behavior.

### Implementing `IDisposable`

The simplest correct implementation for a **sealed** class that holds only managed disposable resources:

```csharp
sealed class DatabaseSession(DbConnection connection) : IDisposable
{
    private bool _disposed;

    public void Dispose()
    {
        if (_disposed) return;
        connection.Dispose();
        _disposed = true;
    }
}
```

For **unsealed classes** (where subclasses might have their own unmanaged resources), use the **protected virtual Dispose(bool disposing)** pattern:

```csharp
class ResourceHolder : IDisposable
{
    private bool _disposed;
    protected IntPtr _handle; // unmanaged resource (example)

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this); // suppress finalizer since we cleaned up already
    }

    protected virtual void Dispose(bool disposing)
    {
        if (_disposed) return;
        if (disposing)
        {
            // Free managed resources
        }
        // Free unmanaged resources (safe to do regardless of disposing flag)
        if (_handle != IntPtr.Zero) { /* release handle */ _handle = IntPtr.Zero; }
        _disposed = true;
    }

    ~ResourceHolder() => Dispose(false); // finalizer as safety net
}
```

> Only add a finalizer if your class **directly holds unmanaged resources** (raw `IntPtr`, `SafeHandle`, etc.). For classes that only wrap other `IDisposable` objects, a finalizer is unnecessary and harmful (it keeps the object alive an extra GC generation).

For most cases today, prefer wrapping unmanaged handles in `SafeHandle` subclasses, which handle their own finalization correctly and make the full dispose pattern unnecessary in your consuming class.

### `IAsyncDisposable` (C# 8 / .NET Core 3.0+)

Some resources require async cleanup: flushing a network buffer, closing a database transaction, gracefully terminating an actor. `IAsyncDisposable` provides `DisposeAsync()` returning `ValueTask`:

```csharp
class AsyncResource : IAsyncDisposable
{
    public async ValueTask DisposeAsync()
    {
        await FlushAndCloseAsync();
    }
}
```

Consumed with `await using`:

```csharp
await using var resource = new AsyncResource();
// resource.DisposeAsync() called when leaving scope
```

If a type implements both `IDisposable` and `IAsyncDisposable`, prefer `await using` in async contexts to avoid blocking.

### Common Types That Implement `IDisposable`

| Type | Resource released |
|---|---|
| `FileStream`, `StreamReader`, `StreamWriter` | OS file handle |
| `SqlConnection`, `DbConnection` | Database connection pool slot |
| `HttpClient` | Socket (but don't dispose per-request — see pitfalls) |
| `CancellationTokenSource` | Kernel timer object |
| `SemaphoreSlim` | Kernel semaphore (when created with initial count) |
| `Timer` | Thread pool timer |
| `DbContext` (EF Core) | Connection + change tracking state |

### `using` with `IDisposable` Objects You Don't Own

If a method *borrows* a resource (receives it as a parameter), it generally should **not** dispose it — only the owner disposes:

```csharp
// BAD: caller still needs the stream after this method
void ReadHeader(Stream stream)
{
    using var reader = new StreamReader(stream); // disposes the stream too!
    ...
}

// GOOD: leave=true tells StreamReader not to close the underlying stream
void ReadHeader(Stream stream)
{
    using var reader = new StreamReader(stream, leaveOpen: true);
    ...
}
```

[See: finalizer-and-dispose-pattern.md](./finalizer-and-dispose-pattern.md) for the full dispose/finalize pattern with unmanaged resources.

## Code Example

```csharp
using System.IO;
using System.Threading.Tasks;

// === Classic using statement ===
void WriteFile(string path, string content)
{
    using (var writer = new StreamWriter(path))
    {
        writer.WriteLine(content);
    } // writer.Dispose() guaranteed here
}

// === using declaration (C# 8+): disposed at end of method ===
void WriteFileModern(string path, string content)
{
    using var writer = new StreamWriter(path); // cleaner syntax
    writer.WriteLine(content);
} // Dispose() called here

// === Multiple disposables in reverse order ===
void CopyFile(string src, string dst)
{
    using var input  = new FileStream(src, FileMode.Open,   FileAccess.Read);
    using var output = new FileStream(dst, FileMode.Create, FileAccess.Write);
    input.CopyTo(output);
} // output.Dispose() first, then input.Dispose()

// === IAsyncDisposable + await using ===
class AsyncDbSession(string connectionString) : IAsyncDisposable
{
    private readonly SqlConnection _conn = new(connectionString);
    private bool _disposed;

    public async Task OpenAsync() => await _conn.OpenAsync();

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        await _conn.DisposeAsync(); // async close
        _disposed = true;
    }
}

async Task RunQueryAsync(string connStr)
{
    await using var session = new AsyncDbSession(connStr);
    await session.OpenAsync();
    // ... execute queries
} // session.DisposeAsync() awaited here

// Placeholder to avoid missing reference warning
class SqlConnection(string s) : IAsyncDisposable
{
    public Task OpenAsync() => Task.CompletedTask;
    public ValueTask DisposeAsync() => ValueTask.CompletedTask;
}
```

## Common Follow-up Questions

- When should you add a finalizer to your class, and when is it harmful?
- What is `SafeHandle` and how does it simplify working with unmanaged resources?
- What happens if `Dispose()` throws an exception — is it swallowed by `using`?
- How does EF Core's `DbContext` implement `IDisposable`, and what happens if you forget to dispose it?
- How does `using` interact with `async` methods — are there any gotchas?
- What is the difference between `DisposeAsync` returning `ValueTask` vs `Task`?

## Common Mistakes / Pitfalls

- **Disposing an object you don't own.** If you received it as a parameter or it's shared, disposing it silently breaks callers. Use `leaveOpen: true` flags where available, or document ownership clearly.
- **Adding a finalizer to a class that only holds managed `IDisposable` fields.** Finalizers delay GC promotion to Gen2 and add overhead. Only add one when you directly hold an unmanaged resource; prefer `SafeHandle` instead.
- **Calling `Dispose()` without a guard.** Re-entrant `Dispose()` calls must be idempotent — the second call should be a no-op. Always guard with a `_disposed` flag.
- **Forgetting `await using` for `IAsyncDisposable`.** Using a plain `using` on an `IAsyncDisposable` calls `Dispose()` synchronously (if it also implements `IDisposable`), or does nothing at all — missing the async cleanup path.
- **Disposing `HttpClient` per request.** `HttpClient` implements `IDisposable` but is meant to be long-lived and reused. Per-request disposal exhausts socket connections (TIME_WAIT). Use `IHttpClientFactory` instead.

## References

- [IDisposable interface — .NET API](https://learn.microsoft.com/dotnet/api/system.idisposable)
- [IAsyncDisposable interface — .NET API](https://learn.microsoft.com/dotnet/api/system.iasyncdisposable)
- [using statement — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/using)
- [Implement a Dispose method — .NET fundamentals](https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-dispose)
- [Implement DisposeAsync — .NET fundamentals](https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-disposeasync)
