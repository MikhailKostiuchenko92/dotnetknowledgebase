# Hash Table vs Balanced BST — When to Choose Which

**Category:** Algorithms / Data Structures
**Difficulty:** Middle
**Tags:** `hash-table`, `BST`, `dictionary`, `sorted-set`, `trade-offs`

## Question
> When would you choose a hash table over a balanced BST, and vice versa? What are the trade-offs?

## Short Answer
Hash tables (`Dictionary<K,V>`) offer O(1) average lookup/insert/delete but don't support ordering. Balanced BSTs (`SortedDictionary<K,V>` / `SortedSet<T>`) offer O(log n) operations but maintain sorted order, enabling range queries and floor/ceiling operations. Choose hash when you need fast exact-match lookups; choose BST when you need order-aware queries.

## Detailed Explanation

### Operation Complexity

| Operation | Hash Table (avg) | Hash Table (worst) | Balanced BST |
|-----------|-----------------|-------------------|--------------|
| Insert    | O(1)            | O(n)*             | O(log n)     |
| Delete    | O(1)            | O(n)*             | O(log n)     |
| Search    | O(1)            | O(n)*             | O(log n)     |
| Min/Max   | O(n)            | O(n)              | O(log n)     |
| Range query | O(n)          | O(n)              | O(k + log n) |
| In-order traversal | O(n)  | O(n)              | O(n) sorted  |

*Worst case due to hash collisions (all keys in one bucket).*

### When to Use a Hash Table (`Dictionary<K,V>`)

✅ Fast exact-key lookups (membership tests, caches, memos)  
✅ Frequency counting (`nums.GroupBy(x => x).ToDictionary(...)`)  
✅ Two-sum, anagram detection, deduplication  
✅ When insertion/lookup dominates and ordering doesn't matter  

### When to Use a Balanced BST (`SortedDictionary<K,V>` / `SortedSet<T>`)

✅ Need sorted iteration  
✅ Range queries: "all keys between 10 and 50"  
✅ Floor / ceiling: "largest key ≤ x"  
✅ `OrderBy` or finding k-th smallest element efficiently  
✅ Sliding window maximum/minimum with sorted structure  

### .NET Implementations

```csharp
// Hash-based
var dict = new Dictionary<string, int>();        // O(1) avg
var set  = new HashSet<string>();               // O(1) avg

// Tree-based (Red-Black tree internally)
var sortedDict = new SortedDictionary<string, int>(); // O(log n)
var sortedSet  = new SortedSet<int>();                // O(log n)
// SortedSet has Min, Max, GetViewBetween(lo, hi), Floor/Ceiling via custom logic
```

### Real-World Decision Examples

| Use case | Choose |
|----------|--------|
| Cache / memoisation | `Dictionary` |
| "Contains" check on a large set | `HashSet` |
| Leaderboard (ordered by score) | `SortedDictionary` |
| Find next greater element | `SortedSet` + `GetViewBetween` |
| Count word frequencies | `Dictionary` |
| Sliding window with sorted order | `SortedSet` |

## Code Example

```csharp
// Hash table: O(1) avg — Two Sum
public int[] TwoSum(int[] nums, int target)
{
    var map = new Dictionary<int, int>();
    for (int i = 0; i < nums.Length; i++)
    {
        int complement = target - nums[i];
        if (map.TryGetValue(complement, out int j)) return [j, i];
        map[nums[i]] = i;
    }
    return [];
}

// Balanced BST: floor/ceiling queries
public int? FloorValue(SortedSet<int> set, int target)
{
    // GetViewBetween(min, target) gives all elements ≤ target
    var view = set.GetViewBetween(set.Min, target);
    return view.Count > 0 ? view.Max : null;
}
```

## Common Follow-up Questions
- What is the load factor in a hash table, and how does it affect performance?
- How does `SortedDictionary` differ from `SortedList` in .NET?
- What is the average case vs worst case for `Dictionary<K,V>` in .NET?
- Can a `HashSet<T>` or `Dictionary<K,V>` be used with custom equality comparers?
- How does a skip list compare to a balanced BST?

## Common Mistakes / Pitfalls
- Using `Dictionary` when the problem requires "find the next largest key" — that needs a sorted structure.
- Assuming `Dictionary` always beats `SortedDictionary` — for small n, the overhead difference is negligible.
- Forgetting that hash tables have O(n) worst-case (denial-of-service with adversarial inputs without randomised hashing).
- Using mutable reference types as `Dictionary` keys without overriding `GetHashCode` / `Equals`.

## References
- [Dictionary<TKey,TValue> — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.dictionary-2)
- [SortedDictionary<TKey,TValue> — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.sorteddictionary-2)
- [SortedSet<T> — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.sortedset-1)
