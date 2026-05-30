# Struct Layout and Packing

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🔴 Senior
**Tags:** `StructLayout`, `LayoutKind.Sequential`, `LayoutKind.Explicit`, `FieldOffset`, `packing`, `blittable`, `Marshal.SizeOf<T>()`, `Unsafe.SizeOf<T>()`

## Question

> How do struct layout and packing work in .NET, especially for interop?

Also asked as:
> What is the difference between `LayoutKind.Sequential`, `Explicit`, and `Auto`?
> What makes a struct blittable, and why do `Marshal.SizeOf<T>()` and `Unsafe.SizeOf<T>()` sometimes disagree?

## Short Answer

`[StructLayout]` controls how a struct is represented for interop: `Sequential` keeps fields in declaration order, `Explicit` lets you place them at exact offsets, and `Auto` lets the runtime choose a layout and therefore is not suitable for native interop. Packing changes the maximum alignment used when inserting padding, so smaller pack values can shrink a struct at the cost of potentially misaligned access. A blittable struct contains no managed references and can be copied directly between managed and unmanaged memory without per-field transformation.

## Detailed Explanation

### Why Layout Matters More for Structs Than Classes

Struct layout matters whenever bytes must match an external contract: P/Invoke, COM interop, file formats, network packets, memory-mapped data, or hardware/device protocols. Unlike ordinary managed classes, structs are value types, so their inline size and field offsets directly affect copies, stack storage, arrays, and marshaling.

### `Sequential`, `Explicit`, and `Auto`

`StructLayoutAttribute` gives the runtime and marshaler layout instructions.

| Layout kind | Meaning | Typical use |
|---|---|---|
| `Sequential` | Preserve declaration order, still insert padding by alignment rules | Native structs, most P/Invoke cases |
| `Explicit` | Developer specifies exact byte offsets with `[FieldOffset]` | Unions, protocol overlays, bit-level interop |
| `Auto` | CLR may reorder fields freely | Purely managed structs, not interop-safe |

With `Sequential`, the order is stable, but padding may still appear between fields and at the end. With `Explicit`, every field must be assigned an offset, so you can intentionally overlap fields to model C-style unions.

### `FieldOffset` and Union-Like Layout

`LayoutKind.Explicit` is the tool for overlapping storage.

```csharp
[StructLayout(LayoutKind.Explicit)]
public struct IntFloatUnion
{
    [FieldOffset(0)] public int Int32;
    [FieldOffset(0)] public float Single;
}
```

This says both fields start at byte 0, so they occupy the same bytes. That is powerful for interop and low-level parsing, but dangerous if you do not fully understand the external memory contract.

> **Warning:** Overlapping non-blittable fields or mixing managed references with explicit byte overlays is a correctness and safety hazard. Reserve union-style layouts for very specific low-level scenarios.

### Packing and Natural Alignment

Packing controls the **maximum alignment** the runtime uses for fields when computing offsets. Typical values are `Pack = 1`, `2`, `4`, or `8`.

| Pack | Effect |
|---|---|
| `1` | Minimize padding aggressively |
| `2` / `4` | Moderate alignment constraint |
| `8` | Common natural alignment on x64 |

The actual offset for a field is based on the smaller of:

1. the field's natural alignment requirement, and
2. the struct's `Pack` value.

For example, an `int` naturally likes 4-byte alignment. Under `Pack = 1`, it can start at any byte boundary, shrinking the struct but possibly forcing the CPU to perform less efficient unaligned access. That is why you should not change packing just to “save memory” unless you are matching a real external layout.

### Blittability

A type is **blittable** when the runtime can copy its bytes directly without conversion. In practice, that means no managed references and only blittable fields inside the struct.

Common blittable ingredients:

- numeric primitives like `int`, `long`, `float`, `double`
- pointers and `IntPtr` / `UIntPtr`
- fixed-size structs composed only of blittable fields

Common non-blittable ingredients:

- `string`
- `bool` and `char` in many interop scenarios
- arrays and normal reference types
- any field that is itself non-blittable

Blittable structs are ideal for P/Invoke and COM because marshaling can often become a simple block copy.

### `Marshal.SizeOf<T>()` vs `Unsafe.SizeOf<T>()`

These APIs are related but not interchangeable.

| API | Meaning |
|---|---|
| `Unsafe.SizeOf<T>()` | Managed inline size of `T` as used by the CLR/JIT |
| `Marshal.SizeOf<T>()` | Unmanaged size the marshaler will use |

For sequential blittable structs, the numbers are often equal. They can diverge when marshaling rules reinterpret fields, especially for `bool`, `char`, or custom marshalling attributes. `Marshal.SizeOf<T>()` is the right question for interop boundaries; `Unsafe.SizeOf<T>()` is the right question for managed in-memory layout. See [memory-layout-of-objects.md](./memory-layout-of-objects.md).

### Interview Takeaway

The best concise answer is: choose `Sequential` for normal interop structs, `Explicit` plus `FieldOffset` for unions, avoid `Auto` for native boundaries, understand that pack changes padding/alignment, and prefer blittable structs because they marshal predictably and efficiently. Future P/Invoke details are covered in [pinvoke-fundamentals.md](./pinvoke-fundamentals.md).

## Code Example

```csharp
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace RuntimeSamples;

[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct PacketHeader
{
    public byte Version;
    public int PayloadLength; // Under Pack=1, this starts immediately after Version.
    public short Checksum;
}

[StructLayout(LayoutKind.Explicit)]
public struct IntFloatUnion
{
    [FieldOffset(0)] public int Int32;
    [FieldOffset(0)] public float Single;
}

public static class StructLayoutDemo
{
    public static void Main()
    {
        Console.WriteLine($"Managed size: {Unsafe.SizeOf<PacketHeader>()} bytes");
        Console.WriteLine($"Marshaled size: {Marshal.SizeOf<PacketHeader>()} bytes");

        IntFloatUnion union = new() { Int32 = 0x3F80_0000 };
        Console.WriteLine($"Reinterpreted as float: {union.Single}"); // 1.0

        PacketHeader header = new() { Version = 1, PayloadLength = 256, Checksum = 99 };
        Console.WriteLine($"Header => v={header.Version}, len={header.PayloadLength}, sum={header.Checksum}");
    }
}
```

## Common Follow-up Questions

- Why is `LayoutKind.Auto` not valid for P/Invoke-facing structs?
- When should you use `FieldOffset` instead of `Sequential`?
- Why can `Pack = 1` be necessary for protocol compatibility but risky for performance?
- What makes a struct blittable or non-blittable?
- In what scenarios do `Marshal.SizeOf<T>()` and `Unsafe.SizeOf<T>()` differ?
- Why are blittable structs easier for COM and native interop?

## Common Mistakes / Pitfalls

- Using `LayoutKind.Auto` on a type that must match a native memory layout.
- Setting `Pack = 1` without checking the actual native contract you need to match.
- Assuming `bool` and `char` are always blittable in interop scenarios.
- Overlapping fields with `Explicit` layout without understanding aliasing and endianness.
- Using `Unsafe.SizeOf<T>()` when you really need the marshaled unmanaged size.

## References

- [StructLayoutAttribute](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.structlayoutattribute)
- [LayoutKind Enum](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.layoutkind)
- [FieldOffsetAttribute](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.fieldoffsetattribute)
- [Blittable and Non-Blittable Types](https://learn.microsoft.com/dotnet/framework/interop/blittable-and-non-blittable-types)
- [Customize structure marshalling](https://learn.microsoft.com/dotnet/standard/native-interop/customize-struct-marshalling)
