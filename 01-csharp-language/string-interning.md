# String Interning

**Category:** C# / Strings
**Difficulty:** 🟡 Middle
**Tags:** `string`, `interning`, `intern-pool`, `string.Intern`, `memory`, `performance`

## Question

> What is string interning in .NET? When does it happen automatically, and when should you call `string.Intern` explicitly?

Additional phrasings:
- *"Why does `ReferenceEquals("abc", "abc")` return `true` for literals but `false` for dynamically built strings?"*
- *"What are the risks of string interning, and when should you avoid it?"*

## Short Answer

String interning is a process where the .NET runtime stores a single copy of each unique string in a hash table called the **intern pool**, so that all references to that string value point to the same object. String literals and `const` strings are interned automatically at JIT/load time. `string.Intern(s)` adds an arbitrary string to the pool at runtime. The main benefit is memory savings when many identical strings exist; the main risk is that interned strings are never garbage collected — they live for the process lifetime.

## Detailed Explanation

### The Intern Pool

The intern pool is an internal, process-wide hash table (`CLR_INTERN_TABLE`) maintained by the runtime. Its keys are the string character content; its values are managed references to `string` objects allocated in a special non-collectible heap segment.

When a string is interned:
1. The runtime checks if an equal string already exists in the pool.
2. If yes, it returns the existing reference.
3. If no, it adds a new entry and returns that reference.

Because the pool holds the only reference to those strings in a non-GC-collected segment, **interned strings are immortal** — they are never freed during the process lifetime.

### Automatic Interning

The CLR automatically interns **string literals** (compile-time constant strings). This happens at assembly load time:

```csharp
string a = "hello";
string b = "hello";
Console.WriteLine(ReferenceEquals(a, b)); // true — same interned object
```

The compiler places each unique literal in the assembly's `#US` (user strings) heap. At load time, the CLR creates one `string` object per unique literal and registers it in the intern pool.

**Concatenation of literals at compile time also produces one interned string:**

```csharp
const string s1 = "hel" + "lo"; // constant folding → single "hello" literal
string s2 = "hello";
Console.WriteLine(ReferenceEquals(s1, s2)); // true
```

### `string.Intern(s)` and `string.IsInterned(s)`

`string.Intern(s)` explicitly adds a runtime-built string to the pool. `string.IsInterned(s)` checks whether a string is already in the pool without adding it:

```csharp
string runtime = new string("hello".ToCharArray()); // not interned
Console.WriteLine(ReferenceEquals(runtime, "hello")); // false

string interned = string.Intern(runtime); // adds to pool (or returns existing)
Console.WriteLine(ReferenceEquals(interned, "hello")); // true
```

### When to Use `string.Intern`

Interning makes sense when:
- A small, **bounded set** of strings is used repeatedly throughout the process lifetime (e.g., configuration keys, column names, protocol tokens).
- Memory savings from deduplication outweigh the permanence cost.
- You need **reference equality** checks for performance (e.g., replacing `Equals` with `ReferenceEquals` after interning both operands — though this is rare and fragile).

### When NOT to Use `string.Intern`

- **Unbounded or large sets of strings.** Each unique string consumes pool memory forever. Interning file paths from user input, user-submitted data, or database results will bloat memory without bound.
- **Short-lived strings.** If a string is only used in one place and then discarded, interning it prevents GC from freeing it.
- **Performance-critical inner loops on non-literal strings.** The hash lookup in the intern pool has overhead. For most scenarios, it's faster to simply use `string.Equals`.

### Interning vs String Deduplication (GC)

Since .NET 4.6.1, the Server GC can perform **string deduplication** as a background process: it scans the heap, finds equal strings, and makes variables point to the same object — without the permanence of interning. This is transparent to the application. Interning is an explicit, permanent mechanism; GC deduplication is an automatic, generational optimization.

| | Interning | GC String Deduplication |
|---|---|---|
| Mechanism | Explicit or literal-automatic | Automatic (Server GC, opt-in) |
| Duration | Permanent (process lifetime) | Until no more references |
| Reference equality guaranteed? | ✅ Yes | ❌ Not guaranteed |
| Risk | Memory leak for large sets | None |
| Control | Full (via `string.Intern`) | None (GC-controlled) |

[See: string-immutability.md](./string-immutability.md) for why immutability makes interning safe.

## Code Example

```csharp
// === Literal interning: automatic ===
string a = "dotnet";
string b = "dotnet";
Console.WriteLine(ReferenceEquals(a, b)); // true — same interned literal

// === Runtime string: NOT automatically interned ===
string c = string.Concat("dot", "net");  // runtime value
Console.WriteLine(ReferenceEquals(a, c)); // false — different objects
Console.WriteLine(a == c);               // true — value equality

// === Explicit intern ===
string d = string.Intern(c);            // add to pool (returns existing "dotnet")
Console.WriteLine(ReferenceEquals(a, d)); // true — same interned object

// === IsInterned: check without adding ===
string? maybe = string.IsInterned("dotnet"); // returns interned ref if present
Console.WriteLine(maybe is not null);        // true

string dynamic = Guid.NewGuid().ToString();
Console.WriteLine(string.IsInterned(dynamic) is null); // true — not in pool

// === Memory concern: don't intern unbounded input ===
// BAD: intern every incoming HTTP header value
void ProcessHeaders(Dictionary<string, string> headers)
{
    foreach (var (key, value) in headers)
    {
        // ❌ value may be unique per request — intern leaks memory
        // var internedValue = string.Intern(value);

        // ✅ intern only the key (small bounded set of known header names)
        var internedKey = string.IsInterned(key) ?? key;
        _ = internedKey; // use it
    }
}
```

## Common Follow-up Questions

- How does the CLR implement the intern pool internally — is it a `Dictionary<string, string>`?
- Does string interning work across `AppDomain` boundaries?
- How does .NET GC string deduplication (Server GC feature) relate to interning?
- What is the interaction between `string.Intern` and `WeakReference<string>`?
- If two assemblies both contain the literal `"hello"`, do they share the same interned object?
- Does interning affect the behavior of `string.GetHashCode()` between processes?

## Common Mistakes / Pitfalls

- **Interning strings derived from user input or database data.** Each unique value permanently occupies the intern pool. For a high-traffic web API this can cause unbounded memory growth.
- **Assuming all equal strings are reference-equal.** Only interned strings share references. Code that relies on `ReferenceEquals` for correctness (rather than performance) is fragile.
- **Using `string.Intern` as a substitute for a `HashSet<string>`.** A `HashSet` is GC-friendly and bounded; the intern pool is not.
- **Interning to "improve" equality performance.** The overhead of `Intern` lookup often exceeds the savings from replacing `Equals` with `ReferenceEquals`. Profile before optimizing.
- **Forgetting that `const string` values are inlined at compile time.** Changing a `const string` in a library requires recompiling all consumers; otherwise they keep the old inlined literal.

## References

- [String.Intern — .NET API](https://learn.microsoft.com/dotnet/api/system.string.intern)
- [String.IsInterned — .NET API](https://learn.microsoft.com/dotnet/api/system.string.isinterned)
- [Strings in C# — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/strings/)
- [GC String Deduplication — .NET runtime documentation](https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals)
