# Unsafe and Pointers

**Category:** C# / Memory & Interop
**Difficulty:** Senior
**Tags:** `unsafe`, `pointers`, `fixed`, `interop`, `nativeaot`

## Question
> What does `unsafe` enable in C#, and when is pointer-based code justified in modern .NET?
>
> How do pointer types, `fixed`, and manual memory access compare with safe abstractions like `Span<T>`?
>
> Is unsafe code compatible with .NET 8/9 deployment models such as Native AOT, and what trade-offs should you discuss in an interview?

## Short Answer
`unsafe` allows C# code to use pointers, pointer arithmetic, `fixed`, and other operations that bypass part of the managed safety model. It is justified mainly for interop, native buffer access, specialized hot paths, and low-level runtime work where safe abstractions are insufficient or measurably slower. Unsafe code can work in modern .NET, including Native AOT, but it increases correctness risk, makes code harder to review, and should usually be hidden behind a small, well-tested boundary.

## Detailed Explanation
### What the `unsafe` context unlocks
Inside an `unsafe` context, you can declare pointer types such as `byte*`, take addresses with `&`, dereference with `*`, and do pointer arithmetic. This gives you a model closer to C or C++ memory handling.

| Capability | Safe code | Unsafe code |
| --- | --- | --- |
| Pointer arithmetic | No | Yes |
| Direct unmanaged memory access | Limited | Yes |
| Bounds checks | Yes | Often manual responsibility |
| GC safety by default | Yes | You must reason about it |

The compiler requires `/unsafe` or `<AllowUnsafeBlocks>true</AllowUnsafeBlocks>` because the language wants this to be an explicit decision.

### When unsafe code is justified
In day-to-day application code, [span-of-t.md](./span-of-t.md), [memory-of-t.md](./memory-of-t.md), and `MemoryMarshal` often remove the need for raw pointers. But unsafe code is still justified when:
- interoperating with native APIs
- accessing pinned memory directly
- working with custom allocators or unmanaged buffers
- implementing extremely low-level performance-critical code after measurement

| Scenario | Usually best choice |
| --- | --- |
| Parsing managed data safely | `Span<T>` |
| Temporary stack buffer | `stackalloc` + `Span<T>` |
| Native library interop | `unsafe` / `fixed` / `SafeHandle` |
| Long-lived native resource | `SafeHandle` over raw `IntPtr` |

> Tip: in interviews, do not sell unsafe code as “faster by default.” The mature answer is “use it only when safe APIs are insufficient and profiling justifies it.”

### Deployment and maintenance trade-offs
Unsafe code itself is not the same as runtime code generation, so it is not automatically incompatible with Native AOT. In fact, low-level interop libraries often use unsafe code successfully in AOT builds. The real issue is maintainability and correctness: one bad pointer, one missing pin, or one incorrect lifetime assumption can produce memory corruption.

Unsafe code often appears together with [pinning-and-gc-handles.md](./pinning-and-gc-handles.md), because managed objects must be pinned before taking stable pointers into them. For native resource cleanup, prefer [finalizer-and-dispose-pattern.md](./finalizer-and-dispose-pattern.md) and `SafeHandle` instead of rolling your own lifetime management.

> Warning: the hardest bugs in unsafe code are often silent memory corruption bugs, not immediate exceptions. That is why small scope, strong tests, and code review matter so much.

## Code Example
```csharp
using System;

Console.WriteLine(SumValues());
Console.WriteLine(FirstCharacterCode("dotnet"));

static unsafe int SumValues()
{
    Span<int> values = stackalloc int[] { 1, 2, 3, 4 };
    int sum = 0;

    fixed (int* pointer = values)
    {
        for (int i = 0; i < values.Length; i++)
        {
            sum += *(pointer + i); // Pointer arithmetic inside a pinned region.
        }
    }

    return sum;
}

static unsafe int FirstCharacterCode(string text)
{
    fixed (char* pointer = text)
    {
        return *pointer; // Reads the first UTF-16 code unit.
    }
}
```

## Common Follow-up Questions
- Why is `fixed` required before taking a pointer into many managed objects?
- When can `Span<T>` replace pointer code entirely?
- What are the main risks of unsafe code besides ordinary exceptions?
- Why is `SafeHandle` usually preferred over manual `IntPtr` lifetime management?
- How does unsafe code differ from runtime code generation in Native AOT discussions?

## Common Mistakes / Pitfalls
- Using unsafe code before measuring whether safe alternatives are actually too slow.
- Forgetting to pin managed memory before keeping a pointer to it.
- Replacing simple span-based code with harder-to-review pointer arithmetic.
- Managing native handles manually instead of using `SafeHandle`.
- Assuming unsafe code is automatically broken in Native AOT just because it is low-level.

## References
- [Microsoft Docs: Unsafe code, pointer types, and function pointers](https://learn.microsoft.com/dotnet/csharp/language-reference/unsafe-code)
- [Microsoft Docs: Native AOT deployment](https://learn.microsoft.com/dotnet/core/deploying/native-aot/)
- [Microsoft Docs: SafeHandle](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.safehandle)
- [See: `stackalloc`](./stackalloc.md)
- [See: Pinning and GCHandle](./pinning-and-gc-handles.md)
