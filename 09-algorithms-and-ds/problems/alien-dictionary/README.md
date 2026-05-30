# Alien Dictionary

**Source:** LeetCode #269 (Premium) / NeetCode
**Difficulty:** 🔴 Hard
**Topics:** Graph, Topological Sort, DFS, BFS (Kahn's)

## Problem Statement

There is a new alien language that uses the English alphabet. The order of letters is **unknown**. Given a list of strings `words` sorted lexicographically by the alien language, derive the character ordering. If the order is invalid, return `""`.

## Examples

```
Input:  words = ["wrt","wrf","er","ett","rftt"]
Output: "wertf"

Input:  words = ["z","x"]
Output: "zx"

Input:  words = ["z","x","z"]
Output: ""   // cycle detected
```

## Constraints

- `1 <= words.Length <= 100`; `1 <= words[i].Length <= 100`; words only contain lowercase letters.

---

## Approach: Kahn's BFS Topological Sort — O(C) time and space

*C = total characters across all words.*

1. Build directed graph: for each adjacent pair of words, find the **first differing character** → add edge `c1 → c2`.
2. Handle invalid case: if word A is a prefix of shorter word B, return `""`.
3. Run Kahn's BFS topological sort on the character graph.
4. If all characters are processed, return the order; else return `""` (cycle).

```csharp
public static string AlienOrder(string[] words)
{
    // Collect all unique characters
    var adj     = new Dictionary<char, List<char>>();
    var indegree = new Dictionary<char, int>();
    foreach (var w in words)
        foreach (var c in w)
        {
            adj.TryAdd(c, []);
            indegree.TryAdd(c, 0);
        }

    // Build edges from adjacent word pairs
    for (int i = 0; i < words.Length - 1; i++)
    {
        string w1 = words[i], w2 = words[i + 1];
        int minLen = Math.Min(w1.Length, w2.Length);
        bool found = false;

        for (int j = 0; j < minLen; j++)
        {
            if (w1[j] != w2[j])
            {
                adj[w1[j]].Add(w2[j]);
                indegree[w2[j]]++;
                found = true;
                break;
            }
        }
        // Invalid: longer word comes before its prefix
        if (!found && w1.Length > w2.Length) return "";
    }

    // Kahn's BFS
    var queue = new Queue<char>();
    foreach (var (c, deg) in indegree)
        if (deg == 0) queue.Enqueue(c);

    var sb = new System.Text.StringBuilder();
    while (queue.Count > 0)
    {
        char c = queue.Dequeue();
        sb.Append(c);
        foreach (char next in adj[c])
            if (--indegree[next] == 0) queue.Enqueue(next);
    }

    return sb.Length == indegree.Count ? sb.ToString() : "";
}
```

---

## Complexity Summary

| Phase        | Time | Space |
|--------------|------|-------|
| Edge building | O(C) | O(1)  |
| Kahn's BFS   | O(V + E) | O(V + E) |

---

## Interview Tips

- The **prefix trap**: `["abc", "ab"]` — longer word first is immediately invalid.
- Only the **first differing character** per word pair gives an ordering constraint.
- If `result.Length < uniqueChars` at the end → cycle detected → return `""`.
