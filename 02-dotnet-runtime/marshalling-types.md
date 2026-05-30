# Marshalling Types in .NET Interop

**Category:** .NET Runtime / Interop
**Difficulty:** 🟡 Middle
**Tags:** `marshalling`, `blittable`, `MarshalAs`, `strings`, `NativeMarshalling`, `interop`

## Question
> What is the difference between blittable and non-blittable types in .NET interop?

> How do you control string and array marshalling in P/Invoke?

> When do you need manual marshalling or custom source-generated marshallers?

## Short Answer
Blittable types have the same binary representation in managed and native memory, so the runtime can often pass them directly with little or no conversion. Non-blittable types such as `string`, `char`, and many `bool` or array scenarios require transformation, copying, encoding, or wrapper logic during the interop boundary. You control those rules with attributes like `[MarshalAs]`, manual allocation APIs like `Marshal.StringToHGlobalUni`, and newer source-generated customization via `[NativeMarshalling]`.

## Detailed Explanation
### Blittable vs Non-Blittable
Interop marshalling starts with layout compatibility. If a managed type already matches what native code expects, it is blittable. Examples include `int`, `float`, `double`, and `IntPtr`. For these, the runtime can often pass memory directly.

Non-blittable types need conversion because the layouts or representations differ.

| Type category | Usually blittable? | Notes |
|---|---|---|
| `int`, `long`, `float`, `double`, `IntPtr` | Yes | Same-size primitive representation |
| `bool` | No | Native side may expect `BOOL`, `_Bool`, or 1-byte bool |
| `char`, `string` | No | Encoding and length rules matter |
| Arrays of blittable types | Sometimes | May still need pinning or copying depending on signature |
| Arrays of non-blittable types | No | Element conversion required |

### Strings Need Explicit Thinking
Strings are one of the most common interop bugs. Managed `string` is UTF-16, immutable, and length-aware. Native APIs may expect null-terminated ANSI, UTF-16, or UTF-8 buffers.

Common `[MarshalAs]` choices:
- `UnmanagedType.LPStr` -> ANSI char*
- `UnmanagedType.LPWStr` -> UTF-16 wchar*
- `UnmanagedType.LPUTF8Str` -> UTF-8 char*

Choosing the wrong one can produce mojibake, truncation, or memory corruption.

### Arrays and Fixed-Size Buffers
For arrays, `[MarshalAs(UnmanagedType.LPArray, SizeConst = N)]` tells the runtime how to treat the managed buffer. This is useful for fixed-size native buffers or classic C APIs. Still, you must match the native signature exactly—size, element type, and ownership rules all matter.

### Manual Marshalling
Sometimes default marshalling is not enough. `Marshal.StringToHGlobalUni` allocates unmanaged memory and copies a managed string into it as UTF-16. You then own that memory and must release it with `Marshal.FreeHGlobal`.

> **Warning:** Manual marshalling shifts lifetime responsibility to you. A missing free leaks native memory; a premature free can crash the process.

### Source-Generated Custom Marshalling
In .NET 7+, source-generated interop lets you describe custom marshallers using `[NativeMarshalling]`. This is especially useful for NativeAOT, performance-sensitive code, and domain-specific structs that need precise conversion logic. The generator emits explicit code instead of relying on broader runtime marshalling behavior.

### Struct Layout Still Matters
Marshalling is not only about individual field types. If you pass structs, the overall layout must match native expectations too. Attributes such as `[StructLayout(LayoutKind.Sequential)]`, explicit packing, and field ordering can change whether a type is safely blittable or whether the runtime must transform it. A signature can look correct at the parameter level and still be wrong because the struct layout does not match the native ABI.

### Practical Guidance
Prefer blittable signatures where possible. Be explicit about strings. Treat `bool` as suspicious until you confirm the native representation. Use manual or source-generated marshalling only when default behavior is not sufficient or not safe.

Related: [P/Invoke Fundamentals](./pinvoke-fundamentals.md) and [Unsafe Code & Pointers](./unsafe-code-and-pointers.md).

## Code Example
```csharp
using System.Runtime.InteropServices;

namespace DotNetRuntimeExamples;

internal static partial class NativeStringMethods
{
    [LibraryImport("user32.dll", EntryPoint = "MessageBoxW", StringMarshalling = StringMarshalling.Utf16)]
    internal static partial int MessageBox(
        nint hWnd,
        string text,
        string caption,
        uint type); // Strings are marshalled as UTF-16.
}

public static class MarshallingDemo
{
    public static void ManualStringCopy(string value)
    {
        var ptr = Marshal.StringToHGlobalUni(value); // Allocate unmanaged UTF-16 memory.

        try
        {
            Console.WriteLine($"Unmanaged pointer: 0x{ptr.ToInt64():X}");
        }
        finally
        {
            Marshal.FreeHGlobal(ptr); // Always free manual allocations.
        }
    }

    public static void ShowFixedArray()
    {
        var buffer = new byte[16];
        buffer[0] = 42; // Blittable byte array is a straightforward interop candidate.
        Console.WriteLine($"First byte: {buffer[0]}");
    }
}
```

## Common Follow-up Questions
- Why is `bool` often treated as non-blittable in interop discussions?
- When does the runtime pin an array versus copy it?
- How do `LPStr`, `LPWStr`, and `LPUTF8Str` differ?
- When should I use manual marshalling instead of `[MarshalAs]`?
- What does `[NativeMarshalling]` enable that classic runtime marshalling does not?

## Common Mistakes / Pitfalls
- Assuming `string` marshalling is always UTF-8 or always UTF-16 without checking the native API.
- Forgetting to free memory allocated with `StringToHGlobalUni`.
- Treating `bool` as layout-compatible across all native ABIs.
- Declaring fixed-size arrays without matching the exact native element count.
- Using non-blittable fields inside structs and expecting zero-copy interop.

## References
- [Customize parameter marshalling](https://learn.microsoft.com/dotnet/standard/native-interop/customize-parameter-marshalling)
- [Default marshalling for strings](https://learn.microsoft.com/dotnet/framework/interop/default-marshalling-for-strings)
- [Marshal.StringToHGlobalUni](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.marshal.stringtohglobaluni)
- [NativeMarshallingAttribute class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.marshalling.nativemarshallingattribute)
