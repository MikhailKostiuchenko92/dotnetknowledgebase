# String Interning and Memory

**Category:** .NET Runtime / Memory Model
**Difficulty:** 🟡 Middle
**Tags:** `string`, `interning`, `String.Intern`, `String.IsInterned`, `StringPool`, `memory`

## Question

> What is string interning in .NET, and when is it useful or harmful?

Also asked as:
> Are string literals interned automatically by the CLR?
> Why can manual interning reduce duplicate strings but still be dangerous for long-running processes?

## Short Answer

String interning means storing a single shared instance of identical string content and reusing that same reference for every equal string. The CLR automatically interns compile-time string literals, and you can manually add runtime strings to the intern pool with `String.Intern`. Interning can save memory when there are many duplicates, but it can also hurt because interned strings stay alive for the lifetime of the process, so overusing it can create permanent memory growth.

## Detailed Explanation

### What the Intern Pool Does

A .NET `string` is a reference type, but it is immutable. That makes it a good candidate for deduplication: if two strings contain the same text, they can safely share one underlying object.

The CLR maintains an **intern pool** for this purpose. Compile-time literals such as `"GET"` or `"Content-Type"` are typically interned automatically, so identical literals in the same process often point to the same object.

| Scenario | Interned automatically | Notes |
|---|---|---|
| Compile-time string literal | Usually yes | CLR literal interning |
| Runtime-built string | No, unless interned explicitly | `String.Intern` can add it |
| Lookup only | N/A | `String.IsInterned` checks presence |

### Automatic vs Manual Interning

Automatic interning mainly helps with literals embedded in assemblies. Manual interning is different: you call `String.Intern(runtimeValue)` to put a runtime-generated string into the global pool. If that content already exists, you get the existing reference back.

This can be useful in parsing-heavy workloads that repeatedly create the same identifiers, headers, tokens, or keywords.

### Why It Can Help

If you parse millions of repeated protocol tokens or small dictionary keys, interning can:

- reduce duplicate string objects
- reduce memory used by repeated values
- make reference equality checks possible for known-interned strings

But the benefit depends on high duplication. If most strings are unique, interning adds overhead with little payoff.

> **Warning:** Interned strings are effectively process-lifetime residents. They are not reclaimed like ordinary short-lived strings, so manually interning unbounded runtime data can create a memory leak pattern.

### Why It Can Hurt

The danger is the global lifetime. Imagine interning user IDs, request paths with unique GUIDs, or arbitrary JSON values. Each unique value can remain in the intern pool for the duration of the process. In a server, that may be far worse than letting normal strings die naturally.

That is why manual interning should be reserved for narrow, well-bounded vocabularies.

### Controlled Alternative: `StringPool`

In ASP.NET Core and related libraries, `Microsoft.Extensions.Primitives.StringPool` offers a more controlled pooling strategy for repeated strings. It is useful when you want deduplication behavior without relying on the CLR’s global intern pool. This can be a better fit for framework or middleware scenarios where memory lifetime must remain manageable.

### Subtle Interview Detail

Unlike value types, strings do **not** box because `string` is already a reference type. The interesting runtime discussion is usually about interning, immutability, and equality semantics. See [boxing-and-unboxing.md](./boxing-and-unboxing.md) for the contrast.

### Interview Takeaway

A strong answer says: literals are automatically interned, `String.Intern` can deduplicate runtime strings, and manual interning only helps when the set of repeated values is small and bounded. Otherwise, it risks turning transient data into permanent memory usage.

## Code Example

```csharp
namespace RuntimeSamples;

public static class StringInterningDemo
{
    public static void Main()
    {
        string literal1 = "dotnet";
        string literal2 = "dot" + "net"; // Compile-time concatenation, typically interned
        Console.WriteLine(ReferenceEquals(literal1, literal2)); // Usually True

        string runtime = string.Concat("dot", DateTime.UtcNow.Year);
        Console.WriteLine(String.IsInterned(runtime) is not null); // Usually False

        string token1 = String.Intern(new string("GET".ToCharArray()));
        string token2 = String.Intern(new string("GET".ToCharArray()));
        Console.WriteLine(ReferenceEquals(token1, token2)); // True: same interned instance

        // Framework code can use a scoped string-pooling abstraction for repeated tokens
        // instead of placing every runtime string into the global CLR intern pool.
    }
}
```

## Common Follow-up Questions

- Are all strings in .NET interned automatically?
- Why is `String.Intern` risky in long-running server processes?
- How is string interning different from boxing or object pooling?
- When can `ReferenceEquals` be valid for strings?
- What problem does `Microsoft.Extensions.Primitives.StringPool` solve?

## Common Mistakes / Pitfalls

- Assuming all runtime-generated strings are interned automatically.
- Interning unbounded user data and causing process-lifetime memory growth.
- Using `ReferenceEquals` for general string equality without knowing whether strings are interned.
- Forgetting that interning is only helpful when duplication is high enough to outweigh pool overhead.
- Confusing string immutability with automatic deduplication of every string value.

## References

- [String.Intern(String) - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.string.intern)
- [String.IsInterned(String) - Microsoft Learn](https://learn.microsoft.com/dotnet/api/system.string.isinterned)
- [System.String supplementary remarks](https://learn.microsoft.com/dotnet/fundamentals/runtime-libraries/system-string)
- [StringPool - Microsoft Learn](https://learn.microsoft.com/dotnet/api/microsoft.extensions.primitives.stringpool) (verify URL)
