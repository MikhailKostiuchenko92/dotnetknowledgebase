# Count of Smaller Numbers After Self

**Source:** LeetCode #315
**Difficulty:** 🔴 Hard
**Topics:** Array, BST, Merge Sort, BIT (Fenwick Tree)

## Problem Statement

Given an integer array `nums`, return an integer array `counts` where `counts[i]` is the number of smaller elements to the right of `nums[i]`.

## Examples

```
Input:  nums = [5,2,6,1]
Output: [2,1,1,0]
// 5 → [2,6,1] has 2 smaller (2,1)
// 2 → [6,1]   has 1 smaller (1)
// 6 → [1]     has 1 smaller (1)
// 1 → []      has 0 smaller

Input:  nums = [-1,-1]
Output: [0,0]
```

## Constraints

- `1 <= nums.Length <= 10⁵`; `-10⁴ <= nums[i] <= 10⁴`

---

## Approach 1: Merge Sort (Count Inversions Variant) — O(n log n) time, O(n) space ✓

Process right-to-left. During merge sort, when an element from the right half is placed before an element from the left half, count how many left-half elements it skips over.

```csharp
public static IList<int> CountSmaller(int[] nums)
{
    int n = nums.Length;
    var result = new int[n];
    var indexed = nums.Select((v, i) => (v, i)).ToArray();
    MergeSort(indexed, result, 0, n - 1);
    return result;
}

private static void MergeSort((int v, int i)[] arr, int[] result, int left, int right)
{
    if (left >= right) return;
    int mid = left + (right - left) / 2;
    MergeSort(arr, result, left, mid);
    MergeSort(arr, result, mid + 1, right);
    Merge(arr, result, left, mid, right);
}

private static void Merge((int v, int i)[] arr, int[] result, int left, int mid, int right)
{
    var tmp = new (int v, int i)[right - left + 1];
    int l = left, r = mid + 1, k = 0;

    while (l <= mid && r <= right)
    {
        if (arr[l].v <= arr[r].v)
        {
            // arr[r..right-1] elements already placed came from the right — those are smaller
            result[arr[l].i] += r - (mid + 1);
            tmp[k++] = arr[l++];
        }
        else
            tmp[k++] = arr[r++];
    }
    while (l <= mid)
    {
        result[arr[l].i] += r - (mid + 1);
        tmp[k++] = arr[l++];
    }
    while (r <= right) tmp[k++] = arr[r++];

    Array.Copy(tmp, 0, arr, left, tmp.Length);
}
```

---

## Approach 2: Fenwick Tree (BIT) — O(n log m) time, O(m) space

Coordinate-compress values, then traverse right-to-left: query prefix sum for `val - 1`, update BIT at `val`.

```csharp
public static IList<int> CountSmallerBIT(int[] nums)
{
    // Coordinate compress to [1..m]
    var sorted = nums.Distinct().OrderBy(x => x).ToList();
    int Rank(int v) => sorted.BinarySearch(v) + 1;
    int m = sorted.Count;

    var bit = new int[m + 1];
    void Update(int i) { for (; i <= m; i += i & -i) bit[i]++; }
    int Query(int i) { int s = 0; for (; i > 0; i -= i & -i) s += bit[i]; return s; }

    var result = new int[nums.Length];
    for (int i = nums.Length - 1; i >= 0; i--)
    {
        int r = Rank(nums[i]);
        result[i] = Query(r - 1);
        Update(r);
    }
    return result;
}
```

---

## Complexity Summary

| Approach        | Time        | Space |
|-----------------|-------------|-------|
| Merge Sort      | O(n log n)  | O(n)  |
| Fenwick Tree    | O(n log m)  | O(m)  |

---

## Interview Tips

- Merge sort is the most intuitive approach — walk through the inversion-counting merge step carefully.
- BIT approach requires coordinate compression — mention this technique explicitly.
- **`long` not needed** here (counts ≤ n = 10⁵), but mention the consideration.
- **Related:** [Count Inversions in Array](../count-inversions-in-array/README.md).
