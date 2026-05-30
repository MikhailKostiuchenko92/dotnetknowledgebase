# Implement Trie (Prefix Tree)

**Source:** LeetCode #208
**Difficulty:** 🟡 Medium
**Topics:** Trie, String, Design

## Problem Statement

Implement a Trie with `insert`, `search`, and `startsWith` methods.

- `insert(word)`: Inserts a word into the trie.
- `search(word)`: Returns `true` if the word is in the trie.
- `startsWith(prefix)`: Returns `true` if any word in the trie starts with `prefix`.

## Examples

```csharp
var trie = new Trie();
trie.Insert("apple");
trie.Search("apple");    // true
trie.Search("app");      // false
trie.StartsWith("app");  // true
trie.Insert("app");
trie.Search("app");      // true
```

## Constraints

- `1 <= word.Length, prefix.Length <= 2000`; lowercase English letters only.

---

## Approach: Array-Based TrieNode — O(m) per operation, O(ALPHABET_SIZE × m × n) space

```csharp
public class Trie
{
    private class TrieNode
    {
        public TrieNode?[] Children = new TrieNode[26];
        public bool IsEnd;
    }

    private readonly TrieNode _root = new();

    public void Insert(string word)
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

    public bool Search(string word)
    {
        var node = FindNode(word);
        return node is not null && node.IsEnd;
    }

    public bool StartsWith(string prefix)
        => FindNode(prefix) is not null;

    private TrieNode? FindNode(string s)
    {
        var node = _root;
        foreach (char c in s)
        {
            int idx = c - 'a';
            if (node.Children[idx] is null) return null;
            node = node.Children[idx]!;
        }
        return node;
    }
}
```

---

## Complexity Summary

| Operation   | Time | Space       |
|-------------|------|-------------|
| Insert      | O(m) | O(m)        |
| Search      | O(m) | O(1)        |
| StartsWith  | O(m) | O(1)        |

*m = word length. Total space O(ALPHABET × m × n) where n = number of words.*

---

## Interview Tips

- **Array vs Dictionary:** Array of 26 is faster (O(1) index) but wastes space for large alphabets. `Dictionary<char, TrieNode>` is more memory-efficient.
- The Trie beats a HashSet for `startsWith` queries — `HashSet<string>` can only do `Contains`, not prefix search.
- **Related:** [Word Search II](../word-search-ii/README.md), [Design Add and Search Words](../design-add-search-words-data-structure/README.md).
