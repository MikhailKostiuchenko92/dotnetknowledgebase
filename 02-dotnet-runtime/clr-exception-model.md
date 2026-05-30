# CLR Exception Model

**Category:** .NET Runtime / Exceptions
**Difficulty:** 🟡 Middle
**Tags:** `clr`, `exceptions`, `seh`, `il`, `filters`, `stack-unwinding`

## Question
> How does the CLR handle exceptions under the hood?

> What does “two-pass exception handling” mean in .NET?

> How do `try/catch/finally` blocks map from C# to IL and runtime behavior?

## Short Answer
The CLR implements managed exceptions using runtime metadata and OS support, with Windows relying on Structured Exception Handling (SEH) and Unix-like systems mapping native signals into a comparable runtime model. Exception handling is two-pass: the first pass searches for a matching handler and evaluates filters, and the second pass unwinds the stack and runs cleanup such as `finally` blocks. C# `try/catch/finally` compiles to IL exception clauses like `.try`, `catch`, `filter`, `finally`, and sometimes `fault`.

## Detailed Explanation
### Managed Exceptions Build on Lower-Level Runtime Support
At source level, exceptions look language-level and object-oriented, but the CLR implements them with help from the execution engine and the underlying operating system. On Windows, the runtime integrates with Structured Exception Handling (SEH). On Linux and macOS, hardware faults and signals are translated into a runtime-specific mechanism that lets managed code participate in a similar exception model.

The important interview point is that .NET exceptions are not just “fancy return codes.” The runtime tracks protected regions, handlers, and cleanup clauses in method metadata so it can navigate the stack correctly when a failure occurs.

### Exception Objects Live on the Managed Heap
When code throws, the runtime creates or propagates an exception object on the managed heap. That object carries type information, message text, inner exceptions, stack trace data, and other metadata. The allocation itself is part of why throwing is relatively expensive compared with a simple branch.

### Two-Pass Handling
The CLR uses a two-pass model.

| Pass | What happens |
|---|---|
| First pass | Search the call stack for a handler; evaluate exception filters top-to-bottom |
| Second pass | Unwind frames, run `finally`/`fault` cleanup, then transfer control to the selected handler |

The subtle but important part is that filters run during the first pass, before stack unwinding. That means a filter can inspect the exception while locals and the current stack are still intact. If the filter returns `false`, the runtime keeps searching as if the catch never matched.

### Handler Selection Order
Within a method, handlers are considered in order. Filters are evaluated top-to-bottom before any handler body executes. The first filter that returns `true`, or the first compatible non-filtered catch, wins. Only after the winning handler is chosen does the runtime unwind intermediate frames.

> **Warning:** Because filters run before unwinding, they should not perform logic that depends on cleanup from `finally` blocks having already happened.

### IL Exception Clauses
C# hides the mechanics, but IL represents exception regions explicitly. A method can contain clauses such as:
- `.try` for the protected block
- `catch` for type-based handlers
- `filter` for user-filtered handlers
- `finally` for cleanup that always runs during exit or unwind
- `fault` for cleanup that runs only when an exception leaves the block (rare in C#, common in IL)

This metadata-driven model is why the runtime can unwind correctly even across optimized JITted code.

### Why This Matters in Practice
Understanding the CLR model explains several surface-level behaviors:
- `throw;` can preserve the original stack because the runtime is still tracking the active exception.
- Filters can log without truly catching.
- `finally` runs during both normal exits and exception unwinds.
- Catching and rethrowing at every layer adds overhead and can distort diagnostics.

It also explains why some failures, especially corrupted-state or stack-overflow situations, are treated differently: the runtime may not be able to guarantee safe continued execution.

See also [Exception Filters](./exception-filters.md) and [Structured Exception Handling](./structured-exception-handling.md).

## Code Example
```csharp
namespace DotNetRuntimeExamples;

public static class ClrExceptionModelDemo
{
    public static void Run()
    {
        try
        {
            Level1();
        }
        catch (InvalidOperationException ex) when (ShouldHandle(ex))
        {
            Console.WriteLine($"Handled after first-pass filter: {ex.Message}");
        }
    }

    private static void Level1()
    {
        try
        {
            Level2();
        }
        finally
        {
            Console.WriteLine("finally in Level1 runs during second-pass unwind.");
        }
    }

    private static void Level2() => throw new InvalidOperationException("Boom from Level2.");

    private static bool ShouldHandle(Exception ex)
    {
        Console.WriteLine($"Filter inspected: {ex.GetType().Name}"); // Runs before unwinding.
        return true;
    }
}
```

## Common Follow-up Questions
- Why do exception filters run before `finally` blocks?
- What is the difference between `finally` and IL `fault`?
- Are exceptions always allocated, or can the runtime reuse an instance?
- How does the CLR map hardware faults like access violations into managed exceptions?
- Why are corrupted-state exceptions treated differently from normal managed exceptions?

## Common Mistakes / Pitfalls
- Thinking a catch block is selected only after the stack has already been unwound.
- Forgetting that filters execute before cleanup in `finally` blocks.
- Assuming Unix runtimes use Windows SEH directly rather than a mapped equivalent runtime mechanism.
- Treating thrown exceptions as cheap enough for hot-path branching.
- Ignoring that IL, not just C#, defines the real exception regions the CLR uses.

## References
- [System.Exception class](https://learn.microsoft.com/dotnet/api/system.exception)
- [Exceptions and exception handling](https://learn.microsoft.com/dotnet/csharp/fundamentals/exceptions/)
- [User-filtered exception handlers](https://learn.microsoft.com/dotnet/standard/exceptions/using-user-filtered-exception-handlers)
- [ECMA-335 Common Language Infrastructure (verify URL)](https://www.ecma-international.org/publications-and-standards/standards/ecma-335/)
