# UTF-8 Strings and `Rune`

**Category:** C# / Strings
**Difficulty:** 🔴 Senior
**Tags:** `UTF-8`, `u8 literal`, `Rune`, `char`, `encoding`, `Unicode`, `surrogate-pairs`, `.NET 7`

## Question

> What is the `Rune` type in .NET, and what problem does it solve that `char` cannot? What are UTF-8 string literals (`u8`)?

Additional phrasings:
- *"Why can a single Unicode character require two `char` values in C#?"*
- *"What is the `u8` literal suffix introduced in .NET 7 / C# 11, and when would you use it?"*

## Short Answer

C# `char` is a 16-bit UTF-16 code unit. Unicode has over 1.1 million code points, but only the 65,536 in the Basic Multilingual Plane (BMP) fit in a single `char`. Characters outside the BMP (emoji, historic scripts, some CJK) require a **surrogate pair** — two `char` values. `Rune` (introduced in .NET 5) represents a single Unicode scalar value (a full code point), making iteration over real characters safe. UTF-8 string literals (`"hello"u8`, C# 11 / .NET 7) produce a `ReadOnlySpan<byte>` containing UTF-8 bytes, avoiding encoding conversion overhead in JSON, HTTP, and database APIs that work in UTF-8.

## Detailed Explanation

### The `char` and UTF-16 Problem

.NET strings are encoded in **UTF-16**: each `char` stores one 16-bit code unit. For characters in the BMP (U+0000–U+FFFF) one `char` = one code point. Fine. For characters above U+FFFF — the **supplementary planes** — UTF-16 uses a **surrogate pair**: two consecutive `char` values (a high surrogate U+D800–U+DBFF followed by a low surrogate U+DC00–U+DFFF) to represent one code point.

Examples:
- `'A'` → one `char` (U+0041) ✅
- `'€'` → one `char` (U+20AC) ✅
- `'😀'` (U+1F600, GRINNING FACE) → **two `char` values**: `'\uD83D'` + `'\uDE00'` ⚠️

This means:
```csharp
string emoji = "😀";
Console.WriteLine(emoji.Length);         // 2 — not 1!
Console.WriteLine(emoji[0]);             // replacement char or garbage
```

String length, character indexing, `Reverse()`, `Substring()` — all operate on `char` (code units), not on human-perceived characters (grapheme clusters), causing subtle bugs in text processing.

### `Rune` — A Full Unicode Scalar Value

`System.Text.Rune` (introduced in .NET 5) represents a single Unicode **scalar value** (any code point except surrogates). It occupies 4 bytes internally:

```csharp
Rune r = new Rune(0x1F600); // 😀
Console.WriteLine(r.Utf16SequenceLength); // 2 — this rune needs 2 chars in UTF-16
Console.WriteLine(r.Utf8SequenceLength);  // 4 — needs 4 bytes in UTF-8
Console.WriteLine(r.IsAscii);             // false
```

`Rune.EnumerateRunes(string)` iterates correctly over a string's code points, including emoji and supplementary characters:

```csharp
string s = "Hello 😀!";
int count = 0;
foreach (Rune rune in s.EnumerateRunes()) count++;
Console.WriteLine(count);        // 8 (H,e,l,l,o, ,😀,!) — correct!
Console.WriteLine(s.Length);     // 9 — char count, wrong for human chars
```

`Rune` also has `IsLetter`, `IsDigit`, `IsWhiteSpace`, `GetUnicodeCategory` — analogues of `char`'s static methods but working on the full Unicode range.

### Grapheme Clusters (Beyond Rune)

Even `Rune` doesn't cover everything a human perceives as "one character." A grapheme cluster can be multiple code points combined: a base character + combining diacritical marks, or emoji + skin-tone modifier + ZWJ sequences:

```
"👨‍👩‍👧‍👦" (family emoji) = 7 code points = multiple Runes = 1 perceived character
```

For grapheme-cluster-aware iteration, use `StringInfo.GetTextElementEnumerator` or `MemoryExtensions.EnumerateRunes` combined with Unicode grapheme breaking rules.

### UTF-8 String Literals (`u8`, C# 11 / .NET 7)

The `u8` suffix on a string literal produces a `ReadOnlySpan<byte>` containing the string's UTF-8 representation, computed at **compile time** — no runtime encoding conversion:

```csharp
ReadOnlySpan<byte> hello = "Hello, World!"u8;
// ↑ same as: new byte[] { 72, 101, 108, 108, 111, 44, ... } but on the stack / in data segment
```

Why it matters:
- .NET, JSON, HTTP, databases, and most modern protocols natively exchange UTF-8 data.
- Previously, going from a string literal to UTF-8 bytes required `Encoding.UTF8.GetBytes(...)` — a heap allocation + encoding pass.
- `u8` literals are placed in the assembly's read-only data segment and exposed as a `ReadOnlySpan<byte>` — **zero allocation, zero runtime cost**.

```csharp
// Before .NET 7: encoding at runtime, allocation
byte[] json = Encoding.UTF8.GetBytes("application/json");

// .NET 7+: compile-time encoding, no allocation
ReadOnlySpan<byte> json = "application/json"u8;
```

`u8` literals can also be stored as `static readonly` fields via `ReadOnlyMemory<byte>`:

```csharp
static ReadOnlySpan<byte> ContentType => "application/json"u8;
```

Because `ReadOnlySpan<byte>` is a `ref struct`, you cannot store `u8` literals directly in class fields. Use `static ReadOnlySpan<byte>` properties (which return the span each time but still point to the same data-segment bytes) or `static readonly byte[]`.

### When to Use `Rune` vs `char`

| Scenario | Use |
|---|---|
| Iterating characters in a string for display/counting | `Rune.EnumerateRunes` |
| Parsing ASCII/BMP-only protocols | `char` (simple, no overhead) |
| Unicode category checks on full code points | `Rune.GetUnicodeCategory` |
| Encoding-aware byte-level text processing | `u8` literals + `ReadOnlySpan<byte>` |
| Grapheme cluster processing (emoji, combining marks) | `StringInfo` + grapheme rules |

## Code Example

```csharp
using System;
using System.Text;

// === char limitation with surrogate pairs ===
string emoji = "😀"; // U+1F600
Console.WriteLine(emoji.Length);             // 2 — two UTF-16 code units
Console.WriteLine(char.IsHighSurrogate(emoji[0])); // true
Console.WriteLine(char.IsLowSurrogate(emoji[1]));  // true

// Naive reversal breaks surrogates:
char[] chars = emoji.ToCharArray();
Array.Reverse(chars);
Console.WriteLine(new string(chars)); // 💣 broken: low surrogate first → invalid string

// === Rune: iterate real code points ===
string mixed = "Caf\u00e9 \U0001F600"; // "Café 😀"
int runeCount = 0;
foreach (Rune r in mixed.EnumerateRunes())
{
    Console.Write($"U+{r.Value:X4} ");
    runeCount++;
}
Console.WriteLine();
Console.WriteLine($"Rune count: {runeCount}"); // 7 (C,a,f,é,space,😀... wait 6)
Console.WriteLine($"Char count: {mixed.Length}"); // 8 (é=1, 😀=2)

// === Rune properties ===
var rune = new Rune(0x1F600);
Console.WriteLine(rune.IsAscii);                    // false
Console.WriteLine(Rune.IsLetter(rune));             // false (emoji ≠ letter)
Console.WriteLine(rune.Utf8SequenceLength);         // 4

// === u8 literal: zero-allocation UTF-8 bytes ===
ReadOnlySpan<byte> contentType = "application/json"u8;
Console.WriteLine(contentType.Length);              // 16 (bytes, not chars)

// Use in a pipe/network scenario (illustrative):
static void WriteHttpHeader(Span<byte> buffer)
{
    "HTTP/1.1 200 OK\r\n"u8.CopyTo(buffer);
    // no Encoding.UTF8.GetBytes allocation
}

// === Encoding comparison ===
string s = "Héllo";
byte[] utf8Bytes    = Encoding.UTF8.GetBytes(s);    // runtime allocation
byte[] utf16Bytes   = Encoding.Unicode.GetBytes(s); // runtime allocation
Console.WriteLine($"UTF-8 length: {utf8Bytes.Length}");   // 6 (é = 2 bytes in UTF-8)
Console.WriteLine($"UTF-16 length: {utf16Bytes.Length}"); // 10 (5 chars × 2 bytes)
```

## Common Follow-up Questions

- What is a grapheme cluster and how does it differ from a `Rune`?
- How does `System.Text.Unicode.Utf8` differ from `Encoding.UTF8`?
- When building a `Utf8JsonWriter` or `System.IO.Pipelines` pipeline, how do `u8` literals integrate?
- What is the performance difference between `Encoding.UTF8.GetBytes` and using `u8` literals?
- How does `string.Normalize` relate to Unicode normalization forms (NFC, NFD)?
- What are the implications of surrogate pairs for `string.Reverse()`, `string.Length`, and `string.Substring`?

## Common Mistakes / Pitfalls

- **Using `string.Length` to count "characters."** For strings containing emoji or supplementary characters, `Length` returns the number of `char` code units, not the number of perceived characters. Use `Rune.EnumerateRunes` for code point count.
- **Indexing a string with `[]` for character manipulation.** `s[i]` returns the i-th `char` code unit. For a string with a surrogate pair at position 3, `s[3]` and `s[4]` are each half a character. Always use `Rune` APIs for character-level work.
- **Using `string.Reverse()` (or `ToCharArray` + `Array.Reverse`) on strings with emoji or combining characters.** This produces invalid strings. Proper reversal requires grapheme-cluster-aware splitting.
- **Storing `u8` literals in an instance field.** `ReadOnlySpan<byte>` is a `ref struct` and cannot be a field. Use a `static` property returning `ReadOnlySpan<byte>`, or store as `static readonly byte[]` or `ReadOnlyMemory<byte>`.
- **Assuming `Rune` equals a "visible character."** Emoji modifiers (skin tone), ZWJ sequences, and combining marks mean multiple `Rune` values can form a single visible character. For UI-level counting, use grapheme cluster APIs.

## References

- [Rune struct — .NET API](https://learn.microsoft.com/dotnet/api/system.text.rune)
- [UTF-8 string literals — C# 11 what's new](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-11#utf-8-string-literals)
- [Character encoding in .NET — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/base-types/character-encoding-introduction)
- [How to use character encoding — .NET guide](https://learn.microsoft.com/dotnet/standard/base-types/character-encoding)
- [Unicode in C# — Nick Chapsas (blog/video)](https://nickchapsas.com) (verify URL)
