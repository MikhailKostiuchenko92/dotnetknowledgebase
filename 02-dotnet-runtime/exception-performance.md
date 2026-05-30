# Exception Performance in .NET

**Category:** .NET Runtime / Exceptions
**Difficulty:** 🟡 Middle
**Tags:** `exceptions`, `performance`, `TryParse`, `Result`, `ThrowIfNull`, `DoesNotReturn`

## Question
> Are exceptions expensive in .NET, and why?

> Why should you avoid using exceptions for control flow on hot paths?

> What patterns does .NET use instead of throwing for expected failures?

## Short Answer
Yes—throwing an exception is orders of magnitude more expensive than a normal branch because the runtime allocates an exception object, captures stack information, walks handler metadata, and unwinds frames. That cost is fine for exceptional failures, but it is the wrong tool for expected outcomes like parse errors or cache misses. On hot paths, prefer patterns like `TryXxx`, result objects, and throw helpers that keep the success path small and allocation-free.

## Detailed Explanation
### Why Throwing Costs More Than a Branch
A normal conditional branch usually stays inside the current method and requires no object allocation. Throwing does much more. The runtime must create or propagate an exception object, inspect exception-handling metadata, capture stack information, search for a handler, and potentially unwind multiple stack frames while running `finally` blocks.

That is why a throw often costs thousands of nanoseconds or more, while a successful branch is usually much cheaper. The exact number depends on the runtime, JIT tiering, architecture, and stack depth, but the shape of the cost is the key interview point: exceptions are optimized for correctness and diagnostics, not for fast-path control flow.

### Use Exceptions Only for Abnormal Failures
If failure is expected as part of ordinary use, design the API so callers do not need to pay the throw cost repeatedly.

| Expected outcome | Preferred pattern |
|---|---|
| Parsing may fail | `TryParse` |
| Key may be absent | `TryGetValue` |
| Business rule may reject input | `Result<T, TError>` or validation object |
| Caller violated API contract | Throw `ArgumentException`/`ArgumentNullException` |

This is the reasoning behind the framework’s heavy use of `TryXxx` APIs.

### `Result<T, TError>` and Discriminated-Union Style APIs
In domain code, a result object can represent success or failure without exceptions. It avoids allocations on the happy path and makes expected failures explicit in the type system. The trade-off is more verbose call sites and the risk of overusing result wrappers for truly exceptional runtime faults that should still throw.

### Throw Helpers Keep the Happy Path Small
Modern .NET uses throw helpers such as `ArgumentNullException.ThrowIfNull(value)`. These are static methods that throw only on the failure path, which helps the JIT keep the hot path compact and more inline-friendly.

`[DoesNotReturn]` complements this pattern. It tells analyzers and flow analysis that a helper never returns, improving nullability and reachability reasoning.

> **Warning:** Throw helpers improve code generation, but they do not make throwing cheap. They optimize the non-throwing path, not the exception path itself.

### Performance Guidance in Real Systems
Do not micro-optimize every throw site. If a path is truly exceptional, clarity matters more than shaving nanoseconds from code that rarely runs. Focus on hotspots: parsing loops, protocol decoders, serializers, routing tables, and other high-volume infrastructure.

A useful mental model is:
- rare bug or invariant violation -> throw
- common negative result -> `TryXxx` or result type
- guard clauses for programmer error -> throw helper

### Interview Summary
Exceptions are great for representing failure that should interrupt normal control flow and surface rich diagnostics. They are a poor fit for expected misses on hot paths. Good .NET API design makes that distinction obvious.

Related: [Exception Design Guidelines](./exception-design-guidelines.md).

## Code Example
```csharp
using System.Diagnostics.CodeAnalysis;

namespace DotNetRuntimeExamples;

public readonly record struct ParseResult<T>(bool Success, T? Value, string? Error);

public static class ExceptionPerformanceDemo
{
    public static ParseResult<int> ParsePort(string? text)
    {
        ThrowIfNullOrWhiteSpace(text, nameof(text)); // Fast guard for programmer error.

        if (!int.TryParse(text, out var port))
        {
            return new ParseResult<int>(false, null, "Port must be an integer."); // Expected failure.
        }

        return new ParseResult<int>(true, port, null);
    }

    public static string Normalize(string? value)
    {
        ArgumentNullException.ThrowIfNull(value); // Throw helper keeps the happy path tiny.
        return value.Trim().ToUpperInvariant();
    }

    [DoesNotReturn]
    private static void ThrowIfNullOrWhiteSpace(string? value, string paramName)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new ArgumentException("Value cannot be null or whitespace.", paramName);
        }
    }
}
```

## Common Follow-up Questions
- How expensive is throwing compared with a branch or boolean return?
- What exactly do throw helpers optimize?
- When is a `Result<T, TError>` better than an exception?
- Why does `TryParse` exist alongside `Parse`?
- How does `[DoesNotReturn]` help analyzers and nullability flow?

## Common Mistakes / Pitfalls
- Using exceptions for routine negative cases inside tight loops.
- Assuming throw helpers make exceptions cheap rather than optimizing only the success path.
- Replacing every exception with result objects, even for true invariants or programmer errors.
- Benchmarking exception cost without considering stack depth and tiered JIT effects.
- Returning vague result errors while also swallowing diagnostic details needed in logs.

## References
- [Best practices for exceptions](https://learn.microsoft.com/dotnet/standard/exceptions/best-practices-for-exceptions)
- [ArgumentNullException.ThrowIfNull](https://learn.microsoft.com/dotnet/api/system.argumentnullexception.throwifnull)
- [DoesNotReturnAttribute](https://learn.microsoft.com/dotnet/api/system.diagnostics.codeanalysis.doesnotreturnattribute)
- [CA1062: Validate arguments of public methods](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1062)
