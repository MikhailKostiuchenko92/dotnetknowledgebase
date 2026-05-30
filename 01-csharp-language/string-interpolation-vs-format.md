# String Interpolation vs `string.Format`

**Category:** C# / Strings
**Difficulty:** 🟢 Junior
**Tags:** `string-interpolation`, `string.Format`, `$""`, `FormattableString`, `interpolated-string-handler`, `.NET 6`

## Question

> What is the difference between string interpolation (`$"..."`) and `string.Format`? When would you choose one over the other?

Additional phrasings:
- *"What does the compiler do with a `$"..."` string at compile time?"*
- *"What are interpolated string handlers in .NET 6 and how do they reduce allocations?"*

## Short Answer

`$"Hello, {name}!"` is syntactic sugar that the compiler transforms into a `string.Format`-style call (or, since C# 10 / .NET 6, a more efficient `DefaultInterpolatedStringHandler`). Both produce the same string; interpolation is simply more readable and less error-prone — no format index mismatches, no mismatched argument counts. Use `$"..."` as the default in modern code. Use `string.Format` when the format string is stored in a variable (e.g., for localization) or when targeting APIs that accept a composite format string directly.

## Detailed Explanation

### What the Compiler Does with `$"..."`

In simple cases (C# 6–9, or when the result type is `string`), the compiler transforms:

```csharp
$"Hello, {firstName} {lastName}!"
```

into approximately:

```csharp
string.Concat("Hello, ", firstName, " ", lastName, "!")
// or, for complex cases with format specifiers:
string.Format("Hello, {0} {1}!", firstName, lastName)
```

The exact lowering depends on the number of holes and format specifiers. `string.Concat` is used when there are no format specifiers; `string.Format` when there are format codes (`{value:F2}`, `{date:yyyy-MM-dd}`).

### Interpolated String Handlers (C# 10 / .NET 6+)

C# 10 introduced a mechanism for method authors to intercept interpolated strings **before they are turned into a `string`**. When you call a method that accepts a `[InterpolatedStringHandler]`-attributed type, the compiler decomposes the interpolation into a series of `Append` calls on a stack-allocated handler struct:

```csharp
// Under the hood for Console.WriteLine($"x = {x:F2}") in .NET 6+
var handler = new DefaultInterpolatedStringHandler(literalLength: 4, formattedCount: 1);
handler.AppendLiteral("x = ");
handler.AppendFormatted(x, "F2");
Console.WriteLine(handler.ToStringAndClear());
```

The `DefaultInterpolatedStringHandler` is a **`ref struct`** that writes into a stack buffer for short strings and rents from `ArrayPool<char>` for longer ones — **avoiding heap allocation entirely** in many cases.

**Practical impact:**
- `Console.WriteLine($"...")`, `StringBuilder.Append($"...")`, `ILogger.LogInformation($"...")` (MEL's `LoggerMessage` source gen) all take advantage of this.
- `string.Format` does **not** benefit — it always allocates a final string.

### `FormattableString` — Capturing the Format for Deferred Use

Sometimes you need to capture an interpolated string for later evaluation (e.g., parameterized SQL, localization):

```csharp
FormattableString fs = $"SELECT * FROM users WHERE id = {userId}";
string sql = fs.ToString(CultureInfo.InvariantCulture); // format with specific culture
object[] args = fs.GetArguments(); // { userId }
```

This is how parameterized query helpers and some localization frameworks work: they examine the format string and arguments separately to avoid SQL injection or to translate the template.

### `string.Format` vs `$"..."` — Comparison

| Feature | `string.Format` | `$"..."` |
|---|---|---|
| Readability | Format string separate from args | Inline — easy to read |
| Compile-time check | ❌ No — `{0}` index can be wrong | ✅ Yes — hole is an expression |
| Refactoring safety | Poor — rename doesn't update `{0}` | ✅ Rename propagates |
| Localizable format string | ✅ Yes — string can come from a resource | ❌ Literal only |
| .NET 6+ allocation savings | ❌ No | ✅ With handler-based overloads |
| Culture-specific formatting | `string.Format(culture, ...)` | `FormattableString` or `$"".ToString(culture)` |
| Works in `const` expressions | ❌ No | ❌ No |

### Culture and Interpolation

By default, `$"..."` formats numeric and date values using `CultureInfo.CurrentCulture`. To force invariant formatting:

```csharp
double pi = 3.14159;
string invariant = FormattableString.Invariant($"Pi is {pi:F4}"); // always "3.1416"
string localized  = $"Pi is {pi:F4}";                             // "3,1416" in German locale
```

Use `FormattableString.Invariant` when producing data for storage, APIs, or logs that must be locale-independent.

[See: string-comparison-and-culture.md](./string-comparison-and-culture.md) for culture considerations in general string handling.

## Code Example

```csharp
using System;
using System.Globalization;

string name = "Alice";
int age = 30;
double score = 98.5;

// === string.Format — verbose, index-based ===
string s1 = string.Format("Name: {0}, Age: {1}, Score: {2:F1}", name, age, score);

// === Interpolation — readable, compile-time safe ===
string s2 = $"Name: {name}, Age: {age}, Score: {score:F1}";

Console.WriteLine(s1 == s2); // true — identical result

// === Format specifiers work in both ===
DateTime now = DateTime.UtcNow;
Console.WriteLine($"ISO date: {now:yyyy-MM-ddTHH:mm:ssZ}");
Console.WriteLine(string.Format("ISO date: {0:yyyy-MM-ddTHH:mm:ssZ}", now));

// === FormattableString for invariant output ===
double value = 1234.56;
string localized  = $"{value:N2}";                          // "1,234.56" or "1.234,56" depending on locale
string invariant  = FormattableString.Invariant($"{value:N2}"); // always "1,234.56"

// === FormattableString for parameterized queries (illustrative) ===
int userId = 42;
FormattableString query = $"SELECT * FROM users WHERE id = {userId}";
Console.WriteLine(query.Format);             // "SELECT * FROM users WHERE id = {0}"
Console.WriteLine(query.GetArguments()[0]);  // 42

// === Interpolated string handler: no allocation for short strings (.NET 6+) ===
// Console.WriteLine takes DefaultInterpolatedStringHandler — no intermediate string
Console.WriteLine($"Result: {score:F2}");   // handler writes directly to output

// === $"" over multiple lines (C# 11 raw strings) ===
string json = $"""
    {{
        "name": "{name}",
        "age": {age}
    }}
    """;
Console.WriteLine(json);
```

## Common Follow-up Questions

- How does `ILogger.LogInformation($"...")` in .NET 6+ avoid allocating a string when the log level is disabled?
- What is `string.Create(int length, TState state, SpanAction<char, TState> action)` and when is it faster than interpolation?
- Can you use string interpolation with `Span<char>` as the target — e.g., `MemoryExtensions.TryWrite`?
- How does `string.Format` handle `null` arguments — does it throw or substitute an empty string?
- What is the `CompositeFormat` class added in .NET 8 and how does it improve `string.Format` performance?
- How does string interpolation interact with `[LoggerMessage]` source-generated logging?

## Common Mistakes / Pitfalls

- **Using `$"..."` with `CurrentCulture`-sensitive values in data storage/APIs.** A `double` formatted as `$"{3.14}"` will be `"3,14"` on a German locale machine, breaking JSON/CSV parsing. Use `FormattableString.Invariant` or explicit format specs with `ToString(CultureInfo.InvariantCulture)`.
- **Forgetting that `$"..."` is not `const`.** You cannot use interpolation in `const string` declarations or attribute arguments (where only compile-time constants are accepted).
- **Using `string.Format` when the format string is hardcoded.** There is no benefit over `$"..."`, and `{0}` indices become a maintenance hazard when argument order changes.
- **Assuming `.NET 6+ handler optimization applies everywhere.** Only method overloads explicitly decorated with `[InterpolatedStringHandlerArgument]` get the zero-allocation path. Assigning `$"..."` to a plain `string` variable still allocates a string — the handler optimization only applies at the call site when the target parameter is a handler type.**
- **Calling `string.Format` with a `null` format string.** This throws `ArgumentNullException`. Interpolation avoids this class of bugs entirely.

## References

- [String interpolation — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/tokens/interpolated)
- [String.Format — .NET API](https://learn.microsoft.com/dotnet/api/system.string.format)
- [Interpolated string handlers — C# 10 what's new](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-10#interpolated-string-handler)
- [FormattableString — .NET API](https://learn.microsoft.com/dotnet/api/system.formattablestring)
- [CompositeFormat — .NET 8 API](https://learn.microsoft.com/dotnet/api/system.text.compositeformat)
