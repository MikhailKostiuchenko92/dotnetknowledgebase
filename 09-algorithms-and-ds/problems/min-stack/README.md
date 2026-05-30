# Min Stack

**Source:** LeetCode #155
**Difficulty:** 🟡 Medium
**Topics:** Stack, Design

## Problem Statement

Design a stack that supports `Push`, `Pop`, `Top`, and retrieving the **minimum element** in **O(1)** time.

- `Push(int val)` — push element onto the stack.
- `Pop()` — remove the top element.
- `Top()` — get the top element.
- `GetMin()` — retrieve the minimum element in the stack.

## Examples

```
MinStack stack = new();
stack.Push(-2);
stack.Push(0);
stack.Push(-3);
stack.GetMin(); // return -3
stack.Pop();
stack.Top();    // return 0
stack.GetMin(); // return -2
```

## Constraints

- `-2³¹ <= val <= 2³¹ - 1`
- All calls to `Pop`, `Top`, `GetMin` are valid.
- At most `3 × 10⁴` calls total.

---

## Approach 1: Auxiliary Min Stack — O(1) all ops, O(n) space ✓

Maintain a second stack (`minStack`) that tracks the **current minimum after each push**. When we pop, we also pop from `minStack`.

```csharp
public class MinStack
{
    private readonly Stack<int> _stack    = new();
    private readonly Stack<int> _minStack = new();

    public void Push(int val)
    {
        _stack.Push(val);
        // Push the min of (val, current min) onto the min stack
        int min = _minStack.Count == 0 ? val : Math.Min(val, _minStack.Peek());
        _minStack.Push(min);
    }

    public void Pop()
    {
        _stack.Pop();
        _minStack.Pop();
    }

    public int Top()    => _stack.Peek();
    public int GetMin() => _minStack.Peek();
}
```

Every entry in `_minStack` = the minimum of all elements up to and including the corresponding `_stack` entry.

---

## Approach 2: Single Stack (Store Pairs) — O(1) all ops, O(n) space

Store `(value, minAtThisPoint)` pairs in a single stack.

```csharp
public class MinStackPairs
{
    private readonly Stack<(int val, int min)> _stack = new();

    public void Push(int val)
    {
        int min = _stack.Count == 0 ? val : Math.Min(val, _stack.Peek().min);
        _stack.Push((val, min));
    }

    public void Pop()    => _stack.Pop();
    public int Top()     => _stack.Peek().val;
    public int GetMin()  => _stack.Peek().min;
}
```

Uses C# value tuples — slightly less code, same complexity.

---

## Approach 3: Encode Min with Math (O(1) space — tricky, edge cases)

> This approach uses the difference encoding trick and is **not recommended** in interviews due to tricky overflow handling. Use approaches 1 or 2.

---

## Complexity Summary

| Operation | Time | Space |
|-----------|------|-------|
| Push      | O(1) | O(n)  |
| Pop       | O(1) | —     |
| Top       | O(1) | —     |
| GetMin    | O(1) | —     |

---

## Interview Tips

- **The key insight:** Store the minimum *at the time of each push*, not just the global minimum. This way, `Pop` correctly restores the previous minimum.
- **Common wrong approach:** Storing only the current global min in a single variable — fails after popping the minimum element because you'd lose the previous minimum.
- The auxiliary stack and the pair approach are equally valid — pick the one you can code faster.
- **Edge cases:** Push followed immediately by `GetMin`, pop the min element and verify `GetMin` updates correctly.
