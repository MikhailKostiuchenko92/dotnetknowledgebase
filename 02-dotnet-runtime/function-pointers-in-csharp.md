# Function Pointers in C#

**Category:** .NET Runtime / Interop
**Difficulty:** 🔴 Senior
**Tags:** `function-pointers`, `delegate*`, `unmanaged`, `SuppressGCTransition`, `UnmanagedCallersOnly`, `interop`

## Question
> What are function pointers in C#, and how are they different from delegates?

> Why are `delegate* unmanaged<...>` function pointers useful in interop-heavy code?

> What does `SuppressGCTransition` do, and when is it safe to use?

## Short Answer
C# function pointers, introduced with the `delegate*` syntax, are low-level callable addresses that avoid delegate allocation and virtual invocation overhead. `delegate* unmanaged<...>` is especially useful for native interop because it expresses an unmanaged calling convention directly in the type. `SuppressGCTransition` can reduce call overhead for extremely tiny native calls, but it is safe only when the native function is trivial, non-blocking, does not callback into managed code, and does not need the runtime to cooperate during the call.

## Detailed Explanation
### Delegates vs Function Pointers
A delegate is a managed object with metadata, target information, and an invocation path the runtime understands. That makes it flexible and safe, but not free. A function pointer is much closer to C: it is simply an address with a compile-time signature.

| Feature | Delegate | `delegate*` function pointer |
|---|---|---|
| Object allocation | Usually yes | No |
| Invocation model | Managed delegate invocation | Direct call instruction |
| Captures instance/state | Yes | No |
| Interop calling conventions | Indirect | Explicit in the type |

### `delegate* unmanaged<...>`
For interop, unmanaged function pointers are the most interesting form. You can declare the ABI in the type itself, for example:
- `delegate* unmanaged<int, int>`
- `delegate* unmanaged[Cdecl]<int, int, int>`
- `delegate* unmanaged[Stdcall]<void>`

This is powerful in hot paths, callback registration, source-generated COM, and JIT/runtime plumbing where even delegate overhead may matter.

### Calling Conventions and Safety
The calling convention is part of correctness, not just optimization. If the pointer says `Cdecl` but the native function is actually `Stdcall`, the call can corrupt the stack. Function pointers therefore belong in expert-level code where you control both sides carefully.

### `SuppressGCTransition`
A managed-to-native call normally switches the runtime into a state where GC and thread coordination work correctly across the interop boundary. `SuppressGCTransition` asks the runtime to skip that transition for extremely fast unmanaged calls.

That can reduce overhead, but the safety rules are strict. The native function should be very short, non-blocking, should not allocate in complicated ways, should not callback into managed code, and should not interact with the runtime.

> **Warning:** `SuppressGCTransition` is not a general performance switch. On the wrong native function it can hurt latency, block GC progress, or create very subtle runtime bugs.

### Practical Use Cases
Function pointers show up in:
- native callback registration
- source-generated COM or specialized interop layers
- runtime intrinsics or low-level libraries
- performance-sensitive bridges where delegate overhead is measurable

### Why They Matter More in Modern .NET
As NativeAOT, source generation, and high-performance interop have become more important, function pointers have become more relevant too. They let low-level libraries describe native ABI contracts directly without paying for delegate wrappers, and they compose well with features like `UnmanagedCallersOnly` when managed code itself needs to be exposed as a raw callable entry point.

Most business applications do not need them. Delegates remain the right default unless you are already working in unsafe or interop-heavy code.

Related: [P/Invoke Fundamentals](./pinvoke-fundamentals.md) and [Intrinsics and SIMD](./intrinsics-and-simd.md).

## Code Example
```csharp
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace DotNetRuntimeExamples;

public static unsafe class FunctionPointerDemo
{
    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvCdecl)])]
    public static int Add(int left, int right) => left + right;

    public static void Run()
    {
        delegate* unmanaged[Cdecl]<int, int, int> addPtr = &Add; // No delegate object is created.
        var sum = addPtr(20, 22); // Direct unmanaged-style call.

        Console.WriteLine($"Sum = {sum}");
    }
}
```

## Common Follow-up Questions
- How do function pointers differ from delegates in allocation and dispatch?
- Why do function pointers require `unsafe` code?
- When is `delegate* unmanaged[Cdecl]<...>` better than a delegate callback?
- What conditions must hold before using `SuppressGCTransition`?
- How do `UnmanagedCallersOnly` and function pointers work together?

## Common Mistakes / Pitfalls
- Treating function pointers as a drop-in replacement for normal delegates everywhere.
- Declaring the wrong unmanaged calling convention and corrupting the stack.
- Using `SuppressGCTransition` on long-running or blocking native calls.
- Expecting function pointers to capture object state or instance targets like delegates.
- Forgetting that all of this lives in `unsafe` territory and weakens safety guarantees.

## References
- [Function pointer syntax](https://learn.microsoft.com/dotnet/csharp/language-reference/unsafe-code#function-pointers)
- [UnmanagedCallersOnlyAttribute](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.unmanagedcallersonlyattribute)
- [SuppressGCTransitionAttribute](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.suppressgctransitionattribute)
- [CallConvCdecl class](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.callconvcdecl)
