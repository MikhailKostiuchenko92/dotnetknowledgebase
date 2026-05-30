# Merge Intervals

**Source:** LeetCode #56
**Difficulty:** 🟡 Medium
**Topics:** Array, Sorting, Greedy

## Problem Statement

Given an array of `intervals` where `intervals[i] = [startᵢ, endᵢ]`, merge all **overlapping intervals** and return an array of the non-overlapping intervals that cover all the intervals in the input.

## Examples

```
Input:  intervals = [[1,3],[2,6],[8,10],[15,18]]
Output: [[1,6],[8,10],[15,18]]   // [1,3] and [2,6] overlap → merged to [1,6]

Input:  intervals = [[1,4],[4,5]]
Output: [[1,5]]   // touching at 4 counts as overlapping
```

## Constraints

- `1 <= intervals.Length <= 10⁴`
- `intervals[i].Length == 2`
- `0 <= startᵢ <= endᵢ <= 10⁴`

---

## Approach: Sort by Start + Greedy Merge — O(n log n) time, O(n) space ✓

Sort intervals by their start time. Then scan linearly: if the current interval overlaps with the last merged interval (current start ≤ last end), extend the end. Otherwise, start a new merged interval.

```csharp
public static int[][] Merge(int[][] intervals)
{
    // Sort by start time
    Array.Sort(intervals, (a, b) => a[0] - b[0]);

    var merged = new List<int[]>();

    foreach (int[] curr in intervals)
    {
        if (merged.Count == 0 || merged[^1][1] < curr[0])
        {
            // No overlap — add as new interval
            merged.Add(curr);
        }
        else
        {
            // Overlap — extend the end of the last merged interval
            merged[^1][1] = Math.Max(merged[^1][1], curr[1]);
        }
    }

    return merged.ToArray();
}
```

### Walkthrough: `[[1,3],[2,6],[8,10],[15,18]]`

```
After sort: [[1,3],[2,6],[8,10],[15,18]] (already sorted)
[1,3]: merged = [[1,3]]
[2,6]: 3 >= 2 → overlap → extend end: merged = [[1,6]]
[8,10]: 6 < 8 → no overlap → merged = [[1,6],[8,10]]
[15,18]: 10 < 15 → no overlap → merged = [[1,6],[8,10],[15,18]]
```

---

## Variant: Insert Interval (LeetCode #57)

Given merged non-overlapping intervals and a `newInterval`, insert and merge:

```csharp
public static int[][] Insert(int[][] intervals, int[] newInterval)
{
    var result = new List<int[]>();
    int i = 0, n = intervals.Length;

    // Add all intervals ending before newInterval starts
    while (i < n && intervals[i][1] < newInterval[0])
        result.Add(intervals[i++]);

    // Merge all overlapping intervals
    while (i < n && intervals[i][0] <= newInterval[1])
    {
        newInterval[0] = Math.Min(newInterval[0], intervals[i][0]);
        newInterval[1] = Math.Max(newInterval[1], intervals[i][1]);
        i++;
    }
    result.Add(newInterval);

    // Add remaining intervals
    while (i < n) result.Add(intervals[i++]);
    return result.ToArray();
}
```

---

## Complexity Summary

| Approach                | Time       | Space |
|-------------------------|------------|-------|
| Sort + greedy merge     | O(n log n) | O(n)  |
| Insert interval (sorted)| O(n)       | O(n)  |

---

## Interview Tips

- **Sort first** — this is the key step that makes the linear merge possible.
- `merged[^1]` uses the C# 8+ index-from-end operator — mention it.
- **Overlap condition:** `curr[0] <= merged[^1][1]` (touching counts as overlapping per the problem).
- **Edge cases:** Single interval, all disjoint, all overlapping (result = one interval).
- **Follow-up:** *"How many rooms are needed for non-overlapping meeting scheduling?"* → [Meeting Rooms II](../meeting-rooms-ii/README.md).
