# Memory Layout of Objects

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🔴 Senior
**Tags:** `object header`, `MethodTable`, `TypeHandle`, `field layout`, `padding`, `Unsafe.SizeOf<T>()`, `Marshal.SizeOf<T>()`

## Question

> What does a managed object look like in memory on the CLR?

Also asked as:
> What are the object header and MethodTable pointer, and where do instance fields live?
> How can you inspect object layout in .NET, and why do `Unsafe.SizeOf<T>()` and `Marshal.SizeOf<T>()` give different answers?

## Short Answer

A managed reference type instance on x64 typically starts with two machine words before its instance data: a header word used for sync-block-related state and an 8-byte MethodTable pointer that identifies the runtime type. After that come the instance fields, with padding added for alignment; for auto-layout reference types, the CLR may reorder fields to reduce padding, so the exact layout is an implementation detail. `Unsafe.SizeOf<T>()` reports managed in-memory size semantics for `T`, while `Marshal.SizeOf<T>()` reports unmanaged marshaled size, so they answer different questions.

## Detailed Explanation

### The Two Words Before the Data

When interviewers ask about object layout, they usually want the high-level CLR picture rather than a debugger dump. On a 64-bit runtime, every ordinary object reference points to a block that begins with runtime metadata before the user-visible fields.

A useful mental model is:

| Region | Typical x64 size | Purpose |
|---|---|---|
| Header word | 8 bytes | Sync-block-related bits, hash code state, locking support |
| MethodTable pointer | 8 bytes | Points to the runtime type metadata for the instance |
| Instance data | variable | The actual fields declared on the type and its base types |

You will also hear people use slightly different terminology. Some call the first word the **object header** and treat the MethodTable pointer separately; others loosely call both machine words “the header.” For interview purposes, the important point is that **an object has runtime overhead before its fields**, and on x64 that overhead is commonly 16 bytes in total.

### What the MethodTable Pointer Gives the Runtime

The MethodTable pointer is the runtime’s fast path to type identity. From it, the CLR can discover the exact type, interface map, virtual dispatch information, GC layout, and other metadata needed for execution. That is why a variable typed as `object` or a base class can still call overridden virtual methods correctly: the actual instance points at its real runtime type information.

This is also one reason boxing exists. A boxed value type becomes a real object with the normal object metadata in front of the copied value payload. See [boxing-and-unboxing.md](./boxing-and-unboxing.md).

### How Fields Are Laid Out

For reference types, the CLR cares about correctness first and compactness second. Instance fields are placed after the runtime metadata and padded to satisfy alignment rules. In practice, auto-layout reference types are often arranged to reduce padding, commonly by placing larger fields earlier, but you should treat the precise order as a **runtime implementation detail**, not a language guarantee.

| Field set | Possible effect |
|---|---|
| `byte, int, byte` | Padding may be inserted around the `int` |
| `long, int, byte` | Often packs more tightly on x64 |
| Includes references | Pointer-sized alignment is usually involved |

> **Warning:** Do not promise a fixed managed layout for ordinary classes unless you are discussing a very specific runtime/version scenario. The CLR is allowed to optimize auto layout.

### Why `StructLayout` Usually Does Not Help for Classes

A common interview trap is to assume `[StructLayout]` controls every managed type. In normal managed execution, you should assume **reference type object layout is not something you control reliably for optimization purposes**. `[StructLayout]` matters primarily for value types and interop scenarios. If you need deterministic field offsets, the normal tool is a struct, not a class. See [struct-layout-and-packing.md](./struct-layout-and-packing.md).

### Measuring Layout Correctly

`Unsafe.SizeOf<T>()` and `Marshal.SizeOf<T>()` are often confused.

| API | What it measures | Important caveat |
|---|---|---|
| `Unsafe.SizeOf<T>()` | Managed size of an inline `T` value | For a reference type `T`, this is the size of the reference, not the whole object instance |
| `Marshal.SizeOf<T>()` | Unmanaged marshaled size | Depends on interop layout rules and can differ from managed layout |

So if `T` is a struct, `Unsafe.SizeOf<T>()` tells you how much inline space the JIT needs for that value type. If `T` is a class, it does **not** tell you the object’s total heap size including header and fields. `Marshal.SizeOf<T>()` is interop-focused and should not be used as a general managed-object-size API.

### Inspecting Real Layout

If you want to see actual field offsets and padding, tools such as **ObjectLayoutInspector** are helpful because they inspect runtime layout rather than relying on guesses. That is the safest way to explore how the CLR arranged a specific type on a specific runtime build.

### Interview Takeaway

A strong answer is: objects carry CLR metadata before instance data, the MethodTable pointer gives type identity and dispatch information, field layout includes padding and is not generally user-controlled for classes, and size APIs differ because one is about managed inline size while the other is about unmanaged marshaling.

## Code Example

```csharp
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace RuntimeSamples;

public sealed class OrderLine
{
    public byte Flags;
    public int Quantity;
    public object? Tag;
}

[StructLayout(LayoutKind.Sequential)]
public struct OrderLineSnapshot
{
    public byte Flags;
    public int Quantity;
    public nint TagAddress; // IntPtr-sized field for unmanaged representation
}

public static class ObjectLayoutDemo
{
    public static void Main()
    {
        OrderLine line = new() { Flags = 1, Quantity = 42, Tag = "hot" };

        Console.WriteLine($"Reference size: {Unsafe.SizeOf<OrderLine>()} bytes");
        // For a class, Unsafe.SizeOf<T>() reports the size of the reference itself on this runtime.

        Console.WriteLine($"Inline struct size: {Unsafe.SizeOf<OrderLineSnapshot>()} bytes");
        Console.WriteLine($"Marshaled struct size: {Marshal.SizeOf<OrderLineSnapshot>()} bytes");

        // There is no built-in API that returns the total managed heap size of 'line',
        // including the header word, MethodTable pointer, field payload, and padding.
        Console.WriteLine($"Runtime type: {line.GetType().FullName}");
    }
}
```

## Common Follow-up Questions

- What information does the MethodTable pointer give the CLR at runtime?
- Why does boxing add object-header overhead to a value type?
- Why is field order in a class not something you should depend on?
- When does `[StructLayout]` matter, and why is it mostly discussed with structs?
- Why does `Unsafe.SizeOf<MyClass>()` not tell you the total size of an object instance?

## Common Mistakes / Pitfalls

- Claiming that managed class layout is fully deterministic and under developer control.
- Treating the MethodTable pointer and object header as the same thing without clarifying terminology.
- Using `Marshal.SizeOf<T>()` as if it were the size of a managed object on the heap.
- Forgetting that boxed value types become full objects with header overhead.
- Assuming field declaration order is always preserved for auto-layout reference types.

## References

- [Managed object internals, Part 4. Fields layout](https://devblogs.microsoft.com/premier-developer/managed-object-internals-part-4-fields-layout/)
- [System.Runtime.CompilerServices.Unsafe.SizeOf<T>](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.unsafe.sizeof)
- [Marshal.SizeOf Method](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.marshal.sizeof)
- [StructLayoutAttribute](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.structlayoutattribute)
- [ObjectLayoutInspector on GitHub](https://github.com/SergeyTeplyakov/ObjectLayoutInspector)
