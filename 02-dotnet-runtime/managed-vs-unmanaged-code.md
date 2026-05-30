# What Is the Difference Between Managed and Unmanaged Code?

**Category:** .NET Runtime / CLR
**Difficulty:** 🟢 Junior
**Tags:** `managed code`, `unmanaged code`, `CLR`, `P/Invoke`, `unsafe`, `CIL`

## Question

> What is the difference between managed and unmanaged code in .NET?

Also asked as:
> What does it mean for code to be "managed" by the CLR?
> What is the role of the `unsafe` keyword, and does it produce unmanaged code?

## Short Answer

Managed code runs under CLR supervision and benefits from automatic memory management, type safety, bounds checking, and structured exception handling. Unmanaged code runs outside the CLR — typically native C/C++ compiled to machine code — and must manage its own memory, has no GC, and can corrupt memory on a bad pointer. The `unsafe` keyword in C# loosens some CLR restrictions (pointer arithmetic, `stackalloc`) but the code still executes inside the CLR and the GC still manages heap objects.

## Detailed Explanation

### Managed Code

Code is *managed* when it is compiled to IL and executed under CLR supervision. The CLR provides:

| Protection | What it prevents |
|-----------|-----------------|
| GC | Memory leaks and double-frees |
| Bounds checking | Buffer overruns (C-style `arr[100]` beyond length) |
| Null checking | Process crashes from null dereferences |
| Type checking | Memory corruption from bad casts |
| Stack overflow detection | Cleaner failure via `StackOverflowException` |

Languages that produce managed code: C#, F#, VB.NET, C++/CLI (managed mode).

### Unmanaged Code

Unmanaged code runs outside the CLR — typically native binaries compiled from C, C++, Rust, or assembly. Characteristics:

- Memory is managed manually (`malloc`/`free`, `new`/`delete`)
- No garbage collector
- Null pointer dereferences and buffer overruns crash the process or corrupt memory silently
- No type verification — casts are bitwise reinterpretation
- Invoked from .NET via **P/Invoke** (`[DllImport]` / `[LibraryImport]`) or COM interop

### The `unsafe` Keyword — Still Managed

`unsafe` blocks allow pointer types and arithmetic in C#:

```csharp
unsafe void WriteToPointer(int* ptr) => *ptr = 42;
```

**What `unsafe` allows:**
- Pointer types (`int*`, `byte*`, `void*`)
- `stackalloc` (stack-allocated buffers)
- `fixed` statement (pins managed objects in memory for pointer access)
- Direct memory reads/writes via `Unsafe` class methods

**What `unsafe` does NOT do:**
- Remove the GC — managed heap objects are still GC-tracked
- Disable exception handling
- Produce unmanaged code — the IL is still executed by the CLR

> **The confusion:** "unsafe" means "the CLR cannot verify type safety for this code," not "runs outside the CLR." The code is still managed by the JIT and GC.

### The Mixed World: Managed ↔ Unmanaged Transitions

When managed code calls native code (or vice versa), a **managed-to-unmanaged transition** occurs:

```
Managed Code (C#)  ──P/Invoke──▶  Unmanaged Code (native DLL)
                   ◀──callback──
```

The CLR marshals data across this boundary: converting `string` to `char*`, `bool` to `BOOL`, etc. This transition has a small cost (roughly a few nanoseconds in .NET 7+, reduced dramatically from earlier versions).

### Verification vs. Execution

The CLR can *verify* IL before execution to prove it is type-safe (no pointer arithmetic, proper cast paths). Verifiable IL gives the strongest safety guarantees. `unsafe` code produces *unverifiable* IL but is still *executed* by the CLR.

In practice, .NET skips verification by default (it was expensive and mostly used for partial trust scenarios removed in .NET Core).

## Code Example

```csharp
using System.Runtime.InteropServices;

// ── Managed code ──────────────────────────────────────────────
int[] arr = [1, 2, 3];
// CLR checks bounds; throws IndexOutOfRangeException, not crash
try { _ = arr[10]; } catch (IndexOutOfRangeException) { }

// ── unsafe: still managed, GC still active ────────────────────
unsafe
{
    // stackalloc: buffer lives on the stack, not the GC heap
    Span<int> stack = stackalloc int[4];
    stack[0] = 99;

    // fixed: pins a managed object so GC won't move it
    fixed (int* p = arr)
    {
        *p = 42; // direct write via pointer — unverifiable but still CLR-managed
    }
}
Console.WriteLine(arr[0]); // 42

// ── P/Invoke: calling truly unmanaged code ────────────────────
// [LibraryImport] is the modern alternative to [DllImport] (.NET 7+)
[LibraryImport("kernel32.dll", StringMarshalling = StringMarshalling.Utf16)]
static partial uint GetCurrentThreadId();

// uint id = GetCurrentThreadId(); // executes native kernel32 code
```

## Common Follow-up Questions

- What is the cost of a managed-to-unmanaged transition, and how has it changed across .NET versions?
- What is `LibraryImport` and why is it preferred over `DllImport` in .NET 7+?
- Can the GC ever collect an object that a native pointer is pointing to?
- What does `fixed` actually do, and what is the risk of using it in tight loops?
- How does NativeAOT change the managed/unmanaged boundary?
- What are blittable types, and why do they matter for P/Invoke performance?

## Common Mistakes / Pitfalls

- **"`unsafe` = unmanaged"** — `unsafe` is still managed. It only allows pointer types and disables verifiability; the GC still runs.
- **Forgetting to `fixed` before passing a managed pointer to native code** — without `fixed`, the GC can relocate the object mid-call, causing the native code to read from freed memory.
- **Not calling `GC.KeepAlive` when passing a pointer to a long-running native operation** — the GC may collect the object if no managed references are live, even though native code is still using the pointer.
- **Assuming COM interop is free** — RCW/CCW marshalling and ref-counting adds overhead and requires explicit `Marshal.ReleaseComObject` in some patterns.
- **Using `unsafe` where `Span<T>` suffices** — `Span<T>` provides safe pointer-like performance without requiring `unsafe` in most cases.

## References

- [Unsafe code, pointer types, and function pointers — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/language-reference/unsafe-code)
- [P/Invoke overview — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/native-interop/pinvoke)
- [Managed and unmanaged threading — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/threading/managed-and-unmanaged-threading-in-windows)
- [Blittable and non-blittable types — Microsoft Learn](https://learn.microsoft.com/dotnet/framework/interop/blittable-and-non-blittable-types)
- [The 'unsafe' keyword in depth — Jon Skeet's C# in Depth (verify URL)](https://csharpindepth.com)
