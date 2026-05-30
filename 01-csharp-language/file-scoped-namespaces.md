# File-Scoped Namespaces

**Category:** C# / Modern C# Features
**Difficulty:** Junior
**Tags:** `file-scoped-namespace`, `namespace`, `editorconfig`, `csharp-10`, `style`

## Question

> What are file-scoped namespaces in C#, and why do many teams prefer them?

Also asked as:
- "How is `namespace MyApp;` different from the old brace-based namespace syntax?"
- "Why can you only have one file-scoped namespace per file?"
- "How do you enforce file-scoped namespaces with `.editorconfig`?"

## Short Answer

A file-scoped namespace uses `namespace MyApp;` instead of a brace-wrapped block, which removes one level of indentation for the entire file. It has the same semantic meaning as a block-scoped namespace, but it improves readability in the common case where a file contains types from just one namespace. In modern .NET 8/9 codebases, many teams make it the default style and enforce it with analyzers or `.editorconfig`.

## Detailed Explanation

### What changes and what does not

A file-scoped namespace is mostly a syntax and style feature. Instead of wrapping the whole file in braces, the namespace declaration ends with a semicolon and applies to the rest of the file.

| Style | Example | Typical effect |
|---|---|---|
| Block-scoped | `namespace Demo { ... }` | Extra indentation level |
| File-scoped | `namespace Demo;` | Flatter file layout |

The compiled namespace is the same. This is not a new runtime feature, and it does not change assembly structure or type identity.

### Why only one per file

Because the declaration applies to the remainder of the file, C# allows only one file-scoped namespace per file. If you need multiple namespaces in the same file, you must use block-scoped form.

In practice, that limitation is rarely painful because well-structured code usually keeps one namespace per file anyway.

> **Tip:** File-scoped namespaces are best when a file contains one primary type and one clear namespace. If a file is doing more than that, the file structure may be the real issue.

### Readability and tooling

The main benefit is less horizontal noise. Nested types, records, primary constructors, and using directives are easier to scan without one extra indentation level. This becomes especially noticeable in modern C# code that already uses concise syntax such as [global-and-implicit-usings.md](./global-and-implicit-usings.md) and [primary-constructors.md](./primary-constructors.md).

Teams often standardize the style with analyzer rules. In .NET tooling, IDE0160 and IDE0161 cover namespace declaration preferences, and `.editorconfig` can make file-scoped namespaces the preferred form.

### When not to use them

File-scoped namespaces are not mandatory. Block-scoped namespaces are still fine when:
- multiple namespaces exist in one file
- generated code uses another style
- a team intentionally standardizes on classic layout for consistency

This is a readability preference with tooling support, not a correctness issue.

## Code Example

```csharp
using System;

namespace Demo.Tools;

Console.WriteLine(Greeter.SayHello("Mikhail"));

public static class Greeter
{
    public static string SayHello(string name)
        => $"Hello, {name}!"; // Everything below belongs to Demo.Tools.
}

public sealed class FormatHelper
{
    public string Normalize(string text)
        => text.Trim().ToUpperInvariant();
}
```

```ini
# .editorconfig
[*.cs]
csharp_style_namespace_declarations = file_scoped:warning
```

## Common Follow-up Questions

- Why is a file-scoped namespace considered a style feature rather than a runtime feature?
- Why can a file contain only one file-scoped namespace?
- When should you keep block-scoped namespaces instead?
- Which analyzer rule family is commonly used to enforce namespace declaration style?
- How does this feature combine well with global usings and other modern C# syntax?

## Common Mistakes / Pitfalls

- Thinking file-scoped namespaces change assembly layout or runtime behavior.
- Trying to declare multiple file-scoped namespaces in the same file.
- Mixing file-scoped and block-scoped styles inconsistently across the same project.
- Converting generated or special-case files without checking whether multiple namespaces are needed.

## References

- [The namespace keyword - C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/namespace)
- [Use file-scoped namespace (IDE0161) - .NET](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/style-rules/ide0161)
- [See: global-and-implicit-usings.md](./global-and-implicit-usings.md)
- [See: primary-constructors.md](./primary-constructors.md)
- [See: constructors-chaining-and-static.md](./constructors-chaining-and-static.md)
