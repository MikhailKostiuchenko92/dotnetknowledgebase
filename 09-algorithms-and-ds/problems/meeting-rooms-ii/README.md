# Meeting Rooms II

**Source:** LeetCode #253 (premium) / NeetCode
**Difficulty:** 🟡 Medium
**Topics:** Array, Greedy, Min-Heap, Sweep Line

## Problem Statement

Given an array of meeting time intervals `intervals[i] = [startᵢ, endᵢ]`, return the **minimum number of conference rooms** required.

## Examples

```
Input:  intervals = [[0,30],[5,10],[15,20]]
Output: 2   // Meeting 1 [0,30] + Meeting 2 [5,10] overlap; Meeting 3 [15,20] can reuse room 2

Input:  intervals = [[7,10],[2,4]]
Output: 1   // No overlap
```

## Constraints

- `1 <= intervals.Length <= 10⁴`
- `0 <= startᵢ < endᵢ <= 10⁶`

---

## Approach 1: Min-Heap — O(n log n) time, O(n) space ✓

Sort by start time. Use a min-heap to track the **earliest end time** among all active rooms. When a new meeting starts, if it starts after the earliest-ending meeting finishes, reuse that room (pop heap, push new end). Otherwise, open a new room.

```csharp
public static int MinMeetingRooms(int[][] intervals)
{
    if (intervals.Length == 0) return 0;

    // Sort by start time
    Array.Sort(intervals, (a, b) => a[0] - b[0]);

    // Min-heap of end times (smallest end = earliest free room)
    var endTimes = new PriorityQueue<int, int>();

    foreach (int[] interval in intervals)
    {
        // Check if the earliest-ending room is free
        if (endTimes.Count > 0 && endTimes.Peek() <= interval[0])
            endTimes.Dequeue(); // reuse the room

        endTimes.Enqueue(interval[1], interval[1]); // allocate/assign room
    }

    return endTimes.Count; // number of active rooms
}
```

---

## Approach 2: Sweep Line (Chronological Events) — O(n log n) time, O(n) space ✓

Treat each start as `+1` event and each end as `-1` event. Sort all events; track running count. The maximum running count = min rooms needed.

```csharp
public static int MinMeetingRoomsSweep(int[][] intervals)
{
    int n = intervals.Length;
    int[] starts = new int[n], ends = new int[n];

    for (int i = 0; i < n; i++) { starts[i] = intervals[i][0]; ends[i] = intervals[i][1]; }
    Array.Sort(starts);
    Array.Sort(ends);

    int rooms = 0, maxRooms = 0, e = 0;
    for (int s = 0; s < n; s++)
    {
        if (starts[s] < ends[e])
            rooms++;         // a new meeting starts before the earliest ends
        else
            e++;             // reuse: one meeting ended
        maxRooms = Math.Max(maxRooms, rooms);
    }
    return maxRooms;
}
```

> **Tie-breaking:** `starts[s] < ends[e]` (strict `<`) means a meeting ending exactly when another starts does **not** require a new room. If the problem states overlapping includes endpoints, change to `<=`.

---

## Complexity Summary

| Approach   | Time       | Space |
|------------|------------|-------|
| Min-Heap   | O(n log n) | O(n)  |
| Sweep Line | O(n log n) | O(n)  |

---

## Interview Tips

- **Heap approach** is more intuitive — simulate assigning rooms.
- **Sweep line** is elegant and slightly easier to implement — preferred under time pressure.
- State the key insight for heap: *"If a room's meeting ends before the next meeting starts, reuse it."*
- **Edge cases:** No meetings (return 0), single meeting (return 1), all meetings at the same time (return n).
- Related: [Merge Intervals](../merge-intervals/README.md) — complementary problem (merge vs. count rooms).
- **Follow-up:** *"Also return which meetings go in each room."* → Track room assignments in the heap using meeting IDs.
