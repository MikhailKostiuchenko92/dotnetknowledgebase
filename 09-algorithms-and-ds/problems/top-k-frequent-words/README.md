# Top K Frequent Words

**Source:** LeetCode #692
**Difficulty:** 🟡 Medium
**Topics:** Heap (Priority Queue), HashMap, Sorting

## Problem Statement

Given an array of strings `words` and an integer `k`, return the `k` most frequent strings. Sort by frequency (highest first); break ties lexicographically (alphabetical order first).

## Examples

```
Input: words = ["i","love","leetcode","i","love","coding"], k = 2
Output: ["i","love"]

Input: words = ["the","day","is","sunny","the","the","the","sunny","is","is"], k = 4
Output: ["the","is","sunny","day"]
```

## Constraints

- `1 <= words.Length <= 500`; `1 <= words[i].Length <= 10`; lowercase; `1 <= k ≤ unique word count`.

---

## Approach: HashMap + Min-Heap of Size k — O(n log k) time, O(n) space ✓

```csharp
public static IList<string> TopKFrequent(string[] words, int k)
{
    var freq = new Dictionary<string, int>();
    foreach (var w in words) freq[w] = freq.GetValueOrDefault(w) + 1;

    // Min-heap: lower frequency first, then reverse lexicographic (so the "worst" is removed)
    var pq = new PriorityQueue<string, (int freq, string word)>(
        Comparer<(int, string)>.Create((a, b) =>
            a.Item1 != b.Item1 ? a.Item1.CompareTo(b.Item1)   // ascending freq
                               : b.Item2.CompareTo(a.Item2))); // descending lex (worst first)

    foreach (var (word, f) in freq)
    {
        pq.Enqueue(word, (f, word));
        if (pq.Count > k) pq.Dequeue(); // remove the "least desirable"
    }

    var result = new List<string>(k);
    while (pq.Count > 0) result.Add(pq.Dequeue());
    result.Reverse(); // heap gave ascending order, we need descending
    return result;
}
```

---

## Complexity Summary

| Approach          | Time      | Space |
|-------------------|-----------|-------|
| HashMap + Min-Heap | O(n log k)| O(n)  |
| Sort              | O(n log n)| O(n)  |

---

## Interview Tips

- The min-heap comparator is the tricky part: to get the **top-k most frequent**, keep the heap small by removing the least-frequent (and lexicographically latest for ties).
- **Simpler alternative for small n:** sort the unique words with a custom comparator and take first `k`.
