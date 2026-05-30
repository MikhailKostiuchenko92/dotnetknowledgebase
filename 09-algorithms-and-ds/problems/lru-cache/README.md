# LRU Cache

**Source:** LeetCode #146
**Difficulty:** 🟡 Medium
**Topics:** Design, Doubly Linked List, HashMap

## Problem Statement

Design a data structure that follows the constraints of a **Least Recently Used (LRU) cache**.

Implement the `LRUCache` class:
- `LRUCache(int capacity)` — initialize with positive capacity.
- `int Get(int key)` — return the value if the key exists, else return `-1`. This operation counts as a "use".
- `void Put(int key, int value)` — update the value if the key exists, or insert the key-value pair. When capacity is reached, evict the **least recently used** key before inserting.

Both operations must run in **O(1)** average time complexity.

## Examples

```
LRUCache cache = new(2);
cache.Put(1, 1);   // cache: {1=1}
cache.Put(2, 2);   // cache: {1=1, 2=2}
cache.Get(1);      // return 1; cache: {2=2, 1=1} (1 is now most recently used)
cache.Put(3, 3);   // capacity exceeded, evict key 2; cache: {1=1, 3=3}
cache.Get(2);      // return -1 (not found)
cache.Put(4, 4);   // evict key 1; cache: {3=3, 4=4}
cache.Get(1);      // return -1
cache.Get(3);      // return 3
cache.Get(4);      // return 4
```

## Constraints

- `1 <= capacity <= 3000`
- `0 <= key <= 10⁴`
- `0 <= value <= 10⁵`
- At most `2 × 10⁵` calls to `Get` and `Put`.

---

## Approach: Doubly Linked List + Dictionary — O(1) for both operations ✓

**Key insight:** O(1) eviction requires knowing which node is LRU (tail) and O(1) removal anywhere requires a doubly linked list.

Use:
- `Dictionary<int, Node>` — maps key → node for O(1) lookup.
- Doubly linked list — maintains access order (head = most recent, tail = least recent).
- **Sentinel head/tail nodes** to avoid null checks.

```csharp
public class LRUCache
{
    private class Node
    {
        public int Key, Val;
        public Node? Prev, Next;
        public Node(int key, int val) { Key = key; Val = val; }
    }

    private readonly int _capacity;
    private readonly Dictionary<int, Node> _map;
    private readonly Node _head, _tail; // sentinels

    public LRUCache(int capacity)
    {
        _capacity = capacity;
        _map = new Dictionary<int, Node>(capacity);
        _head = new Node(0, 0); // most recently used end
        _tail = new Node(0, 0); // least recently used end
        _head.Next = _tail;
        _tail.Prev = _head;
    }

    public int Get(int key)
    {
        if (!_map.TryGetValue(key, out var node)) return -1;
        MoveToFront(node);
        return node.Val;
    }

    public void Put(int key, int value)
    {
        if (_map.TryGetValue(key, out var existing))
        {
            existing.Val = value;
            MoveToFront(existing);
        }
        else
        {
            var node = new Node(key, value);
            _map[key] = node;
            InsertAtFront(node);

            if (_map.Count > _capacity)
            {
                // Evict least recently used (just before tail)
                var lru = _tail.Prev!;
                Remove(lru);
                _map.Remove(lru.Key);
            }
        }
    }

    private void MoveToFront(Node node)
    {
        Remove(node);
        InsertAtFront(node);
    }

    private void InsertAtFront(Node node)
    {
        node.Next = _head.Next;
        node.Prev = _head;
        _head.Next!.Prev = node;
        _head.Next = node;
    }

    private static void Remove(Node node)
    {
        node.Prev!.Next = node.Next;
        node.Next!.Prev = node.Prev;
    }
}
```

---

## .NET Built-in Alternative: `LinkedList<T>` + Dictionary

```csharp
// Conceptually the same, but using .NET's LinkedList<(int key, int value)>
// LinkedListNode<T> allows O(1) removal if you have a reference to the node
var list = new LinkedList<(int, int)>();
var map = new Dictionary<int, LinkedListNode<(int, int)>>();
```

The custom implementation is preferred in interviews to show you understand the internals.

---

## Complexity Summary

| Operation | Time | Space |
|-----------|------|-------|
| Get       | O(1) | —     |
| Put       | O(1) | O(n)  |

---

## Interview Tips

- **State the design** before coding: *"I'll use a hash map for O(1) lookup and a doubly linked list for O(1) insertion/removal while maintaining order."*
- Explain sentinel nodes: *"Dummy head and tail avoid null checks at boundaries."*
- **Common mistake:** Using a singly linked list — O(n) removal because you need the predecessor.
- **Follow-up:** *"Implement LFU Cache (Least Frequently Used)."* → LeetCode #460 — requires tracking frequency counts with multiple doubly linked lists.
- **Real-world context:** .NET's `MemoryCache` uses a different eviction policy; Redis uses an approximated LRU.
