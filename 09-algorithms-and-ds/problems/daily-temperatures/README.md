# Daily Temperatures

**Source:** LeetCode #739
**Difficulty:** 🟡 Medium
**Topics:** Array, Monotonic Stack

## Problem Statement

Given an array of integers `temperatures` representing the daily temperatures, return an array `answer` such that `answer[i]` is the number of days you have to wait after the `i`-th day to get a warmer temperature. If there is no future day with a warmer temperature, keep `answer[i] == 0`.

## Examples

```
Input:  temperatures = [73,74,75,71,69,72,76,73]
Output: [1,1,4,2,1,1,0,0]
//  73 → 74 in 1 day; 75 → 76 in 4 days; 76 has no warmer day → 0

Input:  temperatures = [30,40,50,60]
Output: [1,1,1,0]

Input:  temperatures = [30,60,90]
Output: [1,1,0]
```

## Constraints

- `1 <= temperatures.Length <= 10⁵`
- `30 <= temperatures[i] <= 100`

---

## Approach: Monotonic Stack (Decreasing) — O(n) time, O(n) space ✓

Maintain a stack of **indices** of temperatures waiting for a warmer day (in decreasing temperature order — monotonic decreasing stack). When a temperature is higher than the stack top, the stack top has found its answer.

```csharp
public static int[] DailyTemperatures(int[] temperatures)
{
    int n = temperatures.Length;
    int[] answer = new int[n]; // default 0
    var stack = new Stack<int>(); // stack of indices

    for (int i = 0; i < n; i++)
    {
        // Pop all indices whose temperature is less than temperatures[i]
        while (stack.Count > 0 && temperatures[i] > temperatures[stack.Peek()])
        {
            int idx = stack.Pop();
            answer[idx] = i - idx; // days to wait = current day - that day
        }
        stack.Push(i);
    }

    // Remaining indices in stack have no warmer day → answer[idx] stays 0
    return answer;
}
```

### Walkthrough: `[73,74,75,71,69,72,76,73]`

```
i=0: push 0. stack=[0]
i=1 (74>73): pop 0 → answer[0]=1-0=1. push 1. stack=[1]
i=2 (75>74): pop 1 → answer[1]=2-1=1. push 2. stack=[2]
i=3 (71<75): push 3. stack=[2,3]
i=4 (69<71): push 4. stack=[2,3,4]
i=5 (72>69): pop 4→answer[4]=1; 72>71: pop 3→answer[3]=2; 72<75: stop. push 5. stack=[2,5]
i=6 (76>72): pop 5→answer[5]=1; 76>75: pop 2→answer[2]=4; push 6. stack=[6]
i=7 (73<76): push 7. stack=[6,7]
End: stack=[6,7], answer[6]=answer[7]=0 ✓
```

---

## Complexity Summary

| Approach         | Time | Space |
|------------------|------|-------|
| Monotonic Stack  | O(n) | O(n)  |

Each element is pushed and popped at most once → O(n) total.

---

## Interview Tips

- **Name the pattern:** *"Monotonic decreasing stack — I keep indices of temperatures waiting for a warmer day."*
- **Store indices, not temperatures** — the distance is computed as `i - idx`.
- **Remaining stack items at the end** get answer `0` (no warmer day) — handled by default array initialization.
- **Related patterns:** Next Greater Element, Largest Rectangle in Histogram.
- **Follow-up:** *"What's the next greater temperature within k days?"* → Add a distance check `i - idx <= k` before updating the answer.
