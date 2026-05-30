# `StringBuilder` vs String Concatenation

**Category:** C# / Strings
**Difficulty:** 🟡 Middle
**Tags:** `StringBuilder`, `string`, `concatenation`, `performance`, `allocations`, `string.Join`, `interpolation`

## Question

> When should you use `StringBuilder` instead of string concatenation? What are the performance trade-offs?

Additional phrasings:
- *"Why is repeated `+=` on a string in a loop O(n²)? When does `StringBuilder` actually help?"*
- *"In .NET 6+, are there cases where `StringBuilder` is no longer necessary?"*

## Short Answer

Every `string +` / `+=` operation allocates a new string object and copies all previous characters — making a loop of `n` concatenations O(n²) in time and allocations. `StringBuilder` maintains an internal resizable buffer and amortizes copies like `List<T>`, achieving O(n). Use `StringBuilder` when building a string across **multiple statements** or in a loop where the count is unknown at compile time. For a small, fixed number of concatenations in a single expression, `string.Concat` / `$"..."` is optimal — no `StringBuilder` needed.

## Detailed Explanation

### Why `+=` in a Loop Is Expensive

`string` is immutable. Every `s += part` is:

```
new_string = allocate (s.Length + part.Length) chars
             copy s into new_string
             copy part into new_string
             s = reference to new_string
             old string is GC garbage
```

After `n` iterations with strings of length `L`:
- Total characters copied: `L + 2L + 3L + ... + nL = L × n(n+1)/2` → **O(n²)**
- Total allocations: **n** (one per iteration)

For n = 10,000 strings of average length 10, this copies ~500 MB of data.

### How `StringBuilder` Fixes This

`StringBuilder` (in `System.Text`) maintains a **linked list of char arrays** (chunks), each doubling when full (similar to `List<T>`'s backing array strategy). `Append` writes into the current chunk's free space — O(1) amortized. `ToString()` at the end makes exactly one final allocation.

Net result: **O(n) time and O(n) total allocation**.

### Decision Guide

| Scenario | Best approach |
|---|---|
| 2–4 string parts, single expression | `$"..."` or `+` — compiler emits `string.Concat` |
| Known fixed set of strings | `string.Concat(a, b, c)` or `string.Join(sep, arr)` |
| Loop / unknown count | `StringBuilder` |
| Large number of lines/rows | `StringBuilder` with pre-set `Capacity` |
| Building HTML/JSON/CSV | `StringBuilder` or a dedicated builder (e.g., `Utf8JsonWriter`) |
| Parsing/reading (no new string needed) | `ReadOnlySpan<char>` / `Span<char>` — zero allocation |

### `string.Concat` and String Interpolation

The compiler optimizes `+` chains to a single `string.Concat(...)` call when all operands are in a **single expression**:

```csharp
string s = "Hello, " + firstName + " " + lastName + "!";
// compiled to: string.Concat("Hello, ", firstName, " ", lastName, "!")
// → ONE allocation, ONE pass
```

String interpolation `$"Hello, {firstName} {lastName}!"` compiles to the same `string.Concat` in simple cases, and to `DefaultInterpolatedStringHandler` in .NET 6+ for advanced scenarios.

**These do not need `StringBuilder`.**

The problem arises only when concatenation spans **multiple statements** or a loop:

```csharp
string result = "";
foreach (var item in items)
    result += item; // ← this is the problem
```

### `StringBuilder` API Tips

```csharp
// Pre-allocate capacity to avoid internal resizing
var sb = new StringBuilder(expectedLength);

// Chaining (returns 'this')
sb.Append("Hello").Append(", ").Append(name).AppendLine("!");

// AppendFormat and AppendJoin
sb.AppendJoin(", ", items);

// Insert / Replace (use sparingly — O(n))
sb.Insert(0, "Prefix: ");
sb.Replace("old", "new");

// Avoid calling ToString() in the middle of building — it allocates
```

### .NET 6+ Alternatives to `StringBuilder`

**`ValueStringBuilder`** (internal to `System.Text`) is a ref-struct stack-allocated builder for short strings. Not public but the pattern is replicable.

**Interpolated String Handlers** (C# 10 / .NET 6+): custom handler types can format directly into a buffer without intermediate `string` allocation. `string.Create()` and `ZString` (NuGet) use this pattern.

**`Span<char>` + `MemoryExtensions`**: for high-performance code that builds into a fixed-size buffer.

For most application code, `StringBuilder` remains the standard. Reach for span-based approaches only in measured hot paths.

### Pre-set `Capacity` for Best Performance

```csharp
// If you know or can estimate the final length:
var sb = new StringBuilder(items.Count * averageItemLength);
```

Without `Capacity`, `StringBuilder` starts at 16 chars and doubles. For large outputs, this causes several unnecessary allocations and copies.

## Code Example

```csharp
using System.Text;

// === Single expression: compiler-optimized — no StringBuilder needed ===
string firstName = "Alice", lastName = "Smith";
string greeting = "Hello, " + firstName + " " + lastName + "!";
// or equivalently:
string greeting2 = $"Hello, {firstName} {lastName}!";
// Both: one String.Concat call → one allocation

// === Loop: use StringBuilder ===
string[] words = ["the", "quick", "brown", "fox"];

// ❌ O(n²) — don't do this in a loop
string badResult = "";
foreach (var w in words) badResult += w + " ";

// ✅ O(n) — StringBuilder
var sb = new StringBuilder(words.Sum(w => w.Length) + words.Length);
foreach (var w in words) sb.Append(w).Append(' ');
string goodResult = sb.ToString().TrimEnd();

// ✅ Even better for simple joins:
string bestResult = string.Join(" ", words);

// === StringBuilder chaining ===
var html = new StringBuilder(256)
    .AppendLine("<ul>")
    .AppendJoin('\n', words.Select(w => $"  <li>{w}</li>"))
    .AppendLine()
    .AppendLine("</ul>")
    .ToString();
Console.WriteLine(html);

// === Capacity pre-setting for large outputs ===
static string BuildCsv(IReadOnlyList<(string Name, int Age)> rows)
{
    var sb = new StringBuilder(rows.Count * 20); // estimate
    sb.AppendLine("Name,Age");
    foreach (var (name, age) in rows)
        sb.Append(name).Append(',').AppendLine(age.ToString());
    return sb.ToString();
}
```

## Common Follow-up Questions

- How does `StringBuilder` implement its internal storage — is it a single array or a chain of chunks?
- Is `StringBuilder` thread-safe?
- What does `string.Create(length, state, spanAction)` do, and when is it better than `StringBuilder`?
- How do interpolated string handlers in .NET 6+ affect allocation for `string.Format`-style code?
- When would you use `Span<char>` instead of `StringBuilder`?
- What is the performance difference between `sb.Append(value.ToString())` and `sb.Append(value)` for numeric types?

## Common Mistakes / Pitfalls

- **Using `StringBuilder` for 2–3 concatenations in a single expression.** The overhead of instantiating `StringBuilder`, appending, and calling `ToString()` is *more* expensive than a single `string.Concat`. Use `StringBuilder` only when the savings clearly exceed the instantiation cost — typically 4+ parts in a loop.
- **Calling `sb.ToString()` inside the loop** (e.g., to check the current content). Each `ToString()` allocates a new string. Only call it once at the end.
- **Not pre-setting `Capacity`.** For large or measured outputs, omitting capacity causes unnecessary internal re-allocations as the internal buffer doubles from 16.
- **Using `sb.Append(value.ToString())` for value types** instead of `sb.Append(value)`. `StringBuilder.Append` has overloads for `int`, `double`, `char`, etc. that write directly without allocating a string. The `ToString()` call adds an unnecessary intermediate allocation.
- **Assuming `StringBuilder` is always faster.** For small, known, one-off concatenations, the fixed overhead of `StringBuilder` makes it slower. Benchmark before assuming.

## References

- [StringBuilder class — .NET API](https://learn.microsoft.com/dotnet/api/system.text.stringbuilder)
- [How to use StringBuilder — C# programming guide](https://learn.microsoft.com/dotnet/csharp/how-to/modify-string-contents#dynamically-build-a-string)
- [Interpolated string handlers — What's new in C# 10](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-10#interpolated-string-handler)
- [String performance guidelines — .NET documentation](https://learn.microsoft.com/dotnet/standard/base-types/best-practices-strings)
