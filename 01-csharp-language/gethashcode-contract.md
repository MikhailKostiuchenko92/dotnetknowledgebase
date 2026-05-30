# `GetHashCode` Contract

**Category:** C# / Type System
**Difficulty:** 🔴 Senior
**Tags:** `GetHashCode`, `Equals`, `hash-code`, `dictionary`, `HashSet`, `contract`, `IEqualityComparer`

## Question

> What contract must `GetHashCode` satisfy, and what are the consequences of violating it?

Additional phrasings:
- *"Why must you override `GetHashCode` whenever you override `Equals`?"*
- *"What makes a good hash function for a .NET type, and what are the common mistakes?"*

## Short Answer

`GetHashCode` must satisfy three rules: (1) if `a.Equals(b)` is `true`, then `a.GetHashCode() == b.GetHashCode()` must also be `true`; (2) the hash code must remain stable for the lifetime of the object (or at least as long as the object is used as a dictionary key); (3) different objects *should* (but are not required to) produce different hash codes — collisions are allowed but degrade performance. Violating rule 1 causes silent data loss in `Dictionary<>` and `HashSet<>`: the key exists but can never be found.

## Detailed Explanation

### How Hash-Based Collections Use `GetHashCode`

`Dictionary<TKey, TValue>` and `HashSet<T>` work by dividing objects into **buckets** based on their hash code. A lookup proceeds:

1. Compute `key.GetHashCode()`.
2. Map the hash to a bucket index (modulo bucket count).
3. Walk the bucket's chain and call `key.Equals(candidate)` on each entry.

If two equal objects have **different hash codes**, step 2 sends them to **different buckets** — `Equals` is never called between them. The collection behaves as if the key doesn't exist, even though it does.

### The Three Rules

#### Rule 1: Equal objects must have equal hash codes (mandatory)

```
a.Equals(b) == true  ⟹  a.GetHashCode() == b.GetHashCode()
```

The converse does not need to hold — equal hash codes does not imply equal objects (that would require a perfect hash). Hash collisions are expected and handled by `Equals` fallback.

#### Rule 2: Hash code must be stable during hash-based collection membership (mandatory)

If a key's hash code changes while it is stored in a `Dictionary`/`HashSet`, the collection can no longer find it — it sits in the wrong bucket. This is most commonly violated by:
- Using mutable fields in the hash computation.
- Computing the hash lazily and caching it on a field that changes.

The safe rule: **only use immutable fields in `GetHashCode`**, or make the whole type immutable.

#### Rule 3: Unequal objects should have different hash codes (best-effort)

Perfect distribution reduces bucket collisions and keeps lookup O(1) on average. A bad hash (e.g., always returning 0) makes every collection an O(n) linked list. It doesn't violate correctness but destroys performance.

### The Roslyn Compiler Warning

If you override `Equals` without overriding `GetHashCode`, the compiler emits:

```
CS0659: 'Foo' overrides Object.Equals(object o) but does not override Object.GetHashCode()
```

Always treat this as a blocking warning.

### How to Write a Good `GetHashCode`

**Option 1: `HashCode.Combine` (recommended, .NET Core 2.1+ / .NET Standard 2.1+)**

```csharp
public override int GetHashCode() => HashCode.Combine(Field1, Field2, Field3);
```

`HashCode.Combine` uses a high-quality hash combining algorithm (based on xxHash32) and handles `null` safely. Use this for up to 8 fields.

**Option 2: `HashCode` struct (more than 8 fields)**

```csharp
public override int GetHashCode()
{
    var hc = new HashCode();
    hc.Add(Field1);
    hc.Add(Field2);
    foreach (var item in Collection) hc.Add(item);
    return hc.ToHashCode();
}
```

**Anti-patterns:**
```csharp
// ❌ XOR: symmetric — (1,2) and (2,1) produce the same hash
return X ^ Y;

// ❌ Only first field: all objects with same Field1 collide
return Field1.GetHashCode();

// ❌ Always zero: correct but O(n) dictionary performance
return 0;

// ❌ Using mutable fields: key becomes unfindable after mutation
return MutableName.GetHashCode();
```

### `GetHashCode` for Value Types

For plain `struct`, the default `ValueType.GetHashCode` uses reflection to hash all fields — it is **slow, allocates, and may include padding bytes**. Always override it on structs you use as keys.

### Thread Safety Note

`Dictionary<>` and `HashSet<>` are **not thread-safe**. Even if `GetHashCode` is pure, concurrent structural modifications cause undefined behavior. Use `ConcurrentDictionary<>` for shared state.

### `IEqualityComparer<T>` — Externalizing the Contract

When you can't control a type's `Equals`/`GetHashCode` (e.g., a third-party class), implement `IEqualityComparer<T>` and pass it to the collection constructor:

```csharp
var dict = new Dictionary<Point, string>(new PointByXComparer());
```

This is also the mechanism for case-insensitive string dictionaries (`StringComparer.OrdinalIgnoreCase`).

[See: equality-equals-vs-reference-equals.md](./equality-equals-vs-reference-equals.md) for the full equality contract.

## Code Example

```csharp
using System.Collections.Generic;

// === Correct implementation ===
readonly struct Point(int X, int Y) : IEquatable<Point>
{
    public bool Equals(Point other) => X == other.X && Y == other.Y;
    public override bool Equals(object? obj) => obj is Point p && Equals(p);
    public override int GetHashCode() => HashCode.Combine(X, Y); // ✅ immutable fields
    public static bool operator ==(Point a, Point b) => a.Equals(b);
    public static bool operator !=(Point a, Point b) => !a.Equals(b);
}

var set = new HashSet<Point> { new(1, 2) };
Console.WriteLine(set.Contains(new Point(1, 2))); // true ✅

// === Violation: mutable field in GetHashCode ===
class BadKey
{
    public string Name { get; set; } = "";
    public override bool Equals(object? obj) => obj is BadKey k && k.Name == Name;
    public override int GetHashCode() => Name.GetHashCode(); // ❌ mutable!
}

var dict = new Dictionary<BadKey, int>();
var key = new BadKey { Name = "alpha" };
dict[key] = 1;
key.Name = "beta";   // mutate AFTER insertion
Console.WriteLine(dict.TryGetValue(key, out _)); // false — key is in wrong bucket!
Console.WriteLine(dict.Count); // 1 — the entry still exists, just unfindable

// === IEqualityComparer<T>: externalize the contract ===
class CaseInsensitivePersonComparer : IEqualityComparer<string>
{
    public bool Equals(string? x, string? y) =>
        string.Equals(x, y, StringComparison.OrdinalIgnoreCase);
    public int GetHashCode(string obj) =>
        obj.ToUpperInvariant().GetHashCode(); // ❌ better: use StringComparer.OrdinalIgnoreCase
}

// Preferred: use built-in comparer
var caseDict = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
caseDict["Hello"] = 1;
Console.WriteLine(caseDict.ContainsKey("hello")); // true

// === HashCode.Combine for multi-field types ===
record struct Address(string Street, string City, string Country)
{
    // Record structs auto-generate GetHashCode — but if you need custom:
    public override int GetHashCode() => HashCode.Combine(Street, City, Country);
}
```

## Common Follow-up Questions

- Can `GetHashCode` ever return a negative number? Is that valid?
- How does `HashCode.Combine` differ algorithmically from a simple XOR combine?
- What is `HashCode.AddBytes` used for, and when would you need it?
- How does `ConcurrentDictionary` handle the hash-code contract differently from `Dictionary`?
- What happens to the hash code of `string` when you compare with `StringComparison.OrdinalIgnoreCase` — do you get the same hash for "ABC" and "abc"?
- How do `record` types auto-generate `GetHashCode`, and can you customize it?

## Common Mistakes / Pitfalls

- **Overriding `Equals` without `GetHashCode`.** Rule 1 violation. Causes silent key-not-found bugs in all hash-based collections. The compiler warns but doesn't error.
- **Using mutable fields in the hash computation.** Keys become lost in dictionaries/sets after mutation. Use only immutable fields, or at minimum document that the object must not be mutated while it is a key.
- **XOR combining field hashes.** `a ^ b` is commutative — `(1, 2)` and `(2, 1)` hash to the same value. Always use `HashCode.Combine` or an ordered mixing algorithm.
- **Returning a constant hash (e.g., `return 42`).** Technically correct but degrades every `Dictionary`/`HashSet` to O(n) lookup.
- **Using floating-point fields carelessly.** `double.NaN != double.NaN`, so `NaN.GetHashCode()` must still produce a consistent value. `double.NaN.GetHashCode()` returns `-2146435072` — be aware when hashing floats.
- **Forgetting `null` safety in custom `GetHashCode`.** If a field can be `null`, `field.GetHashCode()` throws. Use `field?.GetHashCode() ?? 0` or `HashCode.Combine` (which handles null).

## References

- [Object.GetHashCode — .NET API](https://learn.microsoft.com/dotnet/api/system.object.gethashcode)
- [HashCode struct — .NET API](https://learn.microsoft.com/dotnet/api/system.hashcode)
- [Guidelines for overriding Equals and GetHashCode — Microsoft Learn](https://learn.microsoft.com/dotnet/csharp/programming-guide/statements-expressions-operators/how-to-define-value-equality-for-a-type)
- [IEqualityComparer<T> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.iequalitycomparer-1)
- [Eric Lippert — "Guidelines and Rules for GetHashCode"](https://ericlippert.com/2011/02/28/guidelines-and-rules-for-gethashcode/) (verify URL)
