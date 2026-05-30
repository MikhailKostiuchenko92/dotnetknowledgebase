# Sliding Window Maximum

**Source:** LeetCode #239
**Difficulty:** 🔴 Hard
**Topics:** Array, Monotonic Deque, Sliding Window

## Problem Statement

You are given an array of integers `nums`. There is a sliding window of size `k` moving from the left to the right of the array. Return the **maximum value in each window position**.

## Examples

```
Input:  nums = [1,3,-1,-3,5,3,6,7], k = 3
Output: [3,3,5,5,6,7]
// Window [1,3,-1]→3, [3,-1,-3]→3, [-1,-3,5]→5, [-3,5,3]→5, [5,3,6]→6, [3,6,7]→7

Input:  nums = [1], k = 1
Output: [1]
```

## Constraints

- `1 <= nums.Length <= 10⁵`
- `-10⁴ <= nums[i] <= 10⁴`
- `1 <= k <= nums.Length`

---

## Approach 1: Brute Force — O(n·k) time, O(1) space

Scan each window for max. Too slow for large inputs.

---

## Approach 2: Monotonic Deque — O(n) time, O(k) space ✓

Maintain a **deque of indices** in **decreasing order of values** (monotonic decreasing deque). The front always holds the index of the maximum in the current window.

```csharp
public static int[] MaxSlidingWindow(int[] nums, int k)
{
    int n = nums.Length;
    int[] result = new int[n - k + 1];
    var deque = new LinkedList<int>(); // indices, front = max of window

    for (int i = 0; i < n; i++)
    {
        // Remove indices outside the current window from the front
        while (deque.Count > 0 && deque.First!.Value < i - k + 1)
            deque.RemoveFirst();

        // Remove smaller elements from the back — they'll never be the max
        while (deque.Count > 0 && nums[deque.Last!.Value] < nums[i])
            deque.RemoveLast();

        deque.AddLast(i);

        // Start recording results once the first full window is formed
        if (i >= k - 1)
            result[i - k + 1] = nums[deque.First!.Value];
    }

    return result;
}
```

### Walkthrough: `[1,3,-1,-3,5,3,6,7]`, k=3

```
i=0(1): deque=[0]
i=1(3): 3>1 → remove 0; deque=[1]
i=2(-1): -1<3 → deque=[1,2]. window[0..2]=max=nums[1]=3 ✓
i=3(-3): -3<-1 → deque=[1,2,3]. window[1..3]=max=nums[1]=3 ✓
i=4(5): remove 3,2,1 (all smaller); deque=[4]. window[2..4]=max=nums[4]=5 ✓
i=5(3): 3<5 → deque=[4,5]. window[3..5]=max=nums[4]=5 ✓
i=6(6): remove 5(3<6),4(5<6); deque=[6]. window[4..6]=max=6 ✓
i=7(7): remove 6(6<7); deque=[7]. window[5..7]=max=7 ✓
```

---

## Complexity Summary

| Approach        | Time  | Space |
|-----------------|-------|-------|
| Brute Force     | O(nk) | O(1)  |
| Monotonic Deque | O(n)  | O(k)  |

Each element is added and removed from the deque at most once → O(n) total.

---

## Interview Tips

- **The deque is maintained as monotonically decreasing:** smaller elements at the back are useless — any window containing them also contains the newer (larger) element, which will be a better max candidate.
- **Two invariants:** (1) front index is within the window; (2) deque is decreasing by value.
- **C# `LinkedList<int>`** supports O(1) `AddFirst`, `AddLast`, `RemoveFirst`, `RemoveLast` — mention this.
- **Edge cases:** k=1 (output = input), k=n (single window).
- **Follow-up:** *"Sliding window minimum."* → Use monotonic increasing deque.
- **Follow-up:** *"Sliding window median."* → Requires two heaps — O(n log k).
