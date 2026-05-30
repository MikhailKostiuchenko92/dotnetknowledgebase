# Design Add and Search Words Data Structure

**Source:** LeetCode #211
**Difficulty:** 🟡 Medium
**Topics:** Trie, DFS, Backtracking, Design

## Problem Statement

Design a data structure that supports adding new words and searching whether a string matches any previously added word. The search supports `'.'` as a wildcard matching any letter.

```csharp
obj.AddWord("bad");
obj.AddWord("dad");
obj.Search("pad") // false
obj.Search(".ad") // true (bad/dad)
obj.Search("b..") // true (bad)
```

## Constraints

- `1 <= word.Length <= 25`; lowercase letters + `'.'`.

---

## Approach: Trie + DFS for Wildcards — O(m) add, O(26^m) worst-case search

```csharp
public class WordDictionary
{
    private class TrieNode
    {
        public TrieNode?[] Children = new TrieNode[26];
        public bool IsEnd;
    }

    private readonly TrieNode _root = new();

    public void AddWord(string word)
    {
        var node = _root;
        foreach (char c in word)
        {
            int idx = c - 'a';
            node.Children[idx] ??= new TrieNode();
            node = node.Children[idx]!;
        }
        node.IsEnd = true;
    }

    public bool Search(string word) => Dfs(_root, word, 0);

    private static bool Dfs(TrieNode node, string word, int idx)
    {
        if (idx == word.Length) return node.IsEnd;

        char c = word[idx];
        if (c != '.')
        {
            var child = node.Children[c - 'a'];
            return child is not null && Dfs(child, word, idx + 1);
        }
        // Wildcard: try all non-null children
        return node.Children.Any(child => child is not null && Dfs(child, word, idx + 1));
    }
}
```

---

## Complexity Summary

| Operation  | Time      | Space |
|------------|-----------|-------|
| AddWord    | O(m)      | O(m)  |
| Search     | O(26^m) worst (all `.`) | O(m) |

---

## Interview Tips

- The Trie structure is identical to [Implement Trie](../implement-trie/README.md); the only difference is DFS-based wildcard expansion.
- In practice, with few wildcards, search is much faster than O(26^m).
