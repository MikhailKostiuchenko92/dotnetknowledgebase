# Word Ladder

**Source:** LeetCode #127
**Difficulty:** 🔴 Hard
**Topics:** String, BFS, HashMap

## Problem Statement

Given a `beginWord`, `endWord`, and a `wordList`, return the **number of words** in the shortest transformation sequence from `beginWord` to `endWord`, or `0` if no such sequence exists.

Rules:
- Every adjacent pair of words differs by exactly one letter.
- Every word in the transformation sequence must exist in `wordList`.
- `beginWord` does not need to be in `wordList`.

## Examples

```
Input: beginWord = "hit", endWord = "cog", wordList = ["hot","dot","dog","lot","log","cog"]
Output: 5   // hit → hot → dot → dog → cog

Input: beginWord = "hit", endWord = "cog", wordList = ["hot","dot","dog","lot","log"]
Output: 0   // cog not in wordList
```

## Constraints

- `1 <= beginWord.Length == endWord.Length <= 10`; `1 <= wordList.Length <= 5000`; all lowercase.

---

## Approach: BFS with Wildcard Pattern Map — O(m² · n) time, O(m² · n) space ✓

Build a mapping from **wildcard patterns** (`h*t` → [hot, hit]) to their words. BFS explores the graph level by level; the first time `endWord` is reached is the shortest path.

```csharp
public static int LadderLength(string beginWord, string endWord, IList<string> wordList)
{
    int m = beginWord.Length;
    var patternMap = new Dictionary<string, List<string>>();

    foreach (var word in wordList)
    {
        for (int i = 0; i < m; i++)
        {
            string pattern = word[..i] + "*" + word[(i + 1)..];
            if (!patternMap.TryGetValue(pattern, out var list))
                patternMap[pattern] = list = [];
            list.Add(word);
        }
    }

    var visited = new HashSet<string> { beginWord };
    var queue   = new Queue<string>();
    queue.Enqueue(beginWord);
    int steps = 1;

    while (queue.Count > 0)
    {
        int size = queue.Count;
        for (int i = 0; i < size; i++)
        {
            var word = queue.Dequeue();
            for (int j = 0; j < m; j++)
            {
                string pattern = word[..j] + "*" + word[(j + 1)..];
                if (!patternMap.TryGetValue(pattern, out var neighbors)) continue;
                foreach (var neighbor in neighbors)
                {
                    if (neighbor == endWord) return steps + 1;
                    if (visited.Add(neighbor)) queue.Enqueue(neighbor);
                }
            }
        }
        steps++;
    }
    return 0;
}
```

---

## Complexity Summary

| Approach              | Time       | Space      |
|-----------------------|------------|------------|
| BFS + wildcard map    | O(m² · n)  | O(m² · n)  |

*m = word length, n = number of words.*

---

## Interview Tips

- The **wildcard pattern** pre-processing is what avoids O(26·m·n) brute force character substitution.
- Level-by-level BFS guarantees the first time `endWord` is encountered is the shortest path — return immediately.
- **Bidirectional BFS** can reduce to O(m · √n) — mention this as an optimisation for large inputs.
