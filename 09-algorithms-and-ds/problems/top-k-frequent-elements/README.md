# Top K Frequent Elements

**Source:** LeetCode #347
**Difficulty:** 🟡 Medium
**Topics:** Array, HashMap, Heap, Bucket Sort

## Problem Statement

Given an integer array `nums` and an integer `k`, return the `k` **most frequent elements**. You may return the answer in any order.

## Examples

```
Input:  nums = [1, 1, 1, 2, 2, 3], k = 2
Output: [1, 2]

Input:  nums = [1], k = 1
Output: [1]
```

## Constraints

- `1 <= nums.Length <= 10⁵`
- `-10⁴ <= nums[i] <= 10⁴`
- `k` is in the range `[1, nums.Length]`.
- The answer is **unique** — there is only one set of k most frequent elements.

---

## Approach 1: HashMap + Min-Heap — O(n log k) time, O(n) space

Count frequencies, then maintain a min-heap of size `k`. The min-heap pops the *least* frequent element when size exceeds `k`, leaving the k most frequent.

```csharp
public static int[] TopKFrequent(int[] nums, int k)
{
    // Step 1: count frequencies
    var freq = new Dictionary<int, int>();
    foreach (int n in nums)
        freq[n] = freq.GetValueOrDefault(n) + 1;

    // Step 2: min-heap ordered by frequency (smallest frequency at top)
    // PriorityQueue<TElement, TPriority> — lower priority = higher priority in .NET
    var minHeap = new PriorityQueue<int, int>(); // (value, frequency)

    foreach (var (val, count) in freq)
    {
        minHeap.Enqueue(val, count);
        if (minHeap.Count > k)
            minHeap.Dequeue(); // remove least frequent
    }

    var result = new int[k];
    for (int i = k - 1; i >= 0; i--)
        result[i] = minHeap.Dequeue();
    return result;
}
```

> **`PriorityQueue<T,P>` is a min-heap** in .NET 6+. Lower priority value = dequeued first. So passing `count` as priority gives us a min-heap by frequency — exactly what we want.

---

## Approach 2: Bucket Sort — O(n) time, O(n) space ✓ Optimal

Use an array of lists where the index is the frequency. The maximum possible frequency is `n` (all elements the same), so the bucket array has size `n + 1`.

```csharp
public static int[] TopKFrequentBucket(int[] nums, int k)
{
    // Step 1: count frequencies
    var freq = new Dictionary<int, int>();
    foreach (int n in nums)
        freq[n] = freq.GetValueOrDefault(n) + 1;

    // Step 2: bucket[i] = list of values with frequency i
    var buckets = new List<int>[nums.Length + 1];
    foreach (var (val, count) in freq)
    {
        buckets[count] ??= new List<int>();
        buckets[count].Add(val);
    }

    // Step 3: collect top-k from highest frequency buckets down
    var result = new List<int>(k);
    for (int i = buckets.Length - 1; i >= 0 && result.Count < k; i--)
        if (buckets[i] != null)
            result.AddRange(buckets[i]);

    return result.Take(k).ToArray();
}
```

---

## Complexity Summary

| Approach          | Time       | Space |
|-------------------|------------|-------|
| HashMap + min-heap| O(n log k) | O(n)  |
| Bucket sort       | O(n)       | O(n)  |

---

## Interview Tips

- **Explain the heap strategy:** *"A min-heap of size k ensures I only keep the k largest frequency elements. When I add a new element and the heap exceeds size k, I eject the least frequent one."*
- **Mention bucket sort** as the O(n) optimal approach — it impresses but explain why the bucket size is bounded by `n`.
- **`PriorityQueue<T,P>` in .NET 6+** — mention it by name and note it's a min-heap with a separate priority key.
- **Edge cases:** `k == nums.Length` (return all), single unique element.
- **Follow-up:** *"What if you need the k least frequent elements?"* → Flip to max-heap (negate priority), or traverse buckets from the low end.
