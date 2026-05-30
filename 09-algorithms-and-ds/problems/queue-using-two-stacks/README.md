# Implement a Queue Using Two Stacks

**Source:** LeetCode #232
**Difficulty:** 🟢 Easy
**Topics:** Stack, Queue, Design, Amortised Analysis

## Problem Statement

Implement a first in first out (FIFO) queue using only two stacks. The implemented queue should support all functions of a normal queue (`push`, `pop`, `peek`, `empty`).

- `Push(int x)` — push element to the back of the queue.
- `Pop()` — remove and return the element from the front.
- `Peek()` — return the element at the front without removing it.
- `Empty()` — return `true` if the queue is empty.

## Examples

```
MyQueue queue = new();
queue.Push(1);
queue.Push(2);
queue.Peek();  // return 1
queue.Pop();   // return 1
queue.Empty(); // return false
```

## Constraints

- `1 <= x <= 9`
- At most `100` calls to `Push`, `Pop`, `Peek`, and `Empty`.
- All calls to `Pop` and `Peek` are valid (queue is non-empty).

---

## Approach: Two Stacks (Lazy Transfer) — O(1) amortised for all operations ✓

- `inputStack` — receives all `Push` calls.
- `outputStack` — serves all `Pop`/`Peek` calls.

Transfer elements from `inputStack` to `outputStack` **only when `outputStack` is empty**. This reverses the order, turning LIFO → FIFO.

```csharp
public class MyQueue
{
    private readonly Stack<int> _input  = new();
    private readonly Stack<int> _output = new();

    public void Push(int x) => _input.Push(x);

    public int Pop()
    {
        Migrate();
        return _output.Pop();
    }

    public int Peek()
    {
        Migrate();
        return _output.Peek();
    }

    public bool Empty() => _input.Count == 0 && _output.Count == 0;

    private void Migrate()
    {
        if (_output.Count == 0)
            while (_input.Count > 0)
                _output.Push(_input.Pop()); // reverse order = FIFO
    }
}
```

### Amortised Analysis

Each element is pushed to `_input` once and `_output` once. The total work across all operations is O(n), so each operation is **O(1) amortised**. Worst-case single `Pop` is O(n) (when migration happens), but this can't happen back-to-back.

---

## Complexity Summary

| Operation | Amortised | Worst-Case |
|-----------|-----------|------------|
| Push      | O(1)      | O(1)       |
| Pop       | O(1)      | O(n)       |
| Peek      | O(1)      | O(n)       |
| Empty     | O(1)      | O(1)       |

---

## Interview Tips

- **Explain the insight:** *"Pushing into one stack reverses order. Popping everything into another stack reverses it again — restoring FIFO order."*
- **Lazy migration beats eager migration** — transfer only when the output stack is empty, not on every push.
- **Amortised O(1)** — be ready to explain the accounting argument if asked.
- **Edge cases:** `Pop` on a queue with elements only in `_input` (triggers migration), empty check after multiple pops.
- **Follow-up:** *"Implement a stack using two queues."* → O(n) `push` (enqueue to Q2, swap Q1↔Q2) or O(n) `pop` (rotate queue).
