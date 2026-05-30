# Boxing and Unboxing

**Category:** C# / Type System
**Difficulty:** 🟡 Middle
**Tags:** `boxing`, `unboxing`, `value-types`, `heap`, `performance`, `allocations`

## Question

> What is boxing and unboxing in C#, and why does it matter for performance?

Additional phrasings you may hear:
- *"When does the runtime box a value type, and what exactly happens at the machine level?"*
- *"How would you detect and eliminate unintended boxing in a performance-sensitive code path?"*

## Short Answer

Boxing is the process of wrapping a value type in a heap-allocated object so it can be treated as `object` (or an interface). Unboxing extracts the value back from the wrapper. Every box operation allocates a new object on the managed heap and triggers a memory copy; in tight loops this creates GC pressure. The primary avoidance strategy is to use generics (`List<int>` instead of `ArrayList`) and to avoid casting value types to interfaces in hot paths.

## Detailed Explanation

### What Happens During Boxing

When a value type needs to be stored as `object` or an interface reference, the CLR:

1. Allocates a new object on the managed heap large enough to hold the value type's data plus the standard object header (sync block index + method table pointer — 8 bytes on 64-bit).
2. Copies the value type's bits into the newly allocated object.
3. Returns a reference to that object.

The resulting heap object is called a **box**. It contains a full copy of the value at the time of boxing — subsequent mutations to the original variable do **not** affect the box, and vice versa.

### What Happens During Unboxing

Unboxing goes the other direction:

1. Verifies at runtime that the `object` reference actually wraps the expected value type (throws `InvalidCastException` if not).
2. Copies the stored bits back out to the target value-type location (stack slot, field, etc.).

Unboxing itself does not free the box; the GC handles that when there are no more references to it.

### When Boxing Occurs (Common Sources)

| Scenario | Example |
|---|---|
| Assigning to `object` | `object o = 42;` |
| Calling non-generic methods that accept `object` | `ArrayList.Add(42)` |
| Value type implementing an interface, referenced via that interface | `IComparable c = DateTime.Now;` |
| String interpolation / `string.Format` with a value type before .NET 6 | `$"Val={someStruct}"` (may allocate) |
| `params object[]` overloads | `Console.WriteLine("{0}", 42)` |
| `Enum` members passed as `object` | `object o = MyEnum.Value;` |

> **Note on string interpolation (.NET 6+):** The interpolated string handler feature introduced in C# 10 / .NET 6 allows `Console.WriteLine` and similar methods to accept value types without boxing when the method opts into `InterpolatedStringHandler`. But generic `$"..."` expressions that ultimately become `string` still box value types that don't have a `ToString()` override recognized by the handler.

### Performance Impact

Each box produces a heap allocation. In a loop that runs millions of times:

```
Benchmark (BenchmarkDotNet-style measurements, approximate):
  Summing List<int> (no boxing)   ≈  1.2 ns / iteration
  Summing ArrayList (boxing each) ≈ 15–30 ns / iteration + GC pauses
```

The costs are:
- **Allocation time** — bump-pointer allocation on the young generation is fast, but not free.
- **GC pressure** — many short-lived boxes fill Gen0 quickly; frequent Gen0 collections add latency.
- **Cache locality** — heap objects are scattered; repeated indirection breaks CPU prefetching.

### How to Avoid Boxing

1. **Use generics.** `List<int>` stores ints directly; `ArrayList` stores `object`.
2. **Avoid interface dispatch on value types in hot paths.** Prefer generic constraints (`where T : IComparable<T>`) over storing a value type as its interface.
3. **Override `ToString()` on your structs.** Some framework APIs call `ToString()` via `object`; a direct override avoids the box.
4. **Use `ValueTask` instead of `Task<T>` for frequently completed async paths.**
5. **Inspect with tools.** Roslyn Analyzer, JetBrains Rider's heap allocation analyzer, or dotMemory can flag boxing at compile or runtime.

[See: value-types-vs-reference-types.md](./value-types-vs-reference-types.md) for the underlying type model.

## Code Example

```csharp
using System.Collections;
using System.Collections.Generic;

// --- Boxing: assigning int to object ---
int x = 42;
object boxed = x;        // heap allocation here
int unboxed = (int)boxed; // unboxing: runtime type check + copy

// --- Box isolation: the box is a separate copy ---
int original = 10;
object box = original;
original = 20;
Console.WriteLine((int)box);    // 10 — box still holds original value

// --- Avoid boxing with generics ---
var generic = new List<int>();
generic.Add(1);    // no boxing
generic.Add(2);

var nonGeneric = new ArrayList();
nonGeneric.Add(1); // boxes 1 → allocates on heap
nonGeneric.Add(2); // boxes 2 → allocates on heap

// --- Interface boxing ---
IComparable slow = DateTime.Now;  // boxes DateTime
IComparable<DateTime> fast = DateTime.Now;  // still boxes (interface)
// Better: use generic constraint so the JIT may devirtualize
static int Compare<T>(T a, T b) where T : IComparable<T> => a.CompareTo(b);
// CompareTo is called directly; no boxing for structs

// --- Detecting boxing in string interpolation ---
int count = 5;
string s1 = $"Count: {count}";    // .NET 6+ — no boxing (ISpanFormattable path)
string s2 = string.Format("Count: {0}", count); // boxes count → object
```

## Common Follow-up Questions

- What is the size overhead of a boxed value type on the heap?
- Can you box a `struct` that implements an interface without additional overhead using generics?
- How does the JIT handle structs that implement interfaces — does it always box?
- What is the relationship between boxing and the `dynamic` keyword?
- How would you detect boxing in a production codebase?
- Why can't you mutate a boxed value type through an interface in a predictable way?

## Common Mistakes / Pitfalls

- **Using `ArrayList` or `Hashtable` with value types** in performance-sensitive code — this is the most common source of accidental boxing in legacy codebases. Always prefer generic equivalents.
- **Mutating a value type through an interface reference and expecting the original to change.** Because the interface stores a boxed copy, mutations go to the copy. This is a subtle and hard-to-find bug.
- **Calling `GetHashCode()` or `Equals()` on a struct via an `object` variable** — this boxes first, then calls the method on the box.
- **Passing `enum` values to `string.Format`** — enums are value types and `Format` takes `object[]`, causing boxing. Use `enum.ToString()` explicitly or `$"{myEnum}"` (which handles the formatter path better in modern .NET).
- **Assuming `interface` variables holding structs are "free."** Any time a `struct` is stored in an interface-typed variable, boxing happens — even for tiny structs.

## References

- [Boxing and Unboxing — C# Programming Guide, Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/types/boxing-and-unboxing)
- [Value types — C# reference](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/value-types)
- [Performance considerations for value types — .NET documentation](https://learn.microsoft.com/dotnet/standard/design-guidelines/choosing-between-class-and-struct)
- [Stephen Toub — "Understanding the cost of `await`"](https://devblogs.microsoft.com/dotnet/understanding-the-whys-whats-and-whens-of-valuetask/) (covers ValueTask and boxing avoidance in async)
