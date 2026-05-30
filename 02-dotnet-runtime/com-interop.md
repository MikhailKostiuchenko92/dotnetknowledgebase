# COM Interop in .NET

**Category:** .NET Runtime / Interop
**Difficulty:** 🟡 Middle
**Tags:** `COM`, `RCW`, `CCW`, `IUnknown`, `STA`, `MTA`, `GeneratedComInterface`

## Question
> How does .NET interoperate with COM components?

> What are RCWs and CCWs, and how do they relate to `IUnknown` reference counting?

> Why do COM apartments like STA and MTA matter to .NET applications?

## Short Answer
COM interop lets .NET consume or expose COM components by bridging different object models and lifetime rules. When managed code calls COM, the CLR creates a Runtime Callable Wrapper (RCW) that translates calls and manages COM reference counting; when COM calls managed code, a COM Callable Wrapper (CCW) exposes the managed object to native clients. Apartment threading still matters: a WinForms UI is typically STA, many server scenarios are MTA, and the COM server’s expectations must match the calling thread model.

## Detailed Explanation
### Core COM Concepts
Classic COM objects expose interfaces and use `IUnknown` for three foundational operations: `QueryInterface`, `AddRef`, and `Release`. Unlike the CLR’s tracing garbage collector, COM uses reference counting. That means lifetime is explicit and sensitive to who owns references.

.NET hides much of that complexity, but it does not erase it. The interop layer has to translate between GC-managed objects and COM reference-counted objects.

### RCW and CCW
The two wrappers are central.

| Wrapper | Direction | Purpose |
|---|---|---|
| RCW (Runtime Callable Wrapper) | Managed -> COM | Makes a COM object look like a managed object |
| CCW (COM Callable Wrapper) | COM -> Managed | Makes a managed object look like a COM object |

An RCW tracks interface pointers and coordinates `AddRef`/`Release` on behalf of managed code. A CCW exposes managed methods through COM-visible interfaces so native or scripting clients can call them.

### Declaring Imported COM Interfaces
`[ComImport]` together with `[Guid]` tells the runtime that an interface is implemented by an external COM component, not by managed code. You usually also specify `InterfaceType` so the CLR knows how to dispatch calls.

### Explicit Release APIs
Most of the time, you let the RCW and GC coordinate cleanup naturally. However, in Office automation or very long-running processes, developers sometimes use `Marshal.ReleaseComObject` or `Marshal.FinalReleaseComObject` to reduce the COM reference count eagerly.

This is powerful but easy to misuse. If other managed code still uses the same RCW, forcing release can cause confusing failures.

> **Warning:** `ReleaseComObject` is not a general replacement for correct ownership design. Use it only when you understand RCW sharing and the COM server’s lifetime behavior.

### Apartments: STA vs MTA
COM threading models matter because many COM servers assume either single-threaded apartment (STA) or multi-threaded apartment (MTA) access.
- STA: one thread owns the apartment; calls may be serialized or marshalled onto it
- MTA: multiple threads can enter concurrently

WinForms and many UI technologies use STA because UI objects are thread-affine. Server or background code is more often MTA. If the apartment model is wrong, COM calls may fail, hang, or marshal unexpectedly.

### COM in Modern .NET and NativeAOT
Traditional COM interop support is strongest on Windows. In modern NativeAOT scenarios, classic runtime-generated COM support is limited, so .NET 8+ emphasizes source-generated COM with attributes like `[GeneratedComInterface]`.

### Interview Summary
COM interop is mostly about bridging two worlds: GC vs reference counting, managed dispatch vs interface pointers, and free-threaded code vs apartment-threaded code.

Related: [P/Invoke Fundamentals](./pinvoke-fundamentals.md).

## Code Example
```csharp
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;

namespace DotNetRuntimeExamples;

[ComImport]
[Guid("00020400-0000-0000-C000-000000000046")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IDispatchLike
{
}

[GeneratedComInterface]
[Guid("4A541C75-76B0-4F77-B9A5-2EE6F9A6A4F9")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public partial interface ICalculator
{
    int Add(int left, int right);
}

public static class ComInteropDemo
{
    public static void Release(object comObject)
    {
        var remaining = Marshal.ReleaseComObject(comObject); // Explicit RCW release only when necessary.
        Console.WriteLine($"Remaining RCW ref count: {remaining}");
    }
}
```

## Common Follow-up Questions
- What is the difference between an RCW and a CCW?
- When is `Marshal.ReleaseComObject` justified?
- Why must WinForms code usually run in STA?
- How does COM reference counting interact with .NET GC?
- What changes for COM interop under NativeAOT?

## Common Mistakes / Pitfalls
- Forgetting that COM components may require a specific apartment model.
- Calling `FinalReleaseComObject` while other code still uses the same RCW.
- Treating COM lifetime as if it were identical to normal managed object lifetime.
- Assuming classic COM interop behaves the same in NativeAOT as in JITed desktop apps.
- Declaring COM interfaces without the correct GUID or interface type.

## References
- [COM interop in .NET](https://learn.microsoft.com/dotnet/standard/native-interop/cominterop)
- [ComImportAttribute class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.comimportattribute)
- [Marshal.ReleaseComObject](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.marshal.releasecomobject)
- [GeneratedComInterfaceAttribute class](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.marshalling.generatedcominterfaceattribute)
