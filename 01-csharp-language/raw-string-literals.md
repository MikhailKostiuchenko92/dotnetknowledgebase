# Raw String Literals

**Category:** C# / Modern C# Features
**Difficulty:** Junior
**Tags:** `raw-string-literals`, `string`, `interpolation`, `json`, `sql`, `csharp-11`

## Question

> What are raw string literals in C#, and when are they better than regular or verbatim strings?

Also asked as:
- "How do triple-quoted strings work in C#?"
- "How does interpolation work with raw strings like `$$"""`?"
- "How does indentation stripping make JSON or SQL easier to embed?"

## Short Answer

Raw string literals use triple quotes or more, such as `"""..."""`, to let you write multi-line text without escaping backslashes and quotes constantly. They also support interpolation with additional `$` characters and strip common indentation so embedded JSON, SQL, or templates stay readable in source code. In .NET 8/9 code, they are great for tests, payload samples, and generated text, but they are still plain strings—so parameterize SQL and JSON handling correctly.

## Detailed Explanation

### Why raw strings exist

Before raw strings, C# developers often had to choose between regular strings with heavy escaping and verbatim strings (`@"..."`) that still got awkward once quotes and interpolation entered the picture. Raw strings reduce that friction.

| String form | Strength | Weakness |
|---|---|---|
| Regular string | Familiar, compact for short text | Escaping grows noisy quickly |
| Verbatim string | Easier paths and multi-line text | Embedded quotes still need doubling |
| Raw string literal | Best for structured multi-line text | Delimiters and indentation rules take practice |

### Triple quotes and indentation stripping

A raw string literal begins and ends with at least three quotes. For multi-line literals, the compiler removes the common indentation shared by all content lines relative to the closing delimiter. That means you can indent the source code naturally without carrying those extra spaces into the resulting string.

This is especially useful for JSON, SQL, HTML, and test snapshots.

> **Tip:** Align the closing delimiter carefully. Raw-string indentation behavior is simple once understood, but small indentation shifts change the resulting text.

### Interpolation with multiple `$` signs

Interpolation still works, but the number of `$` characters controls how many braces are needed. With `$$"""`, a placeholder becomes `{{value}}`. That is valuable when the payload itself contains `{` and `}`—common in JSON templates.

### Good and bad use cases

Good fits:
- JSON payloads in tests or demos
- SQL samples, migration snippets, and text templates
- regex or command text where escaping would otherwise dominate the code

Poor fits:
- user input or dynamic query construction that should use safer APIs
- tiny one-line strings where a normal literal is clearer

This topic relates naturally to [string-interpolation-vs-format.md](./string-interpolation-vs-format.md) and [global-and-implicit-usings.md](./global-and-implicit-usings.md) because all three improve source readability without changing runtime string fundamentals.

## Code Example

```csharp
using System;

namespace Demo;

var environment = "prod";
var json = $$"""
    {
      "service": "orders-api",
      "environment": "{{environment}}",
      "features": ["metrics", "health-checks"]
    }
    """;

var sql = """
    SELECT Id, Name
    FROM Users
    WHERE IsActive = 1
    ORDER BY Name;
    """;

Console.WriteLine(json);
Console.WriteLine();
Console.WriteLine(sql);
```

## Common Follow-up Questions

- When is a raw string literal better than a verbatim string?
- How does indentation stripping decide which spaces become part of the final string?
- Why do extra `$` characters change the brace syntax for interpolation?
- What kinds of payloads benefit most from raw strings in real projects?
- Why do raw strings not remove the need for SQL parameterization or proper JSON APIs?

## Common Mistakes / Pitfalls

- Misaligning the closing delimiter and accidentally changing the resulting indentation.
- Forgetting that more `$` signs require more braces around interpolation holes.
- Using raw strings for dynamic SQL construction and assuming readability makes it safe.
- Choosing raw strings for very short literals where normal syntax is simpler.

## References

- [Raw string literal text - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/tokens/raw-string)
- [See: string-interpolation-vs-format.md](./string-interpolation-vs-format.md)
- [See: global-and-implicit-usings.md](./global-and-implicit-usings.md)
- [See: file-scoped-namespaces.md](./file-scoped-namespaces.md)
