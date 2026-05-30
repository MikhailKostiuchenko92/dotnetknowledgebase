# String Immutability

**Category:** C# / Strings
**Difficulty:** 🟢 Junior
**Tags:** `string`, `immutability`, `heap`, `interning`, `StringBuilder`, `reference-type`

## Question

> Why are strings immutable in C#, and what are the implications of that design?

Additional phrasings:
- *"What happens in memory when you concatenate two strings with `+`?"*
- *"If strings are reference types, why do they behave like value types in comparisons?"*

## Short Answer

Strings are immutable in C# — once a `string` object is created, its character content cannot change. Any operation that appears to "modify" a string (concatenation, `Replace`, `ToUpper`) returns a **new** `string` object, leaving the original unchanged. Immutability enables safe sharing across threads, string interning for literal deduplication, and value-equality semantics without copying. The implication is that repeated concatenation in a loop is O(n²) — use `StringBuilder` when building strings incrementally.

## Detailed Explanation

### What Immutability Means

The `string` type in .NET is a reference type whose internal character array is sealed from modification after construction. There is no public API that changes an existing string's content. All "mutating" methods create and return new strings:

```
"hello".ToUpper()   → new string "HELLO" (original "hello" unchanged)
"hello" + " world"  → new string "hello world"
"hello".Replace('l','r') → new string "herro"
```

### Why Strings Are Immutable

Three main design reasons:

1. **Thread safety.** Because a string's content never changes, multiple threads can read the same string concurrently without locks. No defensive copying needed.

2. **String interning.** The runtime maintains an **intern pool**: identical string literals and interned strings share a single object on the heap. Immutability makes this safe — if "hello" could be mutated, interning would be disastrous.

3. **`GetHashCode` stability.** `string.GetHashCode()` is computed from the characters. Immutability guarantees the hash is stable, making strings safe dictionary keys.

4. **Security.** Paths, connection strings, and security tokens passed around as strings cannot be silently modified by another party after validation.

### Memory Implications of Concatenation

Every `+` operation on strings allocates a new string object:

```csharp
string result = "";
for (int i = 0; i < n; i++)
    result += items[i]; // n allocations, O(n²) total bytes copied
```

For `n = 10,000` strings of average length 5, this copies ~250 MB of character data. With `StringBuilder`:

```csharp
var sb = new StringBuilder();
for (int i = 0; i < n; i++)
    sb.Append(items[i]);   // amortized O(n) — internal buffer doubles like List<T>
string result = sb.ToString(); // one final allocation
```

The tipping point is roughly **4+ string concatenations in a loop** or anywhere the number of concatenations is unknown at compile time.

Compiler-optimized `+` chains: `"a" + "b" + "c"` (all literals, or even non-literals in a single expression) are compiled to a single `string.Concat(...)` call, which allocates exactly once. So `a + b + c + d` is fine — the problem is looping.

### Strings as Reference Types with Value Semantics

`string` is a reference type, but:
- `==` is **overloaded** to perform character-by-character comparison.
- `Equals` is similarly overridden.

This gives strings value-like equality while remaining reference types on the heap. Assignment copies the reference (both variables point to the same string object), but because strings are immutable that doesn't matter — neither party can change the shared object.

### `ReadOnlySpan<char>` — Slicing Without Allocation

Modern .NET APIs offer `ReadOnlySpan<char>` for zero-allocation string processing:

```csharp
ReadOnlySpan<char> s = "hello, world".AsSpan(7, 5); // "world" — no allocation
```

This points directly into the original string's character buffer. Ideal for parsers and formatters in hot paths.

### Mutating Strings: The Unsafe Escape Hatch

It is possible to mutate a string using `unsafe` + `fixed` or `MemoryMarshal`. This is **extremely dangerous** and can corrupt interned strings that other code shares. Never do this in production code except in the most controlled scenarios (e.g., a zero-allocation formatter writing into a freshly-allocated string before it's handed out).

[See: stringbuilder-vs-string-concatenation.md](./stringbuilder-vs-string-concatenation.md) for detailed performance guidance.
[See: string-interning.md](./string-interning.md) for the intern pool mechanics.

## Code Example

```csharp
// === Immutability: operations return new strings ===
string original = "hello";
string upper = original.ToUpper();
Console.WriteLine(original); // "hello" — unchanged
Console.WriteLine(upper);    // "HELLO" — new object

// === Reference semantics, value equality ===
string a = "hello";
string b = "hello";
Console.WriteLine(object.ReferenceEquals(a, b)); // true — same interned literal
Console.WriteLine(a == b);                       // true — value equality

string c = new string("hello".ToCharArray());    // force non-interned
Console.WriteLine(object.ReferenceEquals(a, c)); // false — different objects
Console.WriteLine(a == c);                       // true — value equality still

// === Concatenation cost: O(n²) without StringBuilder ===
var words = Enumerable.Range(1, 1000).Select(i => $"word{i} ").ToArray();

// Bad: 1000 allocations, O(n²) copies
string bad = "";
foreach (var w in words) bad += w;

// Good: amortized O(n), one final allocation
var sb = new System.Text.StringBuilder(words.Sum(w => w.Length));
foreach (var w in words) sb.Append(w);
string good = sb.ToString();

// Best for known-size joins: string.Join (single allocation)
string best = string.Join(" ", words);

// === ReadOnlySpan<char>: zero-allocation slice ===
string csv = "Alice,30,Engineer";
ReadOnlySpan<char> span = csv.AsSpan();
int firstComma = span.IndexOf(',');
ReadOnlySpan<char> name = span[..firstComma]; // "Alice" — no allocation
Console.WriteLine(name.ToString()); // convert to string only when needed
```

## Common Follow-up Questions

- How does the string intern pool work, and when should you call `string.Intern`?
- At what point should you prefer `StringBuilder` over `+` concatenation?
- How does `string.Concat` differ from `+` at the IL level for a chain of literals?
- What are interpolated string handlers in .NET 6+ and how do they reduce allocations?
- How does `Span<char>` / `ReadOnlySpan<char>` differ from `string` for parsing scenarios?
- Can two string variables ever refer to the same interned object? What are the risks?

## Common Mistakes / Pitfalls

- **Repeated `+=` in a loop.** Every iteration allocates a new string and copies all previous characters. The fix is `StringBuilder`, `string.Join`, or `string.Concat` with an enumerable.
- **Assuming `==` checks identity for strings.** It checks value (character equality) when both sides are statically typed as `string`. Cast to `object` and `==` reverts to reference equality.
- **Forgetting that `string.Replace` returns a new string.** A common beginner mistake: `str.Replace("a", "b")` has no effect on `str` unless you assign the result back.
- **Calling `string.Intern` indiscriminately.** Interned strings live for the process lifetime in the intern pool — they are never collected. Interning large or dynamically generated strings causes memory leaks.
- **Using `unsafe` to mutate strings.** You risk corrupting interned strings shared across the entire process and breaking the immutability invariant that many framework components rely on.

## References

- [Strings in C# — Microsoft Learn overview](https://learn.microsoft.com/dotnet/csharp/programming-guide/strings/)
- [String immutability — C# programming guide](https://learn.microsoft.com/dotnet/csharp/programming-guide/strings/#immutability-of-strings)
- [StringBuilder class — .NET API](https://learn.microsoft.com/dotnet/api/system.text.stringbuilder)
- [Memory<T> and Span<T> usage guidelines — Microsoft Learn](https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines)
