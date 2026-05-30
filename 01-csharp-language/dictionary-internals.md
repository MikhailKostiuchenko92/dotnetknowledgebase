# `Dictionary<TKey, TValue>` Internals

**Category:** C# / Collections & LINQ
**Difficulty:** 🟡 Middle
**Tags:** `Dictionary`, `hash-table`, `buckets`, `collisions`, `load-factor`, `GetHashCode`, `performance`

## Question

> How does `Dictionary<TKey, TValue>` work internally? What are buckets, collisions, and load factor?

Additional phrasings:
- *"What happens to `Dictionary` performance when many keys have the same hash code?"*
- *"How does `Dictionary<TKey, TValue>` resize, and what is the cost?"*

## Short Answer

`Dictionary<TKey, TValue>` is a hash table with open addressing via chaining. It maintains an array of bucket slots; each slot stores an index into a parallel entries array. On `Add`, the key's hash code determines the bucket, and the entry is stored (or chained if the bucket is occupied). Lookup is O(1) average — compute hash, find bucket, `Equals`-check the chain. When the ratio of entries to bucket count (load factor) exceeds a threshold (~1.0), the dictionary rehashes: all entries are redistributed into a larger bucket array (prime-sized), which is O(n) but amortized O(1) per insert.

## Detailed Explanation

### Internal Data Structures

.NET's `Dictionary<TKey, TValue>` (as of .NET 5+) maintains:

- **`int[] _buckets`** — an array of length equal to the table size (a prime number). Each slot holds an index into `_entries`, or -1 (empty).
- **`Entry[] _entries`** — a struct array where each `Entry` contains:
  - `int HashCode` — the stored hash code of the key (full, before modulo)
  - `int Next` — index of the next entry in the same bucket chain (-1 = end of chain)
  - `TKey Key`
  - `TValue Value`
- **`int _count`** — number of live entries.
- **`int _freeList`** — index of first removed-but-not-compacted slot (for reuse).

This design is **cache-friendly**: the `_entries` array is contiguous, so iterating the dictionary or chasing collision chains hits sequential memory.

### Lookup Algorithm

```
1. hash = key.GetHashCode() & 0x7FFFFFFF   (strip sign bit)
2. bucket = hash % _buckets.Length
3. i = _buckets[bucket]
4. while i >= 0:
     if _entries[i].HashCode == hash && key.Equals(_entries[i].Key):
         return _entries[i].Value           // found
     i = _entries[i].Next
5. throw KeyNotFoundException              // not found
```

Best case: one hash computation + one bucket lookup + one `Equals` call = O(1).
Worst case (all keys in same bucket): O(n) linear scan of the chain.

### Collisions

Two keys **collide** when `hash1 % bucketCount == hash2 % bucketCount`. The dictionary handles collisions by chaining — the new entry's `Next` points to the previous chain head. With a good hash distribution, chains stay short (≈ 1.0 entries per bucket at full load factor).

Pathological case: all keys have the same hash code → all in one bucket → O(n) lookup. The .NET runtime mitigates **hash flooding attacks** (deliberately crafted inputs to force collisions) using a randomized seed in `string.GetHashCode()` — string hashes differ per process run.

### Load Factor and Rehashing

The dictionary rehashes when `_count >= _buckets.Length` (effective load factor ≈ 1.0). During rehash:

1. Allocate new `_buckets` of the next prime size (~2× current).
2. For each existing entry, recompute `entry.HashCode % newBucketCount` and re-insert into the new bucket chain.
3. Replace old arrays.

Cost: O(n) time and O(n) memory for the new arrays. Amortized over all inserts: O(1) per insert. **Pre-setting capacity** (`new Dictionary<K,V>(expectedCount)`) avoids rehashing entirely, which matters for bulk-load scenarios.

Prime bucket counts reduce clustering — more entries land in distinct buckets than with power-of-2 sizes (though some .NET internal changes have moved toward power-of-2 in certain configurations; the exact behavior is an implementation detail).

### Ordering

`Dictionary<TKey, TValue>` makes **no ordering guarantees**. Iteration order can be insertion-order-like in practice (due to the entries array layout) but this is not contractual and changes after removals or rehashes. Use `SortedDictionary<K,V>` for sorted keys, or `OrderedDictionary` / `List<KeyValuePair<K,V>>` for stable insertion order.

### Removal

`Remove(key)` marks the entry's `HashCode` as a sentinel (-1) and prepends the slot to `_freeList` — it does **not** compact the `_entries` array. Memory is not reclaimed until the dictionary is rebuilt.

### `Dictionary` vs `SortedDictionary` vs `SortedList`

| Collection | Lookup | Insert | Memory | Order |
|---|---|---|---|---|
| `Dictionary<K,V>` | O(1) avg | O(1) amortized | Compact | None |
| `SortedDictionary<K,V>` | O(log n) | O(log n) | Pointer overhead (red-black tree) | Key-sorted |
| `SortedList<K,V>` | O(log n) binary search | O(n) | Compact arrays | Key-sorted |

[See: gethashcode-contract.md](./gethashcode-contract.md) for the `GetHashCode` rules that underpin dictionary correctness.

## Code Example

```csharp
using System.Collections.Generic;

// === Basic usage ===
var dict = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase)
{
    ["Alice"] = 30,
    ["Bob"]   = 25,
};

// TryGetValue: single lookup (safer than ContainsKey + indexer = two lookups)
if (dict.TryGetValue("alice", out int age))
    Console.WriteLine(age); // 30 — case-insensitive

// === Pre-sizing to avoid rehash ===
var bigDict = new Dictionary<int, string>(capacity: 1_000_000);
for (int i = 0; i < 1_000_000; i++)
    bigDict[i] = $"value_{i}"; // no rehash — capacity pre-allocated

// === Collision demo: same bucket, chained ===
// Keys that hash to the same bucket will chain; lookup still correct but slower
// You can observe this by examining bucket chain length with diagnostics

// === Enumerate: no order guarantee ===
foreach (var (key, value) in dict)
    Console.WriteLine($"{key}: {value}"); // order not guaranteed

// === Avoid double-lookup with GetOrAdd pattern ===
var counts = new Dictionary<char, int>();
string text = "hello world";
foreach (char c in text)
{
    // ❌ Two lookups: ContainsKey + indexer
    // if (!counts.ContainsKey(c)) counts[c] = 0;
    // counts[c]++;

    // ✅ One lookup + one write
    counts[c] = counts.TryGetValue(c, out int n) ? n + 1 : 1;

    // ✅ .NET 8+: GetValueOrDefault + assign
    // counts[c] = counts.GetValueOrDefault(c) + 1;
}

// === CollectionsMarshal for high-perf ref access (.NET 5+) ===
ref int countRef = ref System.Runtime.InteropServices.CollectionsMarshal
    .GetValueRefOrAddDefault(counts, 'z', out bool existed);
countRef++; // mutates the value in-place — no second lookup
```

## Common Follow-up Questions

- Why does .NET use prime numbers for bucket counts? (And has this changed in recent .NET versions?)
- How does `ConcurrentDictionary<K,V>` differ in its locking strategy from `Dictionary<K,V>`?
- What is `CollectionsMarshal.GetValueRefOrAddDefault` and why is it useful?
- How does dictionary rehashing affect GC — are the old arrays collected promptly?
- Why is `ContainsKey` followed by an indexer access a double-lookup anti-pattern, and what replaces it?
- How does `FrozenDictionary<K,V>` (.NET 8) improve lookup performance for read-only scenarios?

## Common Mistakes / Pitfalls

- **`ContainsKey` + indexer access = two lookups.** Always use `TryGetValue` when you want to check existence and retrieve the value. A competitive interviewer will always catch this.
- **Not specifying a capacity for bulk inserts.** Without a capacity hint, the dictionary rehashes multiple times (at 4, 8, 16, 32 … entries), copying all data each time. For inserting N items: `new Dictionary<K,V>(N)`.
- **Mutable keys.** If the key's hash or equality changes after insertion, the entry becomes unfindable. Use immutable types (strings, records with immutable properties) as keys.
- **Iterating while modifying.** The dictionary tracks a `_version` counter; any modification during iteration throws `InvalidOperationException`. Collect keys to a list first, then modify.
- **Using `dict[key]` and catching `KeyNotFoundException` as control flow.** This is expensive (exception construction includes a stack trace). Use `TryGetValue` instead.

## References

- [Dictionary<TKey,TValue> — .NET API](https://learn.microsoft.com/dotnet/api/system.collections.generic.dictionary-2)
- [Dictionary source code — .NET runtime GitHub](https://github.com/dotnet/runtime/blob/main/src/libraries/System.Private.CoreLib/src/System/Collections/Generic/Dictionary.cs)
- [CollectionsMarshal — .NET API](https://learn.microsoft.com/dotnet/api/system.runtime.interopservices.collectionsmarshal)
- [Choosing a collection class — .NET guidelines](https://learn.microsoft.com/dotnet/standard/collections/selecting-a-collection-class)
