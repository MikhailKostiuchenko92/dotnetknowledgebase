# Caller Info Attributes

**Category:** C# / Attributes / Diagnostics
**Difficulty:** Middle
**Tags:** `caller-info`, `attributes`, `logging`, `guard-clauses`, `diagnostics`

## Question
> What do caller info attributes like `CallerMemberName`, `CallerFilePath`, and `CallerLineNumber` do in C#?
>
> How does `CallerArgumentExpression` work, and where is it useful in logging, assertions, and guard clauses?
>
> Are caller info attributes implemented with reflection, stack walking, or compile-time substitution?

## Short Answer
Caller info attributes let the compiler inject information about the call site into optional parameters, such as the calling member name, source file path, line number, or even the original argument expression. They are especially useful for logging, validation helpers, and assertion APIs because they improve diagnostics without forcing the caller to repeat information manually. The important detail is that this is compile-time substitution, not runtime reflection or stack inspection.

## Detailed Explanation
### What the compiler injects
Caller info attributes are applied to optional parameters. When the caller omits those arguments, the compiler fills them in using information from the call site.

| Attribute | Injected value | Common use |
| --- | --- | --- |
| `[CallerMemberName]` | Calling method/property/event name | Logging, property change notifications |
| `[CallerFilePath]` | Source file path | Diagnostics, test helpers |
| `[CallerLineNumber]` | Source line number | Error reporting |
| `[CallerArgumentExpression]` | Original source expression for another argument | Guard clauses, assertions |

The big interview point is that these values are inserted by the compiler. The callee does not inspect the stack or use reflection.

> Tip: if an interviewer asks whether caller info is “expensive,” the strong answer is that it is usually cheap because the call site is rewritten at compile time.

### Why `CallerArgumentExpression` is especially useful
`CallerArgumentExpression` was added in C# 10 and is now a common part of .NET guard APIs. It captures the exact source expression passed for another parameter, which makes error messages much more useful.

For example, instead of throwing “value must be positive,” a guard can report `quantity * multiplier` or `order.Total` exactly as the caller wrote it.

| Pattern | Before | With `CallerArgumentExpression` |
| --- | --- | --- |
| Guard clause | Manual string argument | Compiler supplies expression text |
| Assertion helper | Repeated message template | More precise failure details |
| Logging helper | Manually typed member names | Less duplication |

### Practical limits and gotchas
Caller info is convenient, but it is still just text emitted at compile time. Renaming a method updates `[CallerMemberName]` automatically, but `[CallerFilePath]` can leak full source paths into logs if you expose them externally. Also, values are tied to the compile-time call site, so wrappers may change what gets captured.

> Warning: do not treat `[CallerFilePath]` as safe user-facing output. It can reveal repository structure or developer machine paths in logs, exceptions, or telemetry.

Caller info attributes pair naturally with [custom-attributes.md](./custom-attributes.md), and they often appear in diagnostics around async code, so see [async-await-fundamentals.md](./async-await-fundamentals.md) for the surrounding execution model.

## Code Example
```csharp
using System;
using System.Runtime.CompilerServices;

Log("Starting calculation");
EnsurePositive(5 * 2);

try
{
    int quantity = -3;
    EnsurePositive(quantity + 1); // Captures the original expression text.
}
catch (ArgumentOutOfRangeException ex)
{
    Console.WriteLine(ex.Message);
}

static void Log(
    string message,
    [CallerMemberName] string memberName = "",
    [CallerFilePath] string filePath = "",
    [CallerLineNumber] int lineNumber = 0)
{
    // File path is shown here only for demo purposes.
    Console.WriteLine($"[{memberName}] {message} ({System.IO.Path.GetFileName(filePath)}:{lineNumber})");
}

static void EnsurePositive(
    int value,
    [CallerArgumentExpression(nameof(value))] string? expression = null)
{
    if (value <= 0)
    {
        throw new ArgumentOutOfRangeException(nameof(value), $"Expression '{expression}' must be positive.");
    }
}
```

## Common Follow-up Questions
- Why are caller info attributes implemented through optional parameters?
- How is `CallerArgumentExpression` different from `nameof`?
- Why are caller info helpers usually preferable to stack walking for diagnostics?
- What are the security or privacy concerns of logging `[CallerFilePath]`?
- How do wrappers or helper methods affect the captured caller information?

## Common Mistakes / Pitfalls
- Assuming caller info uses reflection or stack inspection at runtime.
- Logging full file paths in production telemetry without considering privacy.
- Forgetting that caller info only works when the caller omits the optional argument.
- Using `CallerArgumentExpression` as if it validated the expression; it only captures text.
- Confusing `nameof(value)` with the original expression text such as `order.Total + tax`.

## References
- [Microsoft Docs: Caller information](https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/caller-information)
- [Microsoft Docs: CallerArgumentExpressionAttribute](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.callerargumentexpressionattribute)
- [Microsoft Docs: CallerMemberNameAttribute](https://learn.microsoft.com/dotnet/api/system.runtime.compilerservices.callermembernameattribute)
- [See: Custom Attributes](./custom-attributes.md)
- [See: Async/Await Fundamentals](./async-await-fundamentals.md)
