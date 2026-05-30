# Structured Exception Handling in .NET

**Category:** .NET Runtime / Interop with Native Errors
**Difficulty:** 🔴 Senior
**Tags:** `seh`, `access-violation`, `corrupted-state`, `windows`, `clr`, `interop`

## Question
> What is Structured Exception Handling (SEH), and how does it relate to .NET?

> How does .NET deal with hardware exceptions like access violations or stack overflows?

> Why are corrupted-state exceptions treated differently from normal managed exceptions?

## Short Answer
Structured Exception Handling (SEH) is the Windows OS mechanism for low-level exception processing, exposed in native code through constructs like `__try`, `__except`, and `__finally`. The CLR builds managed exception handling on top of OS and runtime support, but corrupted-state failures such as access violations are treated specially because the process may no longer be trustworthy. In modern .NET, catching those faults is disabled by default and generally considered unsafe.

## Detailed Explanation
### What SEH Is
On Windows, SEH is the operating system’s mechanism for handling exceptional events such as access violations, illegal instructions, divide-by-zero faults, and explicit raises. Native C/C++ code can participate using `__try`, `__except`, and `__finally`.

The CLR does not replace the operating system. Instead, it cooperates with it. Managed exceptions like `InvalidOperationException` are runtime-level objects, but lower-level faults may enter through SEH and be mapped by the runtime into managed exception forms when that is safe and supported.

### Managed Exceptions vs Corrupted-State Failures
Normal managed exceptions usually mean “the program is in a known bad state for this operation.” Corrupted-state exceptions (CSEs) mean “the process itself may be damaged.” Typical examples include memory corruption, wild native pointers, or stack exhaustion near the edge of the thread stack.

| Failure kind | Typical meaning | Catchability |
|---|---|---|
| `ArgumentException`, `InvalidOperationException` | Normal managed failure | Catchable |
| `AccessViolationException` | Illegal memory access, often native corruption | Not catchable by default in modern .NET |
| `StackOverflowException` | Stack exhausted | Process terminates |

### `AccessViolationException`
`AccessViolationException` often indicates unmanaged code wrote to or read from invalid memory. In .NET Framework 4 and later, these are considered corrupted-state exceptions and are not delivered to ordinary `catch` blocks by default. That policy exists because continuing after memory corruption can produce silent data corruption or unpredictable crashes later.

### Legacy Escape Hatch: `HandleProcessCorruptedStateExceptionsAttribute`
The framework once exposed `HandleProcessCorruptedStateExceptionsAttribute` as a way to opt into catching certain corrupted-state exceptions. This is now deprecated and dangerous. In modern .NET, the recommended policy is not to catch-and-continue from these failures. Log as best you can, capture dumps if possible, and terminate.

> **Warning:** Catching an access violation does not repair heap corruption. It only makes the program look alive for a little longer, often while making the real damage worse.

### Divide-by-Zero Nuance
Interviewers sometimes group divide-by-zero with hardware faults. In managed code, integer divide-by-zero typically surfaces as a managed `DivideByZeroException`, which is different from an unmanaged corrupted-state memory fault. The broad lesson is still important: not every low-level failure is safe to recover from, especially once unmanaged memory corruption is involved.

### Why .NET Prefers Fail-Fast Here
The runtime is conservative because reliability beats false recovery. Once native memory is corrupted, object headers, GC bookkeeping, or control-flow state may be invalid. A clean crash plus a dump is safer than a zombie process returning bad data.

This is especially relevant in P/Invoke, unsafe code, or custom native hosting. If you cross into native code, you inherit native failure modes.

See also [Stack Overflow and OOM](./stack-overflow-and-oom.md) and [CLR Exception Model](./clr-exception-model.md).

## Code Example
```csharp
using System.Runtime.ExceptionServices;

namespace DotNetRuntimeExamples;

public static class SehAwarenessDemo
{
    public static void RunBoundary(Action nativeInteropCall)
    {
        try
        {
            nativeInteropCall(); // May cross into native code.
        }
        catch (Exception ex) when (ex is not AccessViolationException)
        {
            Console.WriteLine($"Handled managed exception: {ex.Message}"); // Normal boundary handling.
            throw;
        }

        // Do not attempt to specially recover from AccessViolationException here.
        // Modern .NET treats corrupted-state failures as process-fatal for good reason.
    }
}
```

## Common Follow-up Questions
- How does Windows SEH differ from managed `try/catch/finally`?
- Why is `AccessViolationException` treated as a corrupted-state exception?
- What did `HandleProcessCorruptedStateExceptionsAttribute` do, and why is it discouraged?
- Is divide-by-zero always a corrupted-state exception in .NET?
- Why is fail-fast safer than catch-and-continue after native memory corruption?

## Common Mistakes / Pitfalls
- Assuming all exceptions are equally safe to catch and recover from.
- Treating `AccessViolationException` like a normal managed validation failure.
- Using legacy corrupted-state exception handling attributes in new code.
- Forgetting that P/Invoke and unsafe code can introduce native failure modes into managed apps.
- Believing a successful catch means the process state is healthy again.

## References
- [Structured Exception Handling (C/C++)](https://learn.microsoft.com/cpp/cpp/structured-exception-handling-c-cpp)
- [AccessViolationException class](https://learn.microsoft.com/dotnet/api/system.accessviolationexception)
- [HandleProcessCorruptedStateExceptionsAttribute class](https://learn.microsoft.com/dotnet/api/system.runtime.exceptionservices.handleprocesscorruptedstateexceptionsattribute)
- [Reliability best practices (verify URL)](https://learn.microsoft.com/dotnet/framework/performance/reliability-best-practices)
