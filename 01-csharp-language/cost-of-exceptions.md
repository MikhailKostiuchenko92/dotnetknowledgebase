# Cost of Exceptions

**Category:** C# / Exceptions
**Difficulty:** Senior
**Tags:** `exceptions`, `performance`, `TryParse`, `Parse`, `first-chance-exceptions`

## Question

> How expensive are exceptions in .NET, and why should they not be used for normal control flow?

Also asked as:
- "What is the runtime cost of throwing an exception versus just having a `try` block?"
- "What are first-chance and second-chance exceptions, and what do they mean in diagnostics?"

## Short Answer

In .NET, having `try`/`catch` blocks around code is usually cheap when no exception is thrown, but actually throwing an exception is expensive because the runtime must create/capture exception state, walk the stack, run filters/finally blocks, and unwind frames until a handler is found. That is why exceptions should represent exceptional failures, not routine branching. In hot paths, prefer result-based APIs such as `TryParse` instead of intentionally throwing repeatedly with `Parse`.

## Detailed Explanation

### The Important Distinction: "Having" vs "Throwing"

A common interview trap is saying "exceptions are always expensive." The more accurate answer is:
- A `try` block by itself is usually cheap.
- **Throwing** an exception is expensive.

Modern JIT and runtime implementations are designed so normal execution does not pay the full cost of the exceptional path. The real cost appears when the exception is actually thrown.

### Why Throwing Costs Real Time

When an exception is thrown, the runtime has to do much more than jump to another line:
- Create or propagate the exception object.
- Capture stack-trace information.
- Search for matching handlers.
- Evaluate exception filters.
- Execute `finally` blocks.
- Unwind stack frames until a handler is found.

All of that is significantly more expensive than an `if` check or a `bool`-returning API. The exact cost depends on stack depth, filters, debugger settings, and runtime version, so you should avoid hard-coded claims like "an exception costs exactly X microseconds." The correct principle is that the exceptional path is orders of magnitude more expensive than ordinary branching.

### Stack Unwinding and Its Side Effects

The high cost is not only CPU time. Unwinding changes control flow across multiple frames. That can:
- Skip remaining statements in the current method.
- Trigger cleanup code in many `finally` blocks.
- Produce extra logging noise.
- Distort performance traces if the application throws frequently.

If a loop throws thousands of exceptions per second, the application may spend more time building stack traces and unwinding than doing useful work.

> **Warning:** Exceptions are a correctness mechanism first, not a control-flow primitive. Using them as a routine branch in parsing, probing, or validation code is a classic performance smell.

### `Parse` vs `TryParse`

This is the canonical example.

| API | Normal invalid-input behavior | Best use |
|---|---|---|
| `int.Parse("abc")` | Throws `FormatException` | Input is expected to be valid; invalid input is truly exceptional |
| `int.TryParse("abc", out value)` | Returns `false` | Invalid input is expected and common |

If user input, CSV import, or external data can often be malformed, `TryParse` is the right choice. Repeatedly calling `Parse` inside a `try`/`catch` is both slower and noisier.

### First-Chance vs Second-Chance Exceptions

These terms are diagnostic concepts, especially visible in debuggers.

- **First-chance exception:** the CLR notifies the debugger that an exception was thrown. The exception may still be caught later. This does **not** automatically mean an error escaped the app.
- **Second-chance exception:** the exception was unhandled by user code and is about to terminate the process or be handled by a last-chance host/debugger mechanism.

Developers sometimes panic when they see many first-chance exceptions in diagnostics. The real question is whether those exceptions are expected, frequent, and harmful to performance. Even if they are eventually caught, a large volume of first-chance exceptions can indicate inefficient design.

### Exceptions in Hot Paths

Hot paths include parsers, serializers, logging pipelines, allocation-sensitive code, game loops, and high-throughput web endpoints. In those places:
- Avoid "probe by throw" patterns.
- Prefer `TryGetValue`, `TryParse`, and guard clauses.
- Validate inputs before calling APIs that are documented to throw for normal invalid data.

This is especially important in ASP.NET Core and background services, where repeated exceptions can hurt throughput and flood telemetry.

### But Do Not Overcorrect

Avoid two bad extremes:
1. Using exceptions for routine branching.
2. Refusing to use exceptions at all for genuine failures.

If opening a file fails because the disk is unavailable, an exception is appropriate. If a user types a non-numeric string into a text box, `TryParse` is usually better.

### Practical Interview Answer

A strong interview answer is:
- No-throw `try` blocks are usually cheap.
- Throwing is expensive due to stack capture and unwinding.
- Exceptions should represent exceptional failures.
- In expected-failure scenarios, prefer `Try*` APIs or explicit result objects.

See also [exception-handling-fundamentals.md](./exception-handling-fundamentals.md) and [exception-filters-when.md](./exception-filters-when.md).

## Code Example

```csharp
using System;

AppDomain.CurrentDomain.FirstChanceException += (_, eventArgs) =>
{
    // Fires for every thrown exception, even if it is later caught.
    Console.WriteLine($"First-chance: {eventArgs.Exception.GetType().Name}");
};

string[] inputs = ["10", "20", "oops", "30"];

Console.WriteLine("Using Parse with exceptions:");
foreach (string input in inputs)
{
    try
    {
        int value = int.Parse(input); // Throws on "oops".
        Console.WriteLine($"Parsed: {value}");
    }
    catch (FormatException)
    {
        Console.WriteLine($"Invalid number: {input}");
    }
}

Console.WriteLine();
Console.WriteLine("Using TryParse without exceptions for expected bad input:");
foreach (string input in inputs)
{
    if (int.TryParse(input, out int value))
    {
        Console.WriteLine($"Parsed: {value}");
    }
    else
    {
        Console.WriteLine($"Invalid number: {input}");
    }
}
```

## Common Follow-up Questions

- Why is a `try` block itself much cheaper than actually throwing an exception?
- When is `Parse` still acceptable even though `TryParse` exists?
- What is the difference between first-chance and second-chance exceptions in Visual Studio diagnostics?
- How can frequent exceptions hurt telemetry, logging costs, and request throughput?
- When would a result type or `Try*` API be better than exceptions for API design?

## Common Mistakes / Pitfalls

- Saying "exceptions are slow" without distinguishing the no-throw path from the throwing path.
- Using exceptions inside tight loops as a normal way to test whether input is valid.
- Treating every first-chance exception as an application failure instead of a debugging signal.
- Over-optimizing away legitimate exception usage for true error conditions.
- Benchmarking exception cost without considering debugger attachment, stack depth, and runtime version.

## References

- [Best practices for exceptions — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/exceptions/best-practices-for-exceptions)
- [Exception-handling statements — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/exception-handling-statements)
- [FirstChanceException Event — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.appdomain.firstchanceexception)
- [Int32.TryParse Method — Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.int32.tryparse)
- [See: exception-filters-when.md](./exception-filters-when.md)
